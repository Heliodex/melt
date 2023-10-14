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
	r := gin.New()
	r.Use(gin.Recovery())
	r.SetTrustedProxies([]string{"127.0.0.1"})

	r.GET("/", func(cx *gin.Context) {
		cx.String(200, "Mercury Sync")
	})
	r.GET("/sync", func(cx *gin.Context) {
		fmt.Println(c.InYellow("Syncing..."))

		// Create struct for JSON response
		type File struct {
			Path    []string `json:"path"`
			Content string   `json:"content"`
			Type    string   `json:"type"`
		}
		var Response struct {
			Files []File `json:"files"`
			// Message string `json:"message"`
		}

		usedFilenames := make(map[string]bool)
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
			var scripttype string

			switch strings.ToLower(filepath.Ext(path)) {
			case ".lua":
				filetype = "lua"
			case ".luau":
				filetype = "luau"
			case ".moon":
				filetype = "moon"
			case ".yue":
				filetype = "yue"
			default:
				return nil
			}

			// Trim target directory and extension from path, and remove suffix if it's a server/client script
			formatPath := strings.TrimPrefix(path, target+string(os.PathSeparator))
			formatPath = strings.TrimSuffix(formatPath, "."+filetype)
			if strings.Contains(formatPath, ".") {
				scripttype = strings.Split(formatPath, ".")[1]
				if scripttype == "server" || scripttype == "client" {
					formatPath = strings.Split(formatPath, ".")[0]
				}
			}
			if scripttype == "" {
				// scripttype = "module"
				fmt.Println(c.InRed("Unknown script type: ") + c.InUnderline(c.InPurple(formatPath)) + c.InRed("!"))
				fmt.Println(c.InYellow("If you were trying to sync a ModuleScript, these are not supported by Mercury Sync. Please transpose them manually."))
			}
			formatPath = strings.ReplaceAll(formatPath, string(os.PathSeparator), ".")

			if usedFilenames[formatPath] {
				fmt.Println(c.InRed("Duplicate filename: ") + c.InUnderline(c.InPurple(formatPath)) + c.InRed("! Skipping..."))
				return nil
			}
			usedFilenames[formatPath] = true

			var content string

			switch filetype {
			case "luau":
				fmt.Println(c.InBlue("Compiling ") + c.InUnderline(c.InPurple(formatPath)) + c.InBlue("..."))
				content, err = CompileLuau(path)
				if err != nil {
					fmt.Println(c.InRed("Error while compiling Luau file:"), err)
					if strings.Contains(err.Error(), "file does not exist") ||
						strings.Contains(err.Error(), "no such file or directory") {

						fmt.Println(c.InYellow("Please place a copy of darklua (name \"darklua\" or \"darklua.exe\") in the tools folder."))
					}
					return nil
				}
			default:
				file, err := os.ReadFile(path)
				if err != nil {
					fmt.Println(c.InRed("Error while reading file:"), err)
					return nil
				}
				content = string(file)
			}

			fmt.Println(c.InGreen("Sending ") + c.InUnderline(c.InPurple(formatPath)) + c.InGreen("..."))

			Response.Files = append(Response.Files, File{
				Path:    strings.Split(formatPath, "."),
				Content: strings.ReplaceAll(content, "\r\n", "\n"),
				Type:    scripttype,
			})

			return nil
		})

		os.Remove("./temp.lua")

		cx.JSON(200, Response)
	})

	fmt.Println(c.InBold(c.InGreen("~ Mercury Sync ~")))
	r.Run("0.0.0.0:2013")
}
