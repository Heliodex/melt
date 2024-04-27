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

func formatCode(sourceCode []byte, main *sitter.Node) string {
	if main.HasError() {
		fmt.Println("Error parsing code")
		return string(sourceCode)
	}

	getContent := func(node sitter.Node) string {
		return node.Content(sourceCode)
	}

	indent := 0

	var formatExpr func(node sitter.Node) string
	formatExpr = func(node sitter.Node) string {
		var formatted string

		writeIndent := func() {
			formatted += strings.Repeat("\t", indent)
		}

		ntype := node.Type()

		switch ntype {
		case "number":
			formatted += getContent(node)
		case "string":
			content := getContent(node)
			// strings can be surrounded by '', "", [[]], [=[]=], [==[]==], etc.

			var prefix, suffix string
			for _, c := range content {
				if strings.Contains(`"[='`, string(c)) {
					prefix += string(c)
					if c == '"' || c == '\'' {
						break
					}
				} else {
					break
				}
			}
			for i := len(content) - 1; i >= 0; i-- {
				c := content[i]
				if strings.Contains(`"]'=`, string(c)) {
					suffix = string(c) + suffix
					if c == '"' || c == '\'' {
						break
					}
				} else {
					break
				}
			}
			main := content[len(prefix) : len(content)-len(suffix)]

			hasEscapedStr := func(str string, escd string) bool {
				// ensure the string has an escd with an odd number of \ before it
				pos := strings.Index(str, escd)

				// count the number of \ before the escd
				count := 0
				for i := pos - 1; i >= 0; i-- {
					if string(str[i]) != `\` {
						break
					}
					count++
				}
				return count%2 == 1
			}

			// Dued, I had no idea string literals could be so complicated
			if !(hasEscapedStr(main, `'`) && hasEscapedStr(main, `"`)) {
				if prefix == `"` {
					if hasEscapedStr(main, `'`) {
						main = strings.ReplaceAll(main, `\'`, `'`)
					} else if hasEscapedStr(main, `"`) && !strings.Contains(main, `'`) {
						main = strings.ReplaceAll(main, `\"`, `"`)
						prefix, suffix = `'`, `'`
					}
				} else if prefix == `'` {
					if hasEscapedStr(main, `"`) {
						main = strings.ReplaceAll(main, `\"`, `"`)
					} else if hasEscapedStr(main, `'`) && !strings.Contains(main, `"`) {
						main = strings.ReplaceAll(main, `\'`, `'`)
						prefix, suffix = `"`, `"`
					}
				}
			} else if hasEscapedStr(main, `'`) && hasEscapedStr(main, `"`) {
				// if both are escaped, unescape the one with the least escapes
				// (default to unescaping single quotes if equal)
				if strings.Count(main, `\"`) > strings.Count(main, `\'`) {
					main = strings.ReplaceAll(main, `\"`, `"`)
					prefix, suffix = `'`, `'`
				} else {
					main = strings.ReplaceAll(main, `\'`, `'`)
					prefix, suffix = `"`, `"`
				}
			}

			// "christ all mighty" - ezio4322, 1 August 2022
			if prefix == `'` && hasEscapedStr(main, `'`) && !hasEscapedStr(main, `"`) &&
				strings.Contains(main, `"`) && strings.Count(main, `\'`) > strings.Count(main, `"`) {
				// There are escaped single quotes, unescaped double quotes, and more single quotes than double quotes
				// Swap the quotes
				main = strings.ReplaceAll(main, `\'`, `'`)
				main = strings.ReplaceAll(main, `"`, `\"`)
				prefix, suffix = `"`, `"`
			} else if prefix == `"` && hasEscapedStr(main, `"`) && !hasEscapedStr(main, `'`) &&
				strings.Contains(main, `'`) && strings.Count(main, `\"`) > strings.Count(main, `'`) {
				// that but the other way around
				main = strings.ReplaceAll(main, `\"`, `"`)
				main = strings.ReplaceAll(main, `'`, `\'`)
				prefix, suffix = `'`, `'`
			}

			formatted += prefix + main + suffix
		case "var":
			formatted += getContent(node)

		case "string_interp":
			for i := range int(node.ChildCount()) {
				child := node.Child(i)
				switch child.Type() {
				case "interp_start", "interp_end":
					formatted += "`"
				case "interp_content":
					formatted += getContent(*child)
				case "interp_exp":
					for j := range int(child.ChildCount()) {
						switch child.Child(j).Type() {
						case "interp_brace_open":
							formatted += "{"
						case "interp_brace_close":
							formatted += "}"
						default:
							formatted += formatExpr(*child.Child(j))
						}
					}

				default:
					panic(c.InRed("Unknown string interpolation child type ") + c.InYellow(child.Type()))
				}
			}

		case "table":
			childCount := node.ChildCount()
			for i := range int(childCount) {
				child := node.Child(i)
				switch child.Type() {
				case "{":
					formatted += "{"
					if childCount > 2 {
						formatted += "\n"
						indent++
					}
				case "}":
					// I love me some trailing commas
					lastChild := node.Child(i - 1)
					if lastChild.Type() == "fieldlist" &&
						lastChild.Child(int(lastChild.ChildCount()-1)).Type() != "," {
						formatted += ",\n"
					}

					if childCount > 2 {
						indent--
						writeIndent()
					}
					formatted += "}"
				case "fieldlist":
					for j := range int(child.ChildCount()) {
						child := child.Child(j)
						switch child.Type() {
						case ",":
							formatted += ",\n"
						case "field":
							for k := range int(child.ChildCount()) {
								field := child.Child(k)
								switch field.Type() {
								case "name":
									writeIndent()
									formatted += getContent(*field)
								case "=":
									formatted += " = "
								case "[":
									writeIndent()
									formatted += "["
								case "]":
									formatted += "]"
								default:
									formatted += formatExpr(*field)
								}
							}
						}
					}
				}
			}

		default:
			panic(c.InRed("Unknown expression type ") + c.InYellow(ntype))
		}

		return formatted
	}

	formatStmt := func(node sitter.Node) string {
		var formatted string

		writeIndent := func() {
			formatted += strings.Repeat("\t", indent)
		}

		ntype := node.Type()

		// parent := node.Parent()

		switch ntype {
		case "local_var_stmt":
			writeIndent()

			for i := range int(node.ChildCount()) {
				child := node.Child(i)
				switch child.Type() {
				case "local":
					formatted += "local "
				case "=":
					formatted += " = "
				case ",":
					formatted += ", "
				case "binding":
					formatted += getContent(*child)
				default:
					formatted += formatExpr(*child)
				}
			}

			formatted += "\n"
		case "assign_stmt":
			writeIndent()

			for i := range int(node.ChildCount()) {
				child := node.Child(i)
				switch child.Type() {
				case "=":
					formatted += " = "
				case "varlist":
					for j := range int(child.ChildCount()) {
						varchild := child.Child(j)
						switch varchild.Type() {
						case "var":
							formatted += getContent(*varchild)
						case ",":
							formatted += ", "
						default:
							panic(c.InRed("unknown varlist child type ") + c.InYellow(varchild.Type()))
						}
					}
				case "explist":
					for j := range int(child.ChildCount()) {
						child := child.Child(j)
						switch child.Type() {
						case ",":
							formatted += ", "
						default:
							formatted += formatExpr(*child)
						}
					}
				default:
					formatted += formatExpr(*child)
				}
			}

			formatted += "\n"
		case "comment":
			writeIndent()

			formatted += getContent(node) + "\n"
		case "call_stmt":
			writeIndent()

			for i := range int(node.ChildCount()) {
				child := node.Child(i)
				switch child.Type() {
				case "var":
					formatted += getContent(*child)
				case "arglist":
					for j := range int(child.ChildCount()) {
						argchild := child.Child(j)
						switch argchild.Type() {
						case "(":
							nextType := child.Child(j + 1).Type()
							if nextType == "string" && child.ChildCount() <= 3 { // function call with single string argument
								formatted += " "
							} else {
								formatted += "("
							}
						case ")":
							prevType := child.Child(j - 1).Type()
							if prevType != "string" || child.ChildCount() > 3 {
								formatted += ")"
							}
						case ",":
							formatted += ", "
						default:
							if j == 0 {
								formatted += " "
							}
							formatted += formatExpr(*argchild)
						}
					}
				default:
					panic(c.InRed("Unknown call statement child type ") + c.InYellow(child.Type()))
				}
			}

			formatted += "\n"

		default:
			panic(c.InRed("Unknown statement type ") + c.InYellow(ntype))
		}

		return formatted
	}

	var formatted string

	for i := range int(main.ChildCount()) {
		formatted += formatStmt(*main.Child(i))
	}

	return formatted
}

func formatFile(filename string) {
	parser := sitter.NewParser()
	parser.SetLanguage(luau.GetLuau())

	sourceCode, err := os.ReadFile(filename)
	if err != nil {
		fmt.Println(err)
		return
	}

	tree, _ := parser.ParseCtx(context.Background(), nil, sourceCode)
	formatted := formatCode(sourceCode, tree.RootNode())

	// replace all ending newlines with a single newline
	formatted = strings.Trim(formatted, "\n") + "\n"

	// write back to file
	err = os.WriteFile(filename, []byte(formatted), 0o644)
	if err != nil {
		fmt.Println(err)
		return
	}
}
