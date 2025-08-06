package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

const (
	// IMDSv2 token endpoint
	tokenURL = "http://169.254.169.254/latest/api/token"
	// Spot interruption notice endpoint
	interruptionURL = "http://169.254.169.254/latest/meta-data/spot/instance-action"
	// Rebalance recommendation endpoint
	rebalanceURL = "http://169.254.169.254/latest/meta-data/events/recommendations/rebalance"
	// Check interval
	checkInterval = 5 * time.Second
)

// SpotInterruptionNotice represents the spot instance interruption notice
type SpotInterruptionNotice struct {
	Action string    `json:"action"`
	Time   time.Time `json:"time"`
}

// RebalanceRecommendation represents the rebalance recommendation
type RebalanceRecommendation struct {
	NoticeTime time.Time `json:"noticeTime"`
}

func getIMDSToken() (string, error) {
	req, err := http.NewRequest("PUT", tokenURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("X-aws-ec2-metadata-token-ttl-seconds", "21600") // 6 hours

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	token, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(token), nil
}

func checkMetadata(token string, ntfyTopic string) {
	// Check for spot interruption notice
	req, _ := http.NewRequest("GET", interruptionURL, nil)
	req.Header.Set("X-aws-ec2-metadata-token", token)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err == nil && resp.StatusCode == 200 {
		defer resp.Body.Close()
		var notice SpotInterruptionNotice
		err = json.NewDecoder(resp.Body).Decode(&notice)
		if err == nil {
			log.Printf("SPOT INTERRUPTION NOTICE: Action: %s, Time: %s", notice.Action, notice.Time)
			err = SendNtfyNotification(NtfyMessage{
				Topic:   ntfyTopic,
				Title:   "EC2 Spot Instance Interruption",
				Message: "Spot instance interruption notice received",
				Tags:    "info,cloud",
			})
			if err != nil {
				log.Printf("Failed to send ntfy notification: %v", err)
			}
		}
	} else {
		log.Printf("No spot interruption notice found or error: %v", err)
	}

	// Check for rebalance recommendation
	req, _ = http.NewRequest("GET", rebalanceURL, nil)
	req.Header.Set("X-aws-ec2-metadata-token", token)

	resp, err = client.Do(req)
	if err == nil && resp.StatusCode == 200 {
		defer resp.Body.Close()
		var rebalance RebalanceRecommendation
		if err = json.NewDecoder(resp.Body).Decode(&rebalance); err == nil {
			log.Printf("REBALANCE RECOMMENDATION: Notice Time: %s", rebalance.NoticeTime)
			err = SendNtfyNotification(NtfyMessage{
				Topic:   ntfyTopic,
				Title:   "EC2 Rebalance Recommendation",
				Message: "Instance received rebalance recommendation",
				Tags:    "info,cloud",
			})
			if err != nil {
				log.Printf("Failed to send ntfy notification: %v", err)
			}
		}
	} else {
		log.Printf("No rebalance recommendation found or error: %v", err)
	}
}

type NtfyMessage struct {
	Topic    string `json:"-"` // Topic is part of URL, not body
	Title    string `json:"title,omitempty"`
	Message  string `json:"message"`
	Priority int    `json:"priority,omitempty"` // 1-5 (low to high)
	Tags     string `json:"tags,omitempty"`
	Click    string `json:"click,omitempty"`
	Actions  string `json:"actions,omitempty"`
	Email    string `json:"email,omitempty"`
	Delay    string `json:"delay,omitempty"`
	Icon     string `json:"icon,omitempty"`
	Markdown bool   `json:"markdown,omitempty"`
}

// SendNtfyNotification sends a notification to ntfy.sh
func SendNtfyNotification(msg NtfyMessage) error {
	if msg.Topic == "" {
		return fmt.Errorf("topic cannot be empty")
	}

	url := fmt.Sprintf("https://ntfy.sh/%s", msg.Topic)

	payload, err := json.Marshal(msg)
	if err != nil {
		return fmt.Errorf("error marshalling message: %v", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(payload))
	if err != nil {
		return fmt.Errorf("error creating request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("error sending notification: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("error response from ntfy.sh: %s, status code: %d", string(body), resp.StatusCode)
	}

	return nil
}

func main() {
	log.Println("EC2 Interruption Monitor starting...")

	ntfyTopic := os.Getenv("NTFY_TOPIC")
	if ntfyTopic == "" {
		log.Fatal("NTFY_TOPIC environment variable is not set")
	}

	log.Println("Using ntfy topic:", ntfyTopic)

	// Setup signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Ticker for regular checks
	ticker := time.NewTicker(checkInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			token, err := getIMDSToken()
			if err != nil {
				log.Printf("Error getting IMDSv2 token: %v", err)
				continue
			}
			checkMetadata(token, ntfyTopic)
		case sig := <-sigChan:
			log.Printf("Received signal %v, shutting down", sig)
			return
		}
	}
}
