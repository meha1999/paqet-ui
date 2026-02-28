package middleware

import (
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func LoggingMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		log.Printf("[%s] %s %s", c.Request.Method, c.Request.RequestURI, c.ClientIP())
		c.Next()
	}
}

func ErrorHandlingMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if len(c.Errors) > 0 {
			err := c.Errors.Last()
			c.JSON(http.StatusBadRequest, gin.H{
				"success": false,
				"message": err.Error(),
			})
		}
	}
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check session or token
		sessionID, err := c.Cookie("session_id")
		if err != nil || sessionID == "" {
			c.Redirect(http.StatusFound, "/panel")
			c.Abort()
			return
		}

		// Validate session (simplified - in production use actual session management)
		if sessionID == "" {
			c.Redirect(http.StatusFound, "/panel")
			c.Abort()
			return
		}

		c.Set("user_id", "1")
		c.Next()
	}
}

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}

func JSONMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if strings.Contains(c.Request.Header.Get("Content-Type"), "application/json") {
			c.Header("Content-Type", "application/json; charset=utf-8")
		}
		c.Next()
	}
}
