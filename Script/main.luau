local fs = require "@lune/fs"
local process = require "@lune/process"

local exit = process.exit
local colour = require "colour"

type TokenKind =
	"INDENT"
	| "DEDENT"
	| "SPACE"
	| "NEWLINE"
	| "IDENTIFIER"
	| "NUMBER"
	| "STRING"
	| "KEYWORD"
	| "TEXTOPERATOR"
	| "EQUALS"
	| "PLUS"
	| "MINUS"
	| "TIMES"
	| "DIVIDE"
	| "MODULO"
	| "EXPONENT"
	| "COLON"
	| "SEMICOLON"
	| "LPAREN"
	| "RPAREN"
	| "LBRACE"
	| "RBRACE"
	| "LBRACKET"
	| "RBRACKET"

type ExprKind =
	"block"
	| "if"
	| "else"
	| "binop"
	| "postfix"
	| "functioncall"
	| "identifier"
	| "number"
	| "string"

local keywords = {
	["if"] = true,
	["else"] = true,
}

local textOperators = {
	["is"] = true,
	["and"] = true,
	["or"] = true,
	["not"] = true,
}

local binaryOperators = {
	["is"] = true,
	["and"] = true,
	["or"] = true,
	["not"] = true,
	["="] = true,
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["%"] = true,
}

type Token = {
	kind: TokenKind,
	value: string,
	line: number,
	column: number,
}

type Expr = {
	kind: ExprKind,
	startToken: Token,
}

type BlockExpr = Expr & {
	expressions: { Expr },
}

local function BlockExpr(startToken: Token, expressions: { Expr }): BlockExpr
	return {
		startToken = startToken,
		kind = "block" :: ExprKind,
		expressions = expressions,
	}
end

type IfExpr = Expr & {
	condition: Expr,
	ifBlock: BlockExpr,
	elseBlock: BlockExpr,
}

local function IfExpr(
	startToken: Token,
	condition: Expr,
	ifBlock: BlockExpr,
	elseBlock: BlockExpr
): IfExpr
	return {
		startToken = startToken,
		kind = "if" :: ExprKind,
		condition = condition,
		ifBlock = ifBlock,
		elseBlock = elseBlock,
	}
end

type BinOpExpr = Expr & {
	left: Expr,
	right: Expr,
	operator: Token,
}

local function BinOpExpr(
	startToken: Token,
	left: Expr,
	right: Expr,
	operator: Token
): BinOpExpr
	return {
		startToken = startToken,
		kind = "binop" :: ExprKind,
		left = left,
		right = right,
		operator = operator,
	}
end

type PostfixOpExpr = Expr & {
	expr: Expr,
	operator: Token,
}

local function PostfixOpExpr(
	startToken: Token,
	expr: Expr,
	operator: Token
): PostfixOpExpr
	return {
		startToken = startToken,
		kind = "postfix" :: ExprKind,
		expr = expr,
		operator = operator,
	}
end

type FunctionCallExpr = Expr & {
	name: Token,
	arg: Expr,
}

local function FunctionCallExpr(
	startToken: Token,
	name: Token,
	arg: Expr
): FunctionCallExpr
	return {
		startToken = startToken,
		kind = "functioncall" :: ExprKind,
		name = name,
		arg = arg,
	}
end

type IdentifierExpr = Expr

local function IdentifierExpr(startToken: Token): IdentifierExpr
	if startToken.kind ~= "IDENTIFIER" then
		error(`expected identifier, got {startToken.kind}`)
	end
	return {
		startToken = startToken,
		kind = "identifier" :: ExprKind,
	}
end

type NumberExpr = Expr

local function NumberExpr(startToken: Token): NumberExpr
	if startToken.kind ~= "NUMBER" then
		error(`expected number, got {startToken.kind}`)
	end
	return {
		startToken = startToken,
		kind = "number" :: ExprKind,
	}
end

type StringExpr = Expr

local function StringExpr(startToken: Token): StringExpr
	if startToken.kind ~= "STRING" then
		error(`expected number, got {startToken.kind}`)
	end
	return {
		startToken = startToken,
		kind = "string" :: ExprKind,
	}
