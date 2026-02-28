package web

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"paqet-ui/config"
	"paqet-ui/web/controller"
	"paqet-ui/web/middleware"
	"paqet-ui/web/service"
	"time"

	"github.com/gin-gonic/gin"
)

type Server struct {
	httpServer *http.Server
	config     *config.Config
	router     *gin.Engine
	ctx        context.Context
	cancel     context.CancelFunc
}

func NewServer(cfg *config.Config) *Server {
	ctx, cancel := context.WithCancel(context.Background())
	return &Server{
		config: cfg,
		ctx:    ctx,
		cancel: cancel,
	}
}

func (s *Server) Start() error {
	// Create router
	s.router = gin.Default()

	// Initialize services
	authService := service.NewAuthService()
	configService := service.NewConfigService()
	connectionService := service.NewConnectionService()

	// Apply middleware
	s.router.Use(middleware.LoggingMiddleware())
	s.router.Use(middleware.ErrorHandlingMiddleware())

	// Set up routes
	s.setupRoutes(authService, configService, connectionService)

	// Configure HTTP server
	addr := fmt.Sprintf(":%d", s.config.Port)
	s.httpServer = &http.Server{
		Addr:           addr,
		Handler:        s.router,
		ReadTimeout:    15 * time.Second,
		WriteTimeout:   15 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	log.Printf("Starting Paqet UI Panel on %s%s", addr, s.config.BasePath)

	// Start server in a goroutine
	go func() {
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("Server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	select {
	case <-s.ctx.Done():
		s.Shutdown()
	}

	return nil
}

func (s *Server) setupRoutes(authService *service.AuthService, configService *service.ConfigService, connService *service.ConnectionService) {
	basePath := s.config.BasePath

	// Public routes
	indexCtrl := controller.NewIndexController()
	s.router.GET("/", indexCtrl.Index)
	s.router.GET(basePath+"/", indexCtrl.Index)
	s.router.POST(basePath+"/login", indexCtrl.Login)
	s.router.GET(basePath+"/logout", indexCtrl.Logout)

	// Protected routes
	authGroup := s.router.Group(basePath)
	authGroup.Use(middleware.AuthMiddleware())

	// Panel routes
	panelCtrl := controller.NewPanelController(configService, connService)
	authGroup.GET("/dashboard", panelCtrl.Dashboard)
	authGroup.GET("/configurations", panelCtrl.Configurations)
	authGroup.GET("/connections", panelCtrl.Connections)
	authGroup.GET("/settings", panelCtrl.Settings)

	// API routes
	apiCtrl := controller.NewAPIController(configService, connService)
	api := authGroup.Group("/api")

	// Config API
	api.GET("/configs", apiCtrl.GetConfigs)
	api.POST("/configs", apiCtrl.CreateConfig)
	api.PUT("/configs/:id", apiCtrl.UpdateConfig)
	api.DELETE("/configs/:id", apiCtrl.DeleteConfig)
	api.POST("/configs/:id/test", apiCtrl.TestConfig)
	api.POST("/configs/:id/start", apiCtrl.StartConfig)
	api.POST("/configs/:id/stop", apiCtrl.StopConfig)

	// Connection API
	api.GET("/connections", apiCtrl.GetConnections)
	api.GET("/connections/stats", apiCtrl.GetConnectionStats)

	// Settings API
	api.GET("/settings", apiCtrl.GetSettings)
	api.PUT("/settings", apiCtrl.UpdateSettings)

	// Server status API
	api.GET("/status", apiCtrl.GetServerStatus)

	// WebSocket
	api.GET("/ws", func(c *gin.Context) {
		apiCtrl.WebSocket(c)
	})
}

func (s *Server) Shutdown() error {
	s.cancel()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	log.Println("Shutting down server...")
	return s.httpServer.Shutdown(ctx)
}
