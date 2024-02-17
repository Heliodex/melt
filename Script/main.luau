local fs = require "@lune/fs"
local process = require "@lune/process"

local exit = process.exit
local colour = require "colour"

type TokenKind =
	"INDENT"
	| "SPACE"
	| "NEWLINE"
	| "IDENTIFIER"
	| "NUMBER"
	| "COMMENT"
	| "STRING"
	| "KEYWORD"
	| "TEXTOPERATOR"
	| "EQUALS"
	| "PLUS"
	| "PLUSPLUS"
	| "PLUSEQUALS"
	| "MINUS"
	| "MINUSMINUS"
	| "MINUSEQUALS"
	| "TIMES"
	| "DIVIDE"
	| "MODULO"

local keywords = {
	["if"] = true,
	["elseif"] = true,
	["else"] = true,
	["loop"] = true,
	["for"] = true,
	["break"] = true,
	["continue"] = true,
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
	["+="] = true,
	["-"] = true,
	["-="] = true,
	["*"] = true,
	["/"] = true,
	["%"] = true,
}

local postfixOperators = {
	["++"] = true,
	["--"] = true,
}

type Token = {
	kind: TokenKind,
	value: string,
	line: number,
	column: number,
}

type Expr = {
	startToken: Token,
	kind: string,
}

type BlockExpr = Expr & {
	expressions: { Expr },
}

local function BlockExpr(startToken: Token, expressions: { Expr }): BlockExpr
	return {
		startToken = startToken,
		kind = "block",
		expressions = expressions,
	}
end

type IfExpr = Expr & {
	condition: Expr,
	block: BlockExpr,
}

local function IfExpr(
	startToken: Token,
	condition: Expr,
	block: BlockExpr
): IfExpr
	return {
		startToken = startToken,
		kind = "if",
		condition = condition,
		block = block,
	}
end

type ElseIfExpr = Expr & {
	condition: Expr,
	block: BlockExpr,
}

local function ElseIfExpr(
	startToken: Token,
	condition: Expr,
	block: BlockExpr
): ElseIfExpr
	return {
		startToken = startToken,
		kind = "elseif",
		condition = condition,
		block = block,
	}
end

type ElseExpr = Expr & {
	block: Expr,
}

local function ElseExpr(startToken: Token, block: BlockExpr): ElseExpr
	return {
		startToken = startToken,
		kind = "else",
		block = block,
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
		kind = "binop",
		left = left,
		right = right,
		operator = operator,
	}
end

type PostfixOpExpr = Expr & {
	expr: Expr,
	operator: Token,
}

local function PostfixOpExpr(startToken: Token, expr: Expr, operator: Token)
	return {
		startToken = startToken,
		kind = "postfix",
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
		kind = "functioncall",
		name = name,
		arg = arg,
	}
end

type IdentifierExpr = Expr

local function IdentifierExpr(startToken: Token): IdentifierExpr
	return {
		startToken = startToken,
		kind = "identifier",
	}
end

