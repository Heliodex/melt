local instances = {
	"Accoutrement",
	"Animation",
	"AnimationController",
	"AnimationTrack",
	"ArcHandles",
	"Backpack",
	"BackpackItem",
	"BillboardGui",
	"BindableEvent",
	"BindableFunction",
	"BlockMesh",
	"BodyAngularVelocityBodyColors",
	"BodyForce",
	"BodyGyro",
	"BodyPosition",
	"BodyThrust",
	"BodyVelocity",
	"BoolValue",
	"BrickColorValue",
	"CFrameValue",
	"Camera",
	"CharacterMesh",
	"ClickDetector",
	"Clothing",
	"Color3Value",
	"Configuration",
	"CornerWedgePart",
	"CustomEvent",
	"CustomEventReceiver",
	"CylinderMesh",
	"Decal",
	"Dialog",
	"DialogChoice",
	"DoubleConstrainedValue",
	"Explosion",
	"Feature",
	"FileMesh",
	"Fire",
	"Flag",
	"FlagStand",
	"FloorWire",
	"ForceField",
	"Frame",
	"Glue",
	"Handles",
	"Hat",
	"Hole",
	"HopperBin",
	"Humanoid",
	"ImageButton",
	"ImageLabel",
	"IntConstrainedValue",
	"IntValue",
	"JointInstance",
	"Keyframe",
	"LocalBackpack",
	"LocalScript",
	"Message",
	"Model",
	"ModuleScript",
	"Motor",
	"MotorFeature",
	"Mouse",
	"NetworkClient",
	"NetworkReplicator",
	"NetworkServer",
	"NumberValue",
	"ObjectValue",
	"Pants",
	"Part",
	"Platform",
	"Plugin",
	"PluginManager",
	"PluginMouse",
	"PointLight",
	"Pose",
	"ProfilingItem",
	"RayValue",
	"RemoteEvent",
	"RemoteFunction",
	"ReplicatedStorage",
	"RocketPropulsion",
	"RotateP",
	"RotateV",
	"ScreenGui",
	"Script",
	"ScriptContext",
	"Seat",
	"Selection",
	"SelectionBox",
	"SelectionPartLasso",
	"SelectionPointLasso",
	"Shirt",
	"ShirtGraphic",
	"SkateboardPlatform",
	"Skin",
	"Sky",
	"Smoke",
	"Snap",
	"Sound",
	"Sparkles",
	"SpawnLocation",
	"SpecialMesh",
	"SpotLight",
	"StarterGear",
	"StatsItem",
	"Status",
	"StringValue",
	"StudioTool",
	"SurfaceGui",
	"SurfaceSelection",
	"TaskScheduler",
	"Team",
	"Terrain",
	"TerrainRegion",
	"TextBox",
	"TextButton",
	"TextLabel",
	"Texture",
	"TextureTrail",
	"Tool",
	"TrussPart",
	"Vector3Value",
	"VehicleSeat",
	"VelocityMotor",
	"WedgePart",
	"Weld",
}

local globals = {}

for _, objectType in ipairs(instances) do
	globals[objectType] = function(dat)
		local obj = Instance.new(objectType)
		local parent

		for k, v in pairs(dat) do
			if type(k) == "string" then
				if k == "Parent" then
					parent = v
				else
					obj[k] = v
				end
			elseif type(k) == "number" and type(v) == "userdata" then
				v.Parent = obj
			end
		end

		obj.Parent = parent

		return obj
	end
end

return function()
	-- Vomit everything into the global scope
	local env = getfenv(0)
	for k, v in globals do
		env[k] = v
	end
	setfenv(0, env)
end
