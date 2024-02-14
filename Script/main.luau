local fs = require "@lune/fs"
local process = require "@lune/process"

local exit = process.exit
local colour = require "colour"

local INDENT = "INDENT"
local SPACE = "SPACE"
local NEWLINE = "NEWLINE"
--  Literals
local IDENTIFIER = "IDENTIFIER"
local NUMBER = "NUMBER"
local COMMENT = "COMMENT"
local STRING = "STRING"
local KEYWORD = "KEYWORD"
--  Operators
local TEXTOPERATOR = "TEXTOPERATOR"
local EQUALS = "EQUALS"
local PLUS = "PLUS"
local PLUSPLUS = "PLUSPLUS"
local PLUSEQUALS = "PLUSEQUALS"
local MINUS = "MINUS"
local MINUSMINUS = "MINUSMINUS"
local MINUSEQUALS = "MINUSEQUALS"
local TIMES = "TIMES"
local DIVIDE = "DIVIDE"
local MODULO = "MODULO"
--  OPEN_BRACE  = "OPEN_BRACE"
--  CLOSE_BRACE = "CLOSE_BRACE"

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

type Token = {
	kind: string,
	value: string,
	line: number,
	column: number,
}

-- local function generate(program): string
-- 	return ""
-- end

-- local function parse(tokens: { Token })
-- 	return {}
-- end

local function lex(source: { string }): { Token }
	local tokens: { Token } = {}

	local function last(n: number): Token
		return tokens[#tokens - (n - 1)]
	end
	local line, column = 1, 0

	local function addToken(
		kind: string,
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
			addToken(EQUALS, "=")
		elseif char == "\n" then -- newline dont work for some reason
			addToken(NEWLINE, "\n")
			line += 1
			column = 0
		elseif char == " " then
			addToken(SPACE, " ")
		elseif char == "\t" then
			-- only if last line is a newline or an indent
			if last(1).kind == NEWLINE or last(1).kind == INDENT then
				addToken(INDENT, "\t")
				column += 3
			else
				addToken(SPACE, "\t")
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
			addToken(COMMENT, comment, line, startColumn)
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

			addToken(STRING, stringLiteral, startLine, startColumn)
		elseif char == "+" then
			-- check if it's a ++ or a += or just a +
			if i + 1 < len and source[i + 1] == "+" then
				addToken(PLUSPLUS, "++")
				i += 1
				column += 1
			elseif i + 1 < len and source[i + 1] == "=" then
				addToken(PLUSEQUALS, "+=")
				i += 1
				column += 1
			else
				addToken(PLUS, "+")
			end
		elseif char == "-" then
			-- check if it's a -- or a -= or just a -
			if i + 1 < len and source[i + 1] == "-" then
				addToken(MINUSMINUS, "--")
				i += 1
				column += 1
			elseif i + 1 < len and source[i + 1] == "=" then
				addToken(MINUSEQUALS, "-=")
				i += 1
				column += 1
			else
				addToken(MINUS, "-")
			end
		elseif char == "*" then
			addToken(TIMES, "*")
		elseif char == "/" then
			addToken(DIVIDE, "/")
		elseif char == "%" then
			addToken(MODULO, "%")
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
				addToken(NUMBER, number, startLine, startColumn)
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
						TEXTOPERATOR,
						identifierOrKeyword,
						startLine,
						startColumn
					)
					continue
				end

				-- check if it's a keyword
				if keywords[identifierOrKeyword] then
					addToken(
						KEYWORD,
						identifierOrKeyword,
						startLine,
						startColumn
					)
					continue
				end

				addToken(
					IDENTIFIER,
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
		if token.kind == SPACE then
			continue
		end
		if token.kind == NEWLINE then
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

	-- local program = parse(tokens)
	-- local out = generate(program)

	-- print(out)
end

main()
