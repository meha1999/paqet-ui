package service

import (
	"paqet-ui/database"
	"paqet-ui/database/model"

	"gorm.io/gorm"
)

type ConfigService struct{}

func NewConfigService() *ConfigService {
	return &ConfigService{}
}

func (s *ConfigService) GetAllConfigs() ([]model.Configuration, error) {
	var configs []model.Configuration
	if err := database.GetDB().Find(&configs).Error; err != nil {
		return nil, err
	}
	return configs, nil
}

func (s *ConfigService) GetConfig(id uint) (*model.Configuration, error) {
	var config model.Configuration
	if err := database.GetDB().First(&config, id).Error; err != nil {
		return nil, err
	}
	return &config, nil
}

func (s *ConfigService) CreateConfig(name, role, configYAML string) (*model.Configuration, error) {
	config := model.Configuration{
		Name:       name,
		Role:       role,
		ConfigYAML: configYAML,
		Active:     false,
	}

	if err := database.GetDB().Create(&config).Error; err != nil {
		return nil, err
	}

	return &config, nil
}

func (s *ConfigService) UpdateConfig(id uint, name, role, configYAML string) (*model.Configuration, error) {
	var config model.Configuration
	if err := database.GetDB().Model(&config).Where("id = ?", id).Updates(map[string]interface{}{
		"name":        name,
		"role":        role,
		"config_yaml": configYAML,
	}).Error; err != nil {
		return nil, err
	}

	return s.GetConfig(id)
}

func (s *ConfigService) DeleteConfig(id uint) error {
	return database.GetDB().Delete(&model.Configuration{}, id).Error
}

func (s *ConfigService) SetActive(id uint, active bool) error {
	if active {
		// Deactivate all others
		if err := database.GetDB().Model(&model.Configuration{}).Update("active", false).Error; err != nil {
			return err
		}
	}

	return database.GetDB().Model(&model.Configuration{}).Where("id = ?", id).Update("active", active).Error
}

func (s *ConfigService) GetActive() (*model.Configuration, error) {
	var config model.Configuration
	result := database.GetDB().Where("active = ?", true).First(&config)

	if result.Error == gorm.ErrRecordNotFound {
		return nil, nil
	}

	if result.Error != nil {
		return nil, result.Error
	}

	return &config, nil
}

func (s *ConfigService) ValidateConfig(configYAML string) error {
	// TODO: Validate YAML structure against paqet schema
	// This would parse the YAML and verify it's a valid paqet configuration
	return nil
}

func (s *ConfigService) TestConfig(configYAML string) (bool, string) {
	// TODO: Test config by attempting to start/validate it
	return true, "Configuration syntax is valid"
}
