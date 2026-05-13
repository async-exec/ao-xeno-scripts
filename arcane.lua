local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local player = game.Players.LocalPlayer
local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
local checkpointPos

player.CharacterAdded:Connect(function(char)
	character = char
end)

local name = string.format("%sBoat", player.Name)

local defaultWalkSpeed

local runService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Players = game:GetService("Players")

local Window = Library:CreateWindow({
	Title = "Nigga Odyssey Hack",
	Center = false,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Main = Window:AddTab('Main'),
	Randoms = Window:AddTab("Random stuff"),
	['UI Settings'] = Window:AddTab('UI Settings'),
}


-- TABLES
local chestEsps = {}
local DarkSeaEsps = {}
local espParts = Instance.new("Folder", workspace)
local enemies : {Model} = {}
local enemyConns = {}
local boats = {}


-- HELPER STUFF

function createText(text, color, object, distance)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 70, 0, 30)
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = distance or math.huge
	billboard.LightInfluence = 0
	billboard.Parent = espParts
	billboard.Adornee = object
	billboard.Name = "EspBillboard"

	local label = Instance.new("TextLabel")
	label.Parent = billboard
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Name = "EspText"

	return billboard
end

for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
	if enemy:IsA("Model") then
		enemies[enemy] = true
	end
end

for _, enemy in ipairs(game.Players:GetPlayers()) do
	if enemy == player then continue end
	if enemy.Character then
		enemies[enemy.Character] = enemy.Character
	end
end

for _, boat in ipairs(workspace.Boats:GetChildren()) do
	if boat:IsA("Model") then
		boats[boat] = true
	end
end

enemyConns[1] = workspace.Enemies.ChildAdded:Connect(function(enemy)
	if enemy:IsA("Model") then
		enemies[enemy] = enemy
	end
end)

enemyConns[2] = workspace.Enemies.ChildRemoved:Connect(function(enemy)
	enemies[enemy] = nil
end)

enemyConns[3] = workspace.ChildAdded:Connect(function(enemy)
	if enemy:FindFirstChild("Humanoid") then
		enemies[enemy] = enemy
	end
end)

enemyConns[4] = workspace.ChildRemoved:Connect(function(enemy)
	if enemy:FindFirstChild("Humanoid") then
		enemies[enemy] = nil
	end
end)

enemyConns[5] = workspace.Boats.ChildAdded:Connect(function(boat)
	if boat:IsA("Model") then
		boats[boat] = boat
	end
end)

enemyConns[6] = workspace.Boats.ChildRemoved:Connect(function(boat)
	boats[boat] = nil
end)

local function getClosestEnemy(pve: boolean?, pvp: boolean?): Model?
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local closestEnemy
	local mobDist = math.huge
	for enemy in pairs(enemies) do
		if not pvp and enemy.Parent == workspace then
			continue
		end
		if not pve and enemy.Parent == workspace.Enemies then
			continue
		end

		local enemyHRP = enemy:FindFirstChild("HumanoidRootPart")
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if hum then
			if hum.Health <= 0 then
				continue
			end
		else
			local atts = enemy:FindFirstChild("Attributes")
			if atts then
				local Health = atts:FindFirstChild("Health")
				if not Health or Health.Value <= 0 then
					continue
				end
			end
		end
		if enemyHRP then
			local distance = (enemyHRP.Position - hrp.Position).Magnitude
			if distance < mobDist then
				mobDist = distance
				closestEnemy = enemy
			end
		end
	end
	return closestEnemy
end

local function getClosestBoat(pve: boolean?, pvp: boolean?): Model?
	if not character then return nil end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local bestDist = math.huge
	local closestBoat
	for _, boat in pairs(boats) do
		if not pvp and boat:FindFirstChild("Owner") and boat.Owner.Value and boat.Owner.Value ~= player then
			continue
		end
		if not pve and not boat:FindFirstChild("Owner") then
			continue
		end

		local primaryPart = boat.PrimaryPart
		if not primaryPart then
			continue
		end

		local dura = boat:FindFirstChild("Dura")
		if not dura or dura.Value <= 0 then
			continue
		end

		local distance = (primaryPart.Position - hrp.Position).Magnitude
		if distance < bestDist then
			bestDist = distance
			closestBoat = boat
		end
	end
	return closestBoat
end

-- CONNECTIONS

local DarkSeaConns = {}
local ChestAddConns = {}
local ChestRemoveConns = {}
local autoFishConn
local godModeTask
local ESPConnection
local ESP_OBJECTS = {}
local MeatToggle
local GalleonToggle
local ModConn
local killAllConn
local noClipParts = {}
local hitboxSizes = {}

