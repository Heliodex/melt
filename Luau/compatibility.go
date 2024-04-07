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

func compatifyCode(sourceCode []byte, tree *sitter.Tree) string {
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

	// replace all ending newlines with a single newline
	sourceString = strings.Trim(sourceString, "\n")
	return sourceString
}

func compatify(filename string) {
	binding := luau.GetLuau()
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
		compatible := compatifyCode(newSource, tree)
		// replace all ending newlines with a single newline
		compatible = strings.Trim(compatible, "\n")

		if compatible == string(code) {
			break
		}
		code = compatible
	}
	fmt.Println(code)

}