local function parse(tokens: { Token }): { Expr }
	local program: { Expr } = {}

	local function addExpr(expr: Expr)
		table.insert(program, expr)
	end

	local i = 0
	local len = #tokens
	while i < len do
		i += 1
		local token = tokens[i]
		local currentIndent = 0

		local function getBlock(): { Token }
			-- get tokens until the end of the block (which is the same indent level as the if statement)
			local blockTokens: { Token } = {}
			local blockIndent = 0

			-- skip newline at start
			i += 1

			while i < len do
				if tokens[i].kind == "NEWLINE" then
					blockIndent = 0
					-- chock next few tokens to see if they're indented

					local j = i + 1
					while j < len and tokens[j].kind == "INDENT" do
						blockIndent += 1
						j += 1
					end
					if blockIndent <= currentIndent then
						break
					end
				end
				table.insert(blockTokens, tokens[i])
				i += 1
			end

			return blockTokens
		end

		local function getCond(): { Token }
			local condTokens: { Token } = {}

			-- skip the keyword
			i += 1

			-- get all tokens until the end of the line
			while i < len and tokens[i + 1].kind ~= "NEWLINE" do
				i += 1
				table.insert(condTokens, tokens[i])
			end

			-- skip the newline
			i += 1

			return condTokens
		end

		local function nextNonSpace(): Token
			while i < len and tokens[i].kind == "SPACE" do
				i += 1
			end
			return tokens[i]
		end

		local function parseCond(condTokens: { Token }): Expr
			local cond = parse(condTokens)
			if #cond > 1 then
				error(colour.red "too many exprs in cond")
			elseif #cond < 1 then
				error(colour.red "not enough exprs in cond")
			end

			return cond[1]
		end

		if token.kind == "INDENT" then
			currentIndent += 1
		elseif token.kind == "NEWLINE" then
			currentIndent = 0
		elseif token.kind == "KEYWORD" then
			if token.value == "if" then
				addExpr(
					IfExpr(
						token,
						parseCond(getCond()),
						BlockExpr(token, parse(getBlock()))
					)
				)
			elseif token.value == "elseif" then
				addExpr(
					ElseIfExpr(
						token,
						parseCond(getCond()),
						BlockExpr(token, parse(getBlock()))
					)
				)
			elseif token.value == "else" then
				-- skip newline
				i += 1

				addExpr(ElseExpr(token, BlockExpr(token, parse(getBlock()))))
			else
				print(token)
				error(colour.red "unknown token value " .. token.value)
			end
		elseif token.kind == "IDENTIFIER" then
			-- identifier is at the start of an expression, it could be:
			-- 1: a binop (next token is a text operator or operator
			-- 3: a postfix op (next token is ++ or --)
			-- 4: a function call
			-- after one 2am philosophical compiler thinking session, I've concluded that yes, an assignment is indeed a binop

			-- skip the identifier
			i += 1
			local nextToken = nextNonSpace()

			if binaryOperators[nextToken.value] then
				-- binop
				addExpr(BinOpExpr(
					token,
					IdentifierExpr(token),
					-- get condition tokens as rhs
					parseCond(getCond()),
					nextToken
				))
			elseif postfixOperators[nextToken.value] then
				-- postfix
				error "unimplemented"
			else
				-- function call
				error "unimplemented"
			end
		elseif token.kind == "SPACE" or token.kind == "COMMENT" then
			-- wtf
		else
			print(token)
			error(colour.red "unknown token kind " .. token.kind)
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
			if last(1).kind == "NEWLINE" or last(1).kind == "INDENT" then
				addToken("INDENT", "\t")
				column += 3
			else
				addToken("SPACE", "\t")
			end
		elseif char == ";" then
			-- parse till end of line
			local startColumn = column
			i += 1 -- skip the semicolon
			local comment = ""
			while i < len and source[i] ~= "\n" do
				comment ..= source[i]
				column += 1
				i += 1
			end
			column -= 1
			i -= 1
			addToken("COMMENT", comment, line, startColumn)
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
			-- check if it's a ++ or a += or just a +
			if i + 1 < len and source[i + 1] == "+" then
				addToken("PLUSPLUS", "++")
				i += 1
				column += 1
			elseif i + 1 < len and source[i + 1] == "=" then
				addToken("PLUSEQUALS", "+=")
				i += 1
				column += 1
			else
				addToken("PLUS", "+")
			end
		elseif char == "-" then
			-- check if it's a -- or a -= or just a -
			if i + 1 < len and source[i + 1] == "-" then
				addToken("MINUSMINUS", "--")
				i += 1
				column += 1
			elseif i + 1 < len and source[i + 1] == "=" then
				addToken("MINUSEQUALS", "-=")
				i += 1
				column += 1
			else
				addToken("MINUS", "-")
			end
		elseif char == "*" then
			addToken("TIMES", "*")
		elseif char == "/" then
			addToken("DIVIDE", "/")
		elseif char == "%" then
			addToken("MODULO", "%")
		else
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

				if i == len then
					-- you can't end a program with an identifier
					print(colour.red "cant end program with identifier")
					exit(1)
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

	local split = string.split(source, "")

	local tokens = lex(split)

	for _, token in tokens do
		if token.kind == "SPACE" then
			continue
		end
		if token.kind == "NEWLINE" then
			print "────────────────┼───────────────┼─────────────────────────────"
			continue
		end

		-- print in a nice format
		local function pad(str: string, len: number): string
			return str .. string.rep(" ", len - #str)
		end

		print(
			pad(`{target}:{token.line}:{token.column}`, 15),
			"│",
			pad(colour.yellow(token.kind), 22),
			"│",
			colour.purple(token.value)
		)
	end

	local program = parse(tokens)
	-- local out = generate(program)

	print(program)

	-- print(out)
end

main()
