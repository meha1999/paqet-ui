package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"paqet-ui/config"
	"paqet-ui/database"
	"paqet-ui/web"

	"github.com/joho/godotenv"
)

var (
	webPort  int
	showHelp bool
	resetDB  bool
	webPath  string
	username string
	password string
)

func init() {
	flag.IntVar(&webPort, "port", 2053, "Web panel port")
	flag.StringVar(&webPath, "path", "/panel", "Web panel base path")
	flag.StringVar(&username, "username", "admin", "Initial username")
	flag.StringVar(&password, "password", "admin", "Initial password")
	flag.BoolVar(&showHelp, "help", false, "Show help information")
	flag.BoolVar(&resetDB, "reset-db", false, "Reset database")
	flag.Parse()

	if showHelp {
		flag.PrintDefaults()
		os.Exit(0)
	}
}

func main() {
	_ = godotenv.Load(".env")

	// Initialize config
	cfg := config.NewConfig()
	cfg.Port = webPort
	cfg.BasePath = webPath

	// Initialize database
	if resetDB {
		_ = os.Remove(config.GetDBPath())
		fmt.Println("Database reset")
	}

	if err := database.InitDB(config.GetDBPath()); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	// Initialize default user if needed
	if err := database.InitDefaultUser(username, password); err != nil {
		log.Printf("Warning: Failed to initialize default user: %v", err)
	}

	// Start web server
	server := web.NewServer(cfg)
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start web server: %v", err)
	}
}
