package main

import (
	"fmt"
	"os"
	"strings"

	c "github.com/TwiN/go-color"
)

func main() {
	args := os.Args

	if len(args) < 2 {
		Error("No command specified. Run with 'help' to see available commands.")
	}

	switch strings.ToLower(args[1]) {
	case "h", "help":
		fmt.Println(c.InYellow("Usage"))
		fmt.Println(c.InGreen("    [executable] [command] [arguments]\n"))
		fmt.Println(c.InYellow("Commands"))
		fmt.Println(c.InBlue("    h help") + "                  Shows this help message")
		fmt.Println(c.InBlue("    f format [file]") + "         Formats the specified file")
		fmt.Println(c.InBlue("    c compatibility [file]") + "  Makes the specified file compatible with Lua")
	case "f", "format":
		if len(args) < 3 {
			Error("No file specified.")
		}
		format(args[2])
	case "c", "compatibility":
		if len(args) < 3 {
			Error("No file specified.")
		}
		compatify(args[2])
	}
}
