-- Services 
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

-- Modules
local BlockDefinitions = require(ReplicatedStorage:WaitForChild("Definitions"):WaitForChild("BlockDefinitions"))
local BackpackDefinitions = require(ReplicatedStorage:WaitForChild("Definitions"):WaitForChild("OtherItemDefinitions"))
local VehicleDefinitions = require(ReplicatedStorage:WaitForChild("Definitions"):WaitForChild("VehicleDefinitions"))
local ToolDefinitions = require(game:GetService("ReplicatedStorage").Packages.InnoTools.ToolDefinitions) 
local MadCommEvents = ReplicatedStorage:WaitForChild("MadCommEvents")

-- Constants
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local root = Character:WaitForChild("HumanoidRootPart")

-- Tables
local ESPObjects = {}
local Remotes = {}
local keys = {}
local Settings = {
	ESP_DISTANCE = 200,
	MIN_VALUE = 0,
	
	CHARACTER_AUTOFARM_DISTANCE = 25,
	CHARACTER_AUTOFARM_RATE = 2,
	CHARACTER_AUTOFARM_MIN_VALUE = 0,
	
	VEHICLE_AUTOFARM_DISTANCE = 25,
	VEHICLE_AUTOFARM_RATE = 2,
	VEHICLE_AUTOFARM_MIN_VALUE = 0,
	
	FLY_SPEED = 1,
	
	VEHICLE_SPEED_MULTIPLIER = 1,
	VEHICLE_MINE_SIZE_X = 25,
	VEHICLE_MINE_SIZE_Y = 25,
	VEHICLE_MINE_SIZE_Z = 2,
	
	VEHICLE_DRILL_POWER = 1,
	VEHICLE_DRILL_SPEED = 1
}

-- Variables
local isSelling = false

-- Private Functions
local function RefreshRemotes()
	for _, Object in pairs(game:GetDescendants()) do
		if Object.Name == "CargoRecovery" or Object.Parent:FindFirstAncestorWhichIsA("Folder") then continue end
		if Object:GetAttribute("OwnerId") == game.Players.LocalPlayer.UserId or Object:GetAttribute("EquippedPlayerId") == game.Players.LocalPlayer.UserId then
			if Object:GetAttribute("MadCommId") then
				Remotes[Object.Name] = Object:GetAttribute("MadCommId")
			end
		end
	end
end

local function CreateOreESP(Ore)
	if ESPObjects[Ore] then return end
	if Ore.Name == "SolidStone" then return end
	if not Ore.Parent then return end

	local mineId = Ore:GetAttribute("MineId")
	if not mineId then return end

	local def = BlockDefinitions[mineId]
	if not def then return end

	local Color = (def.Appearance and def.Appearance.Color) or def.PartProperties.Color
	
	if (Ore.Position - Character.PrimaryPart.Position).Magnitude > Settings.ESP_DISTANCE then return end
	if def.Value < Settings.MIN_VALUE then return end
	
	local m = Instance.new("Model")
	m.Parent = Ore
	
	local p = Instance.new("Part")
	p.Size = Ore.Size
	p.Anchored = true
	p.Position = Ore.Position
	p.Transparency = .99
	p.Material = Enum.Material.Air
	p.CanCollide = false
	p.Parent = m
	
	local h = Instance.new("Highlight")
	h.Parent = m
	h.FillColor = Color
	h.FillTransparency = 0.8
	h.OutlineColor = Color
	h.Name = "ESP_Highlight"
	h.Adornee = p

	local g = Instance.new("BillboardGui")
	g.Name = "Scale"
	g.Parent = p
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Active = true
	g.AlwaysOnTop = true
	g.LightInfluence = 1
	g.Size = UDim2.new(7, 0, 4, 0)
	g.StudsOffset = Vector3.new(0, 4.5, 0)
	g.Enabled = true
	
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = m

	local UIList = Instance.new("Frame")
	UIList.Name = "UIList"
	UIList.Parent = g
	UIList.BackgroundTransparency = 1
	UIList.BorderSizePixel = 0
	UIList.Size = UDim2.new(1, 0, 1, 0)

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.Parent = UIList
	UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local Name = Instance.new("TextLabel")
	Name.Name = "Name"
	Name.Parent = UIList
	Name.BackgroundTransparency = 1
	Name.BorderSizePixel = 0
	Name.Size = UDim2.new(1, 0, 0.4, 0)
	Name.Font = Enum.Font.Code
	Name.Text = mineId
	Name.TextColor3 = Color
	Name.TextScaled = true
	Name.TextStrokeTransparency = 0
	Name.TextWrapped = true

	local Value = Instance.new("TextLabel")
	Value.Name = "Value"
	Value.Parent = UIList
	Value.BackgroundTransparency = 1
	Value.BorderSizePixel = 0
	Value.LayoutOrder = 1
	Value.Size = UDim2.new(1, 0, 0.4, 0)
	Value.Font = Enum.Font.Code
	Value.Text = "$" .. tostring(def.Value)
	Value.TextColor3 = Color3.fromRGB(118, 230, 84)
	Value.TextScaled = true
	Value.TextStrokeTransparency = 0
	Value.TextWrapped = true
	Value.Visible = false

	ESPObjects[Ore] = {
		ESP_Highlight = h,
		ESP_GUI = g,
		ESP_Part = p,
		ESP_Model = m,
		Value = def.Value
	}
end

local function DestroyESP()
	for o, t in pairs(ESPObjects) do
		t.ESP_Model:Destroy()
		ESPObjects[o] = nil
	end
end

