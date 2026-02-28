package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port       int
	BasePath   string
	CertFile   string
	KeyFile    string
	SSLEnabled bool
}

func NewConfig() *Config {
	return &Config{
		Port:       2053,
		BasePath:   "/panel",
		SSLEnabled: false,
	}
}

func GetDatabaseURL() string {
	// Build PostgreSQL DSN from environment variables
	user := os.Getenv("DATABASE_USER")
	if user == "" {
		user = "paqet"
	}
	password := os.Getenv("DATABASE_PASSWORD")
	if password == "" {
		password = "paqet"
	}
	host := os.Getenv("DATABASE_HOST")
	if host == "" {
		host = "localhost"
	}
	port := os.Getenv("DATABASE_PORT")
	if port == "" {
		port = "5432"
	}
	dbname := os.Getenv("DATABASE_NAME")
	if dbname == "" {
		dbname = "paqet_ui"
	}

	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)
}

// Deprecated: Use GetDatabaseURL() instead
func GetDBPath() string {
	return ""
}
