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

type ExprKind =
	"block"
	| "if"
	| "elseif"
	| "else"
	| "binop"
	| "postfix"
	| "functioncall"
	| "identifier"
	| "number"
	| "string"

local keywords = {
	["if"] = true,
	["elseif"] = true,
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
	block: BlockExpr,
}

local function IfExpr(
	startToken: Token,
	condition: Expr,
	block: BlockExpr
): IfExpr
	return {
		startToken = startToken,
		kind = "if" :: ExprKind,
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
		kind = "elseif" :: ExprKind,
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
		kind = "else" :: ExprKind,
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

local function generate(program: { Expr }): string
	local output = ""

	local i = 0
	local len = #program
	while i < len do
		i += 1
		local expr = program[i]

		local kind = expr.kind
		if kind == "binop" then
			local binop = expr :: BinOpExpr
			local value = binop.operator.value

			if value == "=" then
				output ..= "local "
			end

			output ..= generate { binop.left }
			output ..= if value == "is" then " == " else ` {value} `
			output ..= generate { binop.right }
			output ..= "\n"
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
			output ..= "("
			output ..= generate { functioncall.arg }
			output ..= ");\n"
		elseif kind == "if" then
			local ifexpr = expr :: IfExpr
			output ..= "\n(function() if "
			output ..= generate { ifexpr.condition }
			output ..= " then\n"
			output ..= generate { ifexpr.block }

			if i + 1 < len then
				local nextExprKind = program[i + 1].kind

				if nextExprKind ~= "elseif" and nextExprKind ~= "else" then
					output ..= "end end)()"
				end
			end
		elseif kind == "elseif" then
			local elseifexpr = expr :: ElseIfExpr
			output ..= "elseif "
			output ..= generate { elseifexpr.condition }
			output ..= " then\n"
			output ..= generate { elseifexpr.block }

			if i + 1 < len then
				local nextExprKind = program[i + 1].kind

				if nextExprKind ~= "else" then
					output ..= "end end)()"
				end
			end
		elseif kind == "else" then
			local elseexpr = expr :: ElseExpr
			output ..= "else\n"
			output ..= generate { elseexpr.block }
			output ..= "end end)()\n"
		elseif kind == "block" then
			local block = expr :: BlockExpr
			local b = 0
			while b < #block.expressions - 1 do
				b += 1
				output ..= "\t" .. generate { block.expressions[b] }
			end
			output ..= "return "
			output ..= "\t" .. generate { block.expressions[b + 1] }
			output ..= "\n"
		elseif kind == "postfix" then
			local postfix = expr :: PostfixOpExpr
			output ..= generate { postfix.expr }

			local value = postfix.operator.value

			if value == "++" then
				output ..= " += 1\n"
			elseif value == "--" then
				output ..= " -= 1\n"
			else
				error(`unknown postfix operator {value}`)
			end
		else
			error(`unknown expr kind {kind}`)
		end
	end

	return output
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

			while i < len + 1 do -- todo figure out if the + 1 breaks something or not its 5:57 am idck
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

		local function nextNonSpace(): (Token, number)
			local j = i
			while j < len and tokens[j].kind == "SPACE" do
				j += 1
			end
			return tokens[j], j
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

				local block = getBlock()

				print("else block", block)

				addExpr(ElseExpr(token, BlockExpr(token, parse(block))))
			else
				print(token)
				error(colour.red "unknown token value " .. token.value)
			end
		elseif token.kind == "IDENTIFIER" then
			-- identifier is at the start of an expression, it could be:
			-- 1: a binop (next token is a text operator or operator
			-- 3: a postfix op (next token is ++ or --)
			-- 4: a function call
			-- 5: standalone
			-- after one 2am philosophical compiler thinking session, I've concluded that yes, an assignment is indeed a binop

			-- skip the identifier
			i += 1
			local nextToken, advance = nextNonSpace()

			if not nextToken then
				-- standalone
				i = advance
				addExpr(IdentifierExpr(token))
			elseif binaryOperators[nextToken.value] then
				-- binop
				i = advance
				addExpr(BinOpExpr(
					token,
					IdentifierExpr(token),
					-- get condition tokens as rhs
					parseCond(getCond()),
					nextToken
				))
			elseif postfixOperators[nextToken.value] then
				-- postfix
				i = advance
				addExpr(PostfixOpExpr(token, IdentifierExpr(token), nextToken))
			else
				i -= 1 -- getCond skips the identifier
				addExpr(FunctionCallExpr(token, token, parseCond(getCond())))
			end
		elseif token.kind == "NUMBER" then
			-- number is at the start of an expression, it could be:
			-- 1: a binop (next token is a text operator or operator
			-- 2: standalone

			-- skip the number
			i += 1
			local nextToken, advance = nextNonSpace()

			local function standalone()
				i = advance
				addExpr(NumberExpr(token))
			end

			if not nextToken or not binaryOperators[nextToken.value] then
				standalone()
			else
				-- binop
				i = advance
				addExpr(BinOpExpr(
					token,
					IdentifierExpr(token),
					-- get condition tokens as rhs
					parseCond(getCond()),
					nextToken
				))
			end
		elseif token.kind == "STRING" then
			-- string is at the start of an expression, it could be:
			-- 1: a binop (next token is a text operator or operator
			-- 2: standalone

			-- skip the string
			i += 1
			local nextToken, advance = nextNonSpace()

			local function standalone()
				i = advance
				addExpr(StringExpr(token))
			end

			if not nextToken or not binaryOperators[nextToken.value] then
				standalone()
			else
				-- binop
				i = advance
				addExpr(BinOpExpr(
					token,
					IdentifierExpr(token),
					-- get condition tokens as rhs
					parseCond(getCond()),
					nextToken
				))
			end
		elseif token.kind ~= "SPACE" then
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
			i += 1 -- skip the semicolon
			while i < len and source[i] ~= "\n" do
				column += 1
				i += 1
			end
			column -= 1
			i -= 1

			-- I used to do something with it here but nah
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
