package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"
)

// Configuration
type Config struct {
	KeyfactorHost     string
	KeyfactorUsername string
	KeyfactorPassword string
	KeyfactorDomain   string
	ThresholdDays     int
	DryRun            bool
}

// Certificate represents a certificate from Keyfactor
type Certificate struct {
	ID        string    `json:"Id"`
	Subject   string    `json:"IssuedDN"`
	NotAfter  time.Time `json:"NotAfter"`
	Locations []Location `json:"Locations"`
}

// Location represents a certificate store location
type Location struct {
	ID    string `json:"Id"`
	Name  string `json:"Name"`
	Alias string `json:"Alias"`
}

// RenewRequest represents renewal request payload
type RenewRequest struct {
	CertificateID  string `json:"CertificateId"`
	UseExistingCSR bool   `json:"UseExistingCSR"`
}

// DeployRequest represents deployment request payload
type DeployRequest struct {
	CertificateID string `json:"CertificateId"`
	StoreID       string `json:"StoreId"`
	Alias         string `json:"Alias"`
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

// makeRequest creates and executes an HTTP request with authentication
func (c *Client) makeRequest(method, url string, body interface{}) (*http.Response, error) {
	var reqBody []byte
	var err error

	if body != nil {
		reqBody, err = json.Marshal(body)
		if err != nil {
			return nil, err
		}
	}

	req, err := http.NewRequest(method, url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, err
	}

	// Set authentication
	req.SetBasicAuth(
		fmt.Sprintf("%s\\%s", c.config.KeyfactorDomain, c.config.KeyfactorUsername),
		c.config.KeyfactorPassword,
	)
	req.Header.Set("Content-Type", "application/json")

	return c.httpClient.Do(req)
}

// GetExpiringCertificates retrieves certificates expiring within threshold
func (c *Client) GetExpiringCertificates() ([]Certificate, error) {
	expiryDate := time.Now().AddDate(0, 0, c.config.ThresholdDays).Format("2006-01-02")
	url := fmt.Sprintf("%s/KeyfactorAPI/Certificates?pq.queryString=NotAfter<=%s", 
		c.config.KeyfactorHost, expiryDate)

	resp, err := c.makeRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := ioutil.ReadAll(resp.Body)
		return nil, fmt.Errorf("API request failed: %s - %s", resp.Status, string(body))
	}

	var certificates []Certificate
	if err := json.NewDecoder(resp.Body).Decode(&certificates); err != nil {
		return nil, err
	}

	return certificates, nil
}

// RenewCertificate renews a certificate
func (c *Client) RenewCertificate(certID string) error {
	url := fmt.Sprintf("%s/KeyfactorAPI/Certificates/%s/Renew", c.config.KeyfactorHost, certID)

	renewReq := RenewRequest{
		CertificateID:  certID,
		UseExistingCSR: false,
	}

	resp, err := c.makeRequest("POST", url, renewReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := ioutil.ReadAll(resp.Body)
		return fmt.Errorf("renewal failed: %s - %s", resp.Status, string(body))
	}

	log.Printf("Certificate %s renewed successfully", certID)
	return nil
}

// GetCertificateLocations retrieves stores where certificate is deployed
func (c *Client) GetCertificateLocations(certID string) ([]Location, error) {
	url := fmt.Sprintf("%s/KeyfactorAPI/Certificates/%s/Locations", c.config.KeyfactorHost, certID)

	resp, err := c.makeRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get locations: %s", resp.Status)
	}

	var locations []Location
	if err := json.NewDecoder(resp.Body).Decode(&locations); err != nil {
		return nil, err
	}

	return locations, nil
}

// DeployCertificate deploys certificate to a store
func (c *Client) DeployCertificate(certID string, location Location) error {
	url := fmt.Sprintf("%s/KeyfactorAPI/Certificates/%s/Deploy", c.config.KeyfactorHost, certID)

	deployReq := DeployRequest{
		CertificateID: certID,
		StoreID:       location.ID,
		Alias:         location.Alias,
	}

	resp, err := c.makeRequest("POST", url, deployReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := ioutil.ReadAll(resp.Body)
		return fmt.Errorf("deployment failed: %s - %s", resp.Status, string(body))
	}

	log.Printf("Certificate deployed to store: %s", location.Name)
	return nil
}

func main() {
	thresholdDays := flag.Int("threshold", 30, "Days until expiry threshold")
	dryRun := flag.Bool("dry-run", false, "Dry run mode (no actual renewal)")
	flag.Parse()

	config := Config{
		KeyfactorHost:     os.Getenv("KEYFACTOR_HOST"),
		KeyfactorUsername: os.Getenv("KEYFACTOR_USERNAME"),
		KeyfactorPassword: os.Getenv("KEYFACTOR_PASSWORD"),
		KeyfactorDomain:   os.Getenv("KEYFACTOR_DOMAIN"),
		ThresholdDays:     *thresholdDays,
		DryRun:            *dryRun,
	}

	if config.KeyfactorHost == "" || config.KeyfactorUsername == "" || config.KeyfactorPassword == "" {
		log.Fatal("Missing Keyfactor credentials")
	}

	log.Println("Starting certificate renewal process")
	log.Printf("Threshold: %d days", config.ThresholdDays)
	if config.DryRun {
		log.Println("Running in DRY RUN mode")
	}

	client := NewClient(config)

	// Get expiring certificates
	certificates, err := client.GetExpiringCertificates()
	if err != nil {
		log.Fatalf("Failed to get expiring certificates: %v", err)
	}

	log.Printf("Found %d expiring certificates", len(certificates))

	renewed := 0
	failed := 0

	for _, cert := range certificates {
		log.Printf("Processing: %s (Expires: %s)", cert.Subject, cert.NotAfter.Format("2006-01-02"))

		if !config.DryRun {
			// Renew certificate
			if err := client.RenewCertificate(cert.ID); err != nil {
				log.Printf("Failed to renew certificate %s: %v", cert.ID, err)
				failed++
				continue
			}
			renewed++

			// Get stores where certificate is deployed
			locations, err := client.GetCertificateLocations(cert.ID)
			if err != nil {
				log.Printf("Failed to get locations: %v", err)
				continue
			}

			log.Printf("Deploying to %d stores", len(locations))
			for _, location := range locations {
				if err := client.DeployCertificate(cert.ID, location); err != nil {
					log.Printf("Failed to deploy to %s: %v", location.Name, err)
				}
			}

			// Rate limiting
			time.Sleep(2 * time.Second)
		} else {
			log.Printf("Would renew: %s", cert.Subject)
		}
	}

	// Summary
	log.Println("========================================")
	log.Println("Renewal Summary:")
	log.Printf("  Certificates found: %d", len(certificates))
	log.Printf("  Successfully renewed: %d", renewed)
	log.Printf("  Failed: %d", failed)
	log.Println("========================================")
}