local function UpdateESP()
	for o, t in pairs(ESPObjects) do
		if Toggles.VALUEESP.Value then
			t.ESP_GUI.UIList.Value.Visible = true
		else
			t.ESP_GUI.UIList.Value.Visible = false
		end

		local Distance = (o.Position - Character.PrimaryPart.Position).Magnitude
		if Distance > Settings.ESP_DISTANCE or t.Value < Settings.MIN_VALUE then
			t.ESP_Model:Destroy()
			ESPObjects[o] = nil
		end
	end
end

local function GetNearbyOres()
	if not Character or not Character.PrimaryPart then
		return {}
	end

	local range = Settings.ESP_DISTANCE
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Whitelist
	overlapParams.FilterDescendantsInstances = { workspace.PlacedOre }

	local parts = workspace:GetPartBoundsInBox(
		CFrame.new(Character.PrimaryPart.Position),
		Vector3.new(range * 2, range * 2, range * 2),
		overlapParams
	)

	return parts
end

local function SizeToGrid(size)
	return Vector3int16.new(
		math.floor(size.X - 0.5),
		math.floor(size.Y - 0.5),
		math.floor(size.Z - 0.5)
	)
end

local function WorldToGrid(pos)
	return Vector3int16.new(
		math.floor(pos.X / 4),
		math.floor(pos.Y / 4),
		math.floor(pos.Z / 4)
	)
end

local function VehicleSizeToGrid(size)
	return Vector3int16.new(
		math.floor(size.X / 1.25),
		math.floor(size.Y / 1.25),
		math.floor(size.Z / 1.25)
	)
end

local function ConnDisconnect(conn)
	if conn then
		conn:Disconnect()
	end
end

local function getPick(str)
	if not str then return end
	local match = str:match("Pick")
	return match
end

local function FindPickaxe()
	for _, Model in pairs(LocalPlayer.InnoBackpack:GetChildren()) do
		local match = getPick(Model:GetAttribute("ToolId"))
		if match then return Model end
	end
	
	for _, Model in pairs(LocalPlayer.Character:GetChildren()) do
		local match = getPick(Model:GetAttribute("ToolId"))
		if match then return Model end
	end
end

local function GetOreValue(Ore)
	return BlockDefinitions[Ore:GetAttribute("MineId")].Value
end

local function FindPickHardness()
	local PickaxeID = FindPickaxe():GetAttribute("ToolId")	
	return ToolDefinitions[PickaxeID].Stats.Hardness
end

local function GetBackpack()
	return Character.OrePackCargo
end

local function FindBackpackStorage()
	local BackpackModel = GetBackpack()
	local Size = SizeToGrid(BackpackModel.Size)

	for _, Backpack in pairs(BackpackDefinitions) do
		if Size == Backpack.Size then
			return Backpack.Holds
		end
	end
end

local function GetItemsInBackpack()
	local count = 0
	
	for _, Object in pairs(GetBackpack():GetDescendants()) do
		if Object:IsA("MeshPart") then
			count += 1
		end
	end
	
	return count
end

local function FindBlockHardness(Ore)
	local OreData = BlockDefinitions[Ore:GetAttribute("MineId")]
	local Hardness = OreData.Hardness

	return Hardness
end

local function CharacterisFull()
	return GetItemsInBackpack() >= FindBackpackStorage()
end

local function FindVehicleRemote()
	local localUserId = LocalPlayer.UserId
	for _, Model in pairs(workspace.Vehicles:GetChildren()) do
		if Model:GetAttribute("OwnerId") == localUserId and Model:GetAttribute("DrillOn") then
			return Model:GetAttribute("MadCommId")
		end
	end
end

local function FindVehicle()
	local localUserId = LocalPlayer.UserId
	for _, Model in pairs(workspace.Vehicles:GetChildren()) do
		if Model:GetAttribute("OwnerId") == localUserId then
			return Model
		end
	end
end

local function GetVehicleMaxStorage()
	local Vehicle = FindVehicle()
	if not Vehicle then return 0 end

	local int16 = VehicleSizeToGrid(Vehicle.CargoVolume.Size)
	return int16.X * int16.Y * int16.Z
end

local function GetItemsInVehicle()
	local count = 0
	for _, Object in pairs(FindVehicle().CargoVolume:GetChildren()) do
		if Object:IsA("MeshPart") then
			count += 1
		end
	end
	
	return count
end

local function VehicleIsFull()
	return GetItemsInVehicle() >= GetVehicleMaxStorage()
end

local function Noclip()
	for _, Object in ipairs(Character:GetDescendants()) do
		if Object:IsA("BasePart") then
			Object.CanCollide = false
		end
	end
end

local function Clip()
	for _, Object in ipairs(Character:GetDescendants()) do
		if Object:IsA("BasePart") then
			Object.CanCollide = true
		end
	end
end

local function AutoSell()
	if not Toggles.AUTO_SELL.Value or Humanoid.Sit then
		return
	end

	local CargoContainer = workspace.FactoryGridItemsServer[LocalPlayer.Name].CargoVolume
	local Prompt = CargoContainer:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not Prompt then
		return
	end

	local PreviousPos = Character.PrimaryPart.CFrame
	Character:PivotTo(CargoContainer.CFrame * CFrame.new(0, 5, 0))
	task.wait(0.5)
	fireproximityprompt(Prompt)
	Character:PivotTo(PreviousPos)
	isSelling = false
end

