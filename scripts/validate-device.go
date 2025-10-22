// Go Asset Validation Tool
// File: /opt/keyfactor/scripts/validate-device.go
// Author: Adrian Johnson <adrian207@gmail.com>
//
// Build:
//   go build -o validate-device validate-device.go
//
// Usage:
//   ./validate-device webapp01.contoso.com
//   Output: AUTHORIZED|team-web-apps|production|12345
//
//   ./validate-device nonexistent.contoso.com
//   Output: DENIED|Device not found
//   Exit Code: 1

package main

import (
	"context"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/lib/pq" // PostgreSQL driver
)

// AssetInfo represents device/asset metadata
type AssetInfo struct {
	Exists      bool
	OwnerEmail  string
	OwnerTeam   string
	Environment string
	CostCenter  string
	Status      string
}

// Config holds application configuration
type Config struct {
	CSVPath           string
	CachePath         string
	CacheTimeoutSecs  int
	DBHost            string
	DBName            string
	DBUser            string
	DBPassword        string
	SnowInstance      string
	SnowUser          string
	SnowPassword      string
	AzureSubscription string
}

// LoadConfig loads configuration from environment or defaults
func LoadConfig() *Config {
	return &Config{
		CSVPath:           getEnv("ASSET_CSV_PATH", "/opt/keyfactor/asset-inventory/asset-inventory.csv"),
		CachePath:         getEnv("ASSET_CACHE_PATH", "/tmp/asset-inventory-cache.json"),
		CacheTimeoutSecs:  3600,
		DBHost:            getEnv("ASSET_DB_HOST", "asset-db.contoso.com"),
		DBName:            "asset_inventory",
		DBUser:            getEnv("ASSET_DB_USER", "keyfactor_reader"),
		DBPassword:        os.Getenv("ASSET_DB_PASSWORD"),
		SnowInstance:      getEnv("SNOW_INSTANCE", "contoso.service-now.com"),
		SnowUser:          getEnv("SNOW_USER", "keyfactor-api"),
		SnowPassword:      os.Getenv("SNOW_PASSWORD"),
		AzureSubscription: os.Getenv("AZURE_SUBSCRIPTION_ID"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// ValidateFromCSV checks CSV file for hostname
func ValidateFromCSV(hostname string, config *Config) (*AssetInfo, error) {
	// Check cache first
	if isCacheFresh(config.CachePath, config.CacheTimeoutSecs) {
		if asset, err := loadFromCache(config.CachePath, hostname); err == nil && asset != nil {
			return asset, nil
		}
	}

	// Load CSV
	file, err := os.Open(config.CSVPath)
	if err != nil {
		return nil, fmt.Errorf("CSV file not found: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("failed to read CSV: %w", err)
	}

	// Build cache
	cache := make(map[string]*AssetInfo)
	headers := records[0]

	for _, record := range records[1:] {
		if len(record) < len(headers) {
			continue
		}

		asset := &AssetInfo{}
		for i, header := range headers {
			switch header {
			case "hostname":
				if record[i] != "" {
					asset.Exists = true
				}
			case "owner_email":
				asset.OwnerEmail = record[i]
			case "owner_team":
				asset.OwnerTeam = record[i]
			case "environment":
				asset.Environment = record[i]
			case "cost_center":
				asset.CostCenter = record[i]
			case "status":
				asset.Status = record[i]
			}
		}

		if asset.Status == "active" {
			cache[record[0]] = asset // record[0] is hostname
		}
	}

	// Save cache
	saveCache(config.CachePath, cache)

	// Lookup hostname
	if asset, ok := cache[hostname]; ok {
		return asset, nil
	}

	return nil, nil
}

// ValidateFromDatabase queries PostgreSQL database
func ValidateFromDatabase(hostname string, config *Config) (*AssetInfo, error) {
	if config.DBPassword == "" {
		return nil, fmt.Errorf("database password not set")
	}

	connStr := fmt.Sprintf("host=%s dbname=%s user=%s password=%s sslmode=disable connect_timeout=5",
		config.DBHost, config.DBName, config.DBUser, config.DBPassword)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := "SELECT * FROM get_asset($1)"
	row := db.QueryRowContext(ctx, query, hostname)

	var asset AssetInfo
	var dbHostname string
	err = row.Scan(&dbHostname, &asset.OwnerEmail, &asset.OwnerTeam, &asset.Environment, &asset.CostCenter, &asset.Status)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	asset.Exists = true
	return &asset, nil
}

// ServiceNowResponse represents ServiceNow API response
type ServiceNowResponse struct {
	Result []struct {
		Name         string `json:"name"`
		OwnedBy      struct {
			Value string `json:"value"`
		} `json:"owned_by"`
		SupportGroup struct {
			DisplayValue string `json:"display_value"`
		} `json:"support_group"`
		Environment string `json:"environment"`
		CostCenter  string `json:"cost_center"`
	} `json:"result"`
}

// ServiceNowUserResponse for owner email lookup
type ServiceNowUserResponse struct {
	Result struct {
		Email string `json:"email"`
	} `json:"result"`
}

// ValidateFromServiceNow queries ServiceNow CMDB
func ValidateFromServiceNow(hostname string, config *Config) (*AssetInfo, error) {
	if config.SnowPassword == "" {
		return nil, fmt.Errorf("ServiceNow password not set")
	}

	url := fmt.Sprintf("https://%s/api/now/table/cmdb_ci_server?sysparm_query=name=%s^operational_status=1&sysparm_fields=name,owned_by,support_group,environment,cost_center",
		config.SnowInstance, hostname)

	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	req.SetBasicAuth(config.SnowUser, config.SnowPassword)
	req.Header.Set("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("ServiceNow API returned %d", resp.StatusCode)
	}

	var snowResp ServiceNowResponse
	if err := json.NewDecoder(resp.Body).Decode(&snowResp); err != nil {
		return nil, err
	}

	if len(snowResp.Result) == 0 {
		return nil, nil
	}

	ci := snowResp.Result[0]

	// Get owner email
	ownerURL := fmt.Sprintf("https://%s/api/now/table/sys_user/%s", config.SnowInstance, ci.OwnedBy.Value)
	ownerReq, _ := http.NewRequest("GET", ownerURL, nil)
	ownerReq.SetBasicAuth(config.SnowUser, config.SnowPassword)
	ownerReq.Header.Set("Accept", "application/json")

	ownerResp, err := client.Do(ownerReq)
	if err != nil {
		return nil, err
	}
	defer ownerResp.Body.Close()

	var ownerData ServiceNowUserResponse
	json.NewDecoder(ownerResp.Body).Decode(&ownerData)

	return &AssetInfo{
		Exists:      true,
		OwnerEmail:  ownerData.Result.Email,
		OwnerTeam:   ci.SupportGroup.DisplayValue,
		Environment: ci.Environment,
		CostCenter:  ci.CostCenter,
		Status:      "active",
	}, nil
}

// ValidateFromKubernetes checks Kubernetes namespace labels
func ValidateFromKubernetes(hostname string) (*AssetInfo, error) {
	if !strings.HasSuffix(hostname, ".svc.cluster.local") {
		return nil, nil
	}

	parts := strings.Split(hostname, ".")
	if len(parts) < 4 || parts[2] != "svc" {
		return nil, nil
	}

	namespace := parts[1]

	// Call kubectl (requires kubectl in PATH)
	// In production, use Kubernetes Go client library
	cmd := fmt.Sprintf("kubectl get namespace %s -o json 2>/dev/null", namespace)
	output, err := execCommand(cmd)
	if err != nil {
		return nil, nil
	}

	var ns struct {
		Status struct {
			Phase string `json:"phase"`
		} `json:"status"`
		Metadata struct {
			Labels      map[string]string `json:"labels"`
			Annotations map[string]string `json:"annotations"`
		} `json:"metadata"`
	}

	if err := json.Unmarshal([]byte(output), &ns); err != nil {
		return nil, err
	}

	if ns.Status.Phase != "Active" {
		return nil, nil
	}

	ownerEmail := ns.Metadata.Annotations["owner-email"]
	if ownerEmail == "" {
		ownerEmail = ns.Metadata.Labels["owner"]
	}
	if ownerEmail == "" {
		ownerEmail = "unknown@contoso.com"
	}

	return &AssetInfo{
		Exists:      true,
		OwnerEmail:  ownerEmail,
		OwnerTeam:   ns.Metadata.Labels["team"],
		Environment: ns.Metadata.Labels["environment"],
		CostCenter:  ns.Metadata.Labels["cost-center"],
		Status:      "active",
	}, nil
}

// Helper functions

func isCacheFresh(cachePath string, timeoutSecs int) bool {
	info, err := os.Stat(cachePath)
	if err != nil {
		return false
	}
	age := time.Since(info.ModTime())
	return age.Seconds() < float64(timeoutSecs)
}

func loadFromCache(cachePath, hostname string) (*AssetInfo, error) {
	data, err := ioutil.ReadFile(cachePath)
	if err != nil {
		return nil, err
	}

	var cache map[string]*AssetInfo
	if err := json.Unmarshal(data, &cache); err != nil {
		return nil, err
	}

	if asset, ok := cache[hostname]; ok {
		return asset, nil
	}

	return nil, nil
}

func saveCache(cachePath string, cache map[string]*AssetInfo) error {
	data, err := json.MarshalIndent(cache, "", "  ")
	if err != nil {
		return err
	}

	return ioutil.WriteFile(cachePath, data, 0644)
}

func execCommand(cmd string) (string, error) {
	// Simple command execution - in production use exec.Command
	// This is a placeholder
	return "", fmt.Errorf("not implemented")
}

// Main validation logic

func validateHostname(hostname string, config *Config) (*AssetInfo, error) {
	// Try sources in order

	// 1. ServiceNow CMDB
	if config.SnowPassword != "" {
		if asset, err := ValidateFromServiceNow(hostname, config); err == nil && asset != nil {
			return asset, nil
		}
	}

	// 2. Database
	if config.DBPassword != "" {
		if asset, err := ValidateFromDatabase(hostname, config); err == nil && asset != nil {
			return asset, nil
		}
	}

	// 3. Kubernetes (if applicable)
	if strings.HasSuffix(hostname, ".svc.cluster.local") {
		if asset, err := ValidateFromKubernetes(hostname); err == nil && asset != nil {
			return asset, nil
		}
	}

	// 4. CSV (fallback)
	if asset, err := ValidateFromCSV(hostname, config); err == nil && asset != nil {
		return asset, nil
	}

	return nil, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <hostname> [requester_email]\n", filepath.Base(os.Args[0]))
		os.Exit(2)
	}

	hostname := os.Args[1]
	config := LoadConfig()

	asset, err := validateHostname(hostname, config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "DENIED|Validation error: %v\n", err)
		os.Exit(1)
	}

	if asset != nil && asset.Exists && asset.Status == "active" {
		fmt.Printf("AUTHORIZED|%s|%s|%s\n", asset.OwnerTeam, asset.Environment, asset.CostCenter)
		os.Exit(0)
	}

	fmt.Printf("DENIED|Device '%s' not found in any inventory source\n", hostname)
	os.Exit(1)
}

