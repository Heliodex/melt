package main

import (
	"fmt"
	"os"
	"strings"

	c "github.com/TwiN/go-color"
)

type token struct {
	line   int
	column int
	kind   string
	value  string
}

const (
	EOF     = "EOF"
	INDENT  = "INDENT"
	SPACE   = "SPACE"
	NEWLINE = "NEWLINE"

	// Literals
	IDENTIFIER = "IDENTIFIER"
	NUMBER     = "NUMBER"

	// Operators
	EQUALS = "EQUALS"

	// that's all for now
)

func lex(source string) []token {
	var tokens []token

	last := func(n int) token {
		return tokens[len(tokens)-n]
	}
	line := 1
	column := 0
	addToken := func(kind string, value string) {
		tokens = append(tokens, token{line, column, kind, value})
	}

	for i := 0; i < len(source); i++ {
		char := source[i]
		column++
		switch char {
		case '=':
			addToken(EQUALS, "=")
		case '\n':
			addToken(NEWLINE, "\n")
			line++
			column = 0
		case ' ':
			addToken(SPACE, " ")
		case '\t':
			if len(tokens) == 0 {
				fmt.Println(c.InRed("error bruh"))
				os.Exit(1)
			}
			// only if last token is a newline or an indent
			if last(1).kind == NEWLINE || last(1).kind == INDENT {
				addToken(INDENT, "\t")
			} else {
				addToken(SPACE, "\t")
			}
		default:
			if char >= '0' && char <= '9' {
				// keep going until we hit a non-number
				var number string
				for i < len(source) && source[i] >= '0' && source[i] <= '9' {
					number += string(source[i])
					column++
					i++
				}
				i--
				addToken(NUMBER, number)
			} else if char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' {
				// keep going until we hit a non-letter
				var identifier string
				for i < len(source) && source[i] >= 'a' && source[i] <= 'z' || source[i] >= 'A' && source[i] <= 'Z' {
					identifier += string(source[i])
					column++
					i++
				}
				i--
				addToken(IDENTIFIER, identifier)
			} else {
				fmt.Println(c.InRed("error bruh"))
				os.Exit(1)
			}
		}
	}

	return tokens
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println(c.InRed("No target file specified!"))
		fmt.Println(c.InBlue("Run 'melt-script help' for more information."))
		os.Exit(1)
	}
	target := os.Args[1]

	fi, err := os.Stat(target)
	if err != nil {
		fmt.Println(c.InRed("Target file ") + c.InUnderline(c.InPurple(target)) + c.InRed(" does not exist!"))
		os.Exit(1)
	}
	if fi.IsDir() {
		fmt.Println(c.InUnderline(c.InPurple(target)) + c.InRed(" is a directory, please choose a file to compile!"))
		os.Exit(1)
	}

	source, err := os.ReadFile(target)
	if err != nil {
		fmt.Println(c.InRed("Failed to read target file ") + c.InUnderline(c.InPurple(target)) + c.InRed("!"))
		os.Exit(1)
	}

	// replace \r\n with \n
	sourceString := strings.Replace(string(source), "\r\n", "\n", -1)

	tokens := lex(sourceString)
	// ast := parse(tokens)
	// out := generate(ast)

	for _, token := range tokens {
		fmt.Printf("%d:%d %s %s\n", token.line, token.column, c.InYellow(token.kind), c.InGreen(token.value))
	}

	fmt.Println("success")
}