local function CharacterFarm()
	local primaryPart = Character and Character.PrimaryPart
	if not primaryPart then return end
	if CharacterisFull() then return end
	
	local pickaxe = FindPickaxe()
	if not pickaxe then return end
	
	local pickHardness = FindPickHardness()
	local activateRemote = MadCommEvents
		:WaitForChild(pickaxe:GetAttribute("MadCommId"))
		:WaitForChild("Activate")
	
	local characterPos = primaryPart.Position
	local maxDistance = Settings.CHARACTER_AUTOFARM_DISTANCE
	local maxDistanceSq = maxDistance * maxDistance
	local minValue = Settings.CHARACTER_AUTOFARM_MIN_VALUE
	
	for _, Ore in ipairs(workspace.PlacedOre:GetChildren()) do
		local orePos = Ore.Position
		local offset = orePos - characterPos
		local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

		if distanceSq > maxDistanceSq then
			continue
		end
		
		if Ore.Name == "SolidStone" then 
			continue 
		end

		if GetOreValue(Ore) < minValue then
			continue
		end
		
		if FindBlockHardness(Ore) > pickHardness then
			continue
		end
		
		local args = {
			48,
			WorldToGrid(Ore.CFrame.Position)
		}
		
		activateRemote:FireServer(unpack(args))
		break
	end
end

local function VehicleFarm()
	local primaryPart = Character and Character.PrimaryPart
	if not primaryPart then return end
	if VehicleIsFull() then return end

	local vehicleRemote = FindVehicleRemote()
	if not vehicleRemote then return end

	local pickHardness = FindPickHardness()
	local drillRemote = MadCommEvents
		:WaitForChild(tostring(vehicleRemote))
		:WaitForChild("DrillMine")

	local characterPos = primaryPart.Position
	local minValue = Settings.VEHICLE_AUTOFARM_MIN_VALUE
	local maxDistance = Settings.VEHICLE_AUTOFARM_DISTANCE
	local maxDistanceSq = maxDistance * maxDistance
	
	for _, Ore in pairs(workspace.PlacedOre:GetChildren()) do
		if Ore.Name == "SolidStone" then 
			continue 
		end
		
		local orePos = Ore.Position
		local offset = orePos - characterPos
		local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
		
		
		if distanceSq > maxDistanceSq then
			continue
		end

		if GetOreValue(Ore) < minValue then
			continue
		end
		
		if FindBlockHardness(Ore) > pickHardness then
			continue
		end
		
		local args = {
			48,
			WorldToGrid(Ore.CFrame.Position)
		}
		
		drillRemote:FireServer(unpack(args))
		break
	end
end

local function DestroyFly()
	local v = root:FindFirstChild("BodyVelocity")
	local b = root:FindFirstChild("BodyGyro")
	if v and b then
		v:Destroy()
		b:Destroy()
		Humanoid.PlatformStand = false
		Character.HumanoidRootPart.Running.Volume = .65
	end
end

local function Fly()
	if Toggles.FLY.Value then
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(8999999488, 8999999488, 8999999488)
		bv.Velocity = Vector3.zero
		bv.P = 1250
		bv.Parent = root

		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(8999999488, 8999999488, 8999999488)
		bg.P = 90000
		bg.CFrame = root.CFrame
		bg.Parent = root

		Humanoid.PlatformStand = true
		Character.HumanoidRootPart.Running.Volume = 0
	else
		root:FindFirstChild("BodyVelocity"):Destroy()
		root:FindFirstChild("BodyGyro"):Destroy()
		Humanoid.PlatformStand = false
		Character.HumanoidRootPart.Running.Volume = .65
	end
end

local function UpdateFly()
	local bodyVelocity = root:FindFirstChild("BodyVelocity")
	local bodyGyro = root:FindFirstChild("BodyGyro")
	if not Toggles.FLY.Value or not bodyVelocity or not bodyGyro then return end

	local cam = workspace.CurrentCamera
	local moveDir = Vector3.zero

	if keys[Enum.KeyCode.W] then moveDir += cam.CFrame.LookVector end
	if keys[Enum.KeyCode.S] then moveDir -= cam.CFrame.LookVector end
	if keys[Enum.KeyCode.D] then moveDir += cam.CFrame.RightVector end
	if keys[Enum.KeyCode.A] then moveDir -= cam.CFrame.RightVector end
	if keys[Enum.KeyCode.Space] then moveDir += Vector3.new(0,1,0) end
	if keys[Enum.KeyCode.LeftControl] then moveDir -= Vector3.new(0,1,0) end

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	bodyVelocity.Velocity = moveDir * (Settings.FLY_SPEED * 100)
	bodyGyro.CFrame = cam.CFrame
end

local function TeleportToPlayer(Player)
	local Player = Players[Player]
	if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
		Character:PivotTo(Player.Character.PrimaryPart.CFrame)
	end
end

local function GetVehicleDef()
	local Vehicle = FindVehicle()
	if not Vehicle then return end
	
	local Def = VehicleDefinitions[Vehicle.Name]
	return Def
end

local function VehicleSpeedMultipler()
	local Vehicle = FindVehicle()
	local Def = GetVehicleDef()
	
	if Toggles.VEHICLE_SPEED_ENABLE.Value then
		if not Vehicle then return end
		if not Def then return end
		local Speed = Def.Performance.Power * Settings.VEHICLE_SPEED_MULTIPLIER
		if Vehicle:FindFirstChild("PerformanceFolder") then
			Vehicle.PerformanceFolder:SetAttribute("Power", Speed)
		end
	else
		if not Vehicle then return end
		if not Def then return end
		if Vehicle:FindFirstChild("PerformanceFolder") then
			local DefSpeed = Def.Performance.Power
			Vehicle.PerformanceFolder:SetAttribute("Power", DefSpeed)
		end
	end
end

