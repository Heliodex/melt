local stdio = require "@lune/stdio"
local colour = stdio.color
local style = stdio.style

local blue = colour "blue"
local green = colour "green"
local purple = colour "purple"
local red = colour "red"
local yellow = colour "yellow"
local cyan = colour "cyan"

local bold = style "bold"
local dim = style "dim"
local reset = style "reset"

local Colour = {}

function Colour.blue(str: string)
	return blue .. str .. reset
end

function Colour.green(str: string)
	return green .. str .. reset
end

function Colour.purple(str: string)
	return purple .. str .. reset
end

function Colour.red(str: string)
	return red .. str .. reset
end

function Colour.yellow(str: string)
	return yellow .. str .. reset
end

function Colour.cyan(str: string)
	return cyan .. str .. reset
end

function Colour.bold(str: string)
	return bold .. str .. reset
end

function Colour.dim(str: string)
	return dim .. str .. reset
end

return Colour
