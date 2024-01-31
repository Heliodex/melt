package main

import (
	"os"
	"os/exec"
)

func CompileLuau(sourcePath string) (string, error) {
	path, err := exec.LookPath("./tools/darklua")
	if err != nil {
		return "", err
	}

	cmd := exec.Command(path, "process", sourcePath, "./temp.lua")
	err = cmd.Run()
	if err != nil {
		return "", err
	}

	// Return the compiled file
	file, _ := os.ReadFile("./temp.lua")

	return string(file), nil
}