local function AdjustDrillSize(x,y,z)
	local Vehicle = FindVehicle()
	if not Vehicle then return end
	
	local DrillZone = Vehicle.Body:FindFirstChild("DrillZone", true)
	if not DrillZone then return end
	
	if Toggles.VEHICLE_MINE_SETTINGS.Value then
		DrillZone.Transparency = .8
		DrillZone.Size = Vector3.new(Settings.VEHICLE_MINE_SIZE_X, Settings.VEHICLE_MINE_SIZE_Y, Settings.VEHICLE_MINE_SIZE_Z)
	else
		local AssetFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VehicleAssets"):WaitForChild("DiggingVehicles")
		local Model = AssetFolder:FindFirstChild(Vehicle.Name)
		
		DrillZone.Size = Model.Body:FindFirstChild("DrillZone", true).Size
		DrillZone.Transparency = 1
	end
end

local function AdjustDrillPower()
	local Vehicle = FindVehicle()
	if not Vehicle then return end

	local DrillZone = Vehicle.Body:FindFirstChild("DrillZone", true)
	if not DrillZone then return end
	
	local Def = GetVehicleDef()
	if not Def then return end
	
	if Toggles.DRILL_SETTINGS.Value then
		Vehicle.PerformanceFolder:SetAttribute("DrillHardnessPct", Settings.VEHICLE_DRILL_POWER)
	else
		
		
		Vehicle.PerformanceFolder:SetAttribute("DrillHardnessPct", Def.Performance.DrillHardnessPct)
	end
end

local function AdjustDrillSpeed()
	local Vehicle = FindVehicle()
	if not Vehicle then return end

	local DrillZone = Vehicle.Body:FindFirstChild("DrillZone", true)
	if not DrillZone then return end

	local Def = GetVehicleDef()
	if not Def then return end

	if Toggles.DRILL_SETTINGS.Value then
		Vehicle.PerformanceFolder:SetAttribute("DrillSpeedPct", Settings.VEHICLE_DRILL_SPEED)
	else
		Vehicle.PerformanceFolder:SetAttribute("DrillSpeedPct", Def.Performance.DrillSpeedPct)
	end
end

-- Methods
Child_Added_Conn = workspace.PlacedOre.ChildAdded:Connect(function(Ore)
	if not Toggles.ESP.Value then return end
	if Ore.Name == "SolidStone" then return end
	if ESPObjects[Ore] then return end
	if not Character or not Character.PrimaryPart then return end

	if (Ore.Position - Character.PrimaryPart.Position).Magnitude > Settings.ESP_DISTANCE then
		return
	end

	CreateOreESP(Ore)
end)

Child_Removed_Conn = workspace.PlacedOre.ChildRemoved:Connect(function(Ore)
	local t = ESPObjects[Ore]
	if not t then return end

	if t.ESP_Model then
		t.ESP_Model:Destroy()
	end

	ESPObjects[Ore] = nil
end)

UIS_Input_Began_Conn = UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	keys[input.KeyCode] = true
end)

UIS_InputEnded_Conn = UIS.InputEnded:Connect(function(input, gp)
	keys[input.KeyCode] = nil
end)

RunServiceConn = RunService.RenderStepped:Connect(function()
	UpdateESP()
end)

CharacterAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	root = Character:WaitForChild("HumanoidRootPart")
end)

-- UI STUFF
local repo = 'https://raw.githubusercontent.com/WitherArcher/new_ui/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
	Title = 'Ultimate Mining Tycoon - vkdfdf',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Main = Window:AddTab("Main"),
	ESP = Window:AddTab('ESP'),
	['UI Settings'] = Window:AddTab('UI Settings'),
}

-- Mobile UI close/open feature (set to false to disable, true to force on all devices)
local MOBILE_UI_CLOSE_FEATURE = false
local mobileFeatureActive = MOBILE_UI_CLOSE_FEATURE or Library.IsMobile

