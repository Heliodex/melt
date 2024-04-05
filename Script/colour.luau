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

function Colour.blue(str: string | number)
	return blue .. str .. reset
end

function Colour.green(str: string | number)
	return green .. str .. reset
end

function Colour.purple(str: string | number)
	return purple .. str .. reset
end

function Colour.red(str: string | number)
	return red .. str .. reset
end

function Colour.yellow(str: string | number)
	return yellow .. str .. reset
end

function Colour.cyan(str: string | number)
	return cyan .. str .. reset
end

function Colour.bold(str: string | number)
	return bold .. str .. reset
end

function Colour.dim(str: string | number)
	return dim .. str .. reset
end

return Colour
