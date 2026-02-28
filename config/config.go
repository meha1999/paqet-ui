package config

import (
	"os"
	"path/filepath"
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

func GetDBPath() string {
	dbDir := filepath.Join(os.Getenv("HOME"), ".paqet-ui")
	if _, err := os.Stat(dbDir); os.IsNotExist(err) {
		_ = os.MkdirAll(dbDir, 0755)
	}
	return filepath.Join(dbDir, "paqet-ui.db")
}
