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

local buttons = {
	toolbar:CreateButton(
		"", -- The text next to the icon. Leave this blank if the icon is sufficient.
		"Sync!", -- hover text
		"icon.png" -- The icon file's name. Make sure you change it to your own icon file's name!
	),
}

local Fusion = LoadLibrary "RbxFusion"

local New = Fusion.New
local Children = Fusion.Children
local Value = Fusion.Value
local Spring = Fusion.Spring
-- local Tween = Fusion.Tween
-- local TweenInfo = Fusion.TweenInfo
local Observer = Fusion.Observer
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

local idCount = 0
local nCount = 0

local function notify(text, willUpdate)
	nCount = nCount + 1
	idCount = idCount + 1
	local id = idCount

	local position = Value(UDim2.new(0, -WIDTH, 0, 60 * nCount - 50))
	local transparency = Value(0)
	local textValue = Value(text)
	local textChanged
	local arrowRotation = Value(0)
	local done = Value(not willUpdate)
	local background = Value(Color3.new())
	local backgroundSpring = Spring(background, 4)
	local start = tick()

	local disconn = function() end

	if willUpdate then
		textChanged = Observer(textValue)
		disconn = textChanged:onChange(function()
			if tick() - start > 0.5 then -- don't change color if it's just appearing
				backgroundSpring:setPosition(Color3.new(0.4, 0.4, 0.4))
			end
		end)
	end

	local t = New "Frame" {
		Name = "Notification",
		Parent = gui().Notifications,
		BackgroundColor3 = backgroundSpring,
		BackgroundTransparency = Spring(transparency, 15),
		BorderSizePixel = 0,
		Position = Spring(position, 15),
		Size = UDim2.new(1, 0, 0, 50),

		[Children] = {
			New "ImageLabel" {
				Name = "InnerIcon",
				Image = "rbxasset://../../../Plugins/TestPlugin/innerIcon.png",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 5, 0, 5),
				Size = UDim2.new(0, 40, 0, 40),
			},
			New "ImageLabel" {
				Name = "OuterIcon",
				Image = "rbxasset://../../../Plugins/TestPlugin/outerIcon.png",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 5, 0, 5),
				Rotation = Spring(arrowRotation),
				Size = UDim2.new(0, 40, 0, 40),
			},
			New "TextLabel" {
				Position = UDim2.new(0, 50, 0, 0),
				Size = UDim2.new(1, -60, 1, 0),
				BackgroundTransparency = 1,
				Text = textValue,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.SourceSans,
				FontSize = Enum.FontSize.Size18,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			},
		},
	}

	Spawn(function()
		local tbl = {
			obj = t,
			pos = position,
		}

		notifications[id] = tbl

		position:set(peek(position) + UDim2.new(0, WIDTH, 0, 0))
		transparency:set(0.5)

		repeat
			wait(1)
		until peek(done)

		wait(3)

		position:set(UDim2.new(0, 0, 0, -60))
		transparency:set(1)

		notifications[id] = nil
		nCount = nCount - 1

		for _, v in pairs(notifications) do
			if peek(v.pos).Y.Offset > peek(position).Y.Offset then
				v.pos:set(peek(v.pos) - UDim2.new(0, 0, 0, 60))
			end
		end

		wait(1)
		disconn()
		t:Destroy()
	end)

	if willUpdate then
		return {
			text = textValue,
			arrowRotation = arrowRotation,
			done = done,
		}
	end
	return
end

local function makeScript(s) -- because no continue
	local path = s.path -- { "ServerScriptService", "script" }
	local content = s.content
	local type = s.type

	local obj = game
	local ok2 = pcall(function()
		for i = 1, #path - 1 do
			obj = obj:FindFirstChild(path[i])
			if not obj then
				local folder = Instance.new "Model"
				folder.Name = path[i]
				folder.Parent = obj
				obj = folder
			end
		end
	end)
	if not ok2 then
		notify(
			"Failed to sync "
				.. table.concat(path, ".")
				.. "! Is the path correct?"
		)
		return
	end

	local name = path[#path]
	local existingObj = obj:FindFirstChild(name)
	if existingObj then
		if existingObj:IsA "Script" then
			existingObj.Source = content
		else
			notify(
				"Object already exists at path "
					.. table.concat(path, ".")
					.. "! Please remove it and try again."
			)
			return
		end
	else
		local createScript

		if type == "server" then
			createScript = Instance.new "Script"
		elseif type == "client" then
			createScript = Instance.new "LocalScript"
		else
			return
		end

		createScript.Name = name
		createScript.Source = content
		createScript.Parent = obj
	end
end

local debounce

buttons[1].Click:connect(function()
	if debounce then
		return
	end
	debounce = true
	initiate()

	local n = notify("Syncing...", true)

	Spawn(function()
		while not peek(n.done) do
			n.arrowRotation:set(peek(n.arrowRotation) + 180)
			wait(0.9)
		end
	end)

	Spawn(function()
		local ok, res = ypcall(function()
			return HttpService:GetAsync(
				"http://localhost:2013/sync?" .. tick() * 10000
				-- nocache parameter doesn't work
			)
		end)

		local function finish()
			n.done:set(true)
			wait(0.05)
			debounce = false
		end

		if not ok then
			n.text:set "Failed to sync! Is Mercury Sync Server running?"
			finish()
			return
		end

		n.text:set "Decoding..."
		local json = HttpService:JSONDecode(res) -- { files }

		if not json.files or json.files == "null" then
			n.text:set "No files to sync!"
			finish()
			return
		end
		n.text:set "Applying..."

		for _, v in pairs(json.files) do -- { path, content, type }
			makeScript(v)
		end

		n.text:set "Successfully synchronised!"

		finish()
	end)
end)