local MobileCloseButton, MobileOpenButton
if mobileFeatureActive then
	-- Saved window position so we can restore it on reopen
	local savedWindowPosition = nil
	local firstClose = true

	-- Close button: parented to Window.Holder so it moves with the UI when dragged
	MobileCloseButton = Instance.new('TextButton')
	MobileCloseButton.Name = 'MobileCloseButton'
	MobileCloseButton.Text = '✕'
	MobileCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	MobileCloseButton.TextSize = 18
	MobileCloseButton.Font = Enum.Font.GothamBold
	MobileCloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	MobileCloseButton.BorderSizePixel = 0
	MobileCloseButton.Size = UDim2.new(0, 30, 0, 25)
	MobileCloseButton.AnchorPoint = Vector2.new(1, 0)
	MobileCloseButton.Position = UDim2.new(1, -2, 0, 1)
	MobileCloseButton.ZIndex = 999
	MobileCloseButton.Parent = Window.Holder

	-- Rounded corners for close button
	local closeCorner = Instance.new('UICorner')
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = MobileCloseButton

	-- Open button: spawns at the close button's position, draggable
	MobileOpenButton = Instance.new('TextButton')
	MobileOpenButton.Name = 'MobileOpenButton'
	MobileOpenButton.Text = '☰'
	MobileOpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	MobileOpenButton.TextSize = 18
	MobileOpenButton.Font = Enum.Font.GothamBold
	MobileOpenButton.BackgroundColor3 = Color3.fromRGB(0, 85, 255)
	MobileOpenButton.BorderSizePixel = 0
	MobileOpenButton.Size = UDim2.new(0, 40, 0, 40)
	MobileOpenButton.AnchorPoint = Vector2.new(0.5, 0.5)
	MobileOpenButton.Position = UDim2.new(0, 5, 0.5, -17) -- default, will be overwritten on close
	MobileOpenButton.ZIndex = 999
	MobileOpenButton.Visible = false
	MobileOpenButton.Parent = Library.ScreenGui

	-- Rounded corners for open button
	local openCorner = Instance.new('UICorner')
	openCorner.CornerRadius = UDim.new(0, 8)
	openCorner.Parent = MobileOpenButton

	-- Make the open button draggable
	do
		local dragging = false
		local dragOffset = Vector2.zero
		local dragReady = false
		local wasDragged = false

		MobileOpenButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local pos = input.Position
				dragOffset = Vector2.new(
					pos.X - MobileOpenButton.AbsolutePosition.X - MobileOpenButton.AbsoluteSize.X * MobileOpenButton.AnchorPoint.X,
					pos.Y - MobileOpenButton.AbsolutePosition.Y - MobileOpenButton.AbsoluteSize.Y * MobileOpenButton.AnchorPoint.Y
				)
				dragging = true
				wasDragged = false
			elseif input.UserInputType == Enum.UserInputType.Touch then
				dragReady = true
				wasDragged = false
			end
		end)

		UIS.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement
				and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			-- First touch move: calculate offset from real position
			if dragReady and input.UserInputType == Enum.UserInputType.Touch then
				local pos = input.Position
				dragOffset = Vector2.new(
					pos.X - MobileOpenButton.AbsolutePosition.X - MobileOpenButton.AbsoluteSize.X * MobileOpenButton.AnchorPoint.X,
					pos.Y - MobileOpenButton.AbsolutePosition.Y - MobileOpenButton.AbsoluteSize.Y * MobileOpenButton.AnchorPoint.Y
				)
				dragReady = false
				dragging = true
			end

			if not dragging then return end

			wasDragged = true
			local pos = input.Position
			local anchorOffset = MobileOpenButton.AnchorPoint * MobileOpenButton.AbsoluteSize
			MobileOpenButton.Position = UDim2.fromOffset(
				pos.X - dragOffset.X + anchorOffset.X,
				pos.Y - dragOffset.Y + anchorOffset.Y
			)
		end)

		UIS.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				-- If it was a tap (not a drag), treat it as a click to open
				if not wasDragged and MobileOpenButton.Visible then
					-- Restore window to saved position
					if savedWindowPosition then
						Window.Holder.Position = savedWindowPosition
					end
					Window.Holder.Visible = true
					MobileOpenButton.Visible = false
				end
				dragging = false
				dragReady = false
			end
		end)
	end

	MobileCloseButton.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		-- Save the window's current position before hiding
		savedWindowPosition = Window.Holder.Position

		-- Only place the open button at the close button's position the first time
		if firstClose then
			local closeAbsPos = MobileCloseButton.AbsolutePosition
			local closeAbsSize = MobileCloseButton.AbsoluteSize
			MobileOpenButton.Position = UDim2.fromOffset(
				closeAbsPos.X + closeAbsSize.X / 2,
				closeAbsPos.Y + closeAbsSize.Y / 2
			)
			firstClose = false
		end

		Window.Holder.Visible = false
		MobileOpenButton.Visible = true
	end)
end

local CHARACTER_AUTOFARM = Tabs.Main:AddLeftGroupbox('Character Auto Farm')
local VEHICLE_SETTINGS = Tabs.Main:AddLeftGroupbox('Vehicle Settings')
local WORLD = Tabs.Main:AddLeftGroupbox('World')

local NoFogAtmosphere
local FullbrightConnection
local FullbrightColor = Color3.fromRGB(128, 128, 128)

WORLD:AddToggle('NO_FOG', {
	Text = 'Enable No Fog',
	Default = false,
	Callback = function(Value)
		if Value then
			local atmosphere = Lighting:FindFirstChild('Atmosphere')
			if atmosphere then
				NoFogAtmosphere = atmosphere
				atmosphere.Parent = ServerStorage
			end
		else
			if NoFogAtmosphere and NoFogAtmosphere.Parent == ServerStorage then
				NoFogAtmosphere.Parent = Lighting
				NoFogAtmosphere = nil
			end
		end
	end
})

WORLD:AddToggle('FULLBRIGHT', {
	Text = 'Enable Fullbright',
	Default = false,
	Callback = function(Value)
		if Value then
			if FullbrightConnection then
				for _, conn in ipairs(FullbrightConnection) do
					conn:Disconnect()
				end
			end

			FullbrightConnection = {}
			table.insert(FullbrightConnection, Lighting:GetPropertyChangedSignal('ClockTime'):Connect(function()
				Lighting.ClockTime = 14
			end))

			table.insert(FullbrightConnection, Lighting:GetPropertyChangedSignal('Ambient'):Connect(function()
				Lighting.Ambient = Color3.fromRGB(170, 170, 170)
			end))

			table.insert(FullbrightConnection, Lighting:GetPropertyChangedSignal('TimeOfDay'):Connect(function()
				Lighting.TimeOfDay = '14:00:00'
			end))

			table.insert(FullbrightConnection, Lighting:GetPropertyChangedSignal('OutdoorAmbient'):Connect(function()
				Lighting.OutdoorAmbient = FullbrightColor
			end))

			Lighting.Ambient = Color3.fromRGB(170, 170, 170)
			Lighting.OutdoorAmbient = FullbrightColor
			Lighting.ClockTime = 14
			Lighting.TimeOfDay = '14:00:00'
		else
			if FullbrightConnection then
				for _, conn in ipairs(FullbrightConnection) do
					conn:Disconnect()
				end
				FullbrightConnection = nil
			end
		end
	end
})

