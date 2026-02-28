package controller

import (
	"net/http"
	"paqet-ui/web/service"
	"strconv"

	"github.com/gin-gonic/gin"
)

type APIController struct {
	configService     *service.ConfigService
	connectionService *service.ConnectionService
}

func NewAPIController(configService *service.ConfigService, connService *service.ConnectionService) *APIController {
	return &APIController{
		configService:     configService,
		connectionService: connService,
	}
}

// Configuration API endpoints
func (c *APIController) GetConfigs(ctx *gin.Context) {
	configs, err := c.configService.GetAllConfigs()
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"success": true, "data": configs})
}

func (c *APIController) CreateConfig(ctx *gin.Context) {
	var req struct {
		Name       string `json:"name" binding:"required"`
		Role       string `json:"role" binding:"required"`
		ConfigYAML string `json:"config_yaml" binding:"required"`
	}

	if err := ctx.ShouldBindJSON(&req); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error()})
		return
	}

	config, err := c.configService.CreateConfig(req.Name, req.Role, req.ConfigYAML)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusCreated, gin.H{"success": true, "data": config})
}

func (c *APIController) UpdateConfig(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid ID"})
		return
	}

	var req struct {
		Name       string `json:"name"`
		Role       string `json:"role"`
		ConfigYAML string `json:"config_yaml"`
	}

	if err := ctx.ShouldBindJSON(&req); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": err.Error()})
		return
	}

	config, err := c.configService.UpdateConfig(uint(id), req.Name, req.Role, req.ConfigYAML)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{"success": true, "data": config})
}

func (c *APIController) DeleteConfig(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid ID"})
		return
	}

	if err := c.configService.DeleteConfig(uint(id)); err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{"success": true, "message": "Configuration deleted"})
}

func (c *APIController) TestConfig(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid ID"})
		return
	}

	config, err := c.configService.GetConfig(uint(id))
	if err != nil {
		ctx.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Config not found"})
		return
	}

	valid, msg := c.configService.TestConfig(config.ConfigYAML)
	ctx.JSON(http.StatusOK, gin.H{"success": valid, "message": msg})
}

func (c *APIController) StartConfig(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid ID"})
		return
	}

	// TODO: Actually start the paqet process
	if err := c.configService.SetActive(uint(id), true); err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{"success": true, "message": "Configuration started"})
}

func (c *APIController) StopConfig(ctx *gin.Context) {
	id, err := strconv.ParseUint(ctx.Param("id"), 10, 32)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid ID"})
		return
	}

	// TODO: Actually stop the paqet process
	if err := c.configService.SetActive(uint(id), false); err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{"success": true, "message": "Configuration stopped"})
}

// Connection API endpoints
func (c *APIController) GetConnections(ctx *gin.Context) {
	conns, err := c.connectionService.GetAllConnections()
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"success": true, "data": conns})
}

func (c *APIController) GetConnectionStats(ctx *gin.Context) {
	configID, err := strconv.ParseUint(ctx.Query("config_id"), 10, 32)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid config_id"})
		return
	}

	stats, err := c.connectionService.GetConnectionStats(uint(configID))
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{"success": true, "data": stats})
}

// Settings API endpoints
func (c *APIController) GetSettings(ctx *gin.Context) {
	ctx.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{}})
}

func (c *APIController) UpdateSettings(ctx *gin.Context) {
	ctx.JSON(http.StatusOK, gin.H{"success": true, "message": "Settings updated"})
}

// Server status
func (c *APIController) GetServerStatus(ctx *gin.Context) {
	ctx.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{
		"status":  "running",
		"version": "1.0.0",
		"uptime":  3600,
	}})
}

// WebSocket endpoint
func (c *APIController) WebSocket(ctx *gin.Context) {
	ctx.JSON(http.StatusNotImplemented, gin.H{"message": "WebSocket not yet implemented"})
}
