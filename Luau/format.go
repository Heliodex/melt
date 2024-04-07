package main

import (
	luau "Luau/binding"
	"context"
	"fmt"
	"os"
	"strings"

	c "github.com/TwiN/go-color"
	sitter "github.com/smacker/go-tree-sitter"
)

func isInside(ntype string, node *sitter.Node) bool {
	for node != nil {
		if node.Type() == ntype {
			return true
		}
		node = node.Parent()
	}
	return false
}

func formatCode(sourceCode []byte, tree *sitter.Tree) string {
	node := tree.RootNode()
	if node.HasError() {
		fmt.Println("Error parsing code")
		return string(sourceCode)
	}

	var formatted strings.Builder
	indent := 0
	// -1 means at the start of the file
	// 0 means outside of a local var statement
	// 1 means inside a local var statement
	var insideLocal []bool
	var insideComment []bool

	writeIndent := func() {
		formatted.WriteString(strings.Repeat("\t", indent))
	}

	writeFormatted := func(node sitter.Node) {
		// Write the formatted content to the string builder
		content := node.Content(sourceCode)
		ntype := node.Type()

		insideLocal = append(insideLocal, isInside("local_var_stmt", &node))
		insideComment = append(insideComment, isInside("comment", &node))

		parent := node.Parent()

		switch ntype {
		case "comment":
			if len(insideComment) > 1 && !insideComment[len(insideComment)-2] {
				formatted.WriteString("\n")
			}
			formatted.WriteString("\n")
			writeIndent()
			formatted.WriteString(content)

		case "local":
			if len(insideLocal) > 1 && !insideLocal[len(insideLocal)-2] &&
				len(insideComment) > 1 && !insideComment[len(insideComment)-2] {
				formatted.WriteString("\n")
			}
			formatted.WriteString("\n")
			writeIndent()
			formatted.WriteString("local ")

		case "name":
			fmt.Println(parent.Parent().Type(), node.Content(sourceCode))
			if ((parent.Parent().Type() == "call_stmt" && *parent.Child(0) == node) ||
				parent.Parent().Type() == "var_stmt" ||
				parent.Parent().Parent().Type() == "assign_stmt") &&
				!isInside("local_var_stmt", &node) &&
				!isInside("ifexp", &node) &&
				!isInside("binexp", &node) {
				if len(insideLocal) > 1 && insideLocal[len(insideLocal)-2] {
					formatted.WriteString("\n")
				}
				formatted.WriteString("\n")
				writeIndent()
			}
			formatted.WriteString(content)

		case "=":
			formatted.WriteString(" = ")
		case "==":
			formatted.WriteString(" == ")
		case "number":
			formatted.WriteString(content)
		case "return":
			formatted.WriteString("\n")
			writeIndent()
			formatted.WriteString("return ")
		case "if":
			ifType := parent.Type()
			switch ifType {
			case "if_stmt":
				formatted.WriteString("\n")
				writeIndent()
				fallthrough
			case "ifexp":
				formatted.WriteString("if ")
			default:
				// damn better be unreachable
				panic(c.InRed("Unknown if type ") + c.InYellow(ifType))
			}
		case "then":
			ifType := parent.Type()
			switch ifType {
			case "if_stmt":
				formatted.WriteString(" then")
				indent++
			case "ifexp":
				formatted.WriteString(" then ")
			case "elseif_clause":
				formatted.WriteString(" then")
			default:
				panic(c.InRed("Unknown if type ") + c.InYellow(ifType))
			}
		case "elseif":
			pType := parent.Type()
			// if it's in a statement, the parent will be the elseif clause
			// if it's in an expression, the parent will be the if expression
			var ifType string
			switch pType {
			case "elseif_clause":
				ifType = parent.Parent().Type()
			case "ifexp":
				ifType = pType
			default:
				panic(c.InRed("Unknown parent type ") + c.InYellow(pType))
			}

			switch ifType {
			case "if_stmt":
				formatted.WriteString("\n")
				indent--
				writeIndent()
				formatted.WriteString("elseif ")
				indent++
			case "ifexp":
				formatted.WriteString(" elseif ")
			default:
				panic(c.InRed("Unknown if type ") + c.InYellow(ifType))
			}
		case "else":
			pType := parent.Type()
			// if it's in a statement, the parent will be the else clause
			// if it's in an expression, the parent will be the if expression
			var ifType string
			switch pType {
			case "else_clause":
				ifType = parent.Parent().Type()
			case "ifexp":
				ifType = pType
			default:
				panic(c.InRed("Unknown parent type ") + c.InYellow(pType))
			}

			switch ifType {
			case "if_stmt":
				formatted.WriteString("\n")
				indent--
				writeIndent()
				formatted.WriteString("else")
				indent++
			case "ifexp":
				formatted.WriteString(" else ")
			default:
				panic(c.InRed("Unknown if type ") + c.InYellow(ifType))
			}
		case "end":
			formatted.WriteString("\n")
			indent--
			writeIndent()
			formatted.WriteString("end")
		case "string":
			if parent.Type() == "arglist" && parent.ChildCount() == 1 {
				// `print"whatever"` -> `print "whatever"`
				formatted.WriteString(" ")
			}
			formatted.WriteString(content)
		case "interp_start", "interp_end":
			formatted.WriteString("`")
		case "interp_content":
			formatted.WriteString(content)
		case "interp_brace_open":
			formatted.WriteString("{")
		case "interp_brace_close":
			formatted.WriteString("}")
		case ":":
			formatted.WriteString(":")
		case ".":
			formatted.WriteString(".")
		case "(":
			argType := parent.Child(1).Type()
			// `print("whatever")` -> `print "whatever"`
			if parent.Type() == "arglist" && parent.ChildCount() > 3 || argType != "string" && argType != "table" {
				formatted.WriteString("(")
			} else {
				formatted.WriteString(" ")
			}
		case ")":
			argType := parent.Child(1).Type()
			// `print("whatever")` -> `print "whatever"`
			if parent.Type() == "arglist" && parent.ChildCount() > 3 || argType != "string" && argType != "table" {
				formatted.WriteString(")")
			}
		case ",":
			formatted.WriteString(", ")
		case "true":
			formatted.WriteString("true")
		case "false":
			formatted.WriteString("false")
		case "+":
			formatted.WriteString(" + ")
		case "-":
			formatted.WriteString(" - ")
		case "*":
			formatted.WriteString(" * ")
		case "/":
			formatted.WriteString(" / ")
		case "%":
			formatted.WriteString(" % ")
		case "^":
			formatted.WriteString(" ^ ")
		case "//":
			formatted.WriteString(" // ")
		case "+=":
			formatted.WriteString(" += ")
		case "-=":
			formatted.WriteString(" -= ")
		case "*=":
			formatted.WriteString(" *= ")
		case "/=":
			formatted.WriteString(" /= ")
		case "%=":
			formatted.WriteString(" %= ")
		case "^=":
			formatted.WriteString(" ^= ")
		case "//=":
			formatted.WriteString(" //= ")
		case ";":
			// nothing
		default:
			panic(c.InRed("Unknown node type ") + c.InYellow(ntype))
		}
	}

	var appendLeaf func(node sitter.Node)
	appendLeaf = func(node sitter.Node) {
		// Print only the leaf nodes
		if node.ChildCount() == 0 {
			writeFormatted(node)
		} else {
			for i := 0; i < int(node.ChildCount()); i++ {
				appendLeaf(*(node.Child(i)))
			}
		}
	}

	appendLeaf(*node)

	return formatted.String()
}

func format(filename string) {
	parser := sitter.NewParser()
	parser.SetLanguage(luau.GetLuau())

	sourceCode, err := os.ReadFile(filename)
	if err != nil {
		fmt.Println(err)
		return
	}

	tree, _ := parser.ParseCtx(context.Background(), nil, sourceCode)
	formatted := formatCode(sourceCode, tree)

	// replace all ending newlines with a single newline
	formatted = strings.Trim(formatted, "\n") + "\n"

	// write back to file
	err = os.WriteFile(filename, []byte(formatted), 0o644)
	if err != nil {
		fmt.Println(err)
		return
	}
}
