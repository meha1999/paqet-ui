package database

import (
	"fmt"
	"paqet-ui/database/model"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

func InitDB(dbPath string) error {
	var err error
	DB, err = gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Auto migrate models
	if err := DB.AutoMigrate(
		&model.User{},
		&model.Configuration{},
		&model.Connection{},
		&model.Log{},
		&model.Setting{},
	); err != nil {
		return fmt.Errorf("failed to migrate database: %w", err)
	}

	return nil
}
func InitDefaultUser(username, password string) error {
	var user model.User
	result := DB.Where("username = ?", username).First(&user)

	if result.Error == gorm.ErrRecordNotFound {
		// Create default user
		user = model.User{
			Username: username,
			Password: hashPassword(password),
		}
		if err := DB.Create(&user).Error; err != nil {
			return err
		}
	}

	return nil
}

func GetDB() *gorm.DB {
	return DB
}
