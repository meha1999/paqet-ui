package controller

import (
	"net/http"
	"paqet-ui/web/service"

	"github.com/gin-gonic/gin"
)

type PanelController struct {
	configService     *service.ConfigService
	connectionService *service.ConnectionService
}

func NewPanelController(configService *service.ConfigService, connService *service.ConnectionService) *PanelController {
	return &PanelController{
		configService:     configService,
		connectionService: connService,
	}
}

func (c *PanelController) Dashboard(ctx *gin.Context) {
	// Get active config
	activeConfig, _ := c.configService.GetActive()

	// Get stats
	var stats map[string]interface{}
	if activeConfig != nil {
		stats, _ = c.connectionService.GetConnectionStats(activeConfig.ID)
	}

	ctx.HTML(http.StatusOK, "dashboard.html", gin.H{
		"title":         "Dashboard",
		"active_config": activeConfig,
		"stats":         stats,
	})
}

func (c *PanelController) Configurations(ctx *gin.Context) {
	configs, _ := c.configService.GetAllConfigs()

	ctx.HTML(http.StatusOK, "configurations.html", gin.H{
		"title":          "Configurations",
		"configurations": configs,
	})
}

func (c *PanelController) Connections(ctx *gin.Context) {
	conns, _ := c.connectionService.GetAllConnections()

	ctx.HTML(http.StatusOK, "connections.html", gin.H{
		"title":       "Connections",
		"connections": conns,
	})
}

func (c *PanelController) Settings(ctx *gin.Context) {
	ctx.HTML(http.StatusOK, "settings.html", gin.H{
		"title": "Settings",
	})
}