local MISC = Tabs.Main:AddLeftGroupbox('Misc')
local VEHICLE_AUTOFARM = Tabs.Main:AddRightGroupbox('Vehicle Auto Farm')
local TELEPORTS = Tabs.Main:AddRightGroupbox("Teleport")

local ESPSettings = Tabs.ESP:AddLeftGroupbox('ESP Controls')

-- VEHICLE_SETTINGS
local VehicleSpeedToggle = VEHICLE_SETTINGS:AddToggle('VEHICLE_SPEED_ENABLE', {
	Text = 'Enable Speed Multiplier',
	Default = false,

	Callback = function(Value)
		VehicleSpeedMultipler()
	end
})

VehicleSpeedToggle:AddKeyPicker('VEHICLE_SPEED_KEYBIND', {
	Default = 'J',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'Vehicle Speed Keybind'
})

local VEHICLE_SPEED_MULTIPLIER = VEHICLE_SETTINGS:AddDependencyBox();

VEHICLE_SPEED_MULTIPLIER:AddSlider('VEHICLE_SPEED', {
	Text = 'Vehicle Speed Multiplier',
	Default = 1,
	Min = 1,
	Max = 20,
	Rounding = 0,
	Compact = false,
	Suffix = "x",

	Callback = function(Value)
		Settings.VEHICLE_SPEED_MULTIPLIER = Value
		VehicleSpeedMultipler()
	end
})

VEHICLE_SPEED_MULTIPLIER:SetupDependencies({
	{ Toggles.VEHICLE_SPEED_ENABLE, true }
});

local VehicleDrillSettingsToggle = VEHICLE_SETTINGS:AddToggle('VEHICLE_MINE_SETTINGS', {
	Text = 'Enable Drill Expander',
	Default = false,
	
	Callback = function(Value)
		AdjustDrillSize(0,0,0)
	end,
})

VehicleDrillSettingsToggle:AddKeyPicker('VEHICLE_DRILL_SETTINGS_KEYBIND', {
	Default = 'K',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'Vehicle Drill Settings Keybind'
})

local VEHICLE_SETTINGS_DEPBOX = VEHICLE_SETTINGS:AddDependencyBox();

VEHICLE_SETTINGS_DEPBOX:AddSlider('VEHICLE_MINE_X', {
	Text = 'Vehicle Drill Size X',
	Default = 1,
	Min = 1,
	Max = 500,
	Rounding = 0,
	Compact = false,
	Suffix = "",

	Callback = function(Value)
		Settings.VEHICLE_MINE_SIZE_X = Value
		AdjustDrillSize(Value,0,0)
	end
})

VEHICLE_SETTINGS_DEPBOX:AddSlider('VEHICLE_MINE_Y', {
	Text = 'Vehicle Drill Size Y',
	Default = 1,
	Min = 1,
	Max = 500,
	Rounding = 0,
	Compact = false,
	Suffix = "",

	Callback = function(Value)
		Settings.VEHICLE_MINE_SIZE_Y = Value
		AdjustDrillSize(0,Value,0)
	end
})

VEHICLE_SETTINGS_DEPBOX:AddSlider('VEHICLE_MINE_Z', {
	Text = 'Vehicle Drill Size Z',
	Default = 1,
	Min = 1,
	Max = 500,
	Rounding = 0,
	Compact = false,
	Suffix = "",

	Callback = function(Value)
		Settings.VEHICLE_MINE_SIZE_Z = Value
		AdjustDrillSize(0,0,Value)
	end
})

VEHICLE_SETTINGS_DEPBOX:SetupDependencies({
	{ Toggles.VEHICLE_MINE_SETTINGS, true }
});

local VehicleDrillToggle = VEHICLE_SETTINGS:AddToggle('DRILL_SETTINGS', {
	Text = 'Enable Drill Settings',
	Default = false,

	Callback = function(Value)
		AdjustDrillPower()
		AdjustDrillSpeed()
	end
})

VehicleDrillToggle:AddKeyPicker('VEHICLE_DRILL_KEYBIND', {
	Default = 'L',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'Vehicle Drill Keybind'
})

local DRILL_SPEED_DEPBOX = VEHICLE_SETTINGS:AddDependencyBox();

DRILL_SPEED_DEPBOX:AddSlider('DRILL_POWER_VALUE', {
	Text = 'Drill Power',
	Default = 1,
	Min = 1,
	Max = 100,
	Rounding = 0,
	Compact = false,
	Suffix = "",

	Callback = function(Value)
		Settings.VEHICLE_DRILL_POWER = Value
		AdjustDrillPower()
	end
})

DRILL_SPEED_DEPBOX:AddSlider('DRILL_SPEED_VALUE', {
	Text = 'Drill Speed',
	Default = 1,
	Min = 1,
	Max = 100,
	Rounding = 0,
	Compact = false,
	Suffix = "",

	Callback = function(Value)
		Settings.VEHICLE_DRILL_SPEED = Value
		AdjustDrillSpeed()
	end
})

DRILL_SPEED_DEPBOX:SetupDependencies({
	{ Toggles.DRILL_SETTINGS, true }
});

-- TELEPORTS
local BASE_TELEPORT = TELEPORTS:AddButton({
	Text = 'Base',
	Func = function()
		Character:MoveTo(workspace.FactoryGridItemsServer[LocalPlayer.Name].CargoVolume.Position + Vector3.new(0,5,0))
	end,
	DoubleClick = false,
})

local MAIN_SHOP_TELEPORT = TELEPORTS:AddButton({
	Text = 'Gear Shop',
	Func = function()
		Character:MoveTo(Vector3.new(-1552.54541015625, 9.999999046325684, 14.740448951721191) + Vector3.new(0,2,0))
	end,
	DoubleClick = false,
})