local disableFunctions = {
	SpeedToggle = function()
		runService:UnbindFromRenderStep("walkspeedToggle")
		local humanoid = character and character:FindFirstChild("Humanoid")
		if humanoid and defaultWalkSpeed then
			humanoid.WalkSpeed = defaultWalkSpeed
		end
	end,
	FlyToggle = function()
		runService:UnbindFromRenderStep("HackFly")
		local humanoid = character and character:FindFirstChild("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid then
			humanoid.PlatformStand = false
		end
	end,
	NoClipToggle = function()
		runService:UnbindFromRenderStep("NoClipHack")
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
	end,
	RotationToggle = function()
		runService:UnbindFromRenderStep("RotationHack")
		local boat = workspace.Boats:FindFirstChild(name)
		local center = boat and boat:FindFirstChild("Center")

		if boat and center then
			center.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
	end,
	BoatSpeedToggle = function()
		runService:UnbindFromRenderStep("BoatSpeedHack")
		local boat = workspace.Boats:FindFirstChild(name)
		local center = boat and boat:FindFirstChild("Center")

		if boat and center then
			center.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
	end,
	CtrlClickToggle = function()
		runService:UnbindFromRenderStep("CtrlClickToggle")
	end,
	ChestEspToggle = function()
		for chest, esp in pairs(chestEsps) do
			esp:Destroy()
			chestEsps[chest] = nil
		end
		if ChestAddConns then
			for i, conn in pairs(ChestAddConns) do
				conn:Disconnect()
				ChestAddConns[i] = nil
			end
		end
		if ChestRemoveConns then
			for i, conn in pairs(ChestRemoveConns) do
				conn:Disconnect()
				ChestRemoveConns[i] = nil
			end
		end
	end,
	InfJumpToggle = function()
		runService:UnbindFromRenderStep("InfJumpToggle")
	end,
	DarkSeaEsp = function()
		for i, conn in ipairs(DarkSeaConns) do
			conn:Disconnect()
			DarkSeaConns[i] = nil
		end

		for i, esp in DarkSeaEsps do
			esp:Destroy()
			DarkSeaEsps[i] = nil
		end
	end,
	EnemyConnsClear = function()
		for i, conn in ipairs(enemyConns) do
			conn:Disconnect()
			enemyConns[i] = nil
		end
		enemies = nil
	end,
	GodModeToggle = function()
		if godModeTask and hookmetamethod then
			hookmetamethod(game, "__namecall", godModeTask)
		end
	end,
	AutoFishToggle = function()
		if autoFishConn then
			autoFishConn:Disconnect()
			autoFishConn = nil
		end
	end,
	PlayerEspToggle	= function()
		for _, PlayerData in pairs(ESP_OBJECTS) do
			for _, Drawing in pairs(PlayerData.drawings) do
				Drawing.Visible = false
				Drawing:Remove()
			end
		end
		ESP_OBJECTS = {}

		if ESPConnection then
			ESPConnection:Disconnect()
			ESPConnection = nil
		end
	end,
	MeatFarmToggle = function()
		if MeatToggle then
			task.cancel(MeatToggle)
		end
		MeatToggle = nil
	end,
	GalleonFarmToggle = function()
		if GalleonToggle then
			task.cancel(GalleonToggle)
		end
		GalleonToggle = nil
	end,
	ModToggle = function()
		if ModConn then
			ModConn:Disconnect()
			ModConn = nil
		end
	end,
	KillAllToggle = function()
		if killAllConn then
			task.cancel(killAllConn)
			killAllConn = nil
		end
	end,
	BoatNoClipToggle = function()
		for _, part in noClipParts do
			if part and part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end,
	HitboxToggle = function()
		runService:UnbindFromRenderStep("HitboxExpand")
		for part, size in pairs(hitboxSizes) do
			if part and part:IsA("BasePart") then
				part.Size = size
			end
		end
		hitboxSizes = {}
	end,
}
-- GUI

local MovementBox = Tabs.Main:AddRightGroupbox("Movement")
local OtherBox = Tabs.Main:AddLeftGroupbox("Other")
local LeftRandomBox = Tabs.Randoms:AddLeftGroupbox('Stuff')
local RightRandomBox = Tabs.Randoms:AddRightGroupbox('More stuff')

-- FUNCTIONS

SpeedHack = function(Value: boolean)
	if Value then
		local humanoid = character and character:FindFirstChild("Humanoid")
		if not humanoid then
			Toggles.SpeedToggle:SetValue(false)
			return
		end
		defaultWalkSpeed = humanoid.WalkSpeed

		runService:BindToRenderStep("walkspeedToggle", 0, function()
			local char = character
			local humanoid = char:FindFirstChild("Humanoid")
			if char and humanoid then
				humanoid.WalkSpeed = Options.SpeedBox.Value
			end
		end)
	else
		disableFunctions["SpeedToggle"]()
	end
end

FlyHack = function(Value: boolean)
	local function enableFly()
		local humanoid = character and character:FindFirstChild("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		runService:BindToRenderStep("HackFly", 0, function()
			local humanoid = character and character:FindFirstChild("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not rootPart then return end

			humanoid.PlatformStand = true
			rootPart.Anchored = false

			local flySpeed = Options.FlyBox.Value
			local camera = workspace.CurrentCamera
			local direction = Vector3.new(0, 0, 0)

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				direction = direction + camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				direction = direction - camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				direction = direction - camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				direction = direction + camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				direction = direction + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				direction = direction + Vector3.new(0, -1, 0)
			end

			if direction.Magnitude > 0 then
				direction = direction.Unit * flySpeed
				rootPart.AssemblyLinearVelocity = direction

			else
				rootPart.AssemblyLinearVelocity = Vector3.new(0,3.5,0)

			end
			rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + camera.CFrame.LookVector)
		end)
	end

	if Value then
		enableFly()
	else
		disableFunctions["FlyToggle"]()
	end
end

NoclipHack = function(Value: boolean)
	local function enableNoClip()
		runService:BindToRenderStep("NoClipHack", 0, function()

			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
	end

	if Value then
		enableNoClip()
	else
		disableFunctions["NoClipToggle"]()
	end
end

MovementBox:AddInput("SpeedBox",
	{
		Default = "100",
		Numeric = true,
		Finished = true,
		Text = "Insert movement speed",
		Tooltip = ""
	}
)

MovementBox:AddToggle("SpeedToggle",{
	Text = 'Activate speed hack',
	Default = false,
	Tooltip = 'Go fast',
	Callback = SpeedHack
}):AddKeyPicker("SpeedToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "Speed hack toggle"
})

MovementBox:AddInput("FlyBox",
	{
		Default = "100",
		Numeric = true,
		Finished = true,
		Text = "Insert fly speed",
		Tooltip = ""
	}
)

MovementBox:AddToggle("FlyToggle",{
	Text = 'Activate fly hack',
	Default = false,
	Tooltip = 'Go fly',
	Callback = FlyHack}
):AddKeyPicker("FlyToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "Toggle fly hack"
})


Library:SetWatermarkVisibility(false)

Library.KeybindFrame.Visible = true;

MovementBox:AddToggle("NoClipToggle",{
	Text = 'Activate no clip hack',
	Default = false,
	Tooltip = 'Go through walls',
	Callback = NoclipHack
}):AddKeyPicker("NoClipToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "NoClip"
})

MovementBox:AddToggle("InfJumpToggle",{
	Text = 'Activate infinite jump hack',
	Default = false,
	Tooltip = 'Go high up',
	Callback = function(Value)

		if Value then
			runService:BindToRenderStep("InfJumpToggle", 1, function()
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
					root.Velocity = Vector3.new(root.Velocity.X, 45, root.Velocity.Z)
				end
			end)
		else disableFunctions["InfJumpToggle"]() end

	end}):AddKeyPicker("InfJumpkey", {
	Default = "",
	SyncToggleState = true,
	Text = "Infinite Jump"
})
MovementBox:AddDivider()

MovementBox:AddInput("RotationBox",
	{
		Default = "50",
		Numeric = true,
		Finished = true,
		Text = "Insert boat rotation speed",
		Tooltip = ""
	}
)
MovementBox:AddToggle("RotationToggle",{
	Text = 'Fast ship rotation (buggy)',
	Default = false,
	Tooltip = 'makes some ships rotate faster. Wont enable if no boat',
	Callback = function(Value)
		local rotationSpeed = Options.RotationBox.Value
		local name = string.format("%sBoat", player.Name)


		if Value then runService:BindToRenderStep("RotationHack", 0, function()
				local boat = workspace.Boats:FindFirstChild(name)

				local center = boat and boat:FindFirstChild("Center")
				if center then
					local steer = 0
					if UserInputService:IsKeyDown(Enum.KeyCode.A) then
						steer = rotationSpeed
					elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
						steer = -rotationSpeed
					end
					if boat and center then
						center.AssemblyAngularVelocity = Vector3.new(0, steer, 0)
					else
						runService:UnbindFromRenderStep("RotationHack")
						Toggles.RotationToggle:SetValue(false)
					end
				end
			end)


		else
			disableFunctions["RotationToggle"]()
		end
	end,
})
MovementBox:AddInput("BoatSpeedbox",
	{
		Default = "10000",
		Numeric = true,
		Finished = true,
		Text = "Insert boat speed",
		Tooltip = ""
	}
)
MovementBox:AddToggle("BoatSpeedToggle",{
	Text = 'Toggle to increase boat speed',
	Default = false,
	Tooltip = 'If enabled then boat will be a lot faster. W/S backwards/forwards. It will be remote controlled also. WOnt enable if no boat',
	Callback = function(Value)
		if Value then runService:BindToRenderStep("BoatSpeedHack", 0, function()
				local boat = workspace.Boats:FindFirstChild(name)

				local center = boat and boat:FindFirstChild("Center")
				if center then
					local throttle = 0
					if UserInputService:IsKeyDown(Enum.KeyCode.W) then
						throttle = 1
					elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
						throttle = -1
					end
					local cf = center.CFrame
					center.Anchored = false

					local desiredLinearVel = cf.LookVector * throttle * Options.BoatSpeedbox.Value
					center.AssemblyLinearVelocity = center.AssemblyLinearVelocity:Lerp(desiredLinearVel, 0.13)
				end

			end)

		else
			disableFunctions["BoatSpeedToggle"]()
		end
	end,
})