end

-- yea

local function indent(str: string, level: number)
	local outputLines = string.split(str, "\n")

	for j in outputLines do
		-- add indentationLevel
		for _ = 1, level do
			outputLines[j] = "    " .. outputLines[j]
		end
	end

	return table.concat(outputLines, "\n")
end

local function generate(program: { Expr }): string
	local output = ""

	local i = 0
	local len = #program
	while i < len do
		i += 1
		local expr = program[i]

		local nextExprKind = i + 1 < len and program[i + 1].kind

		local kind = expr.kind
		if kind == "binop" then
			local binop = expr :: BinOpExpr
			local operator = if binop.operator.value == "is"
				then "=="
				else binop.operator.value

			if operator == "=" then
				output ..= "local "
			end

			output ..= generate { binop.left }
			output ..= ` {operator} `
			output ..= generate { binop.right }

			if operator == "=" then
				output ..= "\n"
			end
		elseif kind == "identifier" then
			local identifier = expr :: IdentifierExpr
			output ..= identifier.startToken.value
		elseif kind == "number" then
			local number = expr :: NumberExpr
			output ..= number.startToken.value
		elseif kind == "string" then
			local string = expr :: StringExpr
			output ..= `"{string.startToken.value}"`
		elseif kind == "functioncall" then
			local functioncall = expr :: FunctionCallExpr
			output ..= functioncall.name.value

			output ..= if functioncall.arg.kind == "string" then " " else "("
			output ..= generate { functioncall.arg }
			output ..= if functioncall.arg.kind == "string" then "" else ")"

			if nextExprKind == "if" then
				output ..= ";"
			end

			output ..= "\n"
		elseif kind == "if" then
			local ifexpr = expr :: IfExpr
			output ..= "(function()\n"

			local block = ""
			block ..= "if "
			block ..= generate { ifexpr.condition }
			block ..= " then\n"

			block ..= indent(generate { ifexpr.ifBlock }, 1)
			block ..= "\n"

			block ..= "else\n"
			block ..= indent(generate { ifexpr.elseBlock }, 1)

			block ..= "end"

			output ..= indent(block, 1)

			output ..= "\n"
			output ..= "end)()"

			-- ifexpr.next is an elseifexpr or an elseexpr
		elseif kind == "block" then
			local block = expr :: BlockExpr
			local b = 0
			while b < #block.expressions - 1 do
				b += 1
				output ..= generate { block.expressions[b] }
			end
			output ..= "return "
			output ..= generate { block.expressions[b + 1] }
		else
			error(`unknown expr kind {kind}`)
		end
	end

	return output
end

local printIndent = 0

local function printToken(token: Token)
	local pos = `{token.line}:{token.column}`
	while #pos < 5 do
		pos ..= " "
	end

	local kind = token.kind
	while #kind < 13 do
		kind ..= " "
	end

	local value = token.value
	if token.kind == "STRING" then
		value = colour.green(`"{value}"`)
	elseif token.kind == "NUMBER" then
		value = colour.yellow(value)
	elseif token.kind == "IDENTIFIER" then
		value = colour.cyan(value)
	elseif token.kind == "KEYWORD" then
		value = colour.red(value)
	elseif token.kind == "INDENT" then
		value = "{"
		printIndent += 1
	elseif token.kind == "DEDENT" then
		value = "}"
		printIndent -= 1
	elseif token.kind == "NEWLINE" or token.kind == "SPACE" then
		value = ""
	end

	for _ = 1, printIndent - if token.kind == "INDENT" then 1 else 0 do
		value = "  " .. value
	end

	print(pos, colour.blue(kind), colour.bold(value))
end

