local plugin = PluginManager():CreatePlugin()
local initiated = false

local HttpService = game:GetService "HttpService"
HttpService.HttpEnabled = true

local function initiate()
	if initiated then
		return
	end
	initiated = true

	print "Initiating network server for Mercury Sync."
	print "Hosting servers is not possible after opening Mercury Sync! Please restart Studio to host servers again."

	game:GetService("NetworkServer"):Start()
end

local toolbar = plugin:CreateToolbar "Mercury Sync"
local button = toolbar:CreateButton(
	"", -- The text next to the icon. Leave this blank if the icon is sufficient.
	"Sync!", -- hover text
	"icon.png" -- The icon file's name. Make sure you change it to your own icon file's name!
)

local Fusion = LoadLibrary "RbxFusion"

local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Spring = Fusion.Spring
local peek = Fusion.peek

local g
local notifications = {}

local WIDTH = 250

-- the gui is removed when there are no notifications,
-- to prevent remaining in StarterGui
local function gui()
	if not g then
		g = New "ScreenGui" {
			Name = "Mercury Sync",
			Parent = game.StarterGui,

			[Children] = New "Frame" {
				Name = "Notifications",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0, WIDTH, 1, 0),
			},
		}

		local conn, destroyed
		conn = g.Notifications.DescendantRemoving:connect(function()
			wait(1)
			if not destroyed and #g.Notifications:GetChildren() == 0 then
				g:Destroy()
				g = nil
				notifications = {}
				destroyed = true
				conn:disconnect()
			end
		end)
	end

	return g
end

local function notifyCount()
	local count = 0
	for _, _ in pairs(notifications) do
		count = count + 1
	end
	return count
end

local idCount = 0

local function notify(text)
	local startCount = notifyCount()
	local position = Value(UDim2.new(0, -WIDTH, 0, 60 * (startCount + 1) - 50))
	local transparency = Value(0)

	idCount = idCount + 1
	local id = idCount

	local t = New "Frame" {
		Name = "Notification",
		Parent = gui().Notifications,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = Spring(transparency, 15),
		BorderSizePixel = 0,
		Position = Spring(position, 15),
		Size = UDim2.new(1, 0, 0, 50),

		[Children] = {
			New "ImageLabel" {
				Image = "rbxasset://../../../Plugins/TestPlugin/icon2.png",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 5, 0, 5),
				Size = UDim2.new(0, 40, 0, 40),
			},
			New "TextLabel" {
				Position = UDim2.new(0, 50, 0, 0),
				Size = UDim2.new(1, -60, 1, 0),
				BackgroundTransparency = 1,
				Text = text,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.SourceSans,
				FontSize = Enum.FontSize.Size18,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			},
		},
	}
	local tbl = {
		obj = t,
		pos = position,
	}
	notifications[id] = tbl

	position:set(peek(position) + UDim2.new(0, WIDTH, 0, 0))
	transparency:set(0.5)
	wait(3)

	position:set(UDim2.new(0, 0, 0, -60))
	transparency:set(1)

	notifications[id] = nil

	for _, v in pairs(notifications) do
		if peek(v.pos).Y.Offset > peek(position).Y.Offset then
			v.pos:set(peek(v.pos) - UDim2.new(0, 0, 0, 60))
		end
	end

	wait(1)
	t:Destroy()
end

local debounce
button.Click:connect(function()
	if debounce then
		return
	end
	debounce = true
	initiate()

	local ok, res = ypcall(function()
		return HttpService:GetAsync "http://localhost:2013/"
	end)

	if ok then
		notify("Synced: " .. res)
	else
		notify "Failed to sync! Is Mercury Sync Server running?"
	end

	debounce = false
end)
