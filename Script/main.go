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
	TEXTOPERATOR = "TEXTOPERATOR"
	EQUALS       = "EQUALS"

	PLUS       = "PLUS"
	PLUSPLUS   = "PLUSPLUS"
	PLUSEQUALS = "PLUSEQUALS"

	MINUS       = "MINUS"
	MINUSMINUS  = "MINUSMINUS"
	MINUSEQUALS = "MINUSEQUALS"

	TIMES  = "TIMES"
	DIVIDE = "DIVIDE"
	MODULO = "MODULO"

	// OPEN_BRACE  = "OPEN_BRACE"
	// CLOSE_BRACE = "CLOSE_BRACE"
)

var keywords = map[string]bool{
	"if":       true,
	"elseif":   true,
	"else":     true,
	"loop":     true,
	"for":      true,
	"break":    true,
	"continue": true,
}

var textOperators = map[string]bool{
	"is":  true,
	"and": true,
	"or":  true,
	"not": true,
	// "nand": true,
	// "xor":  true,
	// "nor":  true,
	// "xnor": true,
}

func lex(source string) []token {
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

			if i == len(source) {
				fmt.Println(c.InRed("unclosed string literal"))
				os.Exit(1)
			}

			addToken(STRING, stringLiteral, startLine, startColumn)

		case '+':
			// check if it's a ++ or += or just a +
			if i+1 < len(source) && source[i+1] == '+' {
				addToken(PLUSPLUS, "++")
				i++
				column++
			} else if i+1 < len(source) && source[i+1] == '=' {
				addToken(PLUSEQUALS, "+=")
				i++
				column++
			} else {
				addToken(PLUS, "+")
			}
		case '-':
			// check if it's a -- or -= or just a -
			if i+1 < len(source) && source[i+1] == '-' {
				addToken(MINUSMINUS, "--")
				i++
				column++
			} else if i+1 < len(source) && source[i+1] == '=' {
				addToken(MINUSEQUALS, "-=")
				i++
				column++
			} else {
				addToken(MINUS, "-")
			}
		case '*':
			addToken(TIMES, "*")
		case '/':
			addToken(DIVIDE, "/")
		case '%':
			addToken(MODULO, "%")
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

				for i < len(source) &&
					(source[i] >= 'a' && source[i] <= 'z' ||
						source[i] >= 'A' && source[i] <= 'Z' ||
						source[i] >= '0' && source[i] <= '9') {
					identifierOrKeyword += string(source[i])
					column++
					i++
				}

				if i == len(source) {
					// you can't end a program with an identifier (yet)
					fmt.Println(c.InRed("cant end program with identifier"))
					os.Exit(1)
				}

				column--
				i--

				// check if it's a text operator
				if textOperators[identifierOrKeyword] {
					addToken(TEXTOPERATOR, identifierOrKeyword, startLine, startColumn)
					continue ParseLoop
				}

				// check if it's a keyword
				if keywords[identifierOrKeyword] {
					addToken(KEYWORD, identifierOrKeyword, startLine, startColumn)
					continue ParseLoop
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

func generate(tokens []token) string {
	var output string

	for i := 0; i < len(tokens); i++ {
		currentToken := tokens[i]

		nextToken := func(n int) token {
			// gets the nth token after the current token
			// skips over spaces and newlines
			for i+n < len(tokens) {
				if tokens[i+n].kind == SPACE || tokens[i+n].kind == NEWLINE {
					n++
				} else {
					return tokens[i+n]
				}
			}
			return token{}
		}

		usedIdentifiers := map[string]bool{}

		switch currentToken.kind {
		case NEWLINE:
			output += "\n"
		case INDENT:
			output += "\t"
		case NUMBER:
			output += currentToken.value
		case STRING:
			output += fmt.Sprintf("\"%s\"", currentToken.value)
		case IDENTIFIER:
			nextKind := nextToken(1).kind
			switch nextKind {
			case EQUALS:
				// variable assignment
				if !usedIdentifiers[currentToken.value] {
					output += "local "
				}
				output += currentToken.value
				usedIdentifiers[currentToken.value] = true
			case PLUSPLUS:
				output += currentToken.value + " = " + currentToken.value + " + 1"
				i++
			case MINUSMINUS:
				output += currentToken.value + " = " + currentToken.value + " - 1"
				i++
			default:
				output += currentToken.value + " "
			}
		case EQUALS:
			output += " = "
		case COMMENT:
			output += " --" + currentToken.value
		case TEXTOPERATOR:
			switch currentToken.value {
			case "is":
				output += "== "
			default:
				output += currentToken.value
			}
		// case KEYWORD:
		// 	switch currentToken.value {
		// 	case "loop":
		// 		output += "while true do"
		// 	default:
		// 		output += currentToken.value
		// 	}
		// 	output += " "
		}
	}

	return output
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
	// remove trailing newlines
	sourceString = strings.TrimRight(sourceString, "\n")

	tokens := lex(sourceString)

	for _, token := range tokens {
		if token.kind == "SPACE" {
			continue
		}
		if token.kind == "NEWLINE" {
			fmt.Println("────────────────┼───────────────┼─────────────────────────────")
			continue
		}
		toPrint := []any{
			fmt.Sprintf("%s:%d:%d", target, token.line, token.column),
			c.InYellow(token.kind),
			c.InPurple(token.value),
		}

		// print in a nice format
		fmt.Printf("%-15s │ %-22s │ %s\n", toPrint...)
	}

	out := generate(tokens)

	fmt.Println(out)
}
