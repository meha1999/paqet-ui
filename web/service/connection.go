package service

import (
	"paqet-ui/database"
	"paqet-ui/database/model"
	"time"
)

type ConnectionService struct{}

func NewConnectionService() *ConnectionService {
	return &ConnectionService{}
}

func (s *ConnectionService) GetAllConnections() ([]model.Connection, error) {
	var conns []model.Connection
	if err := database.GetDB().Preload("Configuration").Find(&conns).Error; err != nil {
		return nil, err
	}
	return conns, nil
}

func (s *ConnectionService) GetConnectionsByConfig(configID uint) ([]model.Connection, error) {
	var conns []model.Connection
	if err := database.GetDB().Where("config_id = ?", configID).Find(&conns).Error; err != nil {
		return nil, err
	}
	return conns, nil
}

func (s *ConnectionService) GetConnection(id uint) (*model.Connection, error) {
	var conn model.Connection
	if err := database.GetDB().Preload("Configuration").First(&conn, id).Error; err != nil {
		return nil, err
	}
	return &conn, nil
}

func (s *ConnectionService) CreateConnection(configID uint, status string) (*model.Connection, error) {
	conn := model.Connection{
		ConfigID:       configID,
		Status:         status,
		LastActivityAt: time.Now(),
	}

	if err := database.GetDB().Create(&conn).Error; err != nil {
		return nil, err
	}

	return &conn, nil
}

func (s *ConnectionService) UpdateConnectionStatus(id uint, status string) error {
	return database.GetDB().Model(&model.Connection{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":           status,
		"last_activity_at": time.Now(),
	}).Error
}

func (s *ConnectionService) UpdateConnectionTraffic(id uint, bytesIn, bytesOut int64) error {
	return database.GetDB().Model(&model.Connection{}).Where("id = ?", id).Updates(map[string]interface{}{
		"bytes_in":         bytesIn,
		"bytes_out":        bytesOut,
		"last_activity_at": time.Now(),
	}).Error
}

func (s *ConnectionService) LogActivity(conID uint, message string) error {
	log := model.Log{
		Level:   "info",
		Message: message,
		Source:  "connection",
	}
	return database.GetDB().Create(&log).Error
}

func (s *ConnectionService) GetConnectionStats(configID uint) (map[string]interface{}, error) {
	conns, err := s.GetConnectionsByConfig(configID)
	if err != nil {
		return nil, err
	}

	stats := map[string]interface{}{
		"total_connections": len(conns),
		"active":            0,
		"stopped":           0,
		"total_bytes_in":    int64(0),
		"total_bytes_out":   int64(0),
		"uptime":            0,
	}

	var totalBytesIn, totalBytesOut int64
	for _, conn := range conns {
		if conn.Status == "running" {
			stats["active"] = stats["active"].(int) + 1
		} else if conn.Status == "stopped" {
			stats["stopped"] = stats["stopped"].(int) + 1
		}
		totalBytesIn += conn.BytesIn
		totalBytesOut += conn.BytesOut
	}

	stats["total_bytes_in"] = totalBytesIn
	stats["total_bytes_out"] = totalBytesOut

	return stats, nil
}
