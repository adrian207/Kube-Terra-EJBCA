package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

// Configuration
type Config struct {
	KeyfactorHost     string
	KeyfactorUsername string
	KeyfactorPassword string
	KeyfactorDomain   string
	WarningDays       int
	CriticalDays      int
	CheckInterval     int // minutes
}

// Certificate represents a certificate from Keyfactor
type Certificate struct {
	ID         string    `json:"Id"`
	Subject    string    `json:"IssuedDN"`
	Thumbprint string    `json:"Thumbprint"`
	NotAfter   time.Time `json:"NotAfter"`
	Locations  []string  `json:"Locations"`
}

// Monitor handles certificate monitoring
type Monitor struct {
	config Config
	client *http.Client
}

// NewMonitor creates a new certificate monitor
func NewMonitor(config Config) *Monitor {
	return &Monitor{
		config: config,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GetCertificates retrieves all certificates from Keyfactor
func (m *Monitor) GetCertificates() ([]Certificate, error) {
	url := fmt.Sprintf("%s/KeyfactorAPI/Certificates", m.config.KeyfactorHost)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	// Set authentication
	req.SetBasicAuth(
		fmt.Sprintf("%s\\%s", m.config.KeyfactorDomain, m.config.KeyfactorUsername),
		m.config.KeyfactorPassword,
	)
	req.Header.Set("Content-Type", "application/json")

	resp, err := m.client.Do(req)
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

// CheckExpiry checks certificate expiry and sends alerts
func (m *Monitor) CheckExpiry(cert Certificate) string {
	now := time.Now()
	daysUntilExpiry := int(cert.NotAfter.Sub(now).Hours() / 24)

	if daysUntilExpiry < 0 {
		log.Printf("🔴 EXPIRED: %s (Expired %d days ago)", cert.Subject, -daysUntilExpiry)
		return "EXPIRED"
	} else if daysUntilExpiry <= m.config.CriticalDays {
		log.Printf("🔴 CRITICAL: %s (Expires in %d days)", cert.Subject, daysUntilExpiry)
		return "CRITICAL"
	} else if daysUntilExpiry <= m.config.WarningDays {
		log.Printf("🟡 WARNING: %s (Expires in %d days)", cert.Subject, daysUntilExpiry)
		return "WARNING"
	}

	return "OK"
}

// SendAlert sends alert to monitoring system
func (m *Monitor) SendAlert(cert Certificate, severity string) error {
	alertURL := os.Getenv("ALERT_WEBHOOK_URL")
	if alertURL == "" {
		return nil // No alert configured
	}

	now := time.Now()
	daysUntilExpiry := int(cert.NotAfter.Sub(now).Hours() / 24)

	payload := map[string]interface{}{
		"severity":        severity,
		"subject":         cert.Subject,
		"thumbprint":      cert.Thumbprint,
		"daysUntilExpiry": daysUntilExpiry,
		"expiryDate":      cert.NotAfter.Format(time.RFC3339),
		"timestamp":       now.Format(time.RFC3339),
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := http.Post(alertURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return fmt.Errorf("alert webhook returned status %d", resp.StatusCode)
	}

	return nil
}

// MonitorLoop runs continuous monitoring
func (m *Monitor) MonitorLoop() {
	ticker := time.NewTicker(time.Duration(m.config.CheckInterval) * time.Minute)
	defer ticker.Stop()

	for {
		log.Println("Starting certificate expiry check...")

		certificates, err := m.GetCertificates()
		if err != nil {
			log.Printf("Error retrieving certificates: %v", err)
			<-ticker.C
			continue
		}

		log.Printf("Retrieved %d certificates", len(certificates))

		// Counters
		expired := 0
		critical := 0
		warning := 0
		ok := 0

		// Check certificates concurrently
		var wg sync.WaitGroup
		semaphore := make(chan struct{}, 10) // Limit concurrency

		for _, cert := range certificates {
			wg.Add(1)
			go func(c Certificate) {
				defer wg.Done()
				semaphore <- struct{}{}        // Acquire
				defer func() { <-semaphore }() // Release

				status := m.CheckExpiry(c)

				switch status {
				case "EXPIRED":
					expired++
					m.SendAlert(c, "CRITICAL")
				case "CRITICAL":
					critical++
					m.SendAlert(c, "CRITICAL")
				case "WARNING":
					warning++
					m.SendAlert(c, "WARNING")
				default:
					ok++
				}
			}(cert)
		}

		wg.Wait()

		// Summary
		log.Println("======================================")
		log.Printf("Expiry Check Summary:")
		log.Printf("  Total: %d", len(certificates))
		log.Printf("  OK: %d", ok)
		log.Printf("  Warning: %d", warning)
		log.Printf("  Critical: %d", critical)
		log.Printf("  Expired: %d", expired)
		log.Println("======================================")

		<-ticker.C
	}
}

func main() {
	config := Config{
		KeyfactorHost:     os.Getenv("KEYFACTOR_HOST"),
		KeyfactorUsername: os.Getenv("KEYFACTOR_USERNAME"),
		KeyfactorPassword: os.Getenv("KEYFACTOR_PASSWORD"),
		KeyfactorDomain:   os.Getenv("KEYFACTOR_DOMAIN"),
		WarningDays:       30,
		CriticalDays:      7,
		CheckInterval:     60, // 1 hour
	}

	if config.KeyfactorHost == "" || config.KeyfactorUsername == "" || config.KeyfactorPassword == "" {
		log.Fatal("Missing Keyfactor credentials")
	}

	log.Println("Starting Certificate Expiry Monitor...")
	log.Printf("Warning threshold: %d days", config.WarningDays)
	log.Printf("Critical threshold: %d days", config.CriticalDays)
	log.Printf("Check interval: %d minutes", config.CheckInterval)

	monitor := NewMonitor(config)
	monitor.MonitorLoop()
}