MovementBox:AddToggle("BoatNoClipToggle", {
	Text = 'Boat No clip',
	Tooltip = 'makes your boat go through walls',
	Callback = function(Value)
		if Value then
			local boat = workspace.Boats:FindFirstChild(name)
			if not boat then
				Toggles.BoatNoClipToggle:SetValue(false)
				return
			end
			for _, part in boat:GetDescendants() do
				if part:IsA("BasePart") then
					if part.CanCollide then
						table.insert(noClipParts, part)
					end
					part.CanCollide = false
				end
			end
		else
			disableFunctions["BoatNoClipToggle"]()
		end
	end,
})

MovementBox:AddDivider()

MovementBox:AddButton({
	Text = "Teleport current story quest",
	Func = function()
		if workspace.Camera:FindFirstChild("StoryMarker1") then
			if character and character.HumanoidRootPart then
				character.HumanoidRootPart.CFrame = workspace.Camera.StoryMarker1.CFrame
			end
		end
	end,
	Tooltip = "Teleports to current story quest if marker exists"
})

MovementBox:AddButton({
	Text = "Other story quest marker tp",
	Func = function()
		if character and character.HumanoidRootPart then
			for _, child in ipairs(workspace.NPCs:GetDescendants()) do
				if child:IsA("BillboardGui") then
					if child.Name == "Story" then
						character.HumanoidRootPart.CFrame = child.Parent.CFrame
					end
				end
			end
		end
	end,
	Tooltip = "Teleports to current story quest if marker exists. \n It will tp to the question mark symbol instead. Laggier. "
})

MovementBox:AddButton({
	Text = "Tp current quest",
	Func = function()
		if workspace.Camera:FindFirstChild("QuestMarker1") then
			if character and character.HumanoidRootPart then
				character.HumanoidRootPart.CFrame = workspace.Camera.QuestMarker1.CFrame
			end
		end
	end,
	Tooltip = "Teleports to current quest if marker exists."
})

MovementBox:AddButton({
	Text = "Tp map marker",
	Func = function()
		if workspace.Camera:FindFirstChild("Marker") then
			if character and character.HumanoidRootPart then
				character.HumanoidRootPart.CFrame = workspace.Camera.Marker.CFrame
			end
		end
	end,
	Tooltip = "Teleports to current quest if marker exists."
})

MovementBox:AddButton({
	Text = "Tp to ship",
	Func = function()
		local ship= workspace.Boats:FindFirstChild(name)
		if ship then
			if ship:FindFirstChild("Grate") then
				if character and character.HumanoidRootPart then
					character.HumanoidRootPart.CFrame = ship.Grate.CFrame
				end
			else
				character.HumanoidRootPart.CFrame = ship.WorldPivot
			end
		end
	end,
	Tooltip = "Teleports to your ship if it exists."
})

local function refreshPlayerList()
	local plrs = {}
	for _, plr in game.Players:GetPlayers() do
		if plr ~= player then
			table.insert(plrs, plr.Name)
		end
	end
	return #plrs > 0 and plrs or {"No players"}
end

MovementBox:AddDropdown('TpPlayerDropdown', {
	Values = refreshPlayerList(),
	Default = 0,
	Multi = false,
	Text = 'Tp to player',
	Tooltip = 'Teleports to selected player',
	Callback = function(Value)
		if character and character.HumanoidRootPart then
			local target = game.Players:FindFirstChild(Value)
			if target then
				local char = target.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					character.HumanoidRootPart.CFrame = hrp.CFrame * CFrame.new(0, 5, 0)
				end
			end
		end
	end,
})

MovementBox:AddButton({
	Text = "Refresh players",
	Tooltip = "Refreshes the player list in the dropdown",
	Func = function()
		Options.TpPlayerDropdown:SetValues(refreshPlayerList())
	end,
})

MovementBox:AddButton({
	Text = "Set checkpoint",
	Tooltip = "Saves your current position as a teleport checkpoint",
	Func = function()
		if character and character.HumanoidRootPart then
			checkpointPos = character.HumanoidRootPart.Position
		end
	end,
})

MovementBox:AddButton({
	Text = "Tp to checkpoint",
	Tooltip = "Teleports to your saved checkpoint",
	Func = function()
		if character and character.HumanoidRootPart and checkpointPos then
			character.HumanoidRootPart.CFrame = CFrame.new(checkpointPos) * CFrame.new(0, 5, 0)
		end
	end,
})

local dropDownIsland = {}
if workspace:FindFirstChild("Map") then
	for _, folder in ipairs(workspace.Map:GetChildren()) do
		if folder:FindFirstChild("Center") then
			table.insert(dropDownIsland, folder.Name)
		end
	end
end

MovementBox:AddDropdown('IslandTp', {
	Values = dropDownIsland,
	Default = 0,
	Multi = false,

	Text = 'Tp to island',
	Tooltip = 'Tps you to selected island',

	Callback = function(Value)
		if character and character.HumanoidRootPart then
			character.HumanoidRootPart.CFrame = workspace.Map[Value]["Center"].CFrame
		end
	end
})

MovementBox:AddToggle("CtrlClickToggle",{
	Text = 'Ctrl click tp to cursor',
	Default = false,
	Tooltip = 'If you hold down control and click/hold m1 then you tp to cursor position',
	Callback = function(Value)
		if Value then
			local canTp = true
			runService:BindToRenderStep("CtrlClickToggle", Enum.RenderPriority.Input.Value, function()
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if not character:FindFirstChild("HumanoidRootPart") then return end
				if canTp then
					local mouse = player:GetMouse()
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
						if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							local targetPos = mouse.Hit and mouse.Hit.Position
							if targetPos then
								canTp = false
								character.HumanoidRootPart.CFrame = CFrame.new(targetPos)
								task.delay(0.15, function()
									canTp =true
								end)
							end
						end
					end
				end
			end)
		else
			disableFunctions["CtrlClickToggle"]()
		end
	end,
})

OtherBox:AddLabel('Chest Esp Color'):AddColorPicker('ChestEspColor', {
	Default = Color3.new(1, 1, 1),
	Title = 'CHEST ESP COLOR',
})

OtherBox:AddToggle("TreasureChestToggle",{
	Text = 'Common Chest',
	Default = false,
})

OtherBox:AddToggle("ChestToggle_Uncommon", {
	Text = "Uncommon Chest",
	Default = false,
})

OtherBox:AddToggle("ChestToggle_Rare", {
	Text = "Rare Chest",
	Default = true,
})

OtherBox:AddToggle("ChestToggle_Mystic", {
	Text = "Mystic Chest",
	Default = true,
})

OtherBox:AddToggle("ChestToggle_Legendary", {
	Text = "Legendary Chest",
	Default = true,
})

