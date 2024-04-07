package main

import (
	luau "Luau/binding"
	"context"
	"fmt"
	"math/rand"
	"os"
	"strings"

	c "github.com/TwiN/go-color"
	sitter "github.com/smacker/go-tree-sitter"
)

func randomString(length int) string {
	// generate random unicode string
	var str string
	for i := 0; i < length; i++ {
		str += string(rune(rand.Intn(0x7E-0x21) + 0x21))
	}
	return str
}

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
			if parent.Parent().Type() == "call_stmt" && !isInside("local_var_stmt", &node) {
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
		case "interp_start":
			fallthrough
		case "interp_end":
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

func compatibility(sourceCode []byte, tree *sitter.Tree) string {
	node := tree.RootNode()
	if node.HasError() {
		fmt.Println("Error parsing code")
		return string(sourceCode)
	}

	// watch out for passing by reference
	newSource := make([]byte, len(sourceCode))
	copy(newSource, sourceCode)

	type sub struct {
		node      *sitter.Node
		toReplace string
	}
	var toSub []sub

	var findExprs func(node sitter.Node)
	findExprs = func(node sitter.Node) {
		start := node.StartByte()
		end := node.EndByte()
		rand := randomString(int(end - start))
		ntype := node.Type()

		if ntype == "ifexp" || (ntype == "binexp" && node.Child(1).Type() == "//") || (ntype == "var_stmt" && node.Child(1).Type() == "//=") {
			// replace unsupported statements/expressions with a random string
			newSource = append(newSource[:start], append([]byte(rand), newSource[end:]...)...)
			toSub = append(toSub, sub{&node, rand})
		} else {
			for i := range int(node.ChildCount()) {
				findExprs(*(node.Child(i)))
			}
		}
	}

	findExprs(*node)
	sourceString := string(newSource)

	for _, s := range toSub {
		var replacement string

		node := s.node
		ntype := node.Type()

		switch ntype {
		case "ifexp":
			fmt.Println(c.InBlue("replacing"))
			secondCond := node.Child(3).Type()
			hasElseIf := node.Child(4).Type() == "elseif"

			if !hasElseIf && map[string]bool{
				"number":        true,
				"string":        true,
				"string_interp": true,
				"true":          true, // lelel
			}[secondCond] {
				// SPECIAL CASE: the second condition is guaranteed to be truthy
				// this means it can be simplified to Lua's sorta-ternary operator, a and b or c

				// doesn't simplify nested if expressions. GOOD ENOUGH
				for i := range int(node.ChildCount()) {
					child := node.Child(i)
					fmt.Println(child.Type())
					switch child.Type() {
					case "then":
						replacement += "and "
					case "else":
						replacement += "or "
					case "elseif":
						panic("elseif in special case")
					case "if":
						// nothing
					default:
						replacement += child.Content(sourceCode) + " "
					}
				}
			} else {
				replacement += "(function()"
				for i := range int(node.ChildCount()) {
					child := node.Child(i)
					fmt.Println(child.Type())
					switch child.Type() {
					case "if", "elseif", "then":
						replacement += child.Content(sourceCode) + " "
					case "else":
						replacement += "end "
					default:
						prev := node.Child(i - 1).Type()
						if prev == "then" || prev == "else" {
							replacement += "return "
						}
						replacement += child.Content(sourceCode) + " "
					}
				}
				replacement += "end)()"
			}
		case "binexp":
			// child 1 is the operator (//)
			left := node.Child(0).Content(sourceCode)
			right := node.Child(2).Content(sourceCode)
			replacement = fmt.Sprintf("math.floor(%s/%s)", left, right)
		case "var_stmt":
			// child 1 is the operator (//=)
			left := node.Child(0).Content(sourceCode)
			right := node.Child(2).Content(sourceCode)

			// todo: make it so if one of the exprs is a function it don't get evaluated twice
			// nah jk im not doing that
			replacement = fmt.Sprintf("%s=math.floor(%s/%s)", left, left, right)
		default:
			panic("unhandled node type " + ntype)
		}

		sourceString = strings.Replace(sourceString, s.toReplace, replacement, 1)
	}

	return sourceString
}

func main() {
	binding := luau.GetLuau()

	filename := "test.luau"

	sourceCode, err := os.ReadFile(filename)
	if err != nil {
		fmt.Println(err)
		return
	}

	code := string(sourceCode)

	// keep parsing until no changes are made lmao
	for {
		parser := sitter.NewParser()
		parser.SetLanguage(binding)

		newSource := []byte(code)
		tree, err := parser.ParseCtx(context.Background(), nil, newSource)
		if err != nil {
			fmt.Println(err)
			return
		}
		compatible := compatibility(newSource, tree)
		// replace all ending newlines with a single newline
		compatible = strings.Trim(compatible, "\n")

		if compatible == string(code) {
			break
		}
		code = compatible
	}
	fmt.Println(code)
}