local function parse(tokens: { Token }): { Expr }
	local program: { Expr } = {}

	if #tokens == 0 then
		error(colour.red "no tokens to parse")
	end

	-- remove spaces and newlines
	for i, token in tokens do
		if token.kind == "SPACE" then
			table.remove(tokens, i)
		end
	end

	-- A program is a list of expressions

	local function next(): Token
		return tokens[1]
	end

	local function get(): Token
		local token = next()
		table.remove(tokens, 1)
		return token
	end

	local function eat(kind: TokenKind): Token
		local token = get()
		if token.kind ~= kind then
			print(
				colour.red "expected",
				colour.yellow(kind),
				colour.red "got",
				colour.yellow(token.kind)
			)
			exit(1)
		end
		return token
	end

	local function canEndAnExpression(token: Token): boolean
		local kind: TokenKind = token.kind
		return kind == "IDENTIFIER"
			or kind == "NUMBER"
			or kind == "STRING"
			or kind == "RPAREN"
			or kind == "RBRACE"
			or kind == "RBRACKET"
	end

	local function getIfExprCond(): { Token }
		local tokens: { Token } = {}

		local depth = 0
		while true do
			local token = get()
			print("got token", token)
			if token.kind == "COLON" and depth == 0 then
				break
			elseif token.kind == "KEYWORD" and token.value == "if" then
				-- keywords that require a colon
				depth += 1
			end
			table.insert(tokens, token)
		end

		return tokens
	end

	local function getUntilEndOfExpression(): { Token }
		local tokens: { Token } = {}

		-- just because a token can end an expression doesn't mean it does
		local startToken = next()

		if startToken.kind == "KEYWORD" then
			if startToken.value == "if" then
				-- skip the if keyword
				get()
				-- first get the condition
				local conditionTokens = getIfExprCond()
				print("Got tokns", conditionTokens)
			end
		else
			print(
				colour.red "unimplemented token",
				colour.yellow(startToken.kind)
			)
			exit(1)
		end

		return tokens
	end

	while #tokens > 0 do
		local token = get()

		printToken(token)

		if token.kind == "IDENTIFIER" then
			local nextToken = get()

			if binaryOperators[nextToken.value] then
				-- binary operator
				local left = IdentifierExpr(token)
				local operator = nextToken

				local rightTokens = getUntilEndOfExpression()
				local right = parse(rightTokens)[1]

				print(operator)

				table.insert(program, BinOpExpr(token, left, right, operator))
			end
		else
			print(colour.red "unexpected token", colour.yellow(token.kind))
			exit(1)
		end
	end

	return program
end