OtherBox:AddButton({
	Text = "Tp to nearest chest",
	Tooltip = "Teleports to the nearest chest of an enabled type",
	Func = function()
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end
		local hrp = character.HumanoidRootPart
		local closestDist = math.huge
		local closestPos
		local iterate = {
			workspace.Map,
			game.ReplicatedStorage.RS.UnloadIslands
		}
		for _, parent in ipairs(iterate) do
			for _, island in ipairs(parent:GetChildren()) do
				for _, v in ipairs(island:GetChildren()) do
					if typeof(v) == "Instance" and v.Name == "Chests" then
						for _, chest in v:GetChildren() do
							if not chest:FindFirstChild("ChestObj") then continue end
							if chest:FindFirstChild("Open") then continue end
							local enabled =
								(chest.Name == "Treasure Chest" and Toggles.TreasureChestToggle.Value) or
								(chest.Name == "Uncommon Chest" and Toggles.ChestToggle_Uncommon.Value) or
								(chest.Name == "Rare Chest" and Toggles.ChestToggle_Rare.Value) or
								(chest.Name == "Mystic Chest" and Toggles.ChestToggle_Mystic.Value) or
								(chest.Name == "Legendary Chest" and Toggles.ChestToggle_Legendary.Value)
							if not enabled then continue end
							local part = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
							if part then
								local dist = (part.Position - hrp.Position).Magnitude
								if dist < closestDist then
									closestDist = dist
									closestPos = part.Position
								end
							end
						end
					end
				end
			end
		end
		if closestPos then
			hrp.CFrame = CFrame.new(closestPos) * CFrame.new(0, 5, 0)
		end
	end,
})


local function trackChest(chest)
	local obj = chest:FindFirstChild("ChestObj")
	local allowed =
		(chest.Name == "Treasure Chest" and Toggles.TreasureChestToggle.Value) or
		(chest.Name == "Uncommon Chest" and Toggles.ChestToggle_Uncommon.Value) or
		(chest.Name == "Rare Chest" and Toggles.ChestToggle_Rare.Value) or
		(chest.Name == "Mystic Chest" and Toggles.ChestToggle_Mystic.Value) or
		(chest.Name == "Legendary Chest" and Toggles.ChestToggle_Legendary.Value)
	if obj and allowed and not chest:FindFirstChild("Open") then
		if chest:IsA("Model") then
			local part = chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
			if part then
				local color
				if chest.Name == "Treasure Chest" then
					color = Color3.new(1, 1, 1)
				elseif chest.Name == "Uncommon Chest" then
					color = Color3.fromRGB(255, 255, 150)
				elseif chest.Name == "Rare Chest" then
					color = Color3.fromRGB(100, 140, 255)
				elseif chest.Name == "Mystic Chest" then
					color = Color3.fromRGB(255, 100, 100)
				elseif chest.Name == "Legendary Chest" then
					color = Color3.fromRGB(100, 255, 130)
				end
				local esp = createText(chest.Name, color, part)
				chestEsps[chest] = esp
				ChestRemoveConns[chest] = chest.ChildAdded:Connect(function(child)
					if child.Name == "Open" then
						esp:Destroy()
						chestEsps[chest] = nil
						ChestRemoveConns[chest]:Disconnect()
						ChestRemoveConns[chest] = nil
					end
				end)
			end
		end
	end
end

OtherBox:AddToggle("ChestEspToggle", {
	Text = 'Chest esp (dont spam pick chests)',
	Default = false,
	Tooltip = 'Allows you to see all the chests on the map. (use responsibly) \n might kick you if you lag too much',
	Callback = function(Value)
		if Value then
			local iterate = {
				workspace.Map,
				game.ReplicatedStorage.RS.UnloadIslands
			}
			for _, parent in ipairs(iterate) do
				for _, island in ipairs(parent:GetChildren()) do
					for _, v in ipairs(island:GetChildren()) do
						if typeof(v) == "Instance" and v.Name == "Chests" then
							for _, chest in v:GetChildren() do
								trackChest(chest)
							end
							ChestAddConns[v] = v.ChildAdded:Connect(function(chest)
								trackChest(chest)
							end)
						end
					end
				end
			end
		else
			disableFunctions["ChestEspToggle"]()
		end
	end,
}):AddKeyPicker("ChestEspToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "Chest esp"
})

local Camera = workspace.CurrentCamera

local LocalPlayer = player
local ESPConnection

local function WorldToScreen(Position)
	local ScreenPoint, OnScreen = Camera:WorldToViewportPoint(Position)
	return Vector2.new(ScreenPoint.X, ScreenPoint.Y), OnScreen, ScreenPoint.Z > 0
end

local function CreateDrawings()
	local Drawings = {}
	Drawings.Box = Drawing.new("Square")
	Drawings.Box.Color = Color3.fromRGB(255, 255, 255)
	Drawings.Box.Thickness = 2
	Drawings.Box.Filled = false
	Drawings.Box.Transparency = 1
	Drawings.Box.Visible = false
	Drawings.HealthBg = Drawing.new("Square")
	Drawings.HealthBg.Color = Color3.fromRGB(0, 0, 0)
	Drawings.HealthBg.Thickness = 1
	Drawings.HealthBg.Filled = true
	Drawings.HealthBg.Transparency = 0.7
	Drawings.HealthBg.Visible = false
	Drawings.HealthFill = Drawing.new("Square")
	Drawings.HealthFill.Color = Color3.fromRGB(0, 255, 0)
	Drawings.HealthFill.Thickness = 1
	Drawings.HealthFill.Filled = true
	Drawings.HealthFill.Transparency = 1
	Drawings.HealthFill.Visible = false
	Drawings.DistanceText = Drawing.new("Text")
	Drawings.DistanceText.Color = Color3.fromRGB(255, 255, 255)
	Drawings.DistanceText.Size = 14
	Drawings.DistanceText.Font = 2
	Drawings.DistanceText.Outline = true
	Drawings.DistanceText.OutlineColor = Color3.fromRGB(0, 0, 0)
	Drawings.DistanceText.Center = true
	Drawings.DistanceText.Visible = false
	Drawings.NameText = Drawing.new("Text")
	Drawings.NameText.Color = Color3.fromRGB(255, 255, 255)
	Drawings.NameText.Size = 14
	Drawings.NameText.Font = 2
	Drawings.NameText.Outline = true
	Drawings.NameText.OutlineColor = Color3.fromRGB(0, 0, 0)
	Drawings.NameText.Center = true
	Drawings.NameText.Visible = false
	return Drawings
end

