package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"bytes"
)

// Configuration
type Config struct {
	Port          string
	WebhookSecret string
	SlackWebhook  string
}

// WebhookPayload represents incoming webhook data
type WebhookPayload struct {
	EventType    string                 `json:"eventType"`
	Timestamp    string                 `json:"timestamp"`
	CertificateID string                `json:"certificateId"`
	Data         map[string]interface{} `json:"data"`
}

// VerifyHMAC verifies the HMAC signature
func VerifyHMAC(payload []byte, signature string, secret string) bool {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expectedMAC := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(signature), []byte(expectedMAC))
}

// SendSlackNotification sends notification to Slack
func SendSlackNotification(webhookURL string, event WebhookPayload) error {
	var color string
	var emoji string

	switch event.EventType {
	case "CertificateExpired":
		color = "danger"
		emoji = ":rotating_light:"
	case "CertificateExpiring":
		color = "warning"
		emoji = ":warning:"
	case "CertificateRenewed":
		color = "good"
		emoji = ":white_check_mark:"
	default:
		color = "#36a64f"
		emoji = ":information_source:"
	}

	subject := ""
	if data, ok := event.Data["subject"].(string); ok {
		subject = data
	}

	message := map[string]interface{}{
		"text": fmt.Sprintf("%s Keyfactor Certificate Event", emoji),
		"attachments": []map[string]interface{}{
			{
				"color": color,
				"fields": []map[string]interface{}{
					{
						"title": "Event Type",
						"value": event.EventType,
						"short": true,
					},
					{
						"title": "Certificate ID",
						"value": event.CertificateID,
						"short": true,
					},
					{
						"title": "Subject",
						"value": subject,
						"short": false,
					},
					{
						"title": "Timestamp",
						"value": event.Timestamp,
						"short": false,
					},
				},
			},
		},
	}

	jsonData, err := json.Marshal(message)
	if err != nil {
		return err
	}

	resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := ioutil.ReadAll(resp.Body)
		return fmt.Errorf("slack notification failed: %s - %s", resp.Status, string(body))
	}

	return nil
}

// WebhookHandler handles incoming webhook requests
func WebhookHandler(config Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Read body
		body, err := ioutil.ReadAll(r.Body)
		if err != nil {
			log.Printf("Error reading body: %v", err)
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		defer r.Body.Close()

		// Verify HMAC signature
		signature := r.Header.Get("X-Keyfactor-Signature")
		if config.WebhookSecret != "" {
			if signature == "" {
				log.Println("Missing signature header")
				http.Error(w, "Unauthorized - Missing signature", http.StatusUnauthorized)
				return
			}

			if !VerifyHMAC(body, signature, config.WebhookSecret) {
				log.Println("Invalid HMAC signature")
				http.Error(w, "Unauthorized - Invalid signature", http.StatusUnauthorized)
				return
			}
		}

		// Parse payload
		var payload WebhookPayload
		if err := json.Unmarshal(body, &payload); err != nil {
			log.Printf("Error parsing JSON: %v", err)
			http.Error(w, "Bad request", http.StatusBadRequest)
			return
		}

		log.Printf("Received event: %s (Cert ID: %s)", payload.EventType, payload.CertificateID)

		// Route event
		switch payload.EventType {
		case "CertificateIssued":
			log.Println("Handling CertificateIssued event")
			// Add custom logic here
		case "CertificateRenewed":
			log.Println("Handling CertificateRenewed event")
			// Trigger deployment pipeline
		case "CertificateExpiring":
			log.Println("Handling CertificateExpiring event")
			// Send notification
			if config.SlackWebhook != "" {
				if err := SendSlackNotification(config.SlackWebhook, payload); err != nil {
					log.Printf("Failed to send Slack notification: %v", err)
				}
			}
		case "CertificateExpired":
			log.Println("Handling CertificateExpired event - CRITICAL")
			// Create incident
			if config.SlackWebhook != "" {
				if err := SendSlackNotification(config.SlackWebhook, payload); err != nil {
					log.Printf("Failed to send Slack notification: %v", err)
				}
			}
		case "CertificateRevoked":
			log.Println("Handling CertificateRevoked event")
			// Remove from stores
		default:
			log.Printf("Unknown event type: %s", payload.EventType)
		}

		// Return success
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"status":  "success",
			"message": "Event processed",
		})
	}
}

// HealthCheckHandler provides health check endpoint
func HealthCheckHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
	})
}

func main() {
	config := Config{
		Port:          os.Getenv("PORT"),
		WebhookSecret: os.Getenv("WEBHOOK_SECRET"),
		SlackWebhook:  os.Getenv("SLACK_WEBHOOK_URL"),
	}

	if config.Port == "" {
		config.Port = "8080"
	}

	http.HandleFunc("/webhook", WebhookHandler(config))
	http.HandleFunc("/health", HealthCheckHandler)

	log.Printf("Starting webhook receiver on port %s...", config.Port)
	if err := http.ListenAndServe(":"+config.Port, nil); err != nil {
		log.Fatal(err)
	}
}