local REBIRTH_SHOP_TELEPORT = TELEPORTS:AddButton({
	Text = 'Rebirth Shop',
	Func = function()
		Character:MoveTo(Vector3.new(-1453.0103759765625, 9.99999713897705, 228.03382873535156) + Vector3.new(0,2,0))
	end,
	DoubleClick = false,
})

local ORE_DEPO_TELEPORT = TELEPORTS:AddButton({
	Text = 'Ore Storage',
	Func = function()
		Character:MoveTo(Vector3.new(-481.061767578125, -75.0000228881836, 627.1715087890625) + Vector3.new(0,2,0))
	end,
	DoubleClick = false,
})

local EXPLOSIVE_SHOP_TELEPORT = TELEPORTS:AddButton({
	Text = 'Explosive Shop',
	Func = function()
		Character:MoveTo(Vector3.new(388.7626647949219, 78.2343521118164, -750.7398681640625) + Vector3.new(0,2,0))
	end,
	DoubleClick = false,
})

local VEHICLE_TELEPORT = TELEPORTS:AddButton({
	Text = 'Vehicle',
	Func = function()
		Character:MoveTo(FindVehicle().CargoVolume.Position)
	end,
	DoubleClick = false,
})

TELEPORTS:AddLabel('Players', true)
TELEPORTS:AddDivider()
TELEPORTS:AddDropdown('MyPlayerDropdown', {
	SpecialType = 'Player',
	Text = 'Player Dropdown',
})

local PLAYER_TELEPORT = TELEPORTS:AddButton({
	Text = 'Teleport',
	Func = function()
		if not Options.MyPlayerDropdown.Value then return end
		TeleportToPlayer(Options.MyPlayerDropdown.Value)
	end,
	DoubleClick = false,
})

-- MISC
MISC:AddToggle('AUTO_SELL', {
	Text = 'Enable Auto Sell',
	Default = false,
	AUTO_SELL_CONN,

	Callback = function(Value)
		local AUTO_SELL_BUSY = false
		
		if Value then
			if CharacterisFull() then
				AutoSell()
			end
			AUTO_SELL_CONN = GetBackpack().ChildAdded:Connect(function(c)
				if c:IsA("Weld") then return end
				if AUTO_SELL_BUSY then return end
				if not CharacterisFull() then return end

				AUTO_SELL_BUSY = true

				AutoSell()

				task.delay(0.25, function()
					AUTO_SELL_BUSY = false
				end)
			end)
		else
			if AUTO_SELL_CONN then
				AUTO_SELL_CONN:Disconnect()
				AUTO_SELL_CONN = nil
			end
		end
	end
})


local FLY_CONN = nil

local FlyToggle = MISC:AddToggle('FLY', {
	Text = 'Enable Fly',
	Default = false,

	Callback = function(Value)
		Fly()

		if Value then
			-- prevent stacking
			if FLY_CONN then
				FLY_CONN:Disconnect()
			end

			FLY_CONN = RunService.RenderStepped:Connect(function()
				UpdateFly()
			end)
		else
			if FLY_CONN then
				FLY_CONN:Disconnect()
				FLY_CONN = nil
			end
		end
	end
})

FlyToggle:AddKeyPicker('FLY_KEYBIND', {
	Default = 'X',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'Fly Keybind'
})

local Depbox = MISC:AddDependencyBox();
Depbox:AddSlider('FLY_SPEED', {
	Text = 'Fly Speed',
	Default = 1,
	Min = 1,
	Max = 20,
	Rounding = 0,
	Compact = false,
	Suffix = "",

	Callback = function(Value)
		Settings.FLY_SPEED = Value
	end
})
Depbox:SetupDependencies({
	{ Toggles.FLY, true }
});


MISC:AddSlider('WALKSPEED', {
	Text = 'Walkspeed',
	Default = 16,
	Min = 16,
	Max = 500,
	Rounding = 0,
	Compact = false,
	Suffix = " ws",

	Callback = function(Value)
		Character.Humanoid.WalkSpeed = Value
	end
})


local CHARACTER_AURMFARM_FUNC = nil
local CharacterAutoFarmToggle = CHARACTER_AUTOFARM:AddToggle('CHARACTER_AUTOFARM', {
	Text = 'Enable',
	Default = false,

	Callback = function(Value)
		if Value then
			-- prevent stacking
			if CHARACTER_AURMFARM_FUNC then
				task.cancel(CHARACTER_AURMFARM_FUNC)
			end

			CHARACTER_AURMFARM_FUNC = task.spawn(function()
				while true do
					CharacterFarm()
					task.wait(Settings.CHARACTER_AUTOFARM_RATE)

					if Library.Unloaded then break end
				end
			end)
		else
			if CHARACTER_AURMFARM_FUNC then
				task.cancel(CHARACTER_AURMFARM_FUNC)
				CHARACTER_AURMFARM_FUNC = nil
			end
		end
	end
})

CharacterAutoFarmToggle:AddKeyPicker('CHARACTER_AUTOFARM_KEYBIND', {
	Default = 'F', -- change key if you want
	SyncToggleState = true,
	Mode = 'Toggle', -- or 'Hold'
	Text = 'Character AutoFarm Keybind'
})

CHARACTER_AUTOFARM:AddSlider('CHARACTER_AUTOFARM_DISTANCE', {
	Text = 'Distance',
	Default = 25,
	Min = 0,
	Max = 40,
	Rounding = 1,
	Compact = false,
	Suffix = " studs",

	Callback = function(Value)
		Settings.CHARACTER_AUTOFARM_DISTANCE = Value
	end
})