local function UpdateESP(PlayerData, LocalRoot)
	local Character = PlayerData.player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local Head = Character and Character:FindFirstChild("Head")
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not (Character and Humanoid and Head and RootPart and LocalRoot) then
		return false
	end
	local HealthPercent = math.clamp(Humanoid.Health / Humanoid.MaxHealth, 0, 1)
	local TopPoint, TopOnScreen, TopInFront = WorldToScreen(Head.Position + Vector3.new(0, 1, 0))
	local BottomPoint, BottomOnScreen, BottomInFront = WorldToScreen(RootPart.Position - Vector3.new(0, 3, 0))
	local Drawings = PlayerData.drawings
	if not (TopOnScreen and BottomOnScreen and TopInFront and BottomInFront) then
		Drawings.Box.Visible = false
		Drawings.HealthBg.Visible = false
		Drawings.HealthFill.Visible = false
		Drawings.DistanceText.Visible = false
		Drawings.NameText.Visible = false
		return true
	end
	local BoxHeight = math.abs(BottomPoint.Y - TopPoint.Y)
	local BoxWidth = BoxHeight / 2
	local BoxX = TopPoint.X - BoxWidth / 2
	local BoxY = TopPoint.Y
	Drawings.Box.Position = Vector2.new(BoxX, BoxY)
	Drawings.Box.Size = Vector2.new(BoxWidth, BoxHeight)
	Drawings.Box.Visible = true
	local BarX = BoxX - 8
	local BarWidth = 4
	local BarHeight = BoxHeight
	Drawings.HealthBg.Position = Vector2.new(BarX, BoxY)
	Drawings.HealthBg.Size = Vector2.new(BarWidth, BarHeight)
	Drawings.HealthBg.Visible = true
	local FillHeight = BarHeight * HealthPercent
	local FillY = BoxY + BarHeight - FillHeight
	Drawings.HealthFill.Position = Vector2.new(BarX + 1, FillY)
	Drawings.HealthFill.Size = Vector2.new(BarWidth - 2, FillHeight)
	Drawings.HealthFill.Visible = true
	local Distance = (RootPart.Position - LocalRoot.Position).Magnitude
	Drawings.DistanceText.Text = tostring(math.floor(Distance)) .. " studs"
	Drawings.DistanceText.Position = Vector2.new(TopPoint.X, BoxY - 18)
	Drawings.DistanceText.Visible = true
	Drawings.NameText.Text = PlayerData.player.Name
	Drawings.NameText.Position = Vector2.new(TopPoint.X, BoxY - 36)
	Drawings.NameText.Visible = true
	return true
end

local function ESPLoop()
	local LocalCharacter = LocalPlayer.Character
	local LocalRootPart = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
	if not LocalRootPart then
		return
	end

	for Player, PlayerData in pairs(ESP_OBJECTS) do
		if not Players:FindFirstChild(Player.Name) then
			for _, Drawing in pairs(PlayerData.drawings) do
				Drawing:Remove()
			end
			ESP_OBJECTS[Player] = nil
		else
			local ShouldKeep = UpdateESP(PlayerData, LocalRootPart)
			if not ShouldKeep then
				for _, Drawing in pairs(PlayerData.drawings) do
					Drawing:Remove()
				end
				ESP_OBJECTS[Player] = nil
			end
		end
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		if Player ~= LocalPlayer and Player.Character and not ESP_OBJECTS[Player] then
			local Drawings = CreateDrawings()
			ESP_OBJECTS[Player] = {
				player = Player,
				drawings = Drawings
			}
		end
	end
end



OtherBox:AddToggle("PlayerEspToggle", {
	Text = 'Player ESP',
	Default = false,
	Tooltip = 'Shows all player locations',
	Callback = function(Value)
		if Value then
			if not ESPConnection then
				ESPConnection = runService.RenderStepped:Connect(ESPLoop)
			end
			local LocalCharacter = LocalPlayer.Character
			local LocalRootPart = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
			if LocalRootPart then
				for _, Player in ipairs(Players:GetPlayers()) do
					if Player ~= LocalPlayer and Player.Character and not ESP_OBJECTS[Player] then
						local Drawings = CreateDrawings()
						ESP_OBJECTS[Player] = {
							player = Player,
							drawings = Drawings
						}
						UpdateESP(ESP_OBJECTS[Player], LocalRootPart)
					end
				end
			end
		else
			disableFunctions["PlayerEspToggle"]()
		end
	end,
}):AddKeyPicker("PlayerEspToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "Player ESP"
})


OtherBox:AddButton({
	Text = 'Boat esp',
	Default = false,
	Tooltip = '',
	Func = function()
		local iterate = {
			workspace.Boats,
			game.ReplicatedStorage.RS.UnloadNPCShips
		}
		for _, parent in ipairs(iterate) do
			for _, boat in ipairs(parent:GetChildren()) do
				if boat:IsA("Model") and boat.PrimaryPart then

					local dura = boat:FindFirstChild("Dura")
					if not dura or dura.Value <= 0 then
						continue
					end

					if boat:FindFirstChild("Type") and boat.Type.Value then
						createText(`{boat.Type.Value} {boat.Name}`
							, Color3.new(0,1,0), boat.PrimaryPart)
						continue
					end
					createText(boat.Name
						, Color3.new(0,1,0), boat.PrimaryPart)
				end
			end
		end
	end
})

Options.ChestEspColor:OnChanged(function()
	for _, esp in chestEsps do
		esp.EspText.TextColor3 = Options.ChestEspColor.Value
	end
end)

OtherBox:AddToggle("DarkSeaEsp", {
	Text = 'Dark sea  esp',
	Default = false,
	Tooltip = 'Allows you to see all prompts on loaded dark sea islands \n should include hecate, athenas pages, items etc',
	Callback = function(Value)
		if Value then
			for _, prompt in ipairs(workspace.Map.SeaContent.DarkSea:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") or prompt.Name == "HecateEssence" or prompt.Name == "AthenaWisdom" then
					local parent = prompt.Parent
					local color = Color3.new(1,1,1)
					local text
					if  prompt.Name == "HecateEssence" then
						color = Color3.new(0.364706, 0, 1)
						text = "Hecate"
					elseif prompt.Name == "AthenaWisdom" then
						color = Color3.new(0.619608, 1, 0.482353)
						text = "Athena Note"
					else
						if prompt.ObjectText == "Prometheus's Acrimony" or prompt.ObjectText == "Moly" or prompt.ObjectText == "Legendary Chest" then
							color = Color3.new(1, 0.92549, 0.490196)
						end
						if prompt.ObjectText == "Treasure Chest" or prompt.ObjectText == "Uncommon Chest" or prompt.ObjectText == "Thornflower" or prompt.ObjectText == "Seaweed"  then
							continue
						end
						text = prompt.ObjectText
					end
					local parent = prompt.Parent
					if prompt.Name == "HecateEssence" or prompt.Name == "AthenaWisdom" then
						parent = prompt
					end
					local esp = createText(text, color, parent)
					DarkSeaEsps[prompt] = esp
				end
			end

			for _, chest in ipairs(workspace.Map.Temporary:GetChildren()) do
				local prox = chest:FindFirstChild("Prompt")
				if chest.Name == "Dark Sealed Chest" and prox then
					local esp = createText("Dark Sealed Chest", Color3.new(0.564706, 0.419608, 0.654902), chest)
					DarkSeaEsps[chest] = esp
				end
			end

			DarkSeaConns[1] = workspace.Map.SeaContent.DarkSea.DescendantAdded:Connect(function(child)
				if child:IsA("ProximityPrompt") or child.Name == "HecateEssence" or child.Name == "AthenaWisdom" then
					local color = Color3.new(1,1,1)
					local text
					if child.Name == "HecateEssence" then
						color = Color3.new(0.364706, 0, 1)
						text = "Hecate"
					elseif child.Name == "AthenaWisdom" then
						color = Color3.new(0.619608, 1, 0.482353)
						text = "Athena Note"
					else
						if child.ObjectText == "Prometheus's Acrimony" or child.ObjectText == "Moly"  or child.ObjectText == "Legendary Chest" then
							color = Color3.new(1, 0.92549, 0.490196)
						end
						if child.ObjectText == "Treasure Chest" or child.ObjectText == "Uncommon Chest" or child.ObjectText == "Thornflower" or child.ObjectText == "Seaweed" then
							return
						end
						text = child.ObjectText
					end
					local parent = child.Parent
					if child.Name == "HecateEssence" or child.Name == "AthenaWisdom" then
						parent = child
					end
					local esp = createText(text, color, parent)
					DarkSeaEsps[child] = esp
				end
			end)

			DarkSeaConns[2] = workspace.Map.Temporary.ChildAdded:Connect(function(chest)
				local prox = chest:FindFirstChild("Prompt")
				if chest.Name == "Dark Sealed Chest" and prox then
					local esp = createText("Dark Sealed Chest", Color3.new(0.564706, 0.419608, 0.654902), chest)
					DarkSeaEsps[chest] = esp
				end
			end)

			DarkSeaConns[3] = workspace.Map.SeaContent.DarkSea.DescendantRemoving:Connect(function(child)
				if child:IsA("ProximityPrompt") then
					DarkSeaEsps[child]:Destroy()
					DarkSeaEsps[child] = nil
				end
			end)

			DarkSeaConns[4] =  workspace.Map.Temporary.ChildRemoved:Connect(function(child)
				if child.Name == "Dark Sealed Chest" then
					DarkSeaEsps[child]:Destroy()
					DarkSeaEsps[child] = nil
				end
			end)
		else
			disableFunctions["DarkSeaEsp"]()
		end
	end,
}):AddKeyPicker("DarkseaEspToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "Darksea esp"
})

