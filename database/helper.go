package database

import (
	"crypto/sha256"
	"fmt"
	"time"
)

func hashPassword(password string) string {
	hash := sha256.Sum256([]byte(password + "paqet-ui-salt"))
	return fmt.Sprintf("%x", hash)
}

func HashPassword(password string) string {
	return hashPassword(password)
}

func VerifyPassword(password, hash string) bool {
	return hashPassword(password) == hash
}

func GetTimePtr() *time.Time {
	now := time.Now()
	return &now
}