local function lex(source: { string }): { Token }
	local tokens: { Token } = {}

	local function last(n: number): Token
		return tokens[#tokens - (n - 1)]
	end
	local line, column = 1, 0
	local indent = 0

	local function addToken(
		kind: TokenKind,
		value: string,
		newLine: number?,
		newColumn: number?
	)
		table.insert(tokens, {
			kind = kind,
			value = value,
			line = newLine or line,
			column = newColumn or column,
		})
	end

	local len = #source + 1

	local i = 0
	while i < len - 1 do
		i += 1
		local char = source[i]
		column += 1

		if char == "=" then
			addToken("EQUALS", "=")
		elseif char == "\n" then -- newline dont work for some reason
			addToken("NEWLINE", "\n")
			line += 1
			column = 0
		elseif char == " " then
			addToken("SPACE", " ")
		elseif char == "\t" then
			-- only if last line is a newline or an indent
			if last(1).kind ~= "NEWLINE" and last(1).kind ~= "INDENT" then
				addToken("SPACE", "\t")
				continue
			end

			-- count how many tabs there are
			local tabs = 1
			while source[i + tabs] == "\t" do
				tabs += 1
				i += 1
			end

			local diff = tabs - indent
			for _ = 1, math.abs(diff) do
				if diff > 0 then
					addToken("INDENT", "\t")
					indent += 1
				else
					addToken("DEDENT", "\t")
					indent -= 1
				end
			end
		elseif char == '"' then
			local startLine, startColumn = line, column

			local stringLiteral = ""

			column += 1
			i += 1 -- skip the first quote
			while i < len and source[i] ~= '"' do
				stringLiteral ..= source[i]
				column += 1
				i += 1
			end

			if i == len then
				print(colour.red "unclosed string literal", stringLiteral)
				exit(1)
			end

			addToken("STRING", stringLiteral, startLine, startColumn)
		elseif char == "+" then
			addToken("PLUS", "+")
		elseif char == "-" then
			addToken("MINUS", "-")
		elseif char == "*" then
			addToken("TIMES", "*")
		elseif char == "/" then
			addToken("DIVIDE", "/")
		elseif char == "%" then
			addToken("MODULO", "%")
		elseif char == "^" then
			addToken("EXPONENT", "^")
		elseif char == ":" then
			addToken("COLON", ":")
		elseif char == ";" then
			addToken("SEMICOLON", ";")
		elseif char == "(" then
			addToken("LPAREN", "(")
		elseif char == ")" then
			addToken("RPAREN", ")")
		elseif char == "{" then
			addToken("LBRACE", "{")
		elseif char == "}" then
			addToken("RBRACE", "}")
		elseif char == "[" then
			addToken("LBRACKET", "[")
		elseif char == "]" then
			addToken("RBRACKET", "]")
		elseif char ~= " " then
			if char >= "0" and char <= "9" then
				local startLine, startColumn = line, column

				local number = ""

				-- keep going until we hit a non-number
				while i < len and source[i] >= "0" and source[i] <= "9" do
					number ..= source[i]
					column += 1
					i += 1
				end
				column -= 1
				i -= 1
				addToken("NUMBER", number, startLine, startColumn)
			elseif
				char >= "a" and char <= "z" or char >= "A" and char <= "Z"
			then
				local startLine, startColumn = line, column

				local identifierOrKeyword = ""

				-- keep going until we hit a non-letter
				while
					i < len
					and (
						source[i] >= "a" and source[i] <= "z"
						or source[i] >= "A" and source[i] <= "Z"
						or source[i] >= "0" and source[i] <= "9"
					)
				do
					identifierOrKeyword ..= source[i]
					column += 1
					i += 1
				end

				column -= 1
				i -= 1

				-- check if it's a text operator
				if textOperators[identifierOrKeyword] then
					addToken(
						"TEXTOPERATOR",
						identifierOrKeyword,
						startLine,
						startColumn
					)
					continue
				end

				-- check if it's a keyword
				if keywords[identifierOrKeyword] then
					addToken(
						"KEYWORD",
						identifierOrKeyword,
						startLine,
						startColumn
					)
					continue
				end

				addToken(
					"IDENTIFIER",
					identifierOrKeyword,
					startLine,
					startColumn
				)
			else
				print(
					colour.red "that isnt a valid character",
					colour.yellow(char)
				)
				exit(1)
			end
		end
	end

	-- postprocessing

	-- remove leading and trailing newlines
	while tokens[1].kind == "NEWLINE" do
		table.remove(tokens, 1)
	end
	while tokens[#tokens].kind == "NEWLINE" do
		table.remove(tokens, #tokens)
	end

	-- check if the number of indents and dedents are the same, if not add the remaining
	local indents, dedents = 0, 0
	for _, token in tokens do
		if token.kind == "INDENT" then
			indents += 1
		elseif token.kind == "DEDENT" then
			dedents += 1
		end
	end
	if dedents > indents then
		-- huh?????
		print(colour.red "too many dedents")
		exit(1)
	end

	while indents > dedents do
		addToken("DEDENT", "\t")
		dedents += 1
	end

	return tokens
end

local function main()
	if #process.args < 1 then
		print(colour.red "No target file specified!")
		print(colour.blue "Run 'melt-script help' for more information.")
		exit(1)
	end
	local target = process.args[1]

	local fi = fs.metadata(target)
	if not fi.exists then
		print(
			colour.red "Target file",
			colour.bold(target),
			colour.red "does not exist!"
		)
		exit(1)
	end
	if fi.kind == "dir" then
		print(
			colour.bold(target),
			colour.red "is a directory, please choose a file to compile!"
		)
		exit(1)
	end

	local source = fs.readFile(target)

	-- replace \r\n with \n
	source = string.gsub(source, "\r\n", "\n")
	-- remove trailing newlines
	source = string.gsub(source, "\n+$", "")

	local tokens = lex(string.split(source, ""))
	local program = parse(tokens)
	local out = generate(program)

	print(out)
end

main()
