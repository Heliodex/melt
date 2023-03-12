local ReplicatedStorage = game:GetService "ReplicatedStorage"
require(ReplicatedStorage.melt)()

local localPlayer = game:GetService("Players").LocalPlayer

ScreenGui {
	Parent = localPlayer:WaitForChild "PlayerGui",

	Frame {
		Size = UDim2.fromScale(0.5, 0.5),

		TextLabel {
			Position = UDim2.fromScale(0.5, 0.5),
			Text = "Hello world!",
			TextSize = 24,
			BackgroundTransparency = 1,
		},
	},
}