OtherBox:AddButton({
	Text = 'Infinite Stamina',
	Tooltip = "Gives you a very big amount of stamina. Has no downside. \n Cba making a reset. There's no reason to turn it off anyway",
	Func = function()
		ReplicatedStorage.RS.Remotes.Combat.StaminaCost:FireServer(-3400)
		player.CharacterAdded:Connect(function()
			local hum = player:WaitForChild("Humanoid", 10)
			if hum then
				ReplicatedStorage.RS.Remotes.Combat.StaminaCost:FireServer(-3400)
			end
		end)
	end,
})

OtherBox:AddButton({
	Text = 'Disable ship collision damage',
	Tooltip = 'Your ship no longer takes damage when bumping into stuff \n Effect goes away on ship despawn/refresh',
	Func = function(Value)
		local boat = workspace.Boats:FindFirstChild(name)
		if boat then
			for _, transmitter in ipairs(boat:GetDescendants()) do
				if transmitter:IsA("TouchTransmitter") then
					transmitter:Destroy()
				end
			end
		end
	end,
})

OtherBox:AddButton({
	Text = "Optimize lighting",
	Tooltip = "Disable fog, shadows, make it brighter, etc",
	Func = function(Value)
		for _, sky in workspace.Camera:GetChildren() do
			if sky.Name == "DarkSky1" or sky.Name == "DarkSky2" then
				sky:Destroy()
			end
		end

		local lighting = game:GetService("Lighting")
		local folder = Instance.new("Folder")
		local atmo = lighting:FindFirstChild("Atmosphere")
		folder.Parent = lighting
		folder.Name = "Atmosphere"
		if atmo then atmo:Destroy() end

		lighting.GlobalShadows = false
		lighting.Ambient = Color3.new(1,1,1)
		lighting.OutdoorAmbient = Color3.new(1,1,1)

		workspace.Camera.ChildAdded:Connect(function(sky)
			if sky.Name == "DarkSky1" or sky.Name == "DarkSky2" then
				sky:Destroy()
			end
		end)

		for _, effect in lighting:GetChildren() do
			if effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") then
				effect.Enabled = false
			end
		end
	end,
})

OtherBox:AddButton({
	Text = "Disable fall damage",
	Tooltip = "Disables fall damage",
	Func = function()
		if game.ReplicatedStorage.RS.Remotes.Combat:FindFirstChild("FallDamage") then
			game.ReplicatedStorage.RS.Remotes.Combat.FallDamage:Destroy()
		end
	end,
})

OtherBox:AddButton({
	Text = "Wash",
	Tooltip = "Removes dark sea weater poison",
	Func = function()
		if game.ReplicatedStorage.RS.Remotes.Boats:FindFirstChild("Wash") then
			game.ReplicatedStorage.RS.Remotes.Boats.Wash:FireServer()
		end
	end,
})

OtherBox:AddButton({
	Text = "Infinite Zoom",
	Tooltip = "Allows you to scroll your camera forever",
	Func = function()
		game.Players.LocalPlayer.CameraMaxZoomDistance = 1e9
	end,
})

OtherBox:AddInput("RodBox",
	{
		Default = "Wooden Rod",
		Numeric = false,
		Finished = true,
		Text = "Write fishing rod",
		Tooltip = ""
	}
)


OtherBox:AddInput("BaitBox",
	{
		Default = "Normal Bait",
		Numeric = false,
		Finished = true,
		Text = "Write bait name",
		Tooltip = ""
	}
)

OtherBox:AddToggle("AutoFishToggle", {
	Text = "Silent Autofish",
	Tooltip = "Catches fish without using rod",
	Default = false,
	Callback = function(Value)
		if Value then
			autoFishConn = game.ReplicatedStorage.RS.Remotes.Misc.FishEvent.OnClientEvent:Connect(function(arg1, arg2, ...)
				if arg1 == player and arg2 == "Bite" then
					for i = 1, 10 do
						game:GetService("ReplicatedStorage").RS.Remotes.Misc.FishState:FireServer("Reel")
						task.wait()
					end
					task.wait(0.1)
					args = {
						[1] = player.Backpack:FindFirstChild(Options.RodBox.Value),
						[3] = Vector3.new(0/0 --[[NaN]], 0/0 --[[NaN]], 0/0 --[[NaN]]),
						[4] = Options.BaitBox.Value
					}

					ReplicatedStorage.RS.Remotes.Misc.FishClock:FireServer(unpack(args))

				end
			end)

			local args = {
				[1] = player.Backpack:FindFirstChild(Options.RodBox.Value),
				[3] = Vector3.new(0/0 --[[NaN]], 0/0 --[[NaN]], 0/0 --[[NaN]]),
				[4] = Options.BaitBox.Value
			}
			ReplicatedStorage.RS.Remotes.Misc.FishClock:FireServer(unpack(args))

		else
			disableFunctions["AutoFishToggle"]()
			game:GetService("ReplicatedStorage").RS.Remotes.Misc.FishState:FireServer("StopClock")

		end
	end,
})

OtherBox:AddButton({
	Text = "Delete all Esps",
	Tooltip = "Deletes all current esps",
	Func = function()
		for _, esp in espParts:GetChildren() do
			esp:Destroy()
		end
	end,
})

OtherBox:AddToggle("GodModeToggle", {
	Text = 'God Mode',
	Default = false,
	Tooltip = 'Blocks incoming damage from NPCs (requires hookmetamethod)',
	Callback = function(Value)
		if Value then
			godModeTask = hookmetamethod(game, "__namecall", newcclosure(function(remote, ...)
				local getmethod = getnamecallmethod or getnamecall
				if getmethod and not checkcaller() then
					local method = getmethod()
					if method == "FireServer" then
						local args = {...}
						if remote.Name == "TouchDamage" then
							return
						elseif remote.Name == "DealBossDamage" then
							if args[2] == character then
								return
							end
						elseif remote.Name == "TakeSideDamage" then
							return
						elseif remote.Name == "DealAttackDamage" then
							if args[2] == character then
								return
							end
						elseif remote.Name == "DealWeaponDamage" then
							if args[3] == character then
								return
							end
						elseif remote.Name == "DealSWDamage" then
							if args[3] == character then
								return
							end
						elseif remote.Name == "DealStrengthDamage" then
							if args[3] == character then
								return
							end
						elseif remote.Name == "DealAnimalDamage" then
							if args[2] == character then
								return
							end
						end
					end
				end
				return godModeTask(remote, ...)
			end))
		else
			disableFunctions["GodModeToggle"]()
		end
	end,
}):AddKeyPicker("GodModeToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "God Mode"
})