CHARACTER_AUTOFARM:AddSlider('CHARACTER_AUTOFARM_RATE', {
	Text = 'Rate',
	Default = 2.5,
	Min = 0.5,
	Max = 5,
	Rounding = 1,
	Compact = false,
	Suffix = "s",

	Callback = function(Value)
		Settings.CHARACTER_AUTOFARM_RATE = Value
	end
})

CHARACTER_AUTOFARM:AddSlider('CHARACTER_AUTOFARM_MIN_VALUE', {
	Text = 'Minimum Value',
	Default = 0,
	Min = 0,
	Max = 30000,
	Rounding = 0,
	Compact = false,
	HideMax = true,
	Suffix = "$",

	Callback = function(Value)
		Settings.CHARACTER_AUTOFARM_MIN_VALUE = Value
	end
})

-- VEHICLE AUTO FARM
local VehicleAutoFarmToggle = VEHICLE_AUTOFARM:AddToggle('VEHICLE_AUTOFARM', {
	Text = 'Enable',
	Default = false,
	VEHICLE_AURMFARM_FUNC = nil,

	Callback = function(Value)
		if Value then
			VEHICLE_AURMFARM_FUNC = task.spawn(function()
				while true do
					VehicleFarm()
					task.wait(Settings.VEHICLE_AUTOFARM_RATE)
					if Library.Unloaded then break end
				end
			end)
		else
			if VEHICLE_AURMFARM_FUNC then
				task.cancel(VEHICLE_AURMFARM_FUNC)
			end
		end
	end
})

VehicleAutoFarmToggle:AddKeyPicker('VEHICLE_AUTOFARM_KEYBIND', {
	Default = 'T',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'Vehicle AutoFarm Keybind'
})

VEHICLE_AUTOFARM:AddSlider('VEHICLE_AUTOFARM_DISTANCE', {
	Text = 'Distance',
	Default = 25,
	Min = 0,
	Max = 75,
	Rounding = 1,
	Compact = false,
	Suffix = " studs",

	Callback = function(Value)
		Settings.VEHICLE_AUTOFARM_DISTANCE = Value
	end
})

VEHICLE_AUTOFARM:AddSlider('VEHICLE_AUTOFARM_RATE', {
	Text = 'Rate',
	Default = 2.5,
	Min = 0,
	Max = 5,
	Rounding = 1,
	Compact = false,
	Suffix = "s",

	Callback = function(Value)
		Settings.VEHICLE_AUTOFARM_RATE = Value
	end
})

VEHICLE_AUTOFARM:AddSlider('VEHICLE_AUTOFARM_MIN_VALUE', {
	Text = 'Minimum Value',
	Default = 0,
	Min = 0,
	Max = 30000,
	Rounding = 0,
	Compact = false,
	HideMax = true,
	Suffix = "$",

	Callback = function(Value)
		Settings.VEHICLE_AUTOFARM_MIN_VALUE = Value
	end
})

-- ESP
local ESP_CONN = nil
local LastUpdate = 0

ESPSettings:AddToggle('ESP', {
	Text = 'Enable ESP',
	Default = false,

	Callback = function(Value)
		if not Value then
			if ESP_CONN then
				ESP_CONN:Disconnect()
				ESP_CONN = nil
			end
			DestroyESP()
		else
			ESP_CONN = RunService.RenderStepped:Connect(function()
				if tick() - LastUpdate < 0.5 then return end
				LastUpdate = tick()

				for _, Ore in ipairs(GetNearbyOres()) do
					CreateOreESP(Ore)
				end
				UpdateESP()
			end)
		end
	end
})

ESPSettings:AddSlider('ESPDistance', {
	Text = 'ESP Distance',
	Default = 200,
	Min = 0,
	Max = 500,
	Rounding = 1,
	Compact = false,
	Suffix = " studs",

	Callback = function(Value)
		Settings.ESP_DISTANCE = Value
	end
})

ESPSettings:AddToggle('VALUEESP', {
	Text = 'Enable Value ESP',
	Default = false,
	
	Callback = function(Value)
		UpdateESP()
	end
})

ESPSettings:AddSlider('ESPVALUE', {
	Text = 'Minimum Value',
	Default = 0,
	Min = 0,
	Max = 30000,
	Rounding = 0,
	Compact = false,
	HideMax = true,
	Suffix = "$",

	Callback = function(Value)
		Settings.MIN_VALUE = Value
	end
})

Library:SetWatermarkVisibility(false)
local FrameTimer = tick()
local FrameCounter = 0;
local FPS = 60;
local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
	FrameCounter += 1;

	if (tick() - FrameTimer) >= 1 then
		FPS = FrameCounter;
		FrameTimer = tick();
		FrameCounter = 0;
	end;

	Library:SetWatermark(('Ultimate Mining Tycoon - vkdfdf | %s fps | %s ms'):format(
		math.floor(FPS),
		math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
		));
end);

Library.KeybindFrame.Visible = true; -- todo: add a function for this

Library:OnUnload(function()
	WatermarkConnection:Disconnect()
	ConnDisconnect(RunServiceConn)
	ConnDisconnect(CharacterAddedConn)
	ConnDisconnect(UIS_Input_Began_Conn)
	ConnDisconnect(UIS_InputEnded_Conn)
	ConnDisconnect(Child_Added_Conn)
	ConnDisconnect(Child_Removed_Conn)
	ConnDisconnect(ESP_CONN)
	ConnDisconnect(FLY_CONN)
	ConnDisconnect(AUTO_SELL_CONN)
	DestroyFly()
	DestroyESP()
	print('Unloaded!')
	Library.Unloaded = true
end)


local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()