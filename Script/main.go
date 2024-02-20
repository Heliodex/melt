package main

import (
	"fmt"
	"os"
	"strings"

	c "github.com/TwiN/go-color"
)

type Token struct {
	kind   string
	value  string
	line   int
	column int
}

type Node interface{}

// Who needs statements when you can have expressions?
type Expr interface {
	Node
}

type ExprProps struct {
	startToken Token
}

// type Identifier struct {
// 	*ExprProps
// 	name string
// }

// type AssignmentExpr struct {
// 	*ExprProps
// 	left  Expr
// 	right Expr
// }

// type BinaryExpr struct {
// 	*ExprProps
// 	left  Expr
// 	right Expr
// }

// type UnaryExpr struct {
// 	*ExprProps
// 	expr Expr
// }

type IfExpr struct {
	*ExprProps
	condition Expr
	block     BlockExpr
}

type ElseIfExpr struct {
	*ExprProps
	condition Expr
	block     BlockExpr
}

type ElseExpr struct {
	*ExprProps
	block BlockExpr
}

type BlockExpr struct {
	*ExprProps
	expressions []Expr
}

const (
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
}

func generate(program []Expr) string {
	var output string

	for i := 0; i < len(program); i++ {
		var expr = program[i]

		fmt.Println(expr)
	}

	return output
}

func parse(tokens []Token) []Expr {
	var program []Expr

	addExpr := func(expr Expr) {
		program = append(program, expr)
	}

	for i := 0; i < len(tokens); i++ {
		token := tokens[i]
		currentIndent := 0

		getBlock := func() []Token {
			// get tokens until the end of the block (which is the same indent level as the if statement)
			var blockTokens []Token
			blockIndent := 0

			// skip newline at start
			i++

			for i < len(tokens) {
				if tokens[i].kind == NEWLINE {
					blockIndent = 0
					// check next few tokens to see if they're indented
					for j := i + 1; j < len(tokens) && tokens[j].kind == INDENT; j++ {
						blockIndent++
					}
					if blockIndent <= currentIndent {
						break
					}
				}
				blockTokens = append(blockTokens, tokens[i])
				i++
			}

			return blockTokens
		}

		getCondition := func() []Token {
			var condTokens []Token

			// skip the keyword
			i++

			// get all tokens until the end of the line
			for i < len(tokens) && tokens[i+1].kind != NEWLINE {
				i++
				condTokens = append(condTokens, tokens[i])
			}

			// skip the newline
			i++

			return condTokens
		}

		props :=
			&ExprProps{
				startToken: token,
			}

		switch token.kind {
		case INDENT:
			currentIndent++
		case NEWLINE:
			currentIndent = 0
		case KEYWORD:
			switch token.value {
			case "if":
				condTokens := getCondition()
				blockTokens := getBlock()

				addExpr(IfExpr{
					ExprProps: props,
					condition: parse(condTokens),
					block: BlockExpr{
						ExprProps:   props,
						expressions: parse(blockTokens),
					},
				})
			case "elseif":
				condTokens := getCondition()
				blockTokens := getBlock()

				addExpr(ElseIfExpr{
					ExprProps: props,
					condition: parse(condTokens),
					block: BlockExpr{ExprProps: props,
						expressions: parse(blockTokens),
					},
				})
			case "else":
				// skip newline
				i++

				blockTokens := getBlock()

				addExpr(ElseExpr{
					ExprProps: props,
					block: BlockExpr{
						ExprProps:   props,
						expressions: parse(blockTokens),
					},
				})
			}
		}
	}

	return program
}

func lex(source string) []Token {
	var tokens []Token

	last := func(n int) Token {
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

		tokens = append(tokens, Token{
			kind:   kind,
			value:  value,
			line:   currentLine,
			column: currentColumn,
		})
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

				var number string // lele

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

				var identifierOrKeyword string

				// keep going until we hit a non-letter
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
					continue
				}

				// check if it's a keyword
				if keywords[identifierOrKeyword] {
					addToken(KEYWORD, identifierOrKeyword, startLine, startColumn)
					continue
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
	// remove trailing newlines
	sourceString = strings.TrimRight(sourceString, "\n")

	tokens := lex(sourceString)

	for _, token := range tokens {
		if token.kind == SPACE {
			continue
		}
		if token.kind == NEWLINE {
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

	program := parse(tokens)

	out := generate(program)

	fmt.Println(out)
}
