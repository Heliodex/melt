package main

import (
	"fmt"
	"os"
	"strings"

	"path/filepath"

	c "github.com/TwiN/go-color"
	"github.com/gin-gonic/gin"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println(c.InRed("No target directory specified!"))
		fmt.Println(c.InBlue("Run 'mercury-sync help' for more information."))
		os.Exit(1)
	}
	target := os.Args[1]

	fi, err := os.Stat(target)
	if err != nil {
		fmt.Println(c.InRed("Target directory ") + c.InUnderline(c.InPurple(target)) + c.InRed(" does not exist!"))
		os.Exit(1)
	}
	if !fi.IsDir() {
		fmt.Println(c.InUnderline(c.InPurple(target)) + c.InRed(" is a file, please choose a directory to sync with!"))
		os.Exit(1)
	}

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()
	r.SetTrustedProxies([]string{"127.0.0.1"})

	r.GET("/", func(cx *gin.Context) {
		cx.String(200, "Mercury Sync")
	})
	r.GET("/sync", func(cx *gin.Context) {
		fmt.Println(c.InYellow("Syncing..."))

		// Create struct for JSON response
		type File struct {
			Path    string
			Content string
		}
		var Response struct {
			Files []File
		}

		// Read files recursively and send them to the client
		fmt.Println(target)
		filepath.Walk(target, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				fmt.Println(c.InRed("Error while reading file:"), err.Error())
				return nil
			}

			if info.IsDir() {
				return nil
			}

			var filetype string

			switch strings.ToLower(filepath.Ext(path)) {
			case ".lua":
				filetype = "lua"
			case ".luau":
				filetype = "luau"
			default:
				return nil
			}

			// Trim target directory and extension from path
			formatPath := strings.TrimPrefix(path, target+string(os.PathSeparator))
			formatPath = strings.TrimSuffix(formatPath, "."+filetype)

			fmt.Println(c.InGreen("Sending ")+c.InUnderline(c.InPurple(formatPath))+c.InGreen("..."))

			file, err := os.Open(path)
			if err != nil {
				fmt.Println(c.InRed("Error while reading file:"), err.Error())
				return nil
			}

			// Parse file contents
			var content string
			buf := make([]byte, 1024)
			for {
				n, _ := file.Read(buf)
				if n == 0 {
					break
				}
				content += string(buf[:n])
			}

			Response.Files = append(Response.Files, File{
				Path:    formatPath,
				Content: content,
			})

			return nil
		})

		cx.JSON(200, Response)
	})

	fmt.Println(c.InBold(c.InGreen("~ Mercury Sync ~")))
	r.Run("0.0.0.0:2013")
}