OtherBox:AddInput("HitboxScale", {
	Default = "2",
	Text = "Hitbox scale",
	Numeric = true,
	Finished = true,
})

OtherBox:AddToggle("HitboxToggle", {
	Text = 'Hitbox Expander',
	Default = false,
	Tooltip = 'Scales all enemy hitboxes by the multiplier',
	Callback = function(Value)
		if Value then
			runService:BindToRenderStep("HitboxExpand", 0, function()
				local scale = tonumber(Options.HitboxScale.Value) or 2
				for enemy in pairs(enemies) do
					if not enemy then continue end
					for _, part in enemy:GetDescendants() do
						if part:IsA("BasePart") then
							if not hitboxSizes[part] then
								hitboxSizes[part] = part.Size
							end
							part.Size = hitboxSizes[part] * scale
						end
					end
				end
			end)
		else
			disableFunctions["HitboxToggle"]()
		end
	end,
}):AddKeyPicker("HitboxToggleKey", {
	Default = "",
	SyncToggleState = true,
	Text = "Hitbox Expander"
})



LeftRandomBox:AddDropdown("MeatType", {
	Values = {
		"Sparrow",
		"Raven",
		"Seagull",
		"Blue Raven",
		"Eagle"
	},
	Default = 1,
	Multi = false,

	Text = 'Select meat farm',
	Tooltip = '',

})

LeftRandomBox:AddToggle('MeatFarmToggle', {
	Text = "Toggle meat farm",
	Tooltip = "Automatically gives meat",
	Default = false,
	Callback = function(Value)
		if Value then
			MeatToggle = task.spawn(function()
				while task.wait(0.1) do
					local args = {
						[1] = Options.MeatType.Value
					}

					game:GetService("ReplicatedStorage"):WaitForChild("RS"):WaitForChild("Remotes"):WaitForChild("Misc"):WaitForChild("BirdKill"):FireServer(unpack(args))
				end
			end)

		else
			disableFunctions["MeatFarmToggle"]()
		end
	end,
})

LeftRandomBox:AddInput('ItemToSell', {
	Text = "Item to sell",
	Tooltip = 'Sells all of item',
	Default = '',
	Finished = true
})

LeftRandomBox:AddButton({
	Text = 'Sell nearest npc',
	Tooltip = 'Sells all of item to nearest npc (need to be close)',
	Func = function()
		local shopkeepers = workspace.NPCs:QueryDescendants(">Model>Model:has(>Folder#Attributes:has(>Folder#ShopItems))")
		local itemToSell = Options.ItemToSell.Value
		local hrp = character.HumanoidRootPart
		local prompt

		for _, v in ipairs(game.ReplicatedStorage.RS.Remotes.Misc.GetSellItems:InvokeServer()) do
			if v:match(itemToSell) then
				prompt = v
			end
		end

		local amount = HttpService:JSONDecode(prompt).Amount


		for i, shop in ipairs(shopkeepers) do

			if not shop:FindFirstChild("Attributes") or not shop.Attributes:FindFirstChild("ShopBalance") then
				continue
			end
			if (hrp.Position - shop.WorldPivot.Position).Magnitude > 10 then
				continue
			end

			while shop.Attributes.ShopBalance.Value > 1000 do
				if amount <= 0 then
					return
				end
				if (hrp.Position - shop.WorldPivot.Position).Magnitude > 10 then
					break
				end
				newPrompt = HttpService:JSONDecode(prompt)
				newPrompt.Amount = amount
				prompt = HttpService:JSONEncode(newPrompt)
				local args = {
					[1] = shop,
					[2] = {
						[1] = prompt
					},
					[3] = "One"
				}
				task.spawn(function()
					game.ReplicatedStorage.RS.Remotes.Misc.SellItems:InvokeServer(unpack(args))
				end)
				amount = amount - 1
			end
		end

	end,
})

LeftRandomBox:AddButton({
	Text = 'Buy all near npc items',
	Tooltip = 'Buys all of item of nearest npc (need to be close)',
	Func = function()
		local shopkeepers = workspace.NPCs:QueryDescendants(">Model>Model:has(>Folder#Attributes:has(>Folder#ShopItems))")
		local hrp = character.HumanoidRootPart

		for i, shop in ipairs(shopkeepers) do
			local attributes = shop:FindFirstChild("Attributes")
			local shopItems = attributes and attributes:FindFirstChild("ShopItems")
			if not attributes or not shopItems then
				continue
			end

			if (hrp.Position - shop.WorldPivot.Position).Magnitude > 10 then
				continue
			end

			for _, item in ipairs(shopItems:GetChildren()) do
				if (hrp.Position - shop.WorldPivot.Position).Magnitude > 10 then
					break
				end
				local stockValue = item:FindFirstChild("Stock")
				local stock = stockValue and stockValue.Value
				if not stock or stock <= 0 then
					continue
				end
				local args = {
					shop,
					item.Value,
					"",
					stock
				}

				task.spawn(function()
					ReplicatedStorage.RS.Remotes.Misc.BuyItem:InvokeServer(unpack(args))
				end)
			end
		end

	end,
})

LeftRandomBox:AddInput('Deckhand', {
	Text = "Insert Deckhand Number",
	Tooltip = 'Insert deckhand number to change task',
	Default = '',
	Numeric = true,
	Finished = true
})

LeftRandomBox:AddInput('DeckhandTask', {
	Text = "Insert Deckhand task",
	Tooltip = 'Insert task to give to deckhand',
	Default = '',
	Finished = true
})

LeftRandomBox:AddButton({
	Text = "Give task",
	Tooltip = "Gives inserted task to deckhand",
	Func = function()
		local args = {
			tostring(Options.Deckhand.Value),
			"CommandTask",
			Options.DeckhandTask.Value
		}
		game:GetService("ReplicatedStorage"):WaitForChild("RS"):WaitForChild("Remotes"):WaitForChild("Boats"):WaitForChild("Castaway"):FireServer(unpack(args))
	end,
})

LeftRandomBox:AddButton({
	Text = "Restock Supplies",
	Tooltip = "Restock fleet supplies",
	Func = function()
		local args = {
			"1",
			"FleetResupply"
		}
		game:GetService("ReplicatedStorage"):WaitForChild("RS"):WaitForChild("Remotes"):WaitForChild("Boats"):WaitForChild("Castaway"):FireServer(unpack(args))
	end,
})

LeftRandomBox:AddButton({
	Text = "Discover all islands",
	Tooltip = "Discovers all islands",
	Func = function()
		for _, island in workspace.Map:GetChildren() do
			local args = {
				island.Name,
				""
			}
			ReplicatedStorage.RS.Remotes.Misc.UpdateLastSeen:FireServer(unpack(args))
		end
	end,
})

LeftRandomBox:AddToggle('GalleonFarmToggle', {
	Text = "Toggle farm galleons",
	Tooltip = "Automatically gives galleons",
	Default = false,
	Callback = function(Value)
		if Value then
			GalleonToggle = task.spawn(function()
				while task.wait(0.1) do
					local Event = ReplicatedStorage.RS.Remotes.Combat.CitizenKillCredit

					Event:FireServer("Thief")
				end
			end)

		else
			disableFunctions["GalleonFarmToggle"]()
		end
	end,
})

