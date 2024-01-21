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
	COMMENT    = "COMMENT"
	STRING     = "STRING"
	KEYWORD    = "KEYWORD"

	// Operators
	EQUALS = "EQUALS"

	// OPEN_BRACE  = "OPEN_BRACE"
	// CLOSE_BRACE = "CLOSE_BRACE"
)

func lex(source string) []token {
	keywords := map[string]bool{
		"if":       true,
		"elseif":   true,
		"else":     true,
		"loop":     true,
		"for":      true,
		"break":    true,
		"continue": true,
	}

	var tokens []token

	last := func(n int) token {
		return tokens[len(tokens)-n]
	}
	line := 1
	column := 0

	addToken := func(kind string, value string, linecol ...int) {
		currentLine := line
		currentColumn := column
		if len(linecol) > 0 {
			currentLine = linecol[0]
		}
		if len(linecol) > 1 {
			currentColumn = linecol[1]
		}
		tokens = append(tokens, token{currentLine, currentColumn, kind, value})
	}

ParseLoop:
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
			// only if last token is a newline or an indent
			if last(1).kind == NEWLINE || last(1).kind == INDENT {
				addToken(INDENT, "\t")
				column += 3
			} else {
				addToken(SPACE, "\t")
			}
		case ';':
			// parse till end of line
			startColumn := column
			i++ // skip the semicolon
			var comment string
			for i < len(source) && source[i] != '\n' {
				comment += string(source[i])
				column++
				i++
			}
			column--
			i--
			addToken(COMMENT, comment, line, startColumn)
		case '"':
			startLine := line
			startColumn := column

			var stringLiteral string
			
			column++
			i++ // skip the first quote
			for i < len(source) && source[i] != '"' {
				stringLiteral += string(source[i])
				column++
				i++
			}

			addToken(STRING, stringLiteral, startLine, startColumn)
		default:
			if char >= '0' && char <= '9' {
				startLine := line
				startColumn := column

				var number string

				// keep going until we hit a non-number
				for i < len(source) && source[i] >= '0' && source[i] <= '9' {
					number += string(source[i])
					column++
					i++
				}
				column--
				i--
				addToken(NUMBER, number, startLine, startColumn)
			} else if char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' {
				startLine := line
				startColumn := column
				// keep going until we hit a non-letter
				var identifierOrKeyword string

				for i < len(source) && (source[i] >= 'a' && source[i] <= 'z' || source[i] >= 'A' && source[i] <= 'Z') {
					identifierOrKeyword += string(source[i])
					column++
					i++
				}
				column--
				i--

				// check if it's a keyword
				if keywords[identifierOrKeyword] {
					addToken(KEYWORD, identifierOrKeyword, startLine, startColumn)
					continue ParseLoop
				}

				if i == len(source) {
					// you can't end a program with an identifier (yet)
					fmt.Println(c.InRed("cant end program with identifier"))
					os.Exit(1)
				}

				addToken(IDENTIFIER, identifierOrKeyword, startLine, startColumn)
			} else {
				fmt.Println(c.InRed("that isnt a valid character"), c.InYellow(string(char)))
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
	// out := generate(tokens)

	for _, token := range tokens {
		if token.kind == "SPACE" {
			continue
		}
		if token.kind == "NEWLINE" {
			fmt.Println("──────┼─────────────┼─────────────────────────────")
			continue
		}
		toPrint := []string{
			fmt.Sprintf("%d:%d", token.line, token.column),
			c.InYellow(token.kind),
			c.InPurple(token.value),
		}

		// print in a nice format
		fmt.Printf("%-5s │ %-20s │ %s\n", toPrint[0], toPrint[1], toPrint[2])
	}
}
