package model

import (
	"time"

	"gorm.io/gorm"
)

// User model for authentication
type User struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Username  string    `gorm:"uniqueIndex;not null" json:"username"`
	Password  string    `gorm:"not null" json:"-"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Configuration model for paqet configuration
type Configuration struct {
	ID         uint           `gorm:"primaryKey" json:"id"`
	Name       string         `gorm:"not null;index" json:"name"`
	Role       string         `gorm:"not null" json:"role"` // client or server
	ConfigYAML string         `gorm:"type:text" json:"config_yaml"`
	Active     bool           `gorm:"default:false" json:"active"`
	CreatedAt  time.Time      `json:"created_at"`
	UpdatedAt  time.Time      `json:"updated_at"`
	DeletedAt  gorm.DeletedAt `gorm:"index" json:"-"`
}

// Connection model for tracking active connections
type Connection struct {
	ID             uint `gorm:"primaryKey" json:"id"`
	ConfigID       uint `gorm:"not null;index" json:"config_id"`
	Configuration  Configuration `gorm:"foreignKey:ConfigID;references:ID" json:"configuration,omitempty"`
	Status         string    `gorm:"not null" json:"status"` // running, stopped, error
	BytesIn        int64     `json:"bytes_in"`
	BytesOut       int64     `json:"bytes_out"`
	LastActivityAt time.Time `json:"last_activity_at"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// Log model for operation logs
type Log struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Level     string    `json:"level"` // info, warn, error
	Message   string    `gorm:"type:text" json:"message"`
	Source    string    `json:"source"`
	CreatedAt time.Time `json:"created_at"`
}

// Setting model for panel settings
type Setting struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Key       string    `gorm:"uniqueIndex;not null" json:"key"`
	Value     string    `gorm:"type:text" json:"value"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
