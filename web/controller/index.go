package controller

import (
	"net/http"
	"paqet-ui/web/service"

	"github.com/gin-gonic/gin"
)

type IndexController struct{}

func NewIndexController() *IndexController {
	return &IndexController{}
}

func (c *IndexController) Index(ctx *gin.Context) {
	// Redirect to panel if logged in, otherwise show login
	sessionID, err := ctx.Cookie("session_id")
	if err == nil && sessionID != "" {
		ctx.Redirect(http.StatusFound, "/panel/dashboard")
		return
	}

	ctx.HTML(http.StatusOK, "login.html", gin.H{
		"title": "Paqet UI - Login",
	})
}

func (c *IndexController) Login(ctx *gin.Context) {
	username := ctx.PostForm("username")
	password := ctx.PostForm("password")

	if username == "" || password == "" {
		ctx.HTML(http.StatusUnauthorized, "login.html", gin.H{
			"error": "Username and password are required",
		})
		return
	}

	authService := service.NewAuthService()
	user, err := authService.Login(username, password)
	if err != nil {
		ctx.HTML(http.StatusUnauthorized, "login.html", gin.H{
			"error": err.Error(),
		})
		return
	}

	// Set session cookie
	ctx.SetCookie("session_id", "user_"+string(rune(user.ID)), 3600*24, "/", "", false, true)

	ctx.Redirect(http.StatusFound, "/panel/dashboard")
}

func (c *IndexController) Logout(ctx *gin.Context) {
	ctx.SetCookie("session_id", "", -1, "/", "", false, true)
	ctx.Redirect(http.StatusFound, "/")
}
