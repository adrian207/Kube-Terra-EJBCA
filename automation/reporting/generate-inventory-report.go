package main

import (
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"sort"
	"time"
)

// Configuration
type Config struct {
	KeyfactorHost     string
	KeyfactorUsername string
	KeyfactorPassword string
	KeyfactorDomain   string
	OutputPath        string
}

// Certificate represents a certificate from Keyfactor
type Certificate struct {
	ID           string    `json:"Id"`
	Subject      string    `json:"IssuedDN"`
	Issuer       string    `json:"IssuerDN"`
	Thumbprint   string    `json:"Thumbprint"`
	SerialNumber string    `json:"SerialNumber"`
	NotAfter     time.Time `json:"NotAfter"`
}

// ReportData represents processed certificate data
type ReportData struct {
	Subject         string
	Thumbprint      string
	Issuer          string
	Expiry          string
	DaysUntilExpiry int
	Status          string
	SerialNumber    string
}

// Client handles Keyfactor API interactions
type Client struct {
	config     Config
	httpClient *http.Client
}

// NewClient creates a new Keyfactor API client
func NewClient(config Config) *Client {
	return &Client{
		config: config,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GetAllCertificates retrieves all certificates
func (c *Client) GetAllCertificates() ([]Certificate, error) {
	var allCerts []Certificate
	page := 1
	pageSize := 1000

	for {
		url := fmt.Sprintf("%s/KeyfactorAPI/Certificates?pq.pageReturned=%d&pq.returnLimit=%d",
			c.config.KeyfactorHost, page, pageSize)

		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			return nil, err
		}

		req.SetBasicAuth(
			fmt.Sprintf("%s\\%s", c.config.KeyfactorDomain, c.config.KeyfactorUsername),
			c.config.KeyfactorPassword,
		)
		req.Header.Set("Content-Type", "application/json")

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			body, _ := ioutil.ReadAll(resp.Body)
			return nil, fmt.Errorf("API request failed: %s - %s", resp.Status, string(body))
		}

		var batch []Certificate
		if err := json.NewDecoder(resp.Body).Decode(&batch); err != nil {
			return nil, err
		}

		if len(batch) == 0 {
			break
		}

		allCerts = append(allCerts, batch...)
		log.Printf("Retrieved %d certificates...", len(allCerts))
		page++
	}

	return allCerts, nil
}

// ProcessCertificates converts certificates to report data
func ProcessCertificates(certs []Certificate) []ReportData {
	var reportData []ReportData
	now := time.Now()

	for _, cert := range certs {
		daysUntilExpiry := int(cert.NotAfter.Sub(now).Hours() / 24)

		var status string
		switch {
		case daysUntilExpiry < 0:
			status = "Expired"
		case daysUntilExpiry <= 7:
			status = "Critical (< 7 days)"
		case daysUntilExpiry <= 30:
			status = "Warning (< 30 days)"
		case daysUntilExpiry <= 90:
			status = "Attention (< 90 days)"
		default:
			status = "OK"
		}

		reportData = append(reportData, ReportData{
			Subject:         cert.Subject,
			Thumbprint:      cert.Thumbprint,
			Issuer:          cert.Issuer,
			Expiry:          cert.NotAfter.Format("2006-01-02"),
			DaysUntilExpiry: daysUntilExpiry,
			Status:          status,
			SerialNumber:    cert.SerialNumber,
		})
	}

	return reportData
}

// GenerateCSVReport generates a CSV report
func GenerateCSVReport(reportData []ReportData, outputPath string) (string, error) {
	// Create output directory if it doesn't exist
	if err := os.MkdirAll(outputPath, 0755); err != nil {
		return "", err
	}

	timestamp := time.Now().Format("20060102-150405")
	filename := fmt.Sprintf("%s/inventory-%s.csv", outputPath, timestamp)

	file, err := os.Create(filename)
	if err != nil {
		return "", err
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush()

	// Write header
	header := []string{"Subject", "Thumbprint", "Issuer", "Expiry", "DaysUntilExpiry", "Status", "SerialNumber"}
	if err := writer.Write(header); err != nil {
		return "", err
	}

	// Write data
	for _, row := range reportData {
		record := []string{
			row.Subject,
			row.Thumbprint,
			row.Issuer,
			row.Expiry,
			fmt.Sprintf("%d", row.DaysUntilExpiry),
			row.Status,
			row.SerialNumber,
		}
		if err := writer.Write(record); err != nil {
			return "", err
		}
	}

	log.Printf("CSV report saved: %s", filename)
	return filename, nil
}

// GenerateSummary generates and displays summary statistics
func GenerateSummary(reportData []ReportData) {
	statusCounts := make(map[string]int)

	for _, row := range reportData {
		statusCounts[row.Status]++
	}

	// Sort statuses for consistent output
	var statuses []string
	for status := range statusCounts {
		statuses = append(statuses, status)
	}
	sort.Strings(statuses)

	log.Println("========================================")
	log.Println("Report Summary:")
	log.Printf("  Total: %d", len(reportData))
	for _, status := range statuses {
		log.Printf("  %s: %d", status, statusCounts[status])
	}
	log.Println("========================================")
}

func main() {
	outputPath := flag.String("output", "/var/reports/keyfactor", "Output directory for reports")
	flag.Parse()

	config := Config{
		KeyfactorHost:     os.Getenv("KEYFACTOR_HOST"),
		KeyfactorUsername: os.Getenv("KEYFACTOR_USERNAME"),
		KeyfactorPassword: os.Getenv("KEYFACTOR_PASSWORD"),
		KeyfactorDomain:   os.Getenv("KEYFACTOR_DOMAIN"),
		OutputPath:        *outputPath,
	}

	if config.KeyfactorHost == "" || config.KeyfactorUsername == "" || config.KeyfactorPassword == "" {
		log.Fatal("Missing Keyfactor credentials")
	}

	log.Println("Starting certificate inventory report generation")

	client := NewClient(config)

	certificates, err := client.GetAllCertificates()
	if err != nil {
		log.Fatalf("Failed to retrieve certificates: %v", err)
	}

	log.Printf("Total certificates: %d", len(certificates))

	if len(certificates) == 0 {
		log.Println("No certificates found")
		return
	}

	reportData := ProcessCertificates(certificates)

	reportFile, err := GenerateCSVReport(reportData, config.OutputPath)
	if err != nil {
		log.Fatalf("Failed to generate report: %v", err)
	}

	GenerateSummary(reportData)

	log.Printf("Report generated successfully: %s", reportFile)
}