LeftRandomBox:AddInput('DrachmaAmount', {
	Text = "Insert Drachma Amount",
	Tooltip = 'Insert drachma amount to withdraw/deposit \nTakes from paramount bank',
	Default = '',
	Numeric = true,
	Finished = true
})

LeftRandomBox:AddButton({
	Text = "Withdraw drachma",
	Tooltip = "Withdraws drachma from paramount bank",
	Func = function()
		local args = {
			Options.DrachmaAmount.Value
		}
		ReplicatedStorage.RS.Remotes.Misc.Banks.WithdrawBankDrachma:InvokeServer(unpack(args))
	end,
})

LeftRandomBox:AddButton({
	Text = "Deposit drachma",
	Tooltip = "Deposits drachma from paramount bank",
	Func = function()
		local args = {
			Options.DrachmaAmount.Value
		}
		ReplicatedStorage.RS.Remotes.Misc.Banks.DepositBankDrachma:InvokeServer(unpack(args))
	end,
})

LeftRandomBox:AddButton({
	Text = "Upgrade bank",
	Tooltip = "Upgrades bank if enough money stored",
	Func = function()
		ReplicatedStorage.RS.Remotes.Misc.Banks.UpgradeBank:InvokeServer()
	end,
})

LeftRandomBox:AddButton({
	Text = "Disable insanity",
	Tooltip = "Disables insanity effects. Doesn't disable damage",
	Func = function()
		player.PlayerGui.Temp.Insanity.Enabled = false
	end,
})

LeftRandomBox:AddButton({
	Text = "Disable dark sea rain",
	Tooltip = "Disables dark sea rain",
	Func = function()
		ReplicatedStorage.RS.Remotes.Misc.RainEffect:Destroy()
	end,
})

RightRandomBox:AddToggle('ModToggle', {
	Text = "Kick if mod in server",
	Tooltip = "Will kick you if a join is in or joins the server",
	Default = false,
	Callback = function(Value)
		if Value then
			for _, plr in game.Players:GetPlayers() do
				if plr:IsInGroupAsync(3596833) then
					local rank = plr:GetRoleInGroupAsync(3596833)
					if rank:match("Game Moderator") or rank:match("Game Mod Lead") or rank:match("Developer") then
						player:Kick("A moderator has joined your server.")
					end
				end
			end
			ModConn = game.Players.PlayerAdded:Connect(function(plr)
				if plr:IsInGroupAsync(3596833) then
					local rank = plr:GetRoleInGroupAsync(3596833)
					if rank:match("Game Moderator") or rank:match("Game Mod Lead") or rank:match("Developer") then
						player:Kick("A moderator has joined your server.")
					end
				end
			end)

		else
			disableFunctions["ModToggle"]()
		end
	end,
})

local object = workspace
RightRandomBox:AddInput('KillMessage', {
	Text = "Kill message",
	Tooltip = 'Changes the kill message for kill all \nIt will only work if the item exists as an object',
	Default = '',
	Finished = true,
	Callback = function(Value)
		for _, part in workspace:GetDescendants() do
			pcall(function()
				if part.Name == Value then
					object = part
					return
				end
			end)
		end
	end,
})

RightRandomBox:AddToggle('KillAllToggle', {
	Text = "Kill all players",
	Tooltip = "Kills all players in the server except you \n Doesn't track back to you in any way",
	Callback = function(Value)
		if Value then
			killAllConn = task.spawn(function()
				while task.wait(5) do
					for _, plr in game.Players:GetPlayers() do
						if plr == player then continue end
						local args = {
							object ,
							plr.Character,
							"Cataclysm Magic",
							"1",
							'["Pulsar",1.7976931348623157e308,100,100,false,"Two Hands","(None)","Blast","(None)","Fire"]',
							1,
							1
						}

						game.ReplicatedStorage.RS.Remotes.Magic.DealAttackDamage:FireServer(unpack(args))
					end
				end
			end)
		else
			disableFunctions["KillAllToggle"]()
		end
	end,
})

Library:OnUnload(function()
	for _, func in pairs(disableFunctions) do
		func()
	end
	espParts:Destroy()
	print('Unloaded!')
	Library.Unloaded = true
end)
----------

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddToggle('Keybindmenu', {
	Text = "Toggle keybind menu",
	Default = true,
	Callback = function(Value)
		Library.KeybindFrame.Visible = Value
	end

}):AddKeyPicker('Keybindmenupick', {
	Default = '',
	SyncToggleState = true,
	Text = 'toggleKeybind',
	NoUI = true,
})

MenuGroup:AddButton('Copy discord link', function() setclipboard("https://discord.gg/sqtHCHXzCG") end)

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)

ThemeManager:SetFolder('KintamaHack')

ThemeManager:ApplyToTab(Tabs['UI Settings'])

if Toggles.AutoFishToggle.Value then
	autoFishConn = game.ReplicatedStorage.RS.Remotes.Misc.FishEvent.OnClientEvent:Connect(function(arg1, arg2, ...)
		if arg1 == player and arg2 == "Bite" then
			for i = 1, 10 do
				game:GetService("ReplicatedStorage").RS.Remotes.Misc.FishState:FireServer("Reel")
				task.wait()
			end
			task.wait(0.1)
			args = {
				[1] = player.Backpack:FindFirstChild(Options.RodBox.Value),
				[3] = Vector3.new(0/0 --[[NaN]], 0/0 --[[NaN]], 0/0 --[[NaN]]),
				[4] = Options.BaitBox.Value
			}

			ReplicatedStorage.RS.Remotes.Misc.FishClock:FireServer(unpack(args))

		end
	end)


	local args = {
		[1] = player.Backpack:FindFirstChild(Options.RodBox.Value),
		[3] = Vector3.new(0/0 --[[NaN]], 0/0 --[[NaN]], 0/0 --[[NaN]]),
		[4] = Options.BaitBox.Value
	}
	ReplicatedStorage.RS.Remotes.Misc.FishClock:FireServer(unpack(args))
end

if game.ReplicatedStorage.RS.Remotes.Combat:FindFirstChild("FallDamage") then
	game.ReplicatedStorage.RS.Remotes.Combat.FallDamage:Destroy()
end

for _, sky in workspace.Camera:GetChildren() do
	if sky.Name == "DarkSky1" or sky.Name == "DarkSky2" then
		sky:Destroy()
	end
end

local lighting = game:GetService("Lighting")
local folder = Instance.new("Folder")
local atmo = lighting:FindFirstChild("Atmosphere")
folder.Parent = lighting
folder.Name = "Atmosphere"
if atmo then atmo:Destroy() end

lighting.GlobalShadows = false
lighting.Ambient = Color3.new(1,1,1)
lighting.OutdoorAmbient = Color3.new(1,1,1)

workspace.Camera.ChildAdded:Connect(function(sky)
	if sky.Name == "DarkSky1" or sky.Name == "DarkSky2" then
		sky:Destroy()
	end
end)

for _, effect in lighting:GetChildren() do
	if effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") then
		effect.Enabled = false
	end
end

ReplicatedStorage.RS.Remotes.Combat.StaminaCost:FireServer(-3400)
