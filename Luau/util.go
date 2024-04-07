package main

import (
	"fmt"
	"math/rand"
	"os"

	c "github.com/TwiN/go-color"
)

func Error(txt string) {
	fmt.Println(c.InRed("Error: ") + txt)
	os.Exit(1)
}

func Assert(err error, txt string) {
	// so that I don't have to write this every time
	if err != nil {
		fmt.Println(err)
		Error(txt)
	}
}

func randomString(length int) string {
	// generate random unicode string
	var str string
	for i := 0; i < length; i++ {
		str += string(rune(rand.Intn(0x7E-0x21) + 0x21))
	}
	return str
}
