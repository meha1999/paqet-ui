package service

import (
	"errors"
	"paqet-ui/database"
	"paqet-ui/database/model"
)

type AuthService struct{}

func NewAuthService() *AuthService {
	return &AuthService{}
}

func (s *AuthService) Login(username, password string) (*model.User, error) {
	var user model.User
	result := database.GetDB().Where("username = ?", username).First(&user)

	if result.Error != nil {
		return nil, errors.New("invalid credentials")
	}

	if !database.VerifyPassword(password, user.Password) {
		return nil, errors.New("invalid credentials")
	}

	return &user, nil
}

func (s *AuthService) Register(username, password string) (*model.User, error) {
	var existing model.User
	result := database.GetDB().Where("username = ?", username).First(&existing)

	if result.Error == nil {
		return nil, errors.New("username already exists")
	}

	user := model.User{
		Username: username,
		Password: database.hashPassword(password),
	}

	if err := database.GetDB().Create(&user).Error; err != nil {
		return nil, err
	}

	return &user, nil
}

func (s *AuthService) GetUser(userID uint) (*model.User, error) {
	var user model.User
	if err := database.GetDB().First(&user, userID).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (s *AuthService) UpdatePassword(userID uint, oldPassword, newPassword string) error {
	user, err := s.GetUser(userID)
	if err != nil {
		return err
	}

	if !database.VerifyPassword(oldPassword, user.Password) {
		return errors.New("old password is incorrect")
	}

	return database.GetDB().Model(user).Update("password", database.hashPassword(newPassword)).Error
}

// Unexport hashPassword by delegating to database package
var hashPassword = func(password string) string {
	// This should be called from database package
	return ""
}
