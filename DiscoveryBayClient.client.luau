--==============================================================================================
-- DISCOVERY BAY - HUD + trick input (LocalScript, StarterPlayer > StarterPlayerScripts)
--==============================================================================================
-- * money readout in the bottom-left corner (updates live from the Cash leaderstat)
-- * TRICK button in the bottom-right corner + T key; fires DoTrick to the server
-- * floating "+$25 360 Spin!" popups when the server reports a landed trick
--==============================================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local VERSION = "v132"
local SPEED_PASS_ID = 0 -- paste the real Game Pass ID here (same one as in DiscoveryBayShop)
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local plr = Players.LocalPlayer

--==============================================================================================
-- NIGHT SKY SHOOTING STARS & STARLIGHT SHIMMER
--==============================================================================================
task.spawn(function()
	local starColors = {
		Color3.fromRGB(165, 235, 255),
		Color3.fromRGB(255, 235, 165),
		Color3.fromRGB(210, 185, 255),
		Color3.fromRGB(160, 255, 220),
	}
	local rng = Random.new()
	while true do
		task.wait(rng:NextNumber(2.2, 4.8))
		local ct = Lighting.ClockTime
		if ct >= 18.4 or ct <= 5.6 then
			local cam = workspace.CurrentCamera
			local center = (cam and cam.CFrame.Position) or Vector3.new(0, 50, 0)
			local startAngle = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(260, 580)
			local height = rng:NextNumber(240, 420)
			local startPos = center + Vector3.new(math.cos(startAngle) * radius, height, math.sin(startAngle) * radius)
			local streakDir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.32, -0.08), rng:NextNumber(-1, 1)).Unit
			local endPos = startPos + streakDir * rng:NextNumber(280, 460)
			local col = starColors[rng:NextInteger(1, #starColors)]

			local star = Instance.new("Part")
			star.Name = "ShootingStar"
			star.Shape = Enum.PartType.Ball
			star.Size = Vector3.new(2.2, 2.2, 2.2)
			star.Color = col
			star.Material = Enum.Material.Neon
			star.Anchored = true
			star.CanCollide = false
			star.CastShadow = false
			star.CFrame = CFrame.new(startPos)

			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.9, 0)
			a0.Parent = star
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.9, 0)
			a1.Parent = star

			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(col, Color3.fromRGB(90, 140, 255))
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			trail.WidthScale = NumberSequence.new(1, 0)
			trail.Lifetime = 0.55
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Parent = star

			star.Parent = workspace
			local dur = rng:NextNumber(0.85, 1.4)
			local tw = TweenService:Create(star, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(endPos),
				Transparency = 1,
			})
			tw:Play()
			game:GetService("Debris"):AddItem(star, dur + 0.6)
		end
	end
end)
local remotes = ReplicatedStorage:WaitForChild("DiscoveryBayRemotes", 60)
if not remotes then return end
local DoTrick = remotes:WaitForChild("DoTrick")
local TrickResult = remotes:WaitForChild("TrickResult")
local ToggleScooter = remotes:WaitForChild("ToggleScooter")
local HatchEgg = remotes:WaitForChild("HatchEgg")
local UpdatePity = remotes:WaitForChild("UpdatePity")
local ForceWeather = remotes:WaitForChild("ForceWeather", 5) -- optional for testing
local InfiniteMoney = remotes:WaitForChild("InfiniteMoney", 5) -- optional for testing
local FishGame = remotes:WaitForChild("FishGame")
local FishReel = remotes:WaitForChild("FishReel")

--==============================================================================================
-- DYNAMIC AUDIO CONTROLLER (Fisch-style zone music)
--==============================================================================================
local ZONES = {
	{ name = "ShellBlox Gas Station", id = "rbxassetid://9043887091", speed = 1.15 },
	{ name = "Callahan's Coffee and Cones", id = "rbxassetid://9043887091", speed = 0.9 },
	{ name = "Discovery Bay Jiu Jitsu", id = "rbxassetid://9043887091", speed = 0.65 },
	{ name = "Fish N Bait", id = "rbxassetid://9043887091", speed = 0.85 },
	{ name = "Discovery Bay Scooters", id = "rbxassetid://9043887091", speed = 1.35 },
	{ name = "Egg Shop", id = "rbxassetid://9043887091", speed = 0.9 },
}
local OUTDOOR_MUSIC = "rbxassetid://9043887091"
local OUTDOOR_SPEED = 1.0
local currentZone = "Outdoor"
local activeTrack = nil

local SoundService = game:GetService("SoundService")

local function playSound(soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound and sound.Parent then sound:Destroy() end
	end)
end

task.spawn(function()
	local SoundService = game:GetService("SoundService")
	local town = workspace:WaitForChild("DiscoveryBay", 60)
	if not town then return end
	
	local function playTrack(id, vol, speed)
		speed = speed or 1.0
		if activeTrack and activeTrack.SoundId == id then
			if activeTrack.PlaybackSpeed ~= speed then
				TweenService:Create(activeTrack, TweenInfo.new(1.5), {PlaybackSpeed = speed}):Play()
			end
			if activeTrack.Volume ~= vol then
				TweenService:Create(activeTrack, TweenInfo.new(1.5), {Volume = vol}):Play()
			end
			return
		end

		local oldTrack = activeTrack
		if oldTrack then
			TweenService:Create(oldTrack, TweenInfo.new(4.0), {Volume = 0}):Play()
			task.delay(4.0, function() oldTrack:Destroy() end)
		end
		
		local newTrack = Instance.new("Sound")
		newTrack.Name = "ZoneMusic"
		newTrack.SoundId = id
		newTrack.Looped = true
		newTrack.Volume = 0
		newTrack.PlaybackSpeed = speed
		newTrack.Parent = SoundService
		newTrack:Play()
		TweenService:Create(newTrack, TweenInfo.new(4.0), {Volume = vol}):Play()
		activeTrack = newTrack
	end
	
	playTrack(OUTDOOR_MUSIC, 0.4, OUTDOOR_SPEED)
	
	while true do
		task.wait(1)
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if town and hrp then
			local foundZone = "Outdoor"
			
			local Lighting = game:GetService("Lighting")
			local isNight = Lighting.ClockTime >= 17.5 or Lighting.ClockTime <= 6.5
			local targetId = isNight and "rbxassetid://1848354536" or OUTDOOR_MUSIC
			local targetSpeed = isNight and 1.0 or OUTDOOR_SPEED
			
			for _, z in ipairs(ZONES) do
				local shop = town:FindFirstChild(z.name, true)
				if shop then
					local shopPart = shop:FindFirstChild("Floor") or shop:FindFirstChild("KioskFloor") or shop:FindFirstChild("Body") or shop.PrimaryPart or shop:FindFirstChildWhichIsA("BasePart")
					if shopPart and shopPart:IsA("BasePart") then
						local localPos = shopPart.CFrame:PointToObjectSpace(hrp.Position)
						local halfSize = shopPart.Size / 2
						
						if math.abs(localPos.X) <= halfSize.X + 10 and math.abs(localPos.Z) <= halfSize.Z + 10 then
							if hrp.Position.Y >= shopPart.Position.Y - 5 and hrp.Position.Y <= shopPart.Position.Y + 30 then
								foundZone = z.name
								targetId = z.id
								targetSpeed = z.speed or 1.0
								break
							end
						end
					end
				end
			end
			currentZone = foundZone
			playTrack(targetId, 0.4, targetSpeed)
		end
	end
end)

-- HUD ------------------------------------------------------------------------------------------
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

local gui = Instance.new("ScreenGui")
gui.Name = "DiscoveryBayHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false -- hidden until the intro's PLAY button is pressed
gui.Parent = plr:WaitForChild("PlayerGui")

local hotbar = Instance.new("Frame")
hotbar.Name = "CustomHotbar"
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -10)
hotbar.Size = UDim2.new(0, 480, 0, 60)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui

local hbList = Instance.new("UIListLayout")
hbList.FillDirection = Enum.FillDirection.Horizontal
hbList.HorizontalAlignment = Enum.HorizontalAlignment.Center
hbList.VerticalAlignment = Enum.VerticalAlignment.Center
hbList.Padding = UDim.new(0, 8)
hbList.Parent = hotbar

local invFrame = Instance.new("Frame")
invFrame.Name = "CustomInventory"
invFrame.AnchorPoint = Vector2.new(0.5, 1)
invFrame.Position = UDim2.new(0.5, 0, 1, -80)
invFrame.Size = UDim2.new(0, 480, 0, 240)
invFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
invFrame.BackgroundTransparency = 0.2
invFrame.Visible = false
invFrame.Parent = gui
local invCorner = Instance.new("UICorner"); invCorner.CornerRadius = UDim.new(0, 12); invCorner.Parent = invFrame
local invGrid = Instance.new("UIGridLayout")
invGrid.CellSize = UDim2.new(0, 60, 0, 60)
invGrid.CellPadding = UDim2.new(0, 10, 0, 10)
invGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
invGrid.SortOrder = Enum.SortOrder.LayoutOrder
invGrid.Parent = invFrame
local invPad = Instance.new("UIPadding")
invPad.PaddingTop = UDim.new(0, 15)
invPad.PaddingLeft = UDim.new(0, 15)
invPad.PaddingRight = UDim.new(0, 15)
invPad.Parent = invFrame

-- Rebirth Menu
local rebirthMenu = Instance.new("Frame")
rebirthMenu.Name = "RebirthMenu"
rebirthMenu.Size = UDim2.new(0, 300, 0, 220)
rebirthMenu.Position = UDim2.new(0.5, -150, 0.5, -110)
rebirthMenu.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
rebirthMenu.Visible = false
rebirthMenu.Parent = gui

local rmCorner = Instance.new("UICorner")
rmCorner.CornerRadius = UDim.new(0, 12)
rmCorner.Parent = rebirthMenu

local rmTitle = Instance.new("TextLabel")
rmTitle.Size = UDim2.new(1, 0, 0, 40)
rmTitle.BackgroundTransparency = 1
rmTitle.Text = "REBIRTH?"
rmTitle.Font = Enum.Font.LuckiestGuy
rmTitle.TextColor3 = Color3.new(1, 1, 1)
rmTitle.TextSize = 24
rmTitle.Parent = rebirthMenu

local rmDesc = Instance.new("TextLabel")
rmDesc.Size = UDim2.new(1, -20, 0, 120)
rmDesc.Position = UDim2.new(0, 10, 0, 40)
rmDesc.BackgroundTransparency = 1
rmDesc.Text = "Benefits:\n• 1.5x Scooter Speed!\n• 1.5x Cash Multiplier!\n\nWarning: You will lose your house, pet, and money."
rmDesc.Font = Enum.Font.GothamBold
rmDesc.TextColor3 = Color3.new(0.8, 0.8, 0.8)
rmDesc.TextSize = 18
rmDesc.TextWrapped = true
rmDesc.Parent = rebirthMenu

local rmConfirm = Instance.new("TextButton")
rmConfirm.Size = UDim2.new(0.4, 0, 0, 40)
rmConfirm.Position = UDim2.new(0.07, 0, 1, -50)
rmConfirm.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
rmConfirm.Text = "REBIRTH?"
rmConfirm.Font = Enum.Font.LuckiestGuy
rmConfirm.TextColor3 = Color3.new(1, 1, 1)
rmConfirm.TextSize = 16
rmConfirm.Parent = rebirthMenu
local rmcCorner = Instance.new("UICorner"); rmcCorner.CornerRadius = UDim.new(0, 8); rmcCorner.Parent = rmConfirm

local rmCancel = Instance.new("TextButton")
rmCancel.Size = UDim2.new(0.4, 0, 0, 40)
rmCancel.Position = UDim2.new(0.53, 0, 1, -50)
rmCancel.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
rmCancel.Text = "CANCEL"
rmCancel.Font = Enum.Font.LuckiestGuy
rmCancel.TextColor3 = Color3.new(1, 1, 1)
rmCancel.TextSize = 16
rmCancel.Parent = rebirthMenu
local rmxCorner = Instance.new("UICorner"); rmxCorner.CornerRadius = UDim.new(0, 8); rmxCorner.Parent = rmCancel

rmCancel.MouseButton1Click:Connect(function()
	rebirthMenu.Visible = false
end)
rmConfirm.MouseButton1Click:Connect(function()
	remotes:WaitForChild("DoRebirth"):FireServer()
	rebirthMenu.Visible = false
end)

-- Rebirth Button (Left-Center Dock, paired with Shop)
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthBtn"
rebirthBtn.Size = UDim2.new(0, 156, 0, 50)
rebirthBtn.Position = UDim2.new(0, 18, 0.52, 6)
rebirthBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
rebirthBtn.Text = "REBIRTH"
rebirthBtn.Font = Enum.Font.LuckiestGuy
rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthBtn.TextSize = 16
rebirthBtn.Parent = gui

local rCorner = Instance.new("UICorner")
rCorner.CornerRadius = UDim.new(0, 12)
rCorner.Parent = rebirthBtn
local rStroke = Instance.new("UIStroke")
rStroke.Color = Color3.fromRGB(215, 140, 255)
rStroke.Thickness = 2
rStroke.Parent = rebirthBtn

local function getRebirthCost()
	local stats = plr:FindFirstChild("leaderstats")
	local r = stats and stats:FindFirstChild("Rebirths")
	local rVal = r and r.Value or 0
	return 1000 * math.pow(5, rVal)
end

rebirthBtn.MouseButton1Click:Connect(function()
	local stats = plr:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	local cost = getRebirthCost()
	if cash and cash.Value >= cost then
		rebirthMenu.Visible = true
	else
		local origPos = UDim2.new(0, 18, 0.52, 6)
		local tw = TweenService:Create(rebirthBtn, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 3, true), {
			Position = origPos + UDim2.new(0, 10, 0, 0)
		})
		tw:Play()
	end
end)

task.spawn(function()
	while task.wait(0.5) do
		local stats = plr:FindFirstChild("leaderstats")
		local r = stats and stats:FindFirstChild("Rebirths")
		local cost = getRebirthCost()
		if r and r.Value > 0 then
			rebirthBtn.Text = "REBIRTH ($" .. cost .. ")\n" .. r.Value .. " Rebirths!"
		else
			rebirthBtn.Text = "REBIRTH ($" .. cost .. ")"
		end
	end
end)

local hotbarSlots = {}
for i = 1, 9 do
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. i
	slot.Size = UDim2.new(0, 45, 0, 45)
	slot.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
	slot.BackgroundTransparency = 0.4
	slot.Text = ""
	slot.AutoButtonColor = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = slot
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 110, 120)
	stroke.Thickness = 2
	stroke.Parent = slot
	
	local numLbl = Instance.new("TextLabel")
	numLbl.Position = UDim2.new(0, 4, 0, 4)
	numLbl.Size = UDim2.new(0, 12, 0, 12)
	numLbl.BackgroundTransparency = 1
	numLbl.Text = tostring(i)
	numLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	numLbl.Font = Enum.Font.LuckiestGuy
	numLbl.TextSize = 12
	numLbl.Parent = slot
	
	local itemLbl = Instance.new("TextLabel")
	itemLbl.Size = UDim2.new(1, 0, 1, 0)
	itemLbl.BackgroundTransparency = 1
	itemLbl.Text = ""
	itemLbl.TextColor3 = Color3.new(1, 1, 1)
	itemLbl.Font = Enum.Font.LuckiestGuy
	itemLbl.TextSize = 10
	itemLbl.TextWrapped = true
	itemLbl.Parent = slot
	
	slot.Parent = hotbar
	hotbarSlots[i] = { btn = slot, stroke = stroke, name = itemLbl, tool = nil }
end

local function getTools()
	local tools = {}
	for _, t in ipairs(plr:WaitForChild("Backpack"):GetChildren()) do
		if t:IsA("Tool") then table.insert(tools, t) end
	end
	if plr.Character then
		for _, t in ipairs(plr.Character:GetChildren()) do
			if t:IsA("Tool") then table.insert(tools, t) end
		end
	end
	return tools
end

local function refreshHotbar()
	local tools = getTools()
	for i = 1, 9 do
		local slotData = hotbarSlots[i]
		local tool = tools[i]
		slotData.tool = tool
		if tool then
			slotData.name.Text = tool.Name
			if tool.Parent == plr.Character then
				slotData.stroke.Color = Color3.fromRGB(255, 200, 50)
				slotData.stroke.Thickness = 3
			else
				slotData.stroke.Color = Color3.fromRGB(150, 160, 170)
				slotData.stroke.Thickness = 2
			end
		else
			slotData.name.Text = ""
			slotData.stroke.Color = Color3.fromRGB(100, 110, 120)
			slotData.stroke.Thickness = 2
		end
	end
	
	for _, c in ipairs(invFrame:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for i, tool in ipairs(tools) do
		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
		if tool.Parent == plr.Character then btn.BackgroundColor3 = Color3.fromRGB(150, 110, 20) end
		btn.Text = tool.Name
		btn.TextColor3 = Color3.new(1,1,1)
		btn.TextSize = 10
		btn.Font = Enum.Font.LuckiestGuy
		btn.TextWrapped = true
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.3, 0); corner.Parent = btn
		btn.Parent = invFrame
		btn.Activated:Connect(function()
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				if tool.Parent == plr.Character then hum:UnequipTools() else hum:EquipTool(tool) end
			end
			refreshHotbar()
		end)
	end
end

local function equipSlot(i)
	local slotData = hotbarSlots[i]
	if not slotData.tool then return end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if slotData.tool.Parent == plr.Character then
		hum:UnequipTools()
	else
		hum:EquipTool(slotData.tool)
	end
	refreshHotbar()
end

for i = 1, 9 do
	hotbarSlots[i].btn.Activated:Connect(function() equipSlot(i) end)
end

local function hookBackpack(bp)
	bp.ChildAdded:Connect(refreshHotbar)
	bp.ChildRemoved:Connect(refreshHotbar)
	refreshHotbar()
end

if plr:FindFirstChildOfClass("Backpack") then
	hookBackpack(plr:FindFirstChildOfClass("Backpack"))
end
plr.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		hookBackpack(child)
	end
end)

plr.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(c) if c:IsA("Tool") then refreshHotbar() end end)
	char.ChildRemoved:Connect(function(c) if c:IsA("Tool") then refreshHotbar() end end)
	refreshHotbar()
end)
if plr.Character then
	plr.Character.ChildAdded:Connect(function(c) if c:IsA("Tool") then refreshHotbar() end end)
	plr.Character.ChildRemoved:Connect(function(c) if c:IsA("Tool") then refreshHotbar() end end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Backquote then
		invFrame.Visible = not invFrame.Visible
	end
	if input.KeyCode.Value >= Enum.KeyCode.One.Value and input.KeyCode.Value <= Enum.KeyCode.Nine.Value then
		equipSlot(input.KeyCode.Value - Enum.KeyCode.One.Value + 1)
	end
end)

--==============================================================================================
-- SODA QUEST STATE
--==============================================================================================
local questActive = false
local questTimer = 0
local questFound = false
local questCompleted = false
local inTerryCutscene = false
local questHighlight = nil

local questFrame = Instance.new("Frame")
questFrame.Name = "QuestTimerUI"
questFrame.AnchorPoint = Vector2.new(0, 0.5)
questFrame.Position = UDim2.new(0, 18, 0.34, 0)
questFrame.Size = UDim2.new(0, 200, 0, 60)
questFrame.BackgroundColor3 = Color3.fromRGB(30, 150, 60)
questFrame.Visible = false
questFrame.Parent = gui
local qc = Instance.new("UICorner"); qc.CornerRadius = UDim.new(0, 12); qc.Parent = questFrame
local qtxt = Instance.new("TextLabel")
qtxt.Size = UDim2.new(1, 0, 1, 0)
qtxt.BackgroundTransparency = 1
qtxt.Text = "2:00"
qtxt.TextColor3 = Color3.new(1,1,1)
qtxt.Font = Enum.Font.LuckiestGuy
qtxt.TextSize = 24
qtxt.Parent = questFrame

local function updateQuest()
	if not questActive then return end
	if questFound then
		qtxt.Text = "Return to Terry!"
		questFrame.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
		return
	end
	if questTimer > 0 then
		questTimer = questTimer - 1
		local m = math.floor(questTimer / 60)
		local s = questTimer % 60
		qtxt.Text = string.format("Find Soda! %d:%02d", m, s)
	else
		questActive = false
		questFrame.Visible = false
		local soda = workspace:FindFirstChild("TerrysSoda", true)
		if soda then
			soda.Transparency = 1
			local p = soda:FindFirstChildOfClass("ProximityPrompt")
			if p then p.Enabled = false end
		end
		if questHighlight then questHighlight:Destroy() end
	end
end

task.spawn(function()
	while task.wait(1) do
		updateQuest()
	end
end)

local function startQuest()
	questActive = true
	questFound = false
	questTimer = 120
	questFrame.Visible = true
	questFrame.BackgroundColor3 = Color3.fromRGB(30, 150, 60)
	qtxt.Text = "Find Soda! 2:00"
	
	local soda = workspace:FindFirstChild("TerrysSoda", true)
	if soda then
		soda.Transparency = 0
		local p = soda:FindFirstChildOfClass("ProximityPrompt")
		if not p then
			p = Instance.new("ProximityPrompt")
			p.ActionText = "Grab Soda"
			p.ObjectText = "Terry's Soda"
			p.HoldDuration = 1
			p.Parent = soda
			p.Triggered:Connect(function(plyr)
				if plyr == plr and questActive and not questFound then
					questFound = true
					soda.Transparency = 1
					p.Enabled = false
					if questHighlight then questHighlight:Destroy() end
				end
			end)
		end
		p.Enabled = true
		
		if questHighlight then questHighlight:Destroy() end
		questHighlight = Instance.new("Highlight")
		questHighlight.FillColor = Color3.fromRGB(50, 255, 50)
		questHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		questHighlight.Parent = soda
	end
end

--==============================================================================================
-- CUSTOM DIALOGUE UI
--==============================================================================================
local dlgFrame = Instance.new("Frame")
dlgFrame.Name = "DialogueUI"
dlgFrame.AnchorPoint = Vector2.new(0.5, 1)
dlgFrame.Position = UDim2.new(0.5, 0, 1, -80)
dlgFrame.Position = UDim2.new(0.5, 0, 1, -60)
dlgFrame.Size = UDim2.new(0, 660, 0, 190)
dlgFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
dlgFrame.BackgroundTransparency = 0.2
dlgFrame.Visible = false
dlgFrame.Parent = gui

local dlgCorner = Instance.new("UICorner")
dlgCorner.CornerRadius = UDim.new(0, 12)
dlgCorner.Parent = dlgFrame

local dlgName = Instance.new("TextLabel")
dlgName.Position = UDim2.new(0, 20, 0, 10)
dlgName.Size = UDim2.new(1, -40, 0, 24)
dlgName.BackgroundTransparency = 1
dlgName.Font = Enum.Font.LuckiestGuy
dlgName.TextSize = 22
dlgName.TextColor3 = Color3.fromRGB(250, 200, 50)
dlgName.TextXAlignment = Enum.TextXAlignment.Left
dlgName.Parent = dlgFrame

local dlgText = Instance.new("TextLabel")
dlgText.Position = UDim2.new(0, 20, 0, 40)
dlgText.Position = UDim2.new(0, 20, 0, 42)
dlgText.Size = UDim2.new(1, -40, 0, 84)
dlgText.TextScaled = false
dlgText.BackgroundTransparency = 1
dlgText.Font = Enum.Font.GothamBold
dlgText.TextSize = 20
dlgText.TextColor3 = Color3.new(1, 1, 1)
dlgText.TextWrapped = true
dlgText.TextXAlignment = Enum.TextXAlignment.Left
dlgText.TextYAlignment = Enum.TextYAlignment.Top
dlgText.Parent = dlgFrame

local choicesFrame = Instance.new("Frame")
choicesFrame.Position = UDim2.new(0, 20, 0, 136)
choicesFrame.Size = UDim2.new(1, -40, 0, 40)
choicesFrame.BackgroundTransparency = 1
choicesFrame.Parent = dlgFrame

local chList = Instance.new("UIListLayout")
chList.FillDirection = Enum.FillDirection.Horizontal
chList.HorizontalAlignment = Enum.HorizontalAlignment.Center
chList.Padding = UDim.new(0, 10)
chList.Parent = choicesFrame

local activeTypewriter = nil
local currentCutsceneNPC = nil
local cutsceneCamTween = nil
local savedNPCJoints = {}

local topBar = Instance.new("Frame")
topBar.Name = "CutsceneTopBar"
topBar.Size = UDim2.new(1, 0, 0, 0)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.new(0, 0, 0)
topBar.BorderSizePixel = 0
topBar.ZIndex = 9
topBar.Parent = gui

local bottomBar = Instance.new("Frame")
bottomBar.Name = "CutsceneBottomBar"
bottomBar.AnchorPoint = Vector2.new(0, 1)
bottomBar.Size = UDim2.new(1, 0, 0, 0)
bottomBar.Position = UDim2.new(0, 0, 1, 0)
bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
bottomBar.BorderSizePixel = 0
bottomBar.ZIndex = 9
bottomBar.Parent = gui
dlgFrame.ZIndex = 10
dlgName.ZIndex = 12
dlgText.ZIndex = 12
choicesFrame.ZIndex = 12

--==============================================================================================
-- GTA V "WASTED" DEATH SCREEN + ROASTS + CAR FLING PHYSICS
--==============================================================================================
local DEATH_ROASTS = {
	"Is this your best?",
	"Bro looked both ways and still got folded.",
	"The car had the right of way lil bro.",
	"Even the NPCs saw that coming.",
	"You had a whole sidewalk and still chose the bumper.",
	"Skill issue detected. Respawning...",
	"Insurance is NOT covering that one.",
	"Bro became a Discovery Bay speedbump.",
	"My grandma dodges traffic better than that.",
	"That driver didn't even touch the brakes.",
}

local wastedGui = Instance.new("ScreenGui")
wastedGui.Name = "GTAWastedGui"
wastedGui.DisplayOrder = 999
wastedGui.IgnoreGuiInset = true
wastedGui.ResetOnSpawn = false
wastedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
wastedGui.Parent = plr:WaitForChild("PlayerGui")

local wastedBanner = Instance.new("Frame")
wastedBanner.Name = "GTAWastedBanner"
wastedBanner.AnchorPoint = Vector2.new(0.5, 0.5)
wastedBanner.Position = UDim2.new(0.5, 0, 0.46, 0)
wastedBanner.Size = UDim2.new(1, 0, 0, 175)
wastedBanner.BackgroundColor3 = Color3.new(0, 0, 0)
wastedBanner.BackgroundTransparency = 1
wastedBanner.BorderSizePixel = 0
wastedBanner.Visible = false
wastedBanner.ZIndex = 50
wastedBanner.Parent = wastedGui

local wastedTitle = Instance.new("TextLabel")
wastedTitle.Name = "WastedTitle"
wastedTitle.AnchorPoint = Vector2.new(0.5, 0.5)
wastedTitle.Position = UDim2.new(0.5, 0, 0.38, 0)
wastedTitle.Size = UDim2.new(1, 0, 0, 90)
wastedTitle.BackgroundTransparency = 1
wastedTitle.Font = Enum.Font.LuckiestGuy
wastedTitle.Text = "WASTED"
wastedTitle.TextColor3 = Color3.fromRGB(225, 38, 38)
wastedTitle.TextSize = 78
wastedTitle.TextTransparency = 1
wastedTitle.ZIndex = 51
wastedTitle.Parent = wastedBanner

local wastedStroke = Instance.new("UIStroke")
wastedStroke.Color = Color3.new(0, 0, 0)
wastedStroke.Thickness = 4
wastedStroke.Transparency = 1
wastedStroke.Parent = wastedTitle

local wastedRoast = Instance.new("TextLabel")
wastedRoast.Name = "WastedRoast"
wastedRoast.AnchorPoint = Vector2.new(0.5, 0.5)
wastedRoast.Position = UDim2.new(0.5, 0, 0.78, 0)
wastedRoast.Size = UDim2.new(0.9, 0, 0, 36)
wastedRoast.BackgroundTransparency = 1
wastedRoast.Font = Enum.Font.GothamBold
wastedRoast.Text = "Is this your best?"
wastedRoast.TextColor3 = Color3.fromRGB(240, 240, 240)
wastedRoast.TextSize = 24
wastedRoast.TextTransparency = 1
wastedRoast.ZIndex = 51
wastedRoast.Parent = wastedBanner

local wastedRoastStroke = Instance.new("UIStroke")
wastedRoastStroke.Color = Color3.new(0, 0, 0)
wastedRoastStroke.Thickness = 2
wastedRoastStroke.Transparency = 1
wastedRoastStroke.Parent = wastedRoast

local wastedCC = Instance.new("ColorCorrectionEffect")
wastedCC.Name = "WastedColorCorrection"
wastedCC.Enabled = false
wastedCC.Parent = game:GetService("Lighting")

local lastRoastIdx = 0
local function playGTAWasted()
	local oldDeath = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("DeathScreen")
	if oldDeath then oldDeath:Destroy() end
	local idx = math.random(1, #DEATH_ROASTS)
	if idx == lastRoastIdx then idx = (idx % #DEATH_ROASTS) + 1 end
	lastRoastIdx = idx
	wastedRoast.Text = DEATH_ROASTS[idx]

	-- GTA V initial slow-mo flash + heavy bass hit SFX
	local sfx1 = Instance.new("Sound")
	sfx1.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
	sfx1.PlaybackSpeed = 0.52
	sfx1.Volume = 2.4
	sfx1.Parent = game:GetService("SoundService")
	sfx1:Play()
	game:GetService("Debris"):AddItem(sfx1, 4)

	local sfxSting = Instance.new("Sound")
	sfxSting.SoundId = "rbxassetid://9117314405"
	sfxSting.PlaybackSpeed = 0.45
	sfxSting.Volume = 1.8
	sfxSting.Parent = game:GetService("SoundService")
	sfxSting:Play()
	game:GetService("Debris"):AddItem(sfxSting, 4)

	wastedCC.Enabled = true
	wastedCC.Brightness = 0.35
	wastedCC.Contrast = 0.2
	wastedCC.Saturation = -0.3
	wastedCC.TintColor = Color3.fromRGB(255, 190, 190)
	TweenService:Create(wastedCC, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = -0.08,
		Contrast = 0.45,
		Saturation = -0.92,
		TintColor = Color3.fromRGB(225, 195, 195),
	}):Play()

	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = 50,
		}):Play()
	end

	wastedBanner.Visible = true
	wastedBanner.BackgroundTransparency = 1
	wastedTitle.TextTransparency = 1
	wastedStroke.Transparency = 1
	wastedRoast.TextTransparency = 1
	wastedRoastStroke.Transparency = 1
	wastedTitle.TextSize = 115

	task.delay(0.35, function()
		if not wastedBanner.Visible then return end
		-- Second GTA V "WASTED" stamp thud SFX when the banner slams in
		local sfxStamp = Instance.new("Sound")
		sfxStamp.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
		sfxStamp.PlaybackSpeed = 0.36
		sfxStamp.Volume = 2.6
		sfxStamp.Parent = game:GetService("SoundService")
		sfxStamp:Play()
		game:GetService("Debris"):AddItem(sfxStamp, 4)

		TweenService:Create(wastedBanner, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.25,
		}):Play()
		TweenService:Create(wastedTitle, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextTransparency = 0,
			TextSize = 78,
		}):Play()
		TweenService:Create(wastedStroke, TweenInfo.new(0.22), { Transparency = 0 }):Play()
		TweenService:Create(wastedRoast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
		TweenService:Create(wastedRoastStroke, TweenInfo.new(0.35), { Transparency = 0 }):Play()
	end)
end

local wastedShownForChar = nil
local function hookCharacterDeath(ch)
	wastedShownForChar = nil
	wastedBanner.Visible = false
	wastedCC.Enabled = false
	local cam = workspace.CurrentCamera
	if cam and not currentCutsceneNPC then
		cam.FieldOfView = 70
	end
	local hum = ch:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			if wastedShownForChar ~= ch then
				wastedShownForChar = ch
				playGTAWasted()
			end
		end)
	end
end
if plr.Character then
	task.spawn(hookCharacterDeath, plr.Character)
end
plr.CharacterAdded:Connect(hookCharacterDeath)

task.spawn(function()
	local carFlingRemote = remotes:WaitForChild("CarFling", 15)
	if carFlingRemote then
		carFlingRemote.OnClientEvent:Connect(function(flingVel, angVel)
			local ch = plr.Character
			local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				hum.PlatformStand = true
				hum:ChangeState(Enum.HumanoidStateType.Physics)
				hrp.AssemblyLinearVelocity = flingVel
				hrp.AssemblyAngularVelocity = angVel
				if wastedShownForChar ~= ch then
					wastedShownForChar = ch
					playGTAWasted()
				end
			end
		end)
	end
end)

local function restoreNPCPose(npcModel)
	local pose = npcModel and savedNPCJoints[npcModel]
	if pose then
		if pose.torso and pose.torso.Parent and pose.torsoCF then pose.torso.CFrame = pose.torsoCF end
		if pose.head and pose.head.Parent then pose.head.CFrame = pose.headCF end
		if pose.rArm and pose.rArm.Parent then pose.rArm.CFrame = pose.rArmCF end
		if pose.lArm and pose.lArm.Parent then pose.lArm.CFrame = pose.lArmCF end
		if pose.rLeg and pose.rLeg.Parent and pose.rLegCF then pose.rLeg.CFrame = pose.rLegCF end
		if pose.lLeg and pose.lLeg.Parent and pose.lLegCF then pose.lLeg.CFrame = pose.lLegCF end
		if pose.accessories then
			for _, acc in ipairs(pose.accessories) do
				if acc.part and acc.part.Parent then acc.part.CFrame = acc.baseCF end
			end
		end
	end
end

local isNPCTalking = false
local talkWeight = 0
local npcAnimConn = nil
local postTalkConns = {}
local npcFaceUIs = {}

local NPC_CLASSIC_FACE_MAP = {
	-- *Talk faces are open-mouth classic faces; the mouth-flap loop swaps between the stage face and its Talk face
	["Manager Bob"]   = { idle = "Stare",           interact = "Disbelief",       interactTalk = "Roar",           answer = "MrChuckles",     answerTalk = "OpenO" },
	["Eggbert"]       = { idle = "GoodIntentioned", interact = "Skeptic",         interactTalk = "JoyousSurprise", answer = "GoodIntentioned", answerTalk = "JoyfulSmile" },
	["Captain Finn"]  = { idle = "CheckIt",         interact = "Winky",           interactTalk = "JoyfulSmile",    answer = "Disbelief",      answerTalk = "OpenO" },
	["Rider Rick"]    = { idle = "SureImCool",      interact = "Chill",           interactTalk = "JoyfulSmile",    answer = "ItsGoTime",      answerTalk = "TongueOut" },
	["Callahan"]      = { idle = "Smile",           interact = "GoodIntentioned", interactTalk = "JoyfulSmile",    answer = "HappyWink",      answerTalk = "JoyousSurprise" },
	["Thirsty Terry"] = { idle = "Sniffles",        interact = "Disbelief",       interactTalk = "OpenO",          answer = "Puck",           answerTalk = "JoyfulSmile" },
	["Sal"]           = { idle = "Chill",           interact = "MrChuckles",      interactTalk = "JoyfulSmile",    answer = "HappyWink",      answerTalk = "TongueOut" },
	["Sensei"]        = { idle = "Grr",             interact = "ItsGoTime",       interactTalk = "Roar",           answer = "Grr",            answerTalk = "Roar" },
	["Ms. Wheeler"]   = { idle = "Smile",           interact = "Winky",           interactTalk = "JoyousSurprise", answer = "Smile",          answerTalk = "JoyfulSmile" },
	["Pedestrian"]    = { idle = "Smile",           interact = "GoodIntentioned", interactTalk = "OpenO",          answer = "Slickfang",      answerTalk = "Fang", panic = "Roar" },
}

local function getClassicFaceTex(faceKey)
	local folder = remotes:FindFirstChild("ClassicFaces")
	local sv = folder and folder:FindFirstChild(faceKey)
	if sv and sv.Value ~= "" then
		return sv.Value
	end
	if faceKey == "Chill" then
		return "rbxassetid://7074749"
	end
	return "rbxasset://textures/face.png"
end

local function ensureNPCFaceUI(npc)
	if npcFaceUIs[npc] then
		return npcFaceUIs[npc]
	end
	local head = npc and npc:FindFirstChild("Head")
	if not head then return nil end
	local origDecal = head:FindFirstChild("ClassicFace") or head:FindFirstChild("face")
	local ui = {
		decal = origDecal,
		stage = "idle",
		baseKey = "Smile",
		talkKey = "JoyousSurprise",
		lastAppliedTex = "",
	}
	npcFaceUIs[npc] = ui
	return ui
end

local function applyNPCFaceKey(npc, faceKey)
	local ui = ensureNPCFaceUI(npc)
	if not ui or not ui.decal then return end
	local tex = getClassicFaceTex(faceKey)
	if ui.lastAppliedTex ~= tex then
		ui.lastAppliedTex = tex
		ui.decal.Transparency = 0
		ui.decal.Texture = tex
	end
end

local function setNPCFaceState(npc, stage)
	if not npc then return end
	local ui = ensureNPCFaceUI(npc)
	if not ui then return end
	local map = NPC_CLASSIC_FACE_MAP[npc.Name] or NPC_CLASSIC_FACE_MAP["Pedestrian"]
	ui.stage = stage
	ui.baseKey = map[stage] or map.idle or "Smile"
	ui.talkKey = map[stage .. "Talk"] or ui.baseKey
	applyNPCFaceKey(npc, ui.baseKey)
	-- preload the open-mouth face so the first mouth flap doesn't blink blank while it downloads
	local talkTex = getClassicFaceTex(ui.talkKey)
	task.spawn(function()
		pcall(function() game:GetService("ContentProvider"):PreloadAsync({ talkTex }) end)
	end)
end

-- Mouth flapping: while the talking NPC's dialogue is typing, swap its classic face between
-- the stage face (mouth closed) and the stage's open-mouth Talk face
local npcTalkUntil = 0 -- for lines shown without the typewriter (e.g. Terry's soda cutscene)
local flapNPC = nil
local FLAP_INTERVAL = 0.13
RunService.Heartbeat:Connect(function()
	local npc = currentCutsceneNPC
	local talking = npc ~= nil and (isNPCTalking or os.clock() < npcTalkUntil)
	if flapNPC and (flapNPC ~= npc or not talking) then
		-- talking stopped (or the cutscene ended): close the mouth
		local ui = npcFaceUIs[flapNPC]
		if ui and flapNPC.Parent then applyNPCFaceKey(flapNPC, ui.baseKey) end
		flapNPC = nil
	end
	if talking then
		local ui = npcFaceUIs[npc]
		if not ui then return end
		flapNPC = npc
		local mouthOpen = math.floor(os.clock() / FLAP_INTERVAL) % 2 == 0
		applyNPCFaceKey(npc, mouthOpen and ui.talkKey or ui.baseKey)
	end
end)

local function updateNPCAccessories(pose, newHeadCF)
	if pose.accessories then
		for _, acc in ipairs(pose.accessories) do
			if acc.part and acc.part.Parent then
				acc.part.CFrame = newHeadCF * acc.relToHead
			end
		end
	end
end

local function applyLimbsFromTorso(pose, animTorsoCF, headRot, rArmRot, lArmRot, rLegRot, lLegRot)
	if pose.torso and pose.torso.Parent and not pose.sit then
		pose.torso.CFrame = animTorsoCF
	end
	local neckPivot = animTorsoCF * CFrame.new(0, 1, 0)
	local newHeadCF = neckPivot * (headRot or CFrame.new()) * CFrame.new(0, 0.5, 0)
	if pose.head and pose.head.Parent then
		pose.head.CFrame = newHeadCF
	end
	updateNPCAccessories(pose, newHeadCF)
	if not pose.sit then
		if pose.rArm and pose.rArm.Parent then
			pose.rArm.CFrame = (animTorsoCF * CFrame.new(1.5, 0.5, 0)) * (rArmRot or CFrame.new()) * CFrame.new(0, -0.5, 0)
		end
		if pose.lArm and pose.lArm.Parent then
			pose.lArm.CFrame = (animTorsoCF * CFrame.new(-1.5, 0.5, 0)) * (lArmRot or CFrame.new()) * CFrame.new(0, -0.5, 0)
		end
		if pose.rLeg and pose.rLeg.Parent then
			pose.rLeg.CFrame = (animTorsoCF * CFrame.new(0.5, -1, 0)) * (rLegRot or CFrame.new()) * CFrame.new(0, -1, 0)
		end
		if pose.lLeg and pose.lLeg.Parent then
			pose.lLeg.CFrame = (animTorsoCF * CFrame.new(-0.5, -1, 0)) * (lLegRot or CFrame.new()) * CFrame.new(0, -1, 0)
		end
	end
end

local function stopNPCAnimLoop()
	isNPCTalking = false
	talkWeight = 0
	if npcAnimConn then
		npcAnimConn:Disconnect()
		npcAnimConn = nil
	end
end

local function playPostTalkAnimation(npc)
	local pose = npc and savedNPCJoints[npc]
	if not npc or not pose or npc:GetAttribute("PianoDropping") then return end
	if postTalkConns[npc] then
		postTalkConns[npc]:Disconnect()
		postTalkConns[npc] = nil
	end
	local baseTorso = pose.torsoCF or (pose.headCF * CFrame.new(0, -1.5, 0))
	local name = npc.Name
	local dur = 1.8
	local t0 = os.clock()
	postTalkConns[npc] = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - t0
		if elapsed >= dur or not npc.Parent or npc:GetAttribute("PianoDropping") or currentCutsceneNPC == npc then
			if postTalkConns[npc] then
				postTalkConns[npc]:Disconnect()
				postTalkConns[npc] = nil
			end
			if currentCutsceneNPC ~= npc and not npc:GetAttribute("PianoDropping") then
				restoreNPCPose(npc)
				setNPCFaceState(npc, "idle")
			end
			return
		end
		local u = elapsed / dur
		local env = math.sin(u * math.pi)
		local animTorso = baseTorso
		local headRot, rArmRot, lArmRot, rLegRot, lLegRot = CFrame.new(), CFrame.new(), CFrame.new(), CFrame.new(), CFrame.new()

		if name == "Manager Bob" then
			-- Big tired overhead yawn stretch, then grumpy slouch
			local stretch = math.sin(math.clamp(u * 1.4, 0, 1) * math.pi)
			animTorso = baseTorso * CFrame.new(0, stretch * 0.12, 0) * CFrame.Angles(math.rad(14 * stretch - 6 * env), 0, 0)
			headRot = CFrame.Angles(math.rad(25 * stretch), math.sin(elapsed * 6) * math.rad(10 * (1 - stretch)), 0)
			rArmRot = CFrame.Angles(math.rad(165 * stretch), 0, math.rad(18 * stretch))
			lArmRot = CFrame.Angles(math.rad(165 * stretch), 0, math.rad(-18 * stretch))
		elseif name == "Eggbert" then
			-- Excited 360 spin-jump in the air with both arms cheering!
			local jumpH = math.max(0, math.sin(u * math.pi * 2)) * 1.6 * env
			local spin = u * math.pi * 2
			animTorso = baseTorso * CFrame.new(0, jumpH, 0) * CFrame.Angles(0, spin, 0)
			headRot = CFrame.Angles(math.rad(12 * env), 0, 0)
			rArmRot = CFrame.Angles(math.rad(150 * env), 0, math.rad(25 * env))
			lArmRot = CFrame.Angles(math.rad(150 * env), 0, math.rad(-25 * env))
			rLegRot = CFrame.Angles(math.rad(-25 * env), 0, math.rad(10 * env))
			lLegRot = CFrame.Angles(math.rad(25 * env), 0, math.rad(-10 * env))
		elseif name == "Captain Finn" then
			-- Crisp naval salute, then shades eyes looking out at the horizon
			animTorso = baseTorso * CFrame.Angles(math.rad(4 * env), math.sin(u * math.pi) * math.rad(12), 0)
			headRot = CFrame.Angles(math.rad(6 * env), math.sin(elapsed * 3) * math.rad(18 * env), 0)
			rArmRot = CFrame.Angles(math.rad(135 * env), math.rad(-25 * env), math.rad(-35 * env))
			lArmRot = CFrame.Angles(math.rad(20 * env), 0, math.rad(-25 * env))
		elseif name == "Rider Rick" then
			-- Hype skater jump + double fist pump!
			local hop = math.abs(math.sin(elapsed * 9)) * 0.9 * env
			animTorso = baseTorso * CFrame.new(0, hop, 0) * CFrame.Angles(math.rad(-8 * env), math.sin(elapsed * 9) * math.rad(15 * env), 0)
			headRot = CFrame.Angles(math.sin(elapsed * 12) * math.rad(15 * env), 0, 0)
			rArmRot = CFrame.Angles(math.rad(145 * env) + math.sin(elapsed * 14) * math.rad(25 * env), 0, math.rad(15 * env))
			lArmRot = CFrame.Angles(math.rad(110 * env) - math.sin(elapsed * 14) * math.rad(25 * env), 0, math.rad(-15 * env))
			rLegRot = CFrame.Angles(math.rad(-30 * env), 0, 0)
			lLegRot = CFrame.Angles(math.rad(20 * env), 0, 0)
		elseif name == "Callahan" then
			-- Chef's kiss + polite theatrical bow!
			local kissPhase = math.clamp(1 - u * 2, 0, 1)
			local bowPhase = math.sin(math.clamp((u - 0.3) / 0.7, 0, 1) * math.pi)
			animTorso = baseTorso * CFrame.Angles(math.rad(-32 * bowPhase), 0, 0)
			headRot = CFrame.Angles(math.rad(15 * kissPhase - 15 * bowPhase), 0, 0)
			rArmRot = CFrame.Angles(math.rad(115 * kissPhase + 65 * bowPhase), math.rad(-30 * kissPhase), math.rad(40 * bowPhase))
			lArmRot = CFrame.Angles(math.rad(45 * bowPhase), 0, math.rad(-30 * bowPhase))
		elseif name == "Thirsty Terry" then
			-- Exhausted slump forward while fanning his parched face frantically
			animTorso = baseTorso * CFrame.new(0, -0.25 * env, 0) * CFrame.Angles(math.rad(-22 * env), 0, 0)
			headRot = CFrame.Angles(math.rad(18 * env), math.sin(elapsed * 18) * math.rad(10 * env), 0)
			rArmRot = CFrame.Angles(math.rad(110 * env), 0, math.sin(elapsed * 24) * math.rad(28 * env))
			lArmRot = CFrame.Angles(math.rad(35 * env), 0, math.rad(-10 * env))
			rLegRot = CFrame.Angles(math.rad(20 * env), 0, 0)
			lLegRot = CFrame.Angles(math.rad(20 * env), 0, 0)
		elseif name == "Sal" then
			-- Friendly two-handed wave goodbye with a cheerful hop
			local hop = math.abs(math.sin(elapsed * 7)) * 0.3 * env
			animTorso = baseTorso * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, math.sin(elapsed * 7) * math.rad(5 * env))
			headRot = CFrame.Angles(math.sin(elapsed * 10) * math.rad(10 * env), 0, math.sin(elapsed * 7) * math.rad(6 * env))
			rArmRot = CFrame.Angles(math.rad(155 * env), 0, math.rad(20 * env) + math.sin(elapsed * 16) * math.rad(22 * env))
			lArmRot = CFrame.Angles(math.rad(30 * env), 0, math.rad(-15 * env))
		elseif name == "Sensei" then
			-- Deep martial-arts bow, then crane stance!
			local bow = math.sin(math.clamp(u * 1.8, 0, 1) * math.pi)
			local crane = math.sin(math.clamp((u - 0.4) / 0.6, 0, 1) * math.pi)
			animTorso = baseTorso * CFrame.new(0, crane * 0.25, 0) * CFrame.Angles(math.rad(-38 * bow), 0, 0)
			headRot = CFrame.Angles(math.rad(-12 * bow + 8 * crane), 0, 0)
			rArmRot = CFrame.Angles(math.rad(75 * bow + 125 * crane), math.rad(-35 * bow), math.rad(60 * crane))
			lArmRot = CFrame.Angles(math.rad(75 * bow + 125 * crane), math.rad(35 * bow), math.rad(-60 * crane))
			rLegRot = CFrame.Angles(math.rad(55 * crane), 0, 0)
		elseif name == "Ms. Wheeler" then
			-- Encouraging teacher applause + proud nods
			animTorso = baseTorso * CFrame.Angles(math.sin(elapsed * 6) * math.rad(4 * env), 0, 0)
			headRot = CFrame.Angles(math.abs(math.sin(elapsed * 9)) * math.rad(-14 * env), 0, 0)
			local clap = math.abs(math.sin(elapsed * 15)) * 22
			rArmRot = CFrame.Angles(math.rad(85 * env), math.rad((-28 + clap) * env), math.rad(-20 * env))
			lArmRot = CFrame.Angles(math.rad(85 * env), math.rad((28 - clap) * env), math.rad(20 * env))
		else
			-- Pedestrian: confused head-scratch and nervously looking straight up at the sky for pianos!
			animTorso = baseTorso * CFrame.Angles(math.rad(10 * env), math.sin(elapsed * 5) * math.rad(14 * env), 0)
			headRot = CFrame.Angles(math.rad(38 * env), math.sin(elapsed * 6) * math.rad(20 * env), math.rad(8 * env))
			rArmRot = CFrame.Angles(math.rad(145 * env), math.rad(-20 * env), math.rad(-25 * env) + math.sin(elapsed * 16) * math.rad(12 * env))
			lArmRot = CFrame.Angles(math.rad(25 * env), 0, math.rad(-15 * env))
		end

		applyLimbsFromTorso(pose, animTorso, headRot, rArmRot, lArmRot, rLegRot, lLegRot)
	end)
end

local function startNPCAnimLoop()
	if npcAnimConn then return end
	local t0 = os.clock()
	npcAnimConn = RunService.RenderStepped:Connect(function(dt)
		local npc = currentCutsceneNPC
		local pose = npc and savedNPCJoints[npc]
		if not npc or not pose or npc:GetAttribute("PianoDropping") then return end
		local targetW = isNPCTalking and 1 or 0
		talkWeight = talkWeight + (targetW - talkWeight) * math.min(1, dt * 10)
		local t = os.clock() - t0
		local w = talkWeight
		local name = npc.Name
		local baseTorso = pose.torsoCF or (pose.headCF * CFrame.new(0, -1.5, 0))
		local animTorso = baseTorso
		local headRot, rArmRot, lArmRot, rLegRot, lLegRot = CFrame.new(), CFrame.new(), CFrame.new(), CFrame.new(), CFrame.new()

		if name == "Manager Bob" then
			-- Grumpy manager: crossed left arm, tapping right foot, head-shaking & shrugging right hand
			animTorso = baseTorso * CFrame.new(0, math.sin(t * 2) * 0.03, 0) * CFrame.Angles(math.rad(-3 * w), math.sin(t * 2.5) * math.rad(4 * w), math.rad(-2 * w))
			headRot = CFrame.Angles(math.sin(t * 6) * math.rad(3 * w), math.sin(t * 5.5) * math.rad(11 * w), math.rad(-4 * w))
			rArmRot = CFrame.Angles(math.rad(45 * w) + math.sin(t * 5) * math.rad(15 * w), 0, math.rad(18 * w))
			lArmRot = CFrame.Angles(math.rad(78 * w), math.rad(35 * w), math.rad(28 * w))
			rLegRot = CFrame.Angles(math.abs(math.sin(t * 10)) * math.rad(14 * w), 0, 0)
		elseif name == "Eggbert" then
			-- Conspiratorial & hyper: leans forward, rapid toe-bounces, both hands fluttering excitedly
			local bounce = math.abs(math.sin(t * 9)) * 0.14 * w
			animTorso = baseTorso * CFrame.new(0, bounce, 0) * CFrame.Angles(math.rad(-10 * w), math.sin(t * 4.5) * math.rad(8 * w), 0)
			headRot = CFrame.Angles(math.rad(8 * w) + math.sin(t * 11) * math.rad(6 * w), math.sin(t * 5) * math.rad(9 * w), math.cos(t * 6) * math.rad(5 * w))
			rArmRot = CFrame.Angles(math.rad(65 * w) + math.sin(t * 12) * math.rad(22 * w), 0, math.rad(15 * w))
			lArmRot = CFrame.Angles(math.rad(65 * w) + math.cos(t * 12) * math.rad(22 * w), 0, math.rad(-15 * w))
		elseif name == "Captain Finn" then
			-- Sea-captain swagger: rocks side-to-side on sea legs, left hand on hip, right arm casting a rod
			animTorso = baseTorso * CFrame.new(math.sin(t * 2.6) * 0.12 * w, 0, 0) * CFrame.Angles(math.rad(4 * w), math.sin(t * 2.6) * math.rad(6 * w), math.sin(t * 2.6) * math.rad(5 * w))
			headRot = CFrame.Angles(math.sin(t * 7) * math.rad(5 * w), math.cos(t * 2.6) * math.rad(8 * w), 0)
			rArmRot = CFrame.Angles(math.rad(55 * w) + math.sin(t * 4.5) * math.rad(30 * w), 0, math.rad(10 * w))
			lArmRot = CFrame.Angles(math.rad(28 * w), 0, math.rad(-32 * w))
			rLegRot = CFrame.Angles(0, 0, math.rad(6 * w))
			lLegRot = CFrame.Angles(0, 0, math.rad(-6 * w))
		elseif name == "Rider Rick" then
			-- Skater hype: rhythmic knee-bounce, alternating double fist-pumps & energetic head bobs
			local groove = math.abs(math.sin(t * 7.5)) * 0.12 * w
			animTorso = baseTorso * CFrame.new(0, -groove, 0) * CFrame.Angles(math.rad(-6 * w), math.sin(t * 3.75) * math.rad(10 * w), 0)
			headRot = CFrame.Angles(math.sin(t * 7.5) * math.rad(-9 * w), math.sin(t * 3.75) * math.rad(8 * w), 0)
			rArmRot = CFrame.Angles(math.rad(75 * w) + math.sin(t * 7.5) * math.rad(28 * w), 0, math.rad(12 * w))
			lArmRot = CFrame.Angles(math.rad(75 * w) - math.sin(t * 7.5) * math.rad(28 * w), 0, math.rad(-12 * w))
			rLegRot = CFrame.Angles(math.sin(t * 7.5) * math.rad(10 * w), 0, 0)
			lLegRot = CFrame.Angles(-math.sin(t * 7.5) * math.rad(10 * w), 0, 0)
		elseif name == "Callahan" then
			-- Cheerful ice-cream chef: warm sway, left hand holding imaginary cone, right hand flourishing
			animTorso = baseTorso * CFrame.new(0, math.sin(t * 3) * 0.05, 0) * CFrame.Angles(0, math.sin(t * 2.2) * math.rad(7 * w), math.cos(t * 2.2) * math.rad(4 * w))
			headRot = CFrame.Angles(math.sin(t * 8) * math.rad(5 * w), math.sin(t * 3.1) * math.rad(7 * w), math.sin(t * 2.2) * math.rad(5 * w))
			rArmRot = CFrame.Angles(math.rad(50 * w) + math.sin(t * 5.5) * math.rad(20 * w), math.cos(t * 5.5) * math.rad(18 * w), math.rad(22 * w))
			lArmRot = CFrame.Angles(math.rad(68 * w), math.rad(-18 * w), math.rad(-8 * w))
		elseif name == "Thirsty Terry" then
			-- Parched & desperate: shivering/trembling, clutching throat with left hand, reaching out with right
			local shiver = math.sin(t * 22) * math.rad(2.5 * w)
			animTorso = baseTorso * CFrame.new(0, -0.08 * w, 0) * CFrame.Angles(math.rad(-12 * w), shiver, shiver)
			headRot = CFrame.Angles(math.rad(10 * w) + math.sin(t * 9) * math.rad(6 * w), shiver * 2, math.sin(t * 4) * math.rad(8 * w))
			rArmRot = CFrame.Angles(math.rad(82 * w) + math.sin(t * 8) * math.rad(14 * w), 0, math.rad(6 * w))
			lArmRot = CFrame.Angles(math.rad(105 * w), math.rad(28 * w), math.rad(18 * w))
		elseif name == "Sal" then
			-- Chill cashier: casual side lean, left arm pointing toward the store shelves, right hand chatting
			animTorso = baseTorso * CFrame.Angles(0, math.rad(-8 * w) + math.sin(t * 2) * math.rad(4 * w), math.rad(3 * w))
			headRot = CFrame.Angles(math.sin(t * 7.5) * math.rad(5 * w), math.rad(8 * w) + math.sin(t * 3) * math.rad(5 * w), 0)
			rArmRot = CFrame.Angles(math.rad(38 * w) + math.sin(t * 6) * math.rad(14 * w), 0, math.rad(10 * w))
			lArmRot = CFrame.Angles(math.rad(72 * w), 0, math.rad(-38 * w) + math.sin(t * 4) * math.rad(10 * w))
		elseif name == "Sensei" then
			-- Martial arts master: disciplined fighting-stance turns and sharp karate-chop hand gestures
			animTorso = baseTorso * CFrame.Angles(math.rad(-4 * w), math.rad(16 * w) + math.sin(t * 3.5) * math.rad(6 * w), 0)
			headRot = CFrame.Angles(math.abs(math.sin(t * 7)) * math.rad(-8 * w), math.rad(-14 * w), 0)
			rArmRot = CFrame.Angles(math.rad(75 * w) + math.sin(t * 8) * math.rad(25 * w), math.rad(-15 * w), math.rad(12 * w))
			lArmRot = CFrame.Angles(math.rad(55 * w) - math.sin(t * 8) * math.rad(18 * w), math.rad(20 * w), math.rad(-12 * w))
		elseif name == "Ms. Wheeler" then
			-- Enthusiastic teacher: right hand raised pointing at the board, left hand gesturing to the student
			animTorso = baseTorso * CFrame.Angles(math.sin(t * 3) * math.rad(3 * w), math.sin(t * 2.2) * math.rad(6 * w), 0)
			headRot = CFrame.Angles(math.sin(t * 8.5) * math.rad(6 * w), math.sin(t * 3.2) * math.rad(8 * w), math.cos(t * 4) * math.rad(3 * w))
			rArmRot = CFrame.Angles(math.rad(115 * w) + math.sin(t * 6.5) * math.rad(14 * w), 0, math.rad(14 * w))
			lArmRot = CFrame.Angles(math.rad(42 * w) + math.cos(t * 5.5) * math.rad(12 * w), 0, math.rad(-14 * w))
		else
			-- Pedestrians: 3 distinct street personalities based on their world position
			local style = math.floor(math.abs(baseTorso.Position.X + baseTorso.Position.Z)) % 3
			if style == 0 then
				-- Sassy hip-sway with left hand on hip
				animTorso = baseTorso * CFrame.Angles(0, math.sin(t * 3) * math.rad(6 * w), math.rad(4 * w))
				headRot = CFrame.Angles(math.sin(t * 8) * math.rad(5 * w), math.sin(t * 3.5) * math.rad(8 * w), math.rad(-5 * w))
				rArmRot = CFrame.Angles(math.rad(48 * w) + math.sin(t * 7) * math.rad(18 * w), 0, math.rad(16 * w))
				lArmRot = CFrame.Angles(math.rad(25 * w), 0, math.rad(-28 * w))
			elseif style == 1 then
				-- Animated two-handed storyteller
				animTorso = baseTorso * CFrame.new(0, math.abs(math.sin(t * 5)) * 0.06 * w, 0) * CFrame.Angles(math.rad(-4 * w), math.sin(t * 2.8) * math.rad(7 * w), 0)
				headRot = CFrame.Angles(math.sin(t * 9) * math.rad(6 * w), math.cos(t * 4) * math.rad(9 * w), 0)
				rArmRot = CFrame.Angles(math.rad(62 * w) + math.sin(t * 6.5) * math.rad(20 * w), 0, math.rad(18 * w))
				lArmRot = CFrame.Angles(math.rad(58 * w) + math.cos(t * 6.5) * math.rad(20 * w), 0, math.rad(-18 * w))
			else
				-- Chill head-bobber with casual wave
				animTorso = baseTorso * CFrame.new(0, math.sin(t * 2.4) * 0.035, 0) * CFrame.Angles(math.sin(t * 2.4) * math.rad(1.5), math.sin(t * 1.7) * math.rad(4 * w), 0)
				headRot = CFrame.Angles(math.sin(t * 8.5) * math.rad(5 * w), math.sin(t * 3.4) * math.rad(6.5 * w), math.cos(t * 4.1) * math.rad(3 * w))
				rArmRot = CFrame.Angles(math.rad(36 * w) + math.sin(t * 6.2) * math.rad(14 * w), math.sin(t * 4.5) * math.rad(8 * w), math.rad(10 * w))
				lArmRot = CFrame.Angles(math.rad(16 * w) + math.cos(t * 5.4) * math.rad(9 * w), 0, math.rad(-6 * w))
			end
		end

		applyLimbsFromTorso(pose, animTorso, headRot, rArmRot, lArmRot, rLegRot, lLegRot)
	end)
end

-- While talking, the NPC turns to face you, so the camera's spot in front of its face is right
-- where you're standing: hide your own character (on your screen only) so it doesn't block the shot.
local function setLocalCharacterHidden(hidden)
	local char = plr.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function endCutscene()
	activeTypewriter = nil
	setLocalCharacterHidden(false)
	stopNPCAnimLoop()
	dlgFrame.Visible = false
	hotbar.Visible = true
	local finishedNPC = currentCutsceneNPC
	currentCutsceneNPC = nil
	if finishedNPC then
		local h = finishedNPC:FindFirstChild("Head")
		local tp = h and h:FindFirstChild("TalkPrompt")
		if tp then tp.Enabled = true end
		local hum = finishedNPC:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer end
		restoreNPCPose(finishedNPC)
		playPostTalkAnimation(finishedNPC)
	end
	TweenService:Create(topBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = 70 }):Play()
		cam.CameraType = Enum.CameraType.Custom
	end
end

local npcHomeCF = setmetatable({}, { __mode = "k" }) -- NPC torso CFrame before it ever turned to you

local function focusCameraOnNPC(npcModel, wideShot)
	local cam = workspace.CurrentCamera
	local head = npcModel and npcModel:FindFirstChild("Head")
	if not cam or not head then return end
	setLocalCharacterHidden(true)
	local tp = head:FindFirstChild("TalkPrompt")
	if tp then tp.Enabled = false end
	hotbar.Visible = false
	local hum = npcModel:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	ensureNPCFaceUI(npcModel)
	if postTalkConns[npcModel] then
		postTalkConns[npcModel]:Disconnect()
		postTalkConns[npcModel] = nil
		restoreNPCPose(npcModel)
	end
	-- turn to face the player (yaw only, about the torso so they stay on the spot). Only on this
	-- player's screen; the saved pose is re-captured below so the talk animation uses the new facing
	local torso0 = npcModel:FindFirstChild("Torso")
	local myRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if torso0 and not npcHomeCF[npcModel] then npcHomeCF[npcModel] = torso0.CFrame end
	if torso0 and myRoot and not npcModel:GetAttribute("PianoDropping") then
		local c = torso0.Position
		local dir = Vector3.new(myRoot.Position.X - c.X, 0, myRoot.Position.Z - c.Z)
		local f = torso0.CFrame.LookVector
		f = Vector3.new(f.X, 0, f.Z)
		if dir.Magnitude > 0.5 and f.Magnitude > 0.1 then
			dir, f = dir.Unit, f.Unit
			local ang = math.atan2(f:Cross(dir).Y, f:Dot(dir))
			if math.abs(ang) > math.rad(5) then
				npcModel:PivotTo(CFrame.new(c) * CFrame.Angles(0, ang, 0) * CFrame.new(-c) * npcModel:GetPivot())
				savedNPCJoints[npcModel] = nil
			end
		end
	end
	local torso = npcModel:FindFirstChild("Torso")
	local rArm = npcModel:FindFirstChild("Right Arm")
	local lArm = npcModel:FindFirstChild("Left Arm")
	local rLeg = npcModel:FindFirstChild("Right Leg")
	local lLeg = npcModel:FindFirstChild("Left Leg")
	local bodyParts = {
		[head] = true,
		[torso or head] = true,
		[rArm or head] = true,
		[lArm or head] = true,
		[rLeg or head] = true,
		[lLeg or head] = true,
	}
	if not savedNPCJoints[npcModel] then
		local accList = {}
		for _, desc in ipairs(npcModel:GetDescendants()) do
			if desc:IsA("BasePart") and not bodyParts[desc] then
				table.insert(accList, {
					part = desc,
					baseCF = desc.CFrame,
					relToHead = head.CFrame:ToObjectSpace(desc.CFrame),
				})
			end
		end
		savedNPCJoints[npcModel] = {
			torso = torso,
			torsoCF = torso and torso.CFrame,
			head = head,
			headCF = head.CFrame,
			rArm = rArm,
			rArmCF = rArm and rArm.CFrame,
			lArm = lArm,
			lArmCF = lArm and lArm.CFrame,
			rLeg = rLeg,
			rLegCF = rLeg and rLeg.CFrame,
			lLeg = lLeg,
			lLegCF = lLeg and lLeg.CFrame,
			accessories = accList,
		}
	else
		-- Refresh accessory list in case InsertService finished loading hats/hair after first check
		local pose = savedNPCJoints[npcModel]
		local known = {}
		for _, a in ipairs(pose.accessories) do known[a.part] = true end
		for _, desc in ipairs(npcModel:GetDescendants()) do
			if desc:IsA("BasePart") and not bodyParts[desc] and not known[desc] then
				table.insert(pose.accessories, {
					part = desc,
					baseCF = desc.CFrame,
					relToHead = pose.headCF:ToObjectSpace(desc.CFrame),
				})
			end
		end
	end
	currentCutsceneNPC = npcModel
	if not wideShot then
		startNPCAnimLoop()
	else
		stopNPCAnimLoop()
		restoreNPCPose(npcModel)
	end
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(topBar, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 48) }):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 48) }):Play()
	local baseHeadCF = savedNPCJoints[npcModel].headCF
	local targetCF
	local targetFOV = 50
	if wideShot then
		-- hit by a car: they walk ~12 studs out into the road (their original facing) and the car
		-- comes along it from their right, so watch from their left side, looking at the hit spot
		local home = npcHomeCF[npcModel] or baseHeadCF
		local lookTarget = (home * CFrame.new(0, 0, -9)).Position
		local camPos = (home * CFrame.new(-16, 7, -3)).Position
		targetCF = CFrame.lookAt(camPos, lookTarget)
		targetFOV = 65
	else
		local camPos = (baseHeadCF * CFrame.new(1.4, 0.3, -4.8)).Position
		local lookTarget = baseHeadCF.Position + Vector3.new(0, -0.35, 0)
		targetCF = CFrame.lookAt(camPos, lookTarget)
	end
	if cutsceneCamTween then cutsceneCamTween:Cancel() end
	cutsceneCamTween = TweenService:Create(cam, TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		CFrame = targetCF,
		FieldOfView = targetFOV,
	})
	cutsceneCamTween:Play()
end

local function showDialogue(npcName, text, choicesArray, callback)
	dlgFrame.Visible = true
	hotbar.Visible = false
	dlgName.Text = npcName
	dlgText.Text = ""
	for _, c in ipairs(choicesFrame:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	
	activeTypewriter = tick()
	local myType = activeTypewriter
	
	local blip = Instance.new("Sound")
	blip.SoundId = "rbxassetid://12221967" -- reliable UI tick
	blip.Volume = 1
	blip.Parent = game:GetService("SoundService")
	-- 3D overhead chat bubble omitted so it never overlaps the dialogue text or NPC face during cutscenes
	
	task.spawn(function()
		for i = 1, #text do
			if activeTypewriter ~= myType then return end
			dlgText.Text = string.sub(text, 1, i)
			isNPCTalking = true
			local char = string.sub(text, i, i)
			if i % 2 == 1 and char ~= " " and char ~= "." then
				local s = blip:Clone()
				s.Parent = game:GetService("SoundService")
				s:Play()
				game.Debris:AddItem(s, 0.5)
			end
			task.wait(0.02)
		end
		
		isNPCTalking = false
		for _, ch in ipairs(choicesArray) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 160, 0, 36)
			btn.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Font = Enum.Font.LuckiestGuy
			btn.TextSize = 14
			btn.ZIndex = 13
			btn.Text = ch.text
			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 8)
			cCorner.Parent = btn
			btn.Parent = choicesFrame
			
			btn.Activated:Connect(function()
				dlgFrame.Visible = false
	hotbar.Visible = true
				if currentCutsceneNPC then setNPCFaceState(currentCutsceneNPC, "answer") end
				if callback then callback(ch.id) end
				if not dlgFrame.Visible then endCutscene() end
			end)
		end
		
		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 100, 0, 36)
		closeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
		closeBtn.TextColor3 = Color3.new(1, 1, 1)
		closeBtn.Font = Enum.Font.LuckiestGuy
		closeBtn.TextSize = 14
		closeBtn.ZIndex = 13
		closeBtn.Text = "Leave"
		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 8)
		cCorner.Parent = closeBtn
		closeBtn.Parent = choicesFrame
		closeBtn.Activated:Connect(function() endCutscene() end)
	end)
end

local function playTerrySodaCutscene(npcModel)
	if not npcModel then return end
	setLocalCharacterHidden(false)
	stopNPCAnimLoop()
	local pose = savedNPCJoints[npcModel]
	if not pose then return end

	inTerryCutscene = true
	questCompleted = true

	-- Dismount scooter if riding so the player walks up on foot
	if plr:GetAttribute("Mounted") then
		plr:SetAttribute("Mounted", false)
		ToggleScooter:FireServer()
	end

	local controls
	pcall(function()
		controls = require(plr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		controls:Disable()
	end)

	local baseTorso = pose.torsoCF or (pose.headCF * CFrame.new(0, -1.5, 0))
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
		if cutsceneCamTween then cutsceneCamTween:Cancel() end
		-- Full-body 3/4 wide shot so the player's entire body and legs are clearly visible walking up!
		local wideCamPos = (baseTorso * CFrame.new(7.6, 1.6, -5.8)).Position
		local wideLook = (baseTorso * CFrame.new(0, -0.35, -5.4)).Position
		cam.CFrame = CFrame.lookAt(wideCamPos, wideLook)
		cam.FieldOfView = 60
	end

	-- Create a 3D green Soda Can prop for the handoff
	local sodaCan = Instance.new("Part")
	sodaCan.Name = "CutsceneSodaCan"
	sodaCan.Shape = Enum.PartType.Cylinder
	sodaCan.Size = Vector3.new(1.45, 0.9, 0.9)
	sodaCan.Color = Color3.fromRGB(50, 215, 65)
	sodaCan.Material = Enum.Material.SmoothPlastic
	sodaCan.Anchored = true
	sodaCan.CanCollide = false
	sodaCan.Parent = workspace

	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animateScript = char and char:FindFirstChild("Animate")
	local origAnimateDisabled = animateScript and animateScript.Disabled or false
	if animateScript and animateScript:IsA("LocalScript") then
		animateScript.Disabled = true
	end

	-- Immediately remove scooter IK controls & hide scooter on client so arms/legs are 100% free
	if char then
		local sc = char:FindFirstChild("Scooter")
		if sc then
			for _, p in ipairs(sc:GetDescendants()) do
				if p:IsA("BasePart") then p.Transparency = 1 end
			end
		end
	end
	local origWalkSpeed = hum and hum.WalkSpeed or 16
	local origJumpPower = hum and hum.JumpPower or 50
	if hum then
		for _, ikName in ipairs({ "LeftHandGrip", "RightHandGrip" }) do
			local ik = hum:FindFirstChild(ikName)
			if ik then ik:Destroy() end
		end
		local origHip = char and char:GetAttribute("ScooterOrigHip")
		if origHip then hum.HipHeight = origHip end
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	-- Save upright standing base C0 for any joint on the character
	local pBaseC0 = {}
	local function getStandC0(m)
		if not m then return CFrame.new() end
		local walkAttr = m:GetAttribute("WalkOrigC0")
		if walkAttr then
			pBaseC0[m] = walkAttr
			return walkAttr
		end
		if not pBaseC0[m] then
			pBaseC0[m] = m.C0
		end
		return pBaseC0[m]
	end
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") or d.Name == "LeftArmGrip" or d.Name == "RightArmGrip" then
				getStandC0(d)
			end
		end
	end

	-- Place HumanoidRootPart ONCE at the target handshake spot with Anchored = false!
	-- Moving the character backward/forward via Root.C0 (instead of teleporting hrp.CFrame every frame)
	-- keeps Roblox's Motor6D solver 100% active at 60fps just like our Scooter Trick Animator!
	local floorY = baseTorso.Position.Y - 3.0
	local origHip = (char and char:GetAttribute("ScooterOrigHip")) or (hum and hum.HipHeight) or 2.0
	local pRootH = math.max(origHip + (hrp and hrp.Size.Y / 2 or 1.0), 3.0)
	local endSpot = (baseTorso * CFrame.new(0, 0, -2.85)).Position
	local playerEndCF = CFrame.new(endSpot.X, floorY + pRootH, endSpot.Z) * baseTorso.Rotation * CFrame.Angles(0, math.pi, 0)
	local WALK_DIST = 8.0
	local WALK_TIME = 2.2
	-- HumanoidRootPart is anchored and glided toward Terry each frame (no physics shoves),
	-- while a REAL Roblox walk AnimationTrack plays on the Animator (animations still play on anchored rigs)
	local origAnchored = hrp and hrp.Anchored or false
	if hrp then
		hrp.Anchored = true
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = playerEndCF * CFrame.new(0, 0, WALK_DIST)
	end
	-- Reset every joint to its upright on-foot pose so no scooter stance survives into the walk
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") then
				-- guarded: some joints refuse C0 writes, which would abort the cutscene mid-setup
				pcall(function() d.C0 = getStandC0(d) end)
				d.Transform = CFrame.new()
			end
		end
	end

	-- Load the player's walk animation (their avatar's own walk if available, else the stock Roblox walk)
	local walkTrack
	local animatorObj = hum and hum:FindFirstChildOfClass("Animator")
	if hum and not animatorObj then
		animatorObj = Instance.new("Animator")
		animatorObj.Parent = hum
	end
	if animatorObj then
		local isR15 = hum.RigType == Enum.HumanoidRigType.R15
		local walkId = isR15 and "rbxassetid://507777826" or "rbxassetid://180426354"
		pcall(function()
			local walkFolder = animateScript and animateScript:FindFirstChild("walk")
			local wa = walkFolder and walkFolder:FindFirstChildWhichIsA("Animation")
			local id = wa and wa.AnimationId or ""
			-- skip the scooter "glide" (standing idle) id the server swaps in while riding
			if id ~= "" and not string.find(id, "507766666") and not string.find(id, "180435571") then
				walkId = id
			end
		end)
		local anim = Instance.new("Animation")
		anim.AnimationId = walkId
		pcall(function()
			walkTrack = animatorObj:LoadAnimation(anim)
			walkTrack.Priority = Enum.AnimationPriority.Action
			walkTrack.Looped = true
		end)
	end
	local walkStopped = false

	setNPCFaceState(npcModel, "interact")
	activeTypewriter = nil
	-- Keep dialogue box hidden during the walk-up so the bottom of the screen doesn't cover the walking legs!
	dlgFrame.Visible = false
	hotbar.Visible = false
	dlgName.Text = "Thirsty Terry"
	dlgText.Text = "Wait... is that my soda?! Hand it over, kid!"
	for _, c in ipairs(choicesFrame:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	local rewarded = false
	local camZoomed = false
	local dlgShown = false
	local sodaPopPlayed = false
	local dur = 5.4
	local t0 = os.clock()
	local cutRenderConn, cutStepConn

	local function updateCutsceneFrame()
		local elapsed = os.clock() - t0
		if elapsed >= dur or not npcModel.Parent then
			if cutRenderConn then cutRenderConn:Disconnect(); cutRenderConn = nil end
			if cutStepConn then cutStepConn:Disconnect(); cutStepConn = nil end
			inTerryCutscene = false
			if sodaCan and sodaCan.Parent then
				sodaCan:Destroy()
			end
			if char then
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("Motor6D") then
						local stand = d:GetAttribute("WalkOrigC0") or pBaseC0[d]
						if stand then pcall(function() d.C0 = stand end) end
						d.Transform = CFrame.new()
					elseif d:IsA("AnimationConstraint") then
						d.Transform = CFrame.new()
					end
				end
			end
			if animateScript and animateScript.Parent then
				animateScript.Disabled = origAnimateDisabled
			end
			if walkTrack then
				pcall(function() walkTrack:Stop(0); walkTrack:Destroy() end)
				walkTrack = nil
			end
			if hrp and hrp.Parent then
				hrp.CFrame = playerEndCF
				hrp.Anchored = origAnchored
			end
			if hum and hum.Parent then
				hum.WalkSpeed = origWalkSpeed
				hum.JumpPower = origJumpPower
			end
			pcall(function()
				if controls then controls:Enable() end
			end)
			if not rewarded then
				rewarded = true
				remotes:WaitForChild("CompleteQuest"):FireServer("TerrysSoda")
			end
			endCutscene()
			return
		end

		if char then
			local sc = char:FindFirstChild("Scooter")
			if sc then
				for _, p in ipairs(sc:GetDescendants()) do
					if p:IsA("BasePart") then p.Transparency = 1 end
				end
			end
		end
		local walking = elapsed < WALK_TIME
		if hum then
			for _, ikName in ipairs({ "LeftHandGrip", "RightHandGrip" }) do
				local ik = hum:FindFirstChild(ikName)
				if ik then ik:Destroy() end
			end
			local animator = hum:FindFirstChildOfClass("Animator")
			if animator then
				-- Stop every other track (scooter glide/idle) but keep our walk track alive while walking
				for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
					if tr ~= walkTrack then
						tr:Stop(0)
					end
				end
			end
		end

		-- Stage 1 (0.0 - 2.2s): Player WALKS 8 studs up to Terry with a real Roblox walk animation & holds out soda
		-- Stage 2 (2.2 - 3.5s): Player leans in & extends right arm to hand the soda into Terry's left hand
		-- Stage 3 (3.5 - 5.4s): Player & Terry clasp right hands and pump them up and down!
		local walkAlpha = math.clamp(elapsed / WALK_TIME, 0, 1)
		local smoothWalk = 1 - math.pow(1 - walkAlpha, 1.6)
		local walkBack = (1 - smoothWalk) * WALK_DIST
		-- current walking speed (studs/s) so the leg cycle matches the ground speed (no moonwalking)
		local walkVel = WALK_DIST * 1.6 * math.pow(math.max(1 - walkAlpha, 0), 0.6) / WALK_TIME

		if walkTrack then
			if walking then
				if not walkTrack.IsPlaying then
					walkTrack:Play(0.1)
				end
				walkTrack:AdjustSpeed(math.clamp(walkVel / 6.5, 0.45, 1.4))
			elseif not walkStopped then
				walkStopped = true
				walkTrack:Stop(0.2)
			end
		end

		if hrp and hrp.Parent then
			hrp.CFrame = playerEndCF * CFrame.new(0, 0, walkBack)
		end

		if elapsed < 2.0 and cam and not camZoomed then
			-- Full-body side camera that tracks the midpoint between the player and Terry
			local midZ = -(2.85 + walkBack) * 0.5
			local wideCamPos = (baseTorso * CFrame.new(8.6, 1.4, midZ)).Position
			local wideLook = (baseTorso * CFrame.new(0, -0.6, midZ)).Position
			cam.CFrame = CFrame.lookAt(wideCamPos, wideLook)
		end

		if elapsed >= 2.0 and not dlgShown then
			dlgShown = true
			dlgFrame.Visible = true
			npcTalkUntil = os.clock() + 0.8
		end

		if elapsed >= 2.0 and not camZoomed and cam then
			camZoomed = true
			local closeCamPos = (baseTorso * CFrame.new(4.6, 1.0, -1.55)).Position
			local closeLook = (baseTorso * CFrame.new(0, 0.25, -1.42)).Position
			TweenService:Create(cam, TweenInfo.new(0.65, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(closeCamPos, closeLook),
				FieldOfView = 48,
			}):Play()
		end

		if elapsed >= 2.85 and not sodaPopPlayed then
			sodaPopPlayed = true
			setNPCFaceState(npcModel, "answer")
			pcall(playSound, "rbxassetid://9061556942", 0.5)
			dlgText.Text = "You found it!! Thank you so much — deal's a deal, here's $200!"
			npcTalkUntil = os.clock() + 1.4
		end

		if elapsed >= 3.6 and not rewarded then
			rewarded = true
			remotes:WaitForChild("CompleteQuest"):FireServer("TerrysSoda")
		end

		local pRShoulderPitch, pRShoulderYaw, pRElbowPitch = 0, 0, 0
		local pLShoulderPitch, pLElbowPitch = 0, 0
		local pRHipPitch, pRKneePitch, pLHipPitch, pLKneePitch = 0, 0, 0, 0
		local pHeadPitch, pWaistPitch, pWaistYaw, bobY = 0, 0, 0, 0

		local tHeadRot = CFrame.new()
		local tRArmRot = CFrame.new()
		local tLArmRot = CFrame.new()
		local tRLegRot = CFrame.new()
		local tLLegRot = CFrame.new()
		local tTorsoCF = baseTorso

		if elapsed < 2.2 then
			-- ACT 1: Walk-up. Legs, hips, torso bob & left-arm swing come from the real walk AnimationTrack;
			-- we only raise the right arm (layered on top via C0) so the player carries the soda out in front.
			if not walkTrack then
				-- Fallback procedural stride if the walk animation failed to load
				local phase = elapsed * 12.8
				local s = math.sin(phase)
				local c = math.cos(phase)
				local fadeStop = math.clamp((2.2 - elapsed) / 0.25, 0, 1)
				bobY = math.abs(c) * 0.28 * fadeStop
				pWaistYaw = s * math.rad(12 * fadeStop)
				pRHipPitch = s * math.rad(52 * fadeStop)
				pLHipPitch = -s * math.rad(52 * fadeStop)
				pRKneePitch = -math.clamp(0.45 + 0.55 * c, 0, 1.25) * math.rad(68 * fadeStop)
				pLKneePitch = -math.clamp(0.45 - 0.55 * c, 0, 1.25) * math.rad(68 * fadeStop)
				pLShoulderPitch = -s * math.rad(46 * fadeStop)
			end
			pRShoulderPitch = math.rad(66)
			pRElbowPitch = math.rad(34)

			local tBounce = math.abs(math.sin(elapsed * 10)) * 0.14
			tTorsoCF = baseTorso * CFrame.new(0, tBounce, 0) * CFrame.Angles(math.rad(-6), 0, 0)
			tHeadRot = CFrame.Angles(math.rad(8), 0, 0)
			tLArmRot = CFrame.Angles(math.rad(45), 0, math.rad(-12))
			tRArmRot = CFrame.Angles(math.rad(35), 0, math.rad(12))
		elseif elapsed < 3.5 then
			-- ACT 2: Custom Soda Handover Animation (player leans in & extends right arm to hand soda to Terry's left hand)
			local u = (elapsed - 2.2) / 1.3
			local reach = math.sin(u * math.pi)
			pWaistPitch = math.rad(-12 * reach)
			pHeadPitch = math.rad(-8 * reach)
			pRShoulderPitch = math.rad(66 + 34 * reach)
			-- straight ahead: the player's right hand is directly in front of Terry's left hand
			pRShoulderYaw = 0
			pRElbowPitch = math.rad(34 - 26 * reach)
			pLShoulderPitch = math.rad(12 * reach)

			local terryTake = math.clamp(u * 1.4, 0, 1)
			tTorsoCF = baseTorso * CFrame.Angles(math.rad(-6 * (1 - u)), 0, 0)
			tHeadRot = CFrame.Angles(math.rad(-12 * math.sin(u * math.pi * 2)), 0, 0)
			-- Terry's left arm reaches out to take the soda, then pulls it back to hold at his side
			tLArmRot = CFrame.Angles(math.rad(88 * (1 - 0.38 * math.clamp((u - 0.45) * 1.8, 0, 1)) * terryTake), 0, math.rad(16 * (1 - u)))
			tRArmRot = CFrame.Angles(math.rad(25 * u), 0, math.rad(8))
		else
			-- ACT 3: Custom Handshake Animation (both extend right arms and pump up and down together!)
			local u = (elapsed - 3.5) / (dur - 3.5)
			local claspEnv = math.sin(math.clamp(u * 3.5, 0, 1) * math.pi * 0.5) * math.clamp((1 - u) * 3.5, 0, 1)
			local pump = math.sin((elapsed - 3.55) * 18) * math.rad(24) * claspEnv

			pWaistPitch = math.rad(-6 * claspEnv)
			pHeadPitch = math.sin((elapsed - 3.5) * 14) * math.rad(10 * claspEnv)
			-- Facing each other, the two RIGHT hands sit on opposite sides, so both arms angle in
			-- toward the centre line to meet (otherwise the player's right hand hits Terry's left)
			pRShoulderPitch = math.rad(70 * claspEnv) + pump
			pRShoulderYaw = math.rad(42 * claspEnv)
			pRElbowPitch = math.rad(20 * claspEnv) + pump * 0.45
			pLShoulderPitch = math.rad(12 * claspEnv)

			tTorsoCF = baseTorso * CFrame.Angles(math.rad(-6 * claspEnv), 0, 0)
			tHeadRot = CFrame.Angles(math.sin((elapsed - 3.5) * 14) * math.rad(-12 * claspEnv), 0, 0)
			-- Terry holds the soda can in his left hand while shaking with his right hand!
			tLArmRot = CFrame.Angles(math.rad(55), math.rad(-15), math.rad(-12))
			-- yaw applied after the pitch so the raised arm swings inward toward the player's right hand
			tRArmRot = CFrame.Angles(0, math.rad(46 * claspEnv), 0) * CFrame.Angles(math.rad(72 * claspEnv) + pump, 0, 0)
		end

		if char then
			-- Joints may be Motor6D (classic) OR AnimationConstraint (Avatar Joint Upgrade rigs).
			-- AnimationConstraint.C0 is READ-ONLY (writing it throws), so we pose every joint through
			-- .Transform, which both joint types support and which renders on top of C0.
			local function isJoint(j)
				return j ~= nil and (j:IsA("Motor6D") or j:IsA("AnimationConstraint"))
			end
			local function findJoint(part, name)
				local j = part and part:FindFirstChild(name)
				if isJoint(j) then return j end
				return nil
			end
			local function setT(j, cf)
				if j then
					pcall(function() j.Transform = cf end)
				end
			end

			local walkTrackActive = walkTrack ~= nil and elapsed < WALK_TIME + 0.25

			local lowerTorso = char:FindFirstChild("LowerTorso")
			local upperTorso = char:FindFirstChild("UpperTorso")
			local torso = char:FindFirstChild("Torso")
			local head = char:FindFirstChild("Head")

			local rootM = findJoint(lowerTorso, "Root") or findJoint(hrp, "RootJoint")
			local waistM = findJoint(upperTorso, "Waist")
			local neckM = findJoint(head, "Neck") or findJoint(torso, "Neck")

			local rShoulder = findJoint(char:FindFirstChild("RightUpperArm"), "RightShoulder")
			local rElbow = findJoint(char:FindFirstChild("RightLowerArm"), "RightElbow")
			local rWrist = findJoint(char:FindFirstChild("RightHand"), "RightWrist")
			local lShoulder = findJoint(char:FindFirstChild("LeftUpperArm"), "LeftShoulder")
			local lElbow = findJoint(char:FindFirstChild("LeftLowerArm"), "LeftElbow")
			local rHip = findJoint(char:FindFirstChild("RightUpperLeg"), "RightHip")
			local rKnee = findJoint(char:FindFirstChild("RightLowerLeg"), "RightKnee")
			local lHip = findJoint(char:FindFirstChild("LeftUpperLeg"), "LeftHip")
			local lKnee = findJoint(char:FindFirstChild("LeftLowerLeg"), "LeftKnee")

			if walkTrackActive then
				-- Real walk animation drives legs/torso/left arm; we only hold the soda out with the right arm
				setT(rShoulder, CFrame.Angles(pRShoulderPitch, pRShoulderYaw, 0))
				setT(rElbow, CFrame.Angles(pRElbowPitch, 0, 0))
			else
				-- Clear any leftover animation on every joint, then apply our handover / handshake pose
				for _, d in ipairs(char:GetDescendants()) do
					if isJoint(d) then
						d.Transform = CFrame.new()
					end
				end
				setT(rootM, CFrame.new(0, bobY, 0))
				setT(waistM, CFrame.Angles(pWaistPitch, pWaistYaw, 0))
				if upperTorso then setT(neckM, CFrame.Angles(pHeadPitch, 0, 0)) end
				-- yaw must be applied AFTER the pitch (on the raised arm), or it just spins the hanging arm in place
				setT(rShoulder, CFrame.Angles(0, pRShoulderYaw, 0) * CFrame.Angles(pRShoulderPitch, 0, 0))
				setT(rElbow, CFrame.Angles(pRElbowPitch, 0, 0))
				setT(rWrist, CFrame.Angles(pRElbowPitch * -0.3, 0, 0))
				setT(lShoulder, CFrame.Angles(pLShoulderPitch, 0, 0))
				setT(lElbow, CFrame.Angles(pLElbowPitch, 0, 0))
				setT(rHip, CFrame.Angles(pRHipPitch, 0, 0))
				setT(rKnee, CFrame.Angles(pRKneePitch, 0, 0))
				setT(lHip, CFrame.Angles(pLHipPitch, 0, 0))
				setT(lKnee, CFrame.Angles(pLKneePitch, 0, 0))
			end

			-- R6 rig support (Motor6D "Right Shoulder" etc. and the scooter Weld "RightArmGrip")
			if torso then
				local rs6 = findJoint(torso, "Right Shoulder")
				local ls6 = findJoint(torso, "Left Shoulder")
				local rh6 = findJoint(torso, "Right Hip")
				local lh6 = findJoint(torso, "Left Hip")
				local rag = torso:FindFirstChild("RightArmGrip")
				local lag = torso:FindFirstChild("LeftArmGrip")
				setT(rs6, CFrame.Angles(0, pRShoulderYaw, pRShoulderPitch))
				if not walkTrackActive then
					setT(ls6, CFrame.Angles(0, 0, -pLShoulderPitch))
					setT(rh6, CFrame.Angles(0, 0, pRHipPitch))
					setT(lh6, CFrame.Angles(0, 0, -pLHipPitch))
				end
				if rag and rag:IsA("Weld") then rag.C0 = CFrame.new(1.4, 0.25, -0.75) * CFrame.Angles(pRShoulderPitch, pRShoulderYaw, 0) end
				if lag and lag:IsA("Weld") then lag.C0 = CFrame.new(-1.4, 0.25, -0.35) * CFrame.Angles(pLShoulderPitch, 0, 0) end
			end
		end

		applyLimbsFromTorso(pose, tTorsoCF, tHeadRot, tRArmRot, tLArmRot, tRLegRot, tLLegRot)

		-- Position the 3D Soda Can: in player's right hand until 2.6s, then smoothly handed into Terry's left hand!
		if sodaCan and sodaCan.Parent then
			local rHand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
			local pHandCF = rHand and (rHand.CFrame * CFrame.new(0, -0.35, -0.35)) or (playerEndCF * CFrame.new(1.2, 0.2, walkBack - 1.6))
			local tHandCF = pose.lArm and (pose.lArm.CFrame * CFrame.new(0, -1.0, -0.3)) or (baseTorso * CFrame.new(-1.5, 0, -1.2))
			local transferAlpha = math.clamp((elapsed - 2.6) / 0.38, 0, 1)
			local canCF = pHandCF:Lerp(tHandCF, transferAlpha) * CFrame.Angles(0, 0, math.rad(90))
			sodaCan.CFrame = canCF
		end
	end

	-- Connect to BOTH RenderStepped AND Stepped (PreSimulation, which runs AFTER Animator & IKControl!)
	cutRenderConn = RunService.RenderStepped:Connect(updateCutsceneFrame)
	cutStepConn = RunService.Stepped:Connect(updateCutsceneFrame)
end

-- NPC jobs (the server tracks progress in QuestState_<id> / QuestProgress_<id> player attributes)
local NPC_QUESTS = {
	["Captain Finn"] = { id = "FinnFish", reward = 150,
		offer = "Me nets are empty, matey! Catch me 5 fish - any kind - and there's $150 in it for ye.",
		again = "Back for more? Another 5 fish, another $150. Deal?",
		accept = "Aye! Any water in the bay will do. Don't forget yer bait!",
		progress = "How's the fishin'? That's %d of 5 so far.",
		ready = "FIVE fish! Ye've got sea legs after all. Here's yer $150!" },
	["Rider Rick"] = { id = "RickTricks", reward = 200,
		offer = "Think you can ride? Land 15 tricks and I'll pay you $200. Any tricks count.",
		again = "Again? 15 more tricks, $200 more. Let's see it.",
		accept = "Go shred. Z X C V B, or T for a random one.",
		progress = "You're at %d of 15 tricks. Keep shredding!",
		ready = "Fifteen tricks! You're a natural. $200, as promised." },
	["Sensei"] = { id = "SenseiMat", reward = 250,
		offer = "Win my mat challenge three times and you will earn $250. Discipline pays.",
		again = "Your training continues. Three more victories, $250 more.",
		accept = "Step on the grey mat when you are ready.",
		progress = "%d of 3 victories. Focus.",
		ready = "Three victories. You honour this dojo. Take your $250." },
	["Eggbert"] = { id = "EggbertEggs", reward = 120,
		offer = "Help my research! Hatch 3 mystery eggs and I'll pay you $120. Science!",
		again = "More data needed! Hatch 3 more eggs for another $120.",
		accept = "Excellent. Remember - pups need a rented house first!",
		progress = "%d of 3 eggs hatched. The science is going GREAT.",
		ready = "Three hatchlings! The data is beautiful. Here's $120!" },
}
local QuestAction = remotes:WaitForChild("QuestAction", 10)

-- puts the job option at the top of an NPC's choices (label depends on where the job is at)
local function withQuestChoice(npcName, choices)
	local q = NPC_QUESTS[npcName]
	if not q or not QuestAction then return choices end
	local state = plr:GetAttribute("QuestState_" .. q.id)
	local label = (state == "ready") and ("Claim $" .. q.reward .. "!") or (state == "active") and "My job?" or "Got a job?"
	table.insert(choices, 1, { id = "quest", text = label })
	return choices
end

local function handleQuestChoice(npcName)
	local q = NPC_QUESTS[npcName]
	local state = plr:GetAttribute("QuestState_" .. q.id)
	if state == "ready" then
		QuestAction:FireServer(q.id, "claim")
		showDialogue(npcName, q.ready, {}, nil)
	elseif state == "active" then
		showDialogue(npcName, string.format(q.progress, plr:GetAttribute("QuestProgress_" .. q.id) or 0), {}, nil)
	else
		showDialogue(npcName, state == "done" and q.again or q.offer, {
			{ id = "accept", text = "I'm on it!" },
			{ id = "no", text = "Maybe later." },
		}, function(choiceId)
			if choiceId == "accept" then
				QuestAction:FireServer(q.id, "accept")
				showDialogue(npcName, q.accept, {}, nil)
			end
		end)
	end
end

local function hookNPC(prompt)
	local npcName = prompt.ObjectText
	task.spawn(function()
		local npcModel = prompt.Parent and prompt.Parent.Parent
		if not npcModel then return end
		if npcModel.Name == "Thirsty Terry" then
			local tTorso = npcModel:FindFirstChild("Torso")
			local kioskBack = npcModel.Parent and npcModel.Parent:FindFirstChild("KioskBack")
			if tTorso and kioskBack then
				local toWall = (kioskBack.Position - tTorso.Position).Unit
				if tTorso.CFrame.LookVector:Dot(toWall) > 0.2 then
					npcModel:PivotTo(npcModel:GetPivot() * CFrame.Angles(0, math.pi, 0))
				end
			end
		end
		setNPCFaceState(npcModel, "idle")
		local folder = remotes:WaitForChild("ClassicFaces", 10)
		local map = NPC_CLASSIC_FACE_MAP[npcModel.Name] or NPC_CLASSIC_FACE_MAP["Pedestrian"]
		local sv = folder and folder:WaitForChild(map.idle or "Smile", 10)
		if sv then
			if currentCutsceneNPC ~= npcModel then setNPCFaceState(npcModel, "idle") end
			sv.Changed:Connect(function()
				if currentCutsceneNPC ~= npcModel then setNPCFaceState(npcModel, "idle") end
			end)
		end
	end)
	prompt.Triggered:Connect(function()
		local npcModel = prompt.Parent and prompt.Parent.Parent
		focusCameraOnNPC(npcModel, false)
		setNPCFaceState(npcModel, "interact")
		if npcName == "Manager Bob" then
			showDialogue("Manager Bob", "Welcome to the empty void of Bloxway. We sold the aisles. What do you want?", {
				{ id = "Pizza Slice", text = "Buy Pizza ($20)" },
				{ id = "Energy Drink", text = "Buy Energy Drink ($15)" },
				{ id = "Burrito", text = "Buy Burrito ($25)" },
			}, function(choiceId)
				remotes:WaitForChild("BuyCustomItem"):FireServer(choiceId)
			end)
		elseif npcName == "Eggbert" then
			showDialogue("Eggbert", "Psst! Mystery dogs in these eggs. Mostly Mary or Jolene... but one in a HUNDRED hatches Linus. Rent a house first - pups need a home!", withQuestChoice("Eggbert", {
				{ id = "linus", text = "Who's Linus?" }
			}), function(choiceId)
				if choiceId == "quest" then
					handleQuestChoice("Eggbert")
				elseif choiceId == "linus" then
					showDialogue("Eggbert", "A golden legend. Pays $100 a pet. I saw him hatch once. Changed my whole life.", {}, nil)
				end
			end)
		elseif npcName == "Captain Finn" then
			showDialogue("Captain Finn", "Ahoy! Grab a rod, grab bait, and cast into ANY water in the bay. When the bobber glows - REEL! I buy every fish in your inventory.", withQuestChoice("Captain Finn", {
				{ id = "secret", text = "Any secret fish?" }
			}), function(choiceId)
				if choiceId == "quest" then
					handleQuestChoice("Captain Finn")
				elseif choiceId == "secret" then
					showDialogue("Captain Finn", "They whisper of THE LIONEL. One cast in a hundred. Worth five hundred bucks. Never landed it myself... yet.", {}, nil)
				end
			end)
		elseif npcName == "Rider Rick" then
			showDialogue("Rider Rick", "Looking to upgrade? The Fast Scooter bumps your base speed up by 20. And yes, it stacks with the Speed Pass. Pure adrenaline.", withQuestChoice("Rider Rick", {
				{ id = "gold", text = "Why gold?" }
			}), function(choiceId)
				if choiceId == "quest" then
					handleQuestChoice("Rider Rick")
				elseif choiceId == "gold" then
					showDialogue("Rider Rick", "Because you want everyone to know you're rich and fast. Mostly fast.", {}, nil)
				end
			end)
		elseif npcName == "Callahan" then
			showDialogue("Callahan", "Welcome to Callahan's Coffee and Cones! Chocolate makes your legs faster, Vanilla feeds your scooter, and Mint... Mint DOUBLES your trick money!", {
				{ id = "which", text = "Which one should I get?" }
			}, function(choiceId)
				if choiceId == "which" then
					showDialogue("Callahan", "Mint, if you can afford it. I've watched kids earn it back in one lap around Willow Lake.", {}, nil)
				end
			end)
		elseif npcName == "Thirsty Terry" then
			if questCompleted or plr:GetAttribute("TerryQuestCompleted") then
				setNPCFaceState(npcModel, "answer")
				showDialogue("Thirsty Terry", "Thanks again for finding my soda, kid! Best drink I've had all week!", {}, nil)
			elseif not questActive and not questFound then
				showDialogue("Thirsty Terry", "Hey kid... I lost my soda at the school... I'm so thirsty! I'll give you $200 if you find it in 2 minutes!", {
					{ id = "yes", text = "I'll find it!" },
					{ id = "no", text = "Too busy." }
				}, function(choiceId)
					if choiceId == "yes" then
						showDialogue("Thirsty Terry", "Hurry! It's at Discovery Bay Elementary!", {}, nil)
						startQuest()
					end
				end)
			elseif questActive and not questFound then
				showDialogue("Thirsty Terry", "Hurry up! The soda is at the school!", {}, nil)
			elseif questFound then
				questActive = false
				questFound = false
				questCompleted = true
				questFrame.Visible = false
				playTerrySodaCutscene(npcModel)
			end
		elseif npcName == "Sal" then
			showDialogue("Sal", "Welcome to ShellBlox! Fuel for cars, Bloxy Cola for scooters - every can makes that scooter a little quicker. Stacks five times!", {
				{ id = "else", text = "Anything else?" }
			}, function(choiceId)
				if choiceId == "else" then
					showDialogue("Sal", "Snacks, lots of snacks. And don't let Callahan tell you ice cream is fuel. It is delicious though.", {}, nil)
				end
			end)
		elseif npcName == "Sensei" then
			showDialogue("Sensei", "Step on the grey mat to begin your training. Seven buttons. Five seconds each. Miss and you PAY. Win, and you feast: $50.", withQuestChoice("Sensei", {
				{ id = "advice", text = "Any advice?" }
			}), function(choiceId)
				if choiceId == "quest" then
					handleQuestChoice("Sensei")
				elseif choiceId == "advice" then
					showDialogue("Sensei", "Never leave the mat mid-fight. And never, EVER, challenge me on a Monday.", {}, nil)
				end
			end)
		elseif npcName == "Ms. Wheeler" then
			showDialogue("Ms. Wheeler", "Welcome to Room 103, History of Scooters. Hold the red button to study - smart riders are FAST riders.", {
				{ id = "worth", text = "Is studying worth it?" }
			}, function(choiceId)
				if choiceId == "worth" then
					showDialogue("Ms. Wheeler", "Plus ten speed for fifteen whole minutes. Homework has never paid better.", {}, nil)
				end
			end)
		elseif npcName == "Pedestrian" then
			showDialogue("Pedestrian", "I am a perfectly normal pedestrian enjoying this fine stud-covered city.", {
				{ id = "smart", text = "Are you smart?" }
			}, function(choiceId)
				if choiceId == "smart" then
					focusCameraOnNPC(prompt.Parent and prompt.Parent.Parent, true)
					showDialogue("Pedestrian", "I am very smart. I NEVER look both ways!", {}, nil)
					task.delay(1.1, function()
						if npcModel and npcModel.Parent then setNPCFaceState(npcModel, "panic") end
					end)
					task.delay(4.2, function()
						if npcModel and npcModel.Parent then setNPCFaceState(npcModel, "idle") end
					end)
					task.delay(3.4, function()
						if currentCutsceneNPC == (prompt.Parent and prompt.Parent.Parent) then
							endCutscene()
						end
					end)
					game:GetService("ReplicatedStorage"):WaitForChild("DiscoveryBayRemotes"):WaitForChild("PianoDrop"):FireServer(prompt.Parent.Parent)
				end
			end)
		end
	end)
end

workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("ProximityPrompt") and desc.Name == "TalkPrompt" then hookNPC(desc) end
end)
for _, desc in ipairs(workspace:GetDescendants()) do
	if desc:IsA("ProximityPrompt") and desc.Name == "TalkPrompt" then hookNPC(desc) end
end

--==============================================================================================
-- INTRO: aerial camera over the town, then a PLAY button
--==============================================================================================
local function runIntro()
	local introGui = Instance.new("ScreenGui")
	introGui.Name = "DiscoveryBayMenu"
	introGui.IgnoreGuiInset = true
	introGui.ResetOnSpawn = false
	introGui.Parent = plr:WaitForChild("PlayerGui")

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0.08, 0)
	title.Size = UDim2.new(1, 0, 0, 84)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 64
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = "DISCOVERY BAY"
	title.ZIndex = 8 -- above the grey cover
	title.Parent = introGui

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.08, 86)
	subtitle.Size = UDim2.new(1, 0, 0, 28)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.LuckiestGuy
	subtitle.TextSize = 20
	subtitle.TextColor3 = Color3.fromRGB(220, 228, 235)
	subtitle.TextStrokeTransparency = 0.6
	subtitle.Text = "California Delta - scooters - " .. VERSION
	subtitle.ZIndex = 8
	subtitle.Parent = introGui

	-- grey loading cover with a spinning bubbly "L" while the town builds
	local loadFrame = Instance.new("Frame")
	loadFrame.Size = UDim2.fromScale(1, 1)
	loadFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	loadFrame.BorderSizePixel = 0
	loadFrame.ZIndex = 5
	loadFrame.Parent = introGui
	
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 90, 157)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(67, 206, 162))
	})
	grad.Rotation = 45
	grad.Parent = loadFrame
	
	local loadTxt = Instance.new("TextLabel")
	loadTxt.AnchorPoint = Vector2.new(0.5, 0.5)
	loadTxt.Position = UDim2.new(0.5, 0, 0.5, 0)
	loadTxt.Size = UDim2.new(0, 500, 0, 40)
	loadTxt.BackgroundTransparency = 1
	loadTxt.Font = Enum.Font.LuckiestGuy
	loadTxt.TextSize = 26
	loadTxt.TextColor3 = Color3.fromRGB(240, 242, 245)
	loadTxt.Text = "Loading Discovery Bay..."
	loadTxt.ZIndex = 6
	loadTxt.Parent = loadFrame
	local spinner = Instance.new("TextLabel")
	spinner.AnchorPoint = Vector2.new(1, 1)
	spinner.Position = UDim2.new(1, -28, 1, -28)
	spinner.Size = UDim2.new(0, 76, 0, 76)
	spinner.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	spinner.Font = Enum.Font.LuckiestGuy
	spinner.TextSize = 46
	spinner.TextColor3 = Color3.fromRGB(40, 30, 10)
	spinner.Text = "L"
	spinner.ZIndex = 6
	spinner.Parent = loadFrame
	local spinCorner = Instance.new("UICorner")
	spinCorner.CornerRadius = UDim.new(1, 0) -- full bubble
	spinCorner.Parent = spinner
	local spinConn = RunService.RenderStepped:Connect(function(dt)
		spinner.Rotation = spinner.Rotation + dt * 220
	end)
	
	-- Beautiful Sunset Gradient Background
	loadFrame.BackgroundTransparency = 0
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 113, 113)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(155, 89, 182)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(52, 152, 219))
	})
	
	-- Animate the gradient
	local gradOffset = 0
	local gradConn = RunService.RenderStepped:Connect(function(dt)
		gradOffset = (gradOffset + dt * 0.2) % 1
		grad.Offset = Vector2.new(gradOffset, 0)
	end)

	-- freeze movement during the menu
	local controls
	pcall(function()
		controls = require(plr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		controls:Disable()
	end)

	-- wait for the town to finish building
	local town = workspace:WaitForChild("DiscoveryBay", 300)
	while town and not town:GetAttribute("BuildComplete") do
		task.wait(0.25)
	end
	-- town ready: drop the spinner but KEEP the flat gradient background
	spinConn:Disconnect()
	gradConn:Disconnect()
	spinner:Destroy()
	loadTxt:Destroy()

	local playBtn = Instance.new("TextButton")
	playBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	playBtn.Position = UDim2.new(0.5, 0, 0.74, 0)
	playBtn.Size = UDim2.new(0, 260, 0, 84)
	playBtn.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	playBtn.Font = Enum.Font.LuckiestGuy
	playBtn.TextSize = 36
	playBtn.TextColor3 = Color3.fromRGB(40, 30, 10)
	playBtn.Text = "PLAY"
	playBtn.ZIndex = 6
	playBtn.Parent = introGui
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 16)
	playCorner.Parent = playBtn

	-- RULES / INFO buttons flanking PLAY, sharing one pop-up panel
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.4, 0)
	panel.Size = UDim2.new(0, 580, 0, 400)
	panel.BackgroundColor3 = Color3.fromRGB(45, 48, 54)
	panel.Visible = false
	panel.ZIndex = 9
	panel.Parent = introGui
	local panCorner = Instance.new("UICorner")
	panCorner.CornerRadius = UDim.new(0, 18)
	panCorner.Parent = panel
	local panTitle = Instance.new("TextLabel")
	panTitle.AnchorPoint = Vector2.new(0.5, 0)
	panTitle.Position = UDim2.new(0.5, 0, 0, 0)
	panTitle.Size = UDim2.new(1, 0, 0, 40)
	panTitle.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
	panTitle.Font = Enum.Font.LuckiestGuy
	panTitle.TextSize = 20
	panTitle.TextColor3 = Color3.new(1, 1, 1)
	panTitle.Text = "UPDATE NOTES"
	panTitle.ZIndex = 10
	panTitle.Parent = panel
	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 8)
	pCorner.Parent = panTitle
	local panBody = Instance.new("TextLabel")
	panBody.Position = UDim2.new(0, 12, 0, 48)
	panBody.Size = UDim2.new(1, -24, 1, -100)
	panBody.BackgroundTransparency = 1
	panBody.Font = Enum.Font.LuckiestGuy
	panBody.TextSize = 16
	panBody.TextColor3 = Color3.fromRGB(232, 235, 240) -- light text on the dark panel
	panBody.TextWrapped = true
	panBody.TextXAlignment = Enum.TextXAlignment.Left
	panBody.TextYAlignment = Enum.TextYAlignment.Top
	panBody.ZIndex = 10
	panBody.Parent = panel
	local panClose = Instance.new("TextButton")
	panClose.AnchorPoint = Vector2.new(0.5, 1)
	panClose.Position = UDim2.new(0.5, 0, 1, -12)
	panClose.Size = UDim2.new(0, 140, 0, 36)
	panClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	panClose.Font = Enum.Font.LuckiestGuy
	panClose.TextSize = 16
	panClose.TextColor3 = Color3.new(1, 1, 1)
	panClose.Text = "Got it!"
	panClose.ZIndex = 10
	panClose.Parent = panel
	local pcCorner = Instance.new("UICorner")
	pcCorner.CornerRadius = UDim.new(0, 8)
	pcCorner.Parent = panClose
	panClose.Activated:Connect(function() panel.Visible = false end)

	local RULES_TEXT = "1. Traffic is LETHAL. Look both ways or become a ragdoll."
		.. "\n2. Scooter tricks earn cash: Z X C V B, or T for a random one."
		.. "\n3. Snacks are power. Bloxy Cola and Callahan's cones make you faster."
		.. "\n4. The dojo mat pays $50 for 7 quick buttons. Too slow costs $5."
		.. "\n5. Click a RENT sign to own a house, then hatch dogs at the Egg Shop and pet them for cash."
		.. "\n6. Study in Room 103 at the school for a 15-minute scooter boost."
		.. "\n7. Debt drains your health. Stay out of the red!"
		.. "\n8. Every 2 days the weather changes - 50 kinds. Some pay you. Some HURT."
		.. "\n9. M = map, G = hop on/off the scooter."
		.. "\n10. Have fun. Discovery Bay is your town!"
	local INFO_TEXT = "THIS GAME WAS FULLY MADE BY AI."
		.. "\n\nEvery road, house, and shop was generated by Claude (an AI) from real map data"
		.. " of Discovery Bay, California - all 842 roads and thousands of houses."
		.. "\n\nThe scripts, the scooter physics, the trick animations, the dogs, the weather,"
		.. " and this very screen: all written by AI, directed by a human."
		.. "\n\nBuilt for Lionel."

	local function sideBtn(text, xOff)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(0.5, xOff, 0.74, 0)
		b.Size = UDim2.new(0, 170, 0, 62)
		b.BackgroundColor3 = Color3.fromRGB(70, 160, 220)
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.LuckiestGuy
		b.TextSize = 26
		b.Text = text
		b.ZIndex = 8
		b.Parent = introGui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 14)
		c.Parent = b
		return b
	end
	local rulesBtn = sideBtn("RULES", -290)
	local infoBtn = sideBtn("INFO", 290)
	rulesBtn.Activated:Connect(function()
		panTitle.Text = "RULES OF DISCOVERY BAY"
		panBody.Text = RULES_TEXT
		panel.Visible = true
	end)
	infoBtn.Activated:Connect(function()
		panTitle.Text = "ABOUT THIS GAME"
		panBody.Text = INFO_TEXT
		panel.Visible = true
	end)

	playBtn.Activated:Connect(function()
		introGui:Destroy()
		gui.Enabled = true
		
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		
		pcall(function() controls:Enable() end)
		local t = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if t then
			cam.CFrame = CFrame.lookAt(t.Position + Vector3.new(0, 10, 20), t.Position)
		end
		if not activeTrack then
			playTrack(currentZone == "Outdoor" and OUTDOOR_MUSIC or ZONES[1].id,
				0.4, currentZone == "Outdoor" and OUTDOOR_SPEED or ZONES[1].speed)
		end
	end)
end
task.spawn(runIntro)

-- Bottom-Left Status: Cash & Pity Tracker
local money = Instance.new("TextLabel")
money.Name = "Money"
money.AnchorPoint = Vector2.new(0, 1)
money.Position = UDim2.new(0, 18, 1, -18)
money.Size = UDim2.new(0, 195, 0, 48)
money.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
money.BackgroundTransparency = 0.2
money.TextColor3 = Color3.fromRGB(120, 230, 130)
money.Font = Enum.Font.LuckiestGuy
money.TextSize = 26
money.Text = "$ ..."
money.Parent = gui
local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 12)
mCorner.Parent = money
local mStroke = Instance.new("UIStroke")
mStroke.Color = Color3.fromRGB(80, 180, 100)
mStroke.Thickness = 2
mStroke.Parent = money

local ClaimPity = remotes:WaitForChild("ClaimPity")

local pityLabel = Instance.new("TextButton")
pityLabel.Name = "PityLabel"
pityLabel.AnchorPoint = Vector2.new(0, 1)
pityLabel.Position = UDim2.new(0, 18, 1, -74)
pityLabel.Size = UDim2.new(0, 195, 0, 36)
pityLabel.BackgroundColor3 = Color3.fromRGB(115, 35, 145)
pityLabel.TextColor3 = Color3.new(1, 1, 1)
pityLabel.Font = Enum.Font.LuckiestGuy
pityLabel.TextSize = 14
pityLabel.Text = "Pity: 90 rolls until Linus"
pityLabel.Parent = gui
local plCorner = Instance.new("UICorner")
plCorner.CornerRadius = UDim.new(0, 10)
plCorner.Parent = pityLabel

local currentPityRollsLeft = 90
UpdatePity.OnClientEvent:Connect(function(rollsLeft)
	currentPityRollsLeft = rollsLeft
	if rollsLeft <= 0 then
		pityLabel.Text = "CLAIM PITY LINUS!"
		pityLabel.BackgroundColor3 = Color3.fromRGB(250, 180, 20)
	else
		pityLabel.Text = "Pity: " .. tostring(rollsLeft) .. " rolls until Linus"
		pityLabel.BackgroundColor3 = Color3.fromRGB(115, 35, 145)
	end
end)

pityLabel.Activated:Connect(function()
	if currentPityRollsLeft <= 0 then
		ClaimPity:FireServer()
	end
end)

-- Left-Center Dock: Shop Button (paired above Rebirth)
local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopToggle"
shopBtn.AnchorPoint = Vector2.new(0, 1)
shopBtn.Position = UDim2.new(0, 18, 0.52, -4)
shopBtn.Size = UDim2.new(0, 156, 0, 50)
shopBtn.BackgroundColor3 = Color3.fromRGB(230, 145, 35)
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.Font = Enum.Font.LuckiestGuy
shopBtn.TextSize = 20
shopBtn.Text = "SHOP"
shopBtn.Parent = gui
local shCorner = Instance.new("UICorner")
shCorner.CornerRadius = UDim.new(0, 12)
shCorner.Parent = shopBtn
local shStroke = Instance.new("UIStroke")
shStroke.Color = Color3.fromRGB(255, 215, 110)
shStroke.Thickness = 2
shStroke.Parent = shopBtn

-- Top-Right Navigation & Debug Bar: Map (M) & Inf Money
local mapBtn = Instance.new("TextButton")
mapBtn.Name = "MapToggle"
mapBtn.AnchorPoint = Vector2.new(1, 0)
mapBtn.Position = UDim2.new(1, -18, 0, 16)
mapBtn.Size = UDim2.new(0, 136, 0, 42)
mapBtn.BackgroundColor3 = Color3.fromRGB(62, 115, 72)
mapBtn.TextColor3 = Color3.new(1, 1, 1)
mapBtn.Font = Enum.Font.LuckiestGuy
mapBtn.TextSize = 18
mapBtn.Text = "Map  (M)"
mapBtn.Parent = gui
local mbCorner = Instance.new("UICorner")
mbCorner.CornerRadius = UDim.new(0, 12)
mbCorner.Parent = mapBtn
local mbStroke = Instance.new("UIStroke")
mbStroke.Color = Color3.fromRGB(130, 200, 140)
mbStroke.Thickness = 2
mbStroke.Parent = mapBtn

local moneyBtn = Instance.new("TextButton")
moneyBtn.Name = "DebugMoney"
moneyBtn.AnchorPoint = Vector2.new(1, 0)
moneyBtn.Position = UDim2.new(1, -164, 0, 16)
moneyBtn.Size = UDim2.new(0, 148, 0, 42)
moneyBtn.BackgroundColor3 = Color3.fromRGB(30, 135, 65)
moneyBtn.TextColor3 = Color3.new(1, 1, 1)
moneyBtn.Font = Enum.Font.LuckiestGuy
moneyBtn.TextSize = 15
moneyBtn.Text = "+ Inf Money"
-- owner-only (the server checks too): hidden for everyone but the game's owner / Studio testing
moneyBtn.Visible = RunService:IsStudio()
	or (game.CreatorType == Enum.CreatorType.User and plr.UserId == game.CreatorId)
if game.CreatorType == Enum.CreatorType.Group and not moneyBtn.Visible then
	task.spawn(function()
		local ok, rank = pcall(plr.GetRankInGroup, plr, game.CreatorId)
		moneyBtn.Visible = ok and rank == 255
	end)
end
moneyBtn.Parent = gui
local mb2Corner = Instance.new("UICorner")
mb2Corner.CornerRadius = UDim.new(0, 12)
mb2Corner.Parent = moneyBtn

moneyBtn.Activated:Connect(function()
	if InfiniteMoney then
		InfiniteMoney:FireServer()
	end
end)

-- Bottom-Right Scooter Dock: Ride/Get Off (G) + TRICKS Popup Toggle (like Shop!)
local mountBtn = Instance.new("TextButton")
mountBtn.Name = "MountToggle"
mountBtn.AnchorPoint = Vector2.new(1, 1)
mountBtn.Position = UDim2.new(1, -172, 1, -18)
mountBtn.Size = UDim2.new(0, 146, 0, 48)
mountBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 220)
mountBtn.TextColor3 = Color3.new(1, 1, 1)
mountBtn.Font = Enum.Font.LuckiestGuy
mountBtn.TextSize = 16
mountBtn.Text = "Get Off  (G)"
mountBtn.Parent = gui
local mtCorner = Instance.new("UICorner")
mtCorner.CornerRadius = UDim.new(0, 12)
mtCorner.Parent = mountBtn
local mtStroke = Instance.new("UIStroke")
mtStroke.Color = Color3.fromRGB(150, 220, 255)
mtStroke.Thickness = 2
mtStroke.Parent = mountBtn

local tricksToggleBtn = Instance.new("TextButton")
tricksToggleBtn.Name = "TricksToggle"
tricksToggleBtn.AnchorPoint = Vector2.new(1, 1)
tricksToggleBtn.Position = UDim2.new(1, -18, 1, -18)
tricksToggleBtn.Size = UDim2.new(0, 144, 0, 48)
tricksToggleBtn.BackgroundColor3 = Color3.fromRGB(250, 195, 30)
tricksToggleBtn.TextColor3 = Color3.fromRGB(40, 30, 10)
tricksToggleBtn.Font = Enum.Font.LuckiestGuy
tricksToggleBtn.TextSize = 19
tricksToggleBtn.Text = "TRICKS"
tricksToggleBtn.Parent = gui
local ttCorner = Instance.new("UICorner")
ttCorner.CornerRadius = UDim.new(0, 12)
ttCorner.Parent = tricksToggleBtn
local ttStroke = Instance.new("UIStroke")
ttStroke.Color = Color3.fromRGB(255, 240, 140)
ttStroke.Thickness = 2
ttStroke.Parent = tricksToggleBtn

-- the shop page: one glorious gamepass
local shopPage = Instance.new("Frame")
shopPage.Name = "ShopPage"
shopPage.AnchorPoint = Vector2.new(0.5, 0.5)
shopPage.Position = UDim2.new(0.5, 0, 0.5, 0)
shopPage.Size = UDim2.new(0, 400, 0, 320)
shopPage.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
shopPage.Visible = false
shopPage.Parent = gui
local spCorner = Instance.new("UICorner")
spCorner.CornerRadius = UDim.new(0, 14)
spCorner.Parent = shopPage

local shopTitle = Instance.new("TextLabel")
shopTitle.Position = UDim2.new(0, 0, 0, 10)
shopTitle.Size = UDim2.new(1, 0, 0, 36)
shopTitle.BackgroundTransparency = 1
shopTitle.Font = Enum.Font.LuckiestGuy
shopTitle.TextSize = 28
shopTitle.TextColor3 = Color3.new(1, 1, 1)
shopTitle.Text = "SHOP"
shopTitle.Parent = shopPage

local shopClose = Instance.new("TextButton")
shopClose.AnchorPoint = Vector2.new(1, 0)
shopClose.Position = UDim2.new(1, -10, 0, 10)
shopClose.Size = UDim2.new(0, 34, 0, 34)
shopClose.BackgroundColor3 = Color3.fromRGB(160, 60, 55)
shopClose.TextColor3 = Color3.new(1, 1, 1)
shopClose.Font = Enum.Font.LuckiestGuy
shopClose.TextSize = 20
shopClose.Text = "X"
shopClose.Parent = shopPage
local scCorner = Instance.new("UICorner")
scCorner.CornerRadius = UDim.new(0, 8)
scCorner.Parent = shopClose

local passCard = Instance.new("Frame")
passCard.AnchorPoint = Vector2.new(0.5, 0)
passCard.Position = UDim2.new(0.5, 0, 0, 56)
passCard.Size = UDim2.new(1, -24, 0, 190)
passCard.BackgroundColor3 = Color3.fromRGB(36, 46, 62)
passCard.Parent = shopPage
local pcCorner = Instance.new("UICorner")
pcCorner.CornerRadius = UDim.new(0, 12)
pcCorner.Parent = passCard

local passIcon = Instance.new("TextLabel")
passIcon.Position = UDim2.new(0, 14, 0, 14)
passIcon.Size = UDim2.new(0, 90, 0, 90)
passIcon.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
passIcon.Font = Enum.Font.LuckiestGuy
passIcon.TextSize = 40
passIcon.TextColor3 = Color3.fromRGB(40, 30, 10)
passIcon.Text = "2X"
passIcon.Parent = passCard
local piCorner = Instance.new("UICorner")
piCorner.CornerRadius = UDim.new(0, 12)
piCorner.Parent = passIcon

local passName = Instance.new("TextLabel")
passName.Position = UDim2.new(0, 118, 0, 16)
passName.Size = UDim2.new(1, -130, 0, 56)
passName.BackgroundTransparency = 1
passName.Font = Enum.Font.LuckiestGuy
passName.TextSize = 22
passName.TextColor3 = Color3.new(1, 1, 1)
passName.TextWrapped = true
passName.TextXAlignment = Enum.TextXAlignment.Left
passName.Text = "2X Scooter Speed  [Permanent]"
passName.Parent = passCard

local passDesc = Instance.new("TextLabel")
passDesc.Position = UDim2.new(0, 118, 0, 72)
passDesc.Size = UDim2.new(1, -130, 0, 34)
passDesc.BackgroundTransparency = 1
passDesc.Font = Enum.Font.LuckiestGuy
passDesc.TextSize = 14
passDesc.TextColor3 = Color3.fromRGB(190, 200, 215)
passDesc.TextWrapped = true
passDesc.TextXAlignment = Enum.TextXAlignment.Left
passDesc.Text = "Doubles your scooter speed. Forever. Stacks with every boost."
passDesc.Parent = passCard

local buyBtn = Instance.new("TextButton")
buyBtn.AnchorPoint = Vector2.new(0.5, 1)
buyBtn.Position = UDim2.new(0.5, 0, 1, -14)
buyBtn.Size = UDim2.new(0, 220, 0, 52)
buyBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
buyBtn.TextColor3 = Color3.new(1, 1, 1)
buyBtn.Font = Enum.Font.LuckiestGuy
buyBtn.TextSize = 24
buyBtn.Text = "Buy  ·  R$ 299"
buyBtn.Parent = passCard
local bbCorner = Instance.new("UICorner")
bbCorner.CornerRadius = UDim.new(0, 12)
bbCorner.Parent = buyBtn

local shopStatus = Instance.new("TextLabel")
shopStatus.AnchorPoint = Vector2.new(0.5, 1)
shopStatus.Position = UDim2.new(0.5, 0, 1, -12)
shopStatus.Size = UDim2.new(1, -20, 0, 40)
shopStatus.BackgroundTransparency = 1
shopStatus.Font = Enum.Font.LuckiestGuy
shopStatus.TextSize = 14
shopStatus.TextWrapped = true
shopStatus.TextColor3 = Color3.fromRGB(255, 200, 120)
shopStatus.Text = ""
shopStatus.Parent = shopPage

local function refreshPassCard()
	if plr:GetAttribute("SpeedPass") then
		buyBtn.Text = "OWNED"
		buyBtn.BackgroundColor3 = Color3.fromRGB(100, 110, 125)
	end
end
plr:GetAttributeChangedSignal("SpeedPass"):Connect(refreshPassCard)
refreshPassCard()

buyBtn.Activated:Connect(function()
	if plr:GetAttribute("SpeedPass") then return end
	if SPEED_PASS_ID > 0 then
		local MarketplaceService = game:GetService("MarketplaceService")
		MarketplaceService:PromptGamePassPurchase(plr, SPEED_PASS_ID)
	else
		shopStatus.Text = "Coming soon! (The game pass isn't set up on Roblox yet.)"
	end
end)

-- version tag: if you can't see this on screen, you're running an old file
local verTag = Instance.new("TextLabel")
verTag.Name = "Version"
verTag.AnchorPoint = Vector2.new(0, 1)
verTag.Position = UDim2.new(0, 20, 1, -114)
verTag.Size = UDim2.new(0, 190, 0, 16)
verTag.BackgroundTransparency = 1
verTag.TextColor3 = Color3.fromRGB(200, 205, 210)
verTag.TextTransparency = 0.25
verTag.Font = Enum.Font.LuckiestGuy
verTag.TextSize = 12
verTag.TextXAlignment = Enum.TextXAlignment.Left
verTag.Text = "Discovery Bay " .. VERSION
verTag.Parent = gui

local function refreshMountBtn()
	if plr:GetAttribute("Mounted") then
		mountBtn.Text = "Get Off  (G)"
		mountBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 220)
	else
		mountBtn.Text = "Ride  (G)"
		mountBtn.BackgroundColor3 = Color3.fromRGB(80, 190, 120)
	end
end
plr:GetAttributeChangedSignal("Mounted"):Connect(refreshMountBtn)
refreshMountBtn()

-- TRICKS POPUP MODAL (like ShopPage, so 8 trick buttons aren't sitting out on screen!)
local TRICKS = {
	{ key = Enum.KeyCode.Z, label = "Z", name = "Tailwhip",  pay = 4,  color = Color3.fromRGB(45, 115, 175) },
	{ key = Enum.KeyCode.X, label = "X", name = "Kickflip",  pay = 3,  color = Color3.fromRGB(50, 140, 115) },
	{ key = Enum.KeyCode.C, label = "C", name = "360 Spin",  pay = 6,  color = Color3.fromRGB(125, 75, 175) },
	{ key = Enum.KeyCode.V, label = "V", name = "Backflip",  pay = 10, color = Color3.fromRGB(185, 65, 75) },
	{ key = Enum.KeyCode.B, label = "B", name = "Frontflip", pay = 10, color = Color3.fromRGB(195, 105, 45) },
	{ key = Enum.KeyCode.N, label = "N", name = "No-Hander", pay = 5,  color = Color3.fromRGB(65, 95, 165) },
}

local trickPage = Instance.new("Frame")
trickPage.Name = "TrickPage"
trickPage.AnchorPoint = Vector2.new(0.5, 0.5)
trickPage.Position = UDim2.new(0.5, 0, 0.5, 0)
trickPage.Size = UDim2.new(0, 460, 0, 350)
trickPage.BackgroundColor3 = Color3.fromRGB(24, 30, 40)
trickPage.Visible = false
trickPage.Parent = gui
local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 14)
tpCorner.Parent = trickPage
local tpStroke = Instance.new("UIStroke")
tpStroke.Color = Color3.fromRGB(250, 195, 30)
tpStroke.Thickness = 2
tpStroke.Parent = trickPage

local trickTitle = Instance.new("TextLabel")
trickTitle.Position = UDim2.new(0, 0, 0, 10)
trickTitle.Size = UDim2.new(1, 0, 0, 32)
trickTitle.BackgroundTransparency = 1
trickTitle.Font = Enum.Font.LuckiestGuy
trickTitle.TextSize = 26
trickTitle.TextColor3 = Color3.fromRGB(250, 205, 40)
trickTitle.Text = "SCOOTER TRICKS"
trickTitle.Parent = trickPage

local trickSub = Instance.new("TextLabel")
trickSub.Position = UDim2.new(0, 0, 0, 40)
trickSub.Size = UDim2.new(1, 0, 0, 18)
trickSub.BackgroundTransparency = 1
trickSub.Font = Enum.Font.GothamBold
trickSub.TextSize = 13
trickSub.TextColor3 = Color3.fromRGB(185, 195, 210)
trickSub.Text = "Click any card or press its hotkey anytime while riding!"
trickSub.Parent = trickPage

local trickClose = Instance.new("TextButton")
trickClose.AnchorPoint = Vector2.new(1, 0)
trickClose.Position = UDim2.new(1, -10, 0, 10)
trickClose.Size = UDim2.new(0, 34, 0, 34)
trickClose.BackgroundColor3 = Color3.fromRGB(160, 60, 55)
trickClose.TextColor3 = Color3.new(1, 1, 1)
trickClose.Font = Enum.Font.LuckiestGuy
trickClose.TextSize = 20
trickClose.Text = "X"
trickClose.Parent = trickPage
local tcCorner = Instance.new("UICorner")
tcCorner.CornerRadius = UDim.new(0, 8)
tcCorner.Parent = trickClose

local menu = Instance.new("Frame")
menu.Name = "TrickMenu"
menu.AnchorPoint = Vector2.new(0.5, 0)
menu.Position = UDim2.new(0.5, 0, 0, 68)
menu.Size = UDim2.new(1, -28, 0, 204)
menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.Parent = trickPage

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0, 210, 0, 60)
layout.CellPadding = UDim2.new(0, 12, 0, 10)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = menu

local trickButtons = {}
for idx, t in ipairs(TRICKS) do
	local btn = Instance.new("TextButton")
	btn.Name = t.name
	btn.LayoutOrder = idx
	btn.BackgroundColor3 = Color3.fromRGB(36, 46, 62)
	btn.Text = ""
	btn.Parent = menu
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = btn
	local st = Instance.new("UIStroke")
	st.Color = t.color
	st.Thickness = 2
	st.Parent = btn

	local keyBadge = Instance.new("TextLabel")
	keyBadge.AnchorPoint = Vector2.new(0, 0.5)
	keyBadge.Position = UDim2.new(0, 10, 0.5, 0)
	keyBadge.Size = UDim2.new(0, 40, 0, 40)
	keyBadge.BackgroundColor3 = t.color
	keyBadge.TextColor3 = Color3.new(1, 1, 1)
	keyBadge.Font = Enum.Font.LuckiestGuy
	keyBadge.TextSize = 20
	keyBadge.Text = t.label
	keyBadge.Parent = btn
	local kbCorner = Instance.new("UICorner")
	kbCorner.CornerRadius = UDim.new(0, 9)
	kbCorner.Parent = keyBadge

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Position = UDim2.new(0, 58, 0, 8)
	nameLbl.Size = UDim2.new(1, -66, 0, 24)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.LuckiestGuy
	nameLbl.TextSize = 17
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = t.name
	nameLbl.Parent = btn

	local payLbl = Instance.new("TextLabel")
	payLbl.Position = UDim2.new(0, 58, 0, 32)
	payLbl.Size = UDim2.new(1, -66, 0, 18)
	payLbl.BackgroundTransparency = 1
	payLbl.Font = Enum.Font.GothamBold
	payLbl.TextSize = 13
	payLbl.TextColor3 = Color3.fromRGB(120, 235, 135)
	payLbl.TextXAlignment = Enum.TextXAlignment.Left
	payLbl.Text = "+$" .. t.pay .. " per land"
	payLbl.Parent = btn

	trickButtons[t.name] = btn
end

local trickBtn = Instance.new("TextButton")
trickBtn.Name = "RandomTrick"
trickBtn.AnchorPoint = Vector2.new(0.5, 1)
trickBtn.Position = UDim2.new(0.5, 0, 1, -14)
trickBtn.Size = UDim2.new(1, -28, 0, 52)
trickBtn.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
trickBtn.TextColor3 = Color3.fromRGB(40, 30, 10)
trickBtn.Font = Enum.Font.LuckiestGuy
trickBtn.TextSize = 22
trickBtn.Text = "RANDOM TRICK!  (Press T)"
trickBtn.Parent = trickPage
local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 12)
tCorner.Parent = trickBtn

shopBtn.Activated:Connect(function()
	if gui.Enabled then
		shopPage.Visible = not shopPage.Visible
		if shopPage.Visible then trickPage.Visible = false end
	end
end)
shopClose.Activated:Connect(function()
	shopPage.Visible = false
end)

tricksToggleBtn.Activated:Connect(function()
	if gui.Enabled then
		trickPage.Visible = not trickPage.Visible
		if trickPage.Visible then shopPage.Visible = false end
	end
end)
trickClose.Activated:Connect(function()
	trickPage.Visible = false
end)

-- Chunky 3D HUD buttons: drop-shadow base, gradient face, top gloss, sweeping shine, emoji icon,
-- key badge and hover/press animation. The button itself turns invisible and its Text and
-- BackgroundColor3 are mirrored onto the decorated layers, so existing code that updates them keeps working.
local function darken(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function styleHudButton(btn, icon)
	local DEPTH = 4
	local maxText = btn.TextSize
	for _, d in ipairs(btn:GetChildren()) do
		if d:IsA("UICorner") or d:IsA("UIStroke") then d:Destroy() end
	end
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.TextTransparency = 1
	btn.ClipsDescendants = false

	local scale = Instance.new("UIScale")
	scale.Parent = btn

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Position = UDim2.new(0, 0, 0, DEPTH)
	shadow.Size = UDim2.new(1, 0, 1, -DEPTH)
	shadow.BorderSizePixel = 0
	shadow.Parent = btn
	local shCorner = Instance.new("UICorner")
	shCorner.CornerRadius = UDim.new(0, 12)
	shCorner.Parent = shadow

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -DEPTH)
	face.BorderSizePixel = 0
	face.ClipsDescendants = true
	face.ZIndex = 2
	face.Parent = btn
	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 12)
	fCorner.Parent = face
	local fGrad = Instance.new("UIGradient")
	fGrad.Rotation = 90
	fGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	fGrad.Parent = face
	local fStroke = Instance.new("UIStroke")
	fStroke.Thickness = 2.5
	fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	fStroke.Parent = face

	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Position = UDim2.new(0, 4, 0, 3)
	gloss.Size = UDim2.new(1, -8, 0.42, 0)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.72
	gloss.BorderSizePixel = 0
	gloss.ZIndex = 3
	gloss.Parent = face
	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0, 9)
	gCorner.Parent = gloss

	-- diagonal shine streak that sweeps across every few seconds
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, 0, 1, 0)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.ZIndex = 4
	shine.Parent = face
	local shineGrad = Instance.new("UIGradient")
	shineGrad.Rotation = 20
	shineGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineGrad.Offset = Vector2.new(-1, 0)
	shineGrad.Parent = shine

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Name = "Icon"
	iconLbl.BackgroundTransparency = 1
	iconLbl.AnchorPoint = Vector2.new(0, 0.5)
	iconLbl.Position = UDim2.new(0, 8, 0.5, 0)
	iconLbl.Size = UDim2.new(0, 28, 0, 28)
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextScaled = true
	iconLbl.Text = icon or ""
	iconLbl.ZIndex = 5
	iconLbl.Parent = face

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, icon and 40 or 10, 0, 2)
	label.Size = UDim2.new(1, icon and -48 or -20, 1, -4)
	label.Font = btn.Font
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.ZIndex = 5
	label.Parent = face
	local lSize = Instance.new("UITextSizeConstraint")
	lSize.MaxTextSize = maxText
	lSize.Parent = label
	local lStroke = Instance.new("UIStroke")
	lStroke.Thickness = 2
	lStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	lStroke.Parent = label

	-- keyboard shortcut like "(G)" in the text becomes a little key badge in the corner
	local badge = Instance.new("TextLabel")
	badge.Name = "KeyBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 6, 0, -7)
	badge.Size = UDim2.new(0, 22, 0, 22)
	badge.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	badge.Font = Enum.Font.GothamBlack
	badge.TextSize = 13
	badge.TextColor3 = Color3.fromRGB(35, 35, 45)
	badge.ZIndex = 6
	badge.Visible = false
	badge.Parent = btn
	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 6)
	bCorner.Parent = badge
	local bStroke = Instance.new("UIStroke")
	bStroke.Thickness = 2
	bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- outline the chip, not the letter
	bStroke.Parent = badge

	local function syncText()
		local key = string.match(btn.Text, "%((%a)%)")
		local clean = string.gsub(btn.Text, "%s*%(%a%)", "")
		label.Text = clean
		badge.Text = key or ""
		badge.Visible = key ~= nil
	end
	local function syncColor()
		local c = btn.BackgroundColor3
		face.BackgroundColor3 = c
		shadow.BackgroundColor3 = darken(c, 0.5)
		fStroke.Color = darken(c, 0.38)
		lStroke.Color = darken(c, 0.3)
		bStroke.Color = darken(c, 0.4)
	end
	syncText()
	syncColor()
	btn:GetPropertyChangedSignal("Text"):Connect(syncText)
	btn:GetPropertyChangedSignal("BackgroundColor3"):Connect(syncColor)

	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local hovering = false
	local function setPressed(down)
		TweenService:Create(face, quick, { Position = UDim2.new(0, 0, 0, down and DEPTH - 1 or 0) }):Play()
	end
	btn.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(scale, quick, { Scale = 1.06 }):Play()
		TweenService:Create(gloss, quick, { BackgroundTransparency = 0.55 }):Play()
		TweenService:Create(iconLbl, quick, { Rotation = -10 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		setPressed(false)
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
		TweenService:Create(gloss, quick, { BackgroundTransparency = 0.72 }):Play()
		TweenService:Create(iconLbl, quick, { Rotation = 0 }):Play()
	end)
	btn.MouseButton1Down:Connect(function() setPressed(true) end)
	btn.MouseButton1Up:Connect(function() setPressed(false) end)
	btn.Activated:Connect(function()
		setPressed(false)
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = hovering and 1.06 or 1 }):Play()
	end)

	task.spawn(function()
		task.wait(math.random() * 3)
		while btn.Parent do
			shineGrad.Offset = Vector2.new(-1, 0)
			TweenService:Create(shineGrad, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(4 + math.random() * 2)
		end
	end)
end

styleHudButton(shopBtn, "🛒")
styleHudButton(rebirthBtn, "♻️")
styleHudButton(mapBtn, "🗺️")
styleHudButton(moneyBtn, "💰")
styleHudButton(mountBtn, "🛴")
styleHudButton(tricksToggleBtn, "🔥")
styleHudButton(pityLabel, "🥚")

-- LOW DETAIL MODE (LDM) -----------------------------------------------------------------------
-- For phones: hides small decoration parts (trees, yard and window trim, shop dressing, interior
-- clutter) on this client only, and switches off shadows, lights, particles and glow effects.
-- On by default for touch devices without a keyboard; the HUD button toggles it for anyone.
local LDM_HIDE = {}
for _, n in ipairs({
	-- house exteriors
	"Shrub", "Flowers", "FlowerBox", "Mullion", "Transom", "WindowHeader", "Sill", "WindowSill", "WindowJamb",
	"Shutter", "MailboxPost", "Mailbox", "MailboxFlag", "PorchLight", "RidgeCap", "GarageTrim", "DoorJamb",
	"DoorLintel", "RentPostCap", "RentChain", "Walkway",
	-- shop dressing
	"BaseCourse", "Pilaster", "ParapetCap", "LanternArm", "Lantern", "Planter", "PlanterShrub", "AwningStripe",
	"AwningValance", "RoofAC", "RoofACFan", "RoofVent", "PumpStripe", "PumpScreen", "PumpNozzle", "PumpHose",
	"Bollard", "EggSpot", "SpotlightPost", "SpotlightHead", "TurntableGlow", "FacadeNeon", "WallNeon", "RunwayTile",
	"CafeChairLeg", "BenchLeg", "RackWheel", "TireRim", "CoolerDoorSplit",
	-- interior clutter
	"Books", "Magazine", "Mug", "Kibble", "ChewBone", "PoolBall", "PoolCue", "CabinetLine", "Burner", "FridgeSeam",
	"FridgeDrawing", "ThrowPillow", "LightCord", "Baseboard", "GameConsole", "Soundbar", "Pot", "CupStack",
}) do
	LDM_HIDE[n] = true
end
local LDM_TREES = { tree_oak = true, tree_palm = true }
local LDM_FX = { "PointLight", "SpotLight", "SurfaceLight", "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles" }
local ldmOn = false
local ldmHidden = {}   -- part -> true (we set its LocalTransparencyModifier)
local ldmDisabled = {} -- light/effect -> true (we switched it off)
local ldmLightingWas = nil
local ldmConns = {}

local function ldmIsFx(d)
	for _, c in ipairs(LDM_FX) do
		if d:IsA(c) then return true end
	end
	return false
end
local function ldmApply(d)
	if d:IsA("BasePart") then
		local m = d.Parent
		if LDM_HIDE[d.Name] or (m and LDM_TREES[m.Name]) then
			d.LocalTransparencyModifier = 1
			ldmHidden[d] = true
		end
	elseif ldmIsFx(d) and d.Enabled then
		d.Enabled = false
		ldmDisabled[d] = true
	end
end

local function setLowDetail(on)
	if on == ldmOn then return end
	ldmOn = on
	for _, c in ipairs(ldmConns) do c:Disconnect() end
	ldmConns = {}
	if on then
		ldmLightingWas = { shadows = Lighting.GlobalShadows, effects = {} }
		Lighting.GlobalShadows = false
		for _, e in ipairs(Lighting:GetChildren()) do
			if (e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect")) and e.Enabled then
				e.Enabled = false
				table.insert(ldmLightingWas.effects, e)
			end
		end
		-- the server (weather, day/night) may switch shadows back on; keep them off while LDM is on
		table.insert(ldmConns, Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
			if ldmOn and Lighting.GlobalShadows then Lighting.GlobalShadows = false end
		end))
		-- interiors, cars and effects keep arriving as you play
		table.insert(ldmConns, workspace.DescendantAdded:Connect(function(d)
			if ldmOn then task.defer(ldmApply, d) end
		end))
		task.spawn(function()
			for i, d in ipairs(workspace:GetDescendants()) do
				if not ldmOn then return end
				ldmApply(d)
				if i % 4000 == 0 then task.wait() end
			end
		end)
	else
		for p in pairs(ldmHidden) do
			if p.Parent then p.LocalTransparencyModifier = 0 end
		end
		for e in pairs(ldmDisabled) do
			if e.Parent then e.Enabled = true end
		end
		ldmHidden, ldmDisabled = {}, {}
		if ldmLightingWas then
			Lighting.GlobalShadows = ldmLightingWas.shadows
			for _, e in ipairs(ldmLightingWas.effects) do
				if e.Parent then e.Enabled = true end
			end
			ldmLightingWas = nil
		end
	end
end

local ldmBtn = Instance.new("TextButton")
ldmBtn.Name = "LowDetailToggle"
ldmBtn.AnchorPoint = Vector2.new(1, 0)
ldmBtn.Position = UDim2.new(1, -18, 0, 66)
ldmBtn.Size = UDim2.new(0, 136, 0, 38)
ldmBtn.Font = Enum.Font.LuckiestGuy
ldmBtn.TextSize = 15
ldmBtn.TextColor3 = Color3.new(1, 1, 1)
ldmBtn.Parent = gui
local function refreshLdmBtn()
	ldmBtn.Text = ldmOn and "LDM: ON" or "LDM: OFF"
	ldmBtn.BackgroundColor3 = ldmOn and Color3.fromRGB(60, 150, 90) or Color3.fromRGB(90, 95, 110)
end
refreshLdmBtn()
styleHudButton(ldmBtn, "📱")
ldmBtn.Activated:Connect(function()
	setLowDetail(not ldmOn)
	refreshLdmBtn()
end)
-- phones and tablets start in low detail
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	task.spawn(function()
		local town = workspace:WaitForChild("DiscoveryBay", 300)
		while town and not town:GetAttribute("BuildComplete") do task.wait(0.5) end
		setLowDetail(true)
		refreshLdmBtn()
	end)
end

-- Global UI sound effects
for _, child in ipairs(gui:GetDescendants()) do
	if child:IsA("TextButton") then
		child.MouseEnter:Connect(function()
			pcall(playSound, "rbxassetid://12221967", 0.25) -- soft hover
		end)
		child.Activated:Connect(function()
			pcall(playSound, "rbxassetid://9065609404", 1.0) -- crisp click
		end)
	end
end

-- live money readout ----------------------------------------------------------------------------
local function watchCash()
	local stats = plr:WaitForChild("leaderstats", 60)
	local cash = stats and stats:WaitForChild("Cash", 60)
	if not cash then return end
	local function update()
		money.Text = "$ " .. tostring(cash.Value)
		-- red when in debt (debt drains your health until you're back to $0+)
		money.TextColor3 = cash.Value < 0 and Color3.fromRGB(240, 90, 90)
			or Color3.fromRGB(120, 230, 130)
		money.TextSize = 30
		TweenService:Create(money, TweenInfo.new(0.25), { TextSize = 26 }):Play()
	end
	cash.Changed:Connect(update)
	update()
end
task.spawn(watchCash)

--==============================================================================================
-- MAP: shows the road network + shops; click to set a waypoint (beacon + stud counter)
--==============================================================================================
local mapGui = Instance.new("ScreenGui")
mapGui.Name = "DiscoveryBayMap"
mapGui.ResetOnSpawn = false
mapGui.IgnoreGuiInset = true -- makes AbsolutePosition match raw mouse coords for clicks
mapGui.Enabled = false
mapGui.Parent = plr:WaitForChild("PlayerGui")

local mapFrame = Instance.new("Frame")
mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mapFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mapFrame.BackgroundColor3 = Color3.fromRGB(72, 96, 64)
mapFrame.BorderSizePixel = 0
mapFrame.ClipsDescendants = true
mapFrame.Parent = mapGui
local mfCorner = Instance.new("UICorner")
mfCorner.CornerRadius = UDim.new(0, 12)
mfCorner.Parent = mapFrame

local mapLegend = Instance.new("TextLabel")
mapLegend.AnchorPoint = Vector2.new(0.5, 0)
mapLegend.Position = UDim2.new(0.5, 0, 0, 6)
mapLegend.Size = UDim2.new(1, -20, 0, 22)
mapLegend.BackgroundTransparency = 1
mapLegend.Font = Enum.Font.LuckiestGuy
mapLegend.TextSize = 15
mapLegend.TextColor3 = Color3.new(1, 1, 1)
mapLegend.TextStrokeTransparency = 0.5
mapLegend.Text = "S ShellBlox   C Callahan's   B Bloxway   J Jiu Jitsu   E School   F Fish   ● stores   -   click to mark"
mapLegend.ZIndex = 10
mapLegend.Parent = mapFrame

local clearBtn = Instance.new("TextButton")
clearBtn.AnchorPoint = Vector2.new(1, 0)
clearBtn.Position = UDim2.new(1, -8, 0, 32)
clearBtn.Size = UDim2.new(0, 110, 0, 30)
clearBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 55)
clearBtn.TextColor3 = Color3.new(1, 1, 1)
clearBtn.Font = Enum.Font.LuckiestGuy
clearBtn.TextSize = 15
clearBtn.Text = "Clear mark"
clearBtn.ZIndex = 10
clearBtn.Parent = mapFrame
local cbCorner = Instance.new("UICorner")
cbCorner.CornerRadius = UDim.new(0, 8)
cbCorner.Parent = clearBtn

local playerDot = Instance.new("Frame")
playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
playerDot.Size = UDim2.new(0, 10, 0, 10)
playerDot.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
playerDot.ZIndex = 8
playerDot.Parent = mapFrame
local pdCorner = Instance.new("UICorner")
pdCorner.CornerRadius = UDim.new(1, 0)
pdCorner.Parent = playerDot

local markPin = Instance.new("Frame")
markPin.AnchorPoint = Vector2.new(0.5, 0.5)
markPin.Size = UDim2.new(0, 12, 0, 12)
markPin.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
markPin.Rotation = 45
markPin.Visible = false
markPin.ZIndex = 9
markPin.Parent = mapFrame

-- waypoint HUD readout (top center, lives in the main HUD gui)
local wayLabel = Instance.new("TextLabel")
wayLabel.AnchorPoint = Vector2.new(0.5, 0)
wayLabel.Position = UDim2.new(0.5, 0, 0, 8)
wayLabel.Size = UDim2.new(0, 340, 0, 32)
wayLabel.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
wayLabel.BackgroundTransparency = 0.25
wayLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
wayLabel.Font = Enum.Font.LuckiestGuy
wayLabel.TextSize = 18
wayLabel.Visible = false
wayLabel.Parent = gui
local wlCorner = Instance.new("UICorner")
wlCorner.CornerRadius = UDim.new(0, 8)
wlCorner.Parent = wayLabel

local worldW, worldH = nil, nil
local mapBuilt = false
local waypoint = nil -- Vector3 (world)
local beacon = nil   -- client-only beam part

local function worldToMap(x, z)
	return UDim2.new(x / worldW, 0, z / worldH, 0)
end

local function buildMap()
	if mapBuilt then return false end
	local town = workspace:FindFirstChild("DiscoveryBay")
	if not town or not town:GetAttribute("BuildComplete") then return false end
	worldW = town:GetAttribute("WorldW")
	worldH = town:GetAttribute("WorldH")
	if not worldW or not worldH then return false end
	-- size the frame to 70% of screen height at the world's aspect ratio
	local vps = workspace.CurrentCamera.ViewportSize
	local hpx = math.floor(vps.Y * 0.7)
	local wpx = math.floor(hpx * (worldW / worldH))
	mapFrame.Size = UDim2.new(0, wpx, 0, hpx)
	local pxPerStud = hpx / worldH
	-- draw the road skeleton (skip service lanes/tracks; thin residential kept if long)
	local roadsFolder = town:FindFirstChild("Roads")
	local made = 0
	if roadsFolder then
		for _, rm in ipairs(roadsFolder:GetChildren()) do
			local cls = rm:GetAttribute("RoadClass")
			if cls ~= "s" and cls ~= "k" and made < 8000 then
				for _, seg in ipairs(rm:GetChildren()) do
					if seg.Name == "Seg" and seg:IsA("BasePart") then
						local len = seg.Size.Z
						if true then
							local lv = seg.CFrame.LookVector
							local line = Instance.new("Frame")
							line.AnchorPoint = Vector2.new(0.5, 0.5)
							line.Position = worldToMap(seg.Position.X, seg.Position.Z)
							line.Size = UDim2.new(0, math.max(3, len * pxPerStud + 2), 0,
								(cls == "r") and 2 or 3)
							line.Rotation = math.deg(math.atan2(lv.Z, lv.X))
							line.BackgroundColor3 = Color3.fromRGB(52, 52, 54)
							line.BorderSizePixel = 0
							line.ZIndex = 2
							line.Parent = mapFrame
							made = made + 1
							if made >= 8000 then break end
						end
					end
				end
			end
		end
	end
	-- shop markers
	local landmarks = town:FindFirstChild("Landmarks")
	local function dot(model, letter, color)
		if not model then return end
		local p = model:GetPivot().Position
		local dm = Instance.new("TextLabel")
		dm.AnchorPoint = Vector2.new(0.5, 0.5)
		dm.Position = worldToMap(p.X, p.Z)
		dm.Size = UDim2.new(0, 20, 0, 20)
		dm.BackgroundColor3 = color
		dm.TextColor3 = Color3.new(1, 1, 1)
		dm.Font = Enum.Font.LuckiestGuy
		dm.TextSize = 14
		dm.Text = letter
		dm.ZIndex = 6
		dm.Parent = mapFrame
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dm
	end
	if landmarks then
		local plaza = landmarks:FindFirstChild("Discovery Bay Blvd Plaza")
		dot(plaza and plaza:FindFirstChild("ShellBlox Gas Station"), "S", Color3.fromRGB(230, 180, 30))
		dot(plaza and plaza:FindFirstChild("Fish N Bait"), "F", Color3.fromRGB(60, 160, 220))
		dot(plaza and plaza:FindFirstChild("Callahan's Coffee and Cones"), "C", Color3.fromRGB(200, 100, 140))
		dot(plaza and plaza:FindFirstChild("Discovery Bay Jiu Jitsu"), "J", Color3.fromRGB(40, 45, 60))
		dot(landmarks:FindFirstChild("BLOXWAY"), "B", Color3.fromRGB(200, 60, 55))
		-- Discovery Bay Elementary (study buffs live here)
		local school = landmarks:FindFirstChild("Discovery Bay Elementary School")
		dot(school, "E", Color3.fromRGB(45, 90, 170))
		if school then
			local p = school:GetPivot().Position
			local u, v = p.X / worldW, p.Z / worldH
			local lbl = Instance.new("TextLabel")
			lbl.AnchorPoint = Vector2.new(0.5, 0)
			lbl.Position = UDim2.new(u, 0, v, 10)
			lbl.Size = UDim2.new(0, 160, 0, 14)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.LuckiestGuy
			lbl.TextSize = 11
			lbl.TextColor3 = Color3.new(1, 1, 1)
			lbl.TextStrokeTransparency = 0.3
			lbl.Text = "Discovery Bay Elementary"
			lbl.ZIndex = 7
			lbl.Parent = mapFrame
		end
	end
	-- every OTHER real named store in town (McDonald's, CVS, Starbucks, ...): purple
	-- dot + name label, exactly like the hero shops
	local bld = town:FindFirstChild("Buildings")
	if bld then
		local generic = { House = true, Commercial = true, School = true }
		local flip = false
		for _, model in ipairs(bld:GetChildren()) do
			if model:IsA("Model") and not generic[model.Name] then
				local p = model:GetPivot().Position
				local u, v = p.X / worldW, p.Z / worldH
				local dm = Instance.new("Frame")
				dm.AnchorPoint = Vector2.new(0.5, 0.5)
				dm.Position = UDim2.new(u, 0, v, 0)
				dm.Size = UDim2.new(0, 12, 0, 12)
				dm.BackgroundColor3 = Color3.fromRGB(170, 90, 200)
				dm.ZIndex = 6
				dm.Parent = mapFrame
				local dc = Instance.new("UICorner")
				dc.CornerRadius = UDim.new(1, 0)
				dc.Parent = dm
				local lbl = Instance.new("TextLabel")
				lbl.AnchorPoint = Vector2.new(0.5, 0)
				-- alternate label above/below so clustered stores stay readable
				lbl.Position = UDim2.new(u, 0, v, flip and -24 or 8)
				lbl.Size = UDim2.new(0, 120, 0, 14)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.LuckiestGuy
				lbl.TextSize = 11
				lbl.TextColor3 = Color3.new(1, 1, 1)
				lbl.TextStrokeTransparency = 0.3
				lbl.Text = model.Name
				lbl.ZIndex = 7
				lbl.Parent = mapFrame
				flip = not flip
			end
		end
	end
	mapBuilt = true
	return true
end

local function setWaypoint(wx, wz)
	waypoint = Vector3.new(wx, 0, wz)
	markPin.Visible = true
	markPin.Position = worldToMap(wx, wz)
	wayLabel.Visible = true
	if beacon then beacon:Destroy() end
	beacon = Instance.new("Part")
	beacon.Name = "WaypointBeacon"
	beacon.Size = Vector3.new(3, 400, 3)
	beacon.Position = Vector3.new(wx, 200, wz)
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 110, 110)
	beacon.Transparency = 0.35
	beacon.Parent = workspace -- client-only: nobody else sees your beacon
end

local function clearWaypoint()
	waypoint = nil
	markPin.Visible = false
	wayLabel.Visible = false
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end
clearBtn.Activated:Connect(clearWaypoint)

local function toggleMap()
	if not gui.Enabled then return end -- not during the intro
	if not mapGui.Enabled then
		if not buildMap() and not mapBuilt then return end
		mapGui.Enabled = true
	else
		mapGui.Enabled = false
	end
end
mapBtn.Activated:Connect(toggleMap)

mapFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		local rel = Vector2.new(input.Position.X, input.Position.Y) - mapFrame.AbsolutePosition
		local u = math.clamp(rel.X / mapFrame.AbsoluteSize.X, 0, 1)
		local v = math.clamp(rel.Y / mapFrame.AbsoluteSize.Y, 0, 1)
		setWaypoint(u * worldW, v * worldH)
	end
end)

-- live updates: player dot on the map, waypoint distance readout
RunService.Heartbeat:Connect(function()
	local ch = plr.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if hrp and mapGui.Enabled and worldW then
		playerDot.Position = worldToMap(hrp.Position.X, hrp.Position.Z)
	end
	if hrp and waypoint then
		local flat = Vector3.new(hrp.Position.X - waypoint.X, 0, hrp.Position.Z - waypoint.Z)
		wayLabel.Text = "Waypoint: " .. math.floor(flat.Magnitude) .. " studs"
	end
end)

-- trick input ------------------------------------------------------------------------------------
local lastClientTrickTime = 0
local function requestTrick(name)
	local now = os.clock()
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local isMounted = plr:GetAttribute("Mounted") or (char and char:FindFirstChild("Scooter") ~= nil)
	if isMounted and hum and hrp and hum.Health > 0 and (now - lastClientTrickTime >= 0.60) then
		lastClientTrickTime = now
		if hum.FloorMaterial ~= Enum.Material.Air then
			local v = hrp.AssemblyLinearVelocity
			local jumpV = 50
			if plr:GetAttribute("CarbLoad") then jumpV = 36 end
			if plr:GetAttribute("BeanPower") then jumpV = 85 end
			hrp.AssemblyLinearVelocity = Vector3.new(v.X, jumpV, v.Z)
		end
	end
	DoTrick:FireServer(name)
end
trickBtn.Activated:Connect(function()
	requestTrick(nil) -- random
end)
for _, t in ipairs(TRICKS) do
	trickButtons[t.name].Activated:Connect(function()
		requestTrick(t.name)
	end)
end
mountBtn.Activated:Connect(function()
	ToggleScooter:FireServer()
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.T then
		requestTrick(nil)
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		ToggleScooter:FireServer()
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		toggleMap()
		return
	end
	for _, t in ipairs(TRICKS) do
		if input.KeyCode == t.key then
			requestTrick(t.name)
			return
		end
	end
end)

--==============================================================================================
-- PET-SIM-X-STYLE HATCH: dimmed screen, big 3D egg wobbling center-screen, flash,
-- then the actual pet spinning in 3D with its name
--==============================================================================================
local DOG_LOOKS = { -- keep in sync with the server's DOGS table
	["Mary"]   = { color = Color3.fromRGB(38, 32, 30),    accent = Color3.fromRGB(150, 95, 50),
		scale = 1,    tag = "Mary!",                    tagColor = Color3.new(1, 1, 1) },
	["Jolene"] = { color = Color3.fromRGB(168, 170, 175), accent = Color3.fromRGB(245, 245, 245),
		scale = 1.25, tag = "Jolene!",                  tagColor = Color3.new(1, 1, 1) },
	["Linus"]  = { color = Color3.fromRGB(175, 125, 75),  accent = Color3.fromRGB(120, 80, 45),
		scale = 1,    tag = "LINUS  -  1% LEGENDARY!",  tagColor = Color3.fromRGB(255, 215, 80) },
}
local hatchOverlay = nil

HatchEgg.OnClientEvent:Connect(function(dogName)
	local look = DOG_LOOKS[dogName]
	if not look then return end
	if hatchOverlay then hatchOverlay:Destroy() end
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "HatchOverlay"
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.Parent = plr:WaitForChild("PlayerGui")
	hatchOverlay = overlay

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.Parent = overlay

	local vf = Instance.new("ViewportFrame")
	vf.AnchorPoint = Vector2.new(0.5, 0.5)
	vf.Position = UDim2.new(0.5, 0, 0.46, 0)
	vf.Size = UDim2.new(0, 420, 0, 420)
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(200, 200, 200)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.Parent = overlay
	local cam = Instance.new("Camera")
	cam.Parent = vf
	vf.CurrentCamera = cam
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.2, 9), Vector3.new(0, 0.6, 0))

	task.spawn(function()
		-- phase 1: the egg wobbles harder and harder
		local egg = Instance.new("Part")
		egg.Shape = Enum.PartType.Ball
		egg.Size = Vector3.new(4.4, 4.4, 4.4)
		egg.Color = Color3.fromRGB(250, 245, 228)
		egg.Parent = vf
		local sign = 1
		for i = 1, 14 do
			if not overlay.Parent then return end
			sign = -sign
			egg.CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(sign * (5 + i * 2)))
			task.wait(0.09)
		end
		-- flash
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BorderSizePixel = 0
		flash.Parent = overlay
		egg:Destroy()
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		task.delay(0.5, function() flash:Destroy() end)

		-- phase 2: the pet, in 3D, slowly spinning
		local k = look.scale
		local c, a = look.color, look.accent
		local function vpart(size, off, color, shape)
			local p = Instance.new("Part")
			p.Size = size * k
			p.CFrame = CFrame.new(off * k)
			p.Color = color
			p.Parent = vf
			if shape then p.Shape = shape end
			return p
		end
		vpart(Vector3.new(2.2, 1.8, 3.6), Vector3.new(0, 0, 0), c)
		vpart(Vector3.new(1.6, 1.2, 0.6), Vector3.new(0, -0.2, -1.7), a)
		vpart(Vector3.new(1.7, 1.7, 1.7), Vector3.new(0, 1.3, -1.9), c, Enum.PartType.Ball)
		vpart(Vector3.new(0.8, 0.6, 0.9), Vector3.new(0, 1, -2.8), a)
		vpart(Vector3.new(0.4, 0.9, 0.4), Vector3.new(-0.6, 2.2, -1.9), c)
		vpart(Vector3.new(0.4, 0.9, 0.4), Vector3.new(0.6, 2.2, -1.9), c)
		vpart(Vector3.new(0.4, 0.4, 1.5), Vector3.new(0, 0.8, 2.2), c)
		for _, lx in ipairs({ -0.7, 0.7 }) do
			for _, lz in ipairs({ -1.2, 1.2 }) do
				vpart(Vector3.new(0.6, 1.4, 0.6), Vector3.new(lx, -1.4, lz), lz < 0 and a or c)
			end
		end

		local tag = Instance.new("TextLabel")
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 0.72, 0)
		tag.Size = UDim2.new(1, 0, 0, 56)
		tag.BackgroundTransparency = 1
		tag.Font = Enum.Font.LuckiestGuy
		tag.TextSize = (dogName == "Linus") and 52 or 42
		tag.TextColor3 = look.tagColor
		tag.TextStrokeTransparency = 0.3
		tag.Text = look.tag
		tag.Parent = overlay

		-- orbit the camera around the pet for the reveal
		local t0 = os.clock()
		local spin = RunService.RenderStepped:Connect(function()
			local ang = (os.clock() - t0) * 1.6
			cam.CFrame = CFrame.lookAt(
				Vector3.new(math.sin(ang) * 9, 1.6, math.cos(ang) * 9),
				Vector3.new(0, 0.2, 0))
		end)
		task.wait(2.6)
		spin:Disconnect()
		if overlay.Parent then
			overlay:Destroy()
		end
		if hatchOverlay == overlay then hatchOverlay = nil end
	end)
end)

-- trick popups -----------------------------------------------------------------------------------
TrickResult.OnClientEvent:Connect(function(trickName, pay)
	-- "WX|" prefix = weather announcement: big banner across the top instead of a popup
	if type(trickName) == "string" and string.sub(trickName, 1, 3) == "WX|" then
		local banner = Instance.new("TextLabel")
		banner.AnchorPoint = Vector2.new(0.5, 0)
		banner.Position = UDim2.new(0.5, 0, 0.09, 0)
		banner.Size = UDim2.new(0, 860, 0, 56)
		banner.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
		banner.BackgroundTransparency = 0.25
		banner.Font = Enum.Font.LuckiestGuy
		banner.TextSize = 26
		banner.TextWrapped = true
		banner.TextColor3 = Color3.fromRGB(255, 225, 120)
		banner.TextStrokeTransparency = 0.4
		banner.Text = string.sub(trickName, 4)
		banner.Parent = gui
		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 12)
		bCorner.Parent = banner
		task.delay(5, function()
			TweenService:Create(banner, TweenInfo.new(0.8), {
				BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1,
			}):Play()
			task.delay(0.85, function()
				banner:Destroy()
			end)
		end)
		return
	end
	local pop = Instance.new("TextLabel")
	pop.AnchorPoint = Vector2.new(0, 1)
	pop.Position = UDim2.new(0, 20, 1, -140)
	pop.Size = UDim2.new(0, 320, 0, 34)
	pop.BackgroundTransparency = 1
	pop.Font = Enum.Font.LuckiestGuy
	pop.TextSize = 24
	pop.TextXAlignment = Enum.TextXAlignment.Left
	pop.TextStrokeTransparency = 0.4
	if pay and pay > 0 then
		pop.Text = "+$" .. pay .. "  " .. trickName .. "!"
		pop.TextColor3 = Color3.fromRGB(120, 230, 130)
		pcall(playSound, "rbxassetid://9061556942", 0.4) -- landing chime

		-- camera shake on landing a trick
		task.spawn(function()
			local cam = workspace.CurrentCamera
			if cam then
				local t = 0.15
				local speed = 25
				local size = 0.4
				local t0 = os.clock()
				while os.clock() - t0 < t do
					local elapsed = os.clock() - t0
					local offset = Vector3.new(
						math.sin(elapsed * speed) * size * (1 - elapsed/t),
						math.cos(elapsed * speed) * size * (1 - elapsed/t),
						0
					)
					cam.CFrame = cam.CFrame * CFrame.new(offset)
					task.wait()
				end
			end
		end)
	else
		pop.Text = trickName
		pop.TextColor3 = Color3.fromRGB(120, 200, 255)
		local lowerMsg = string.lower(trickName)
		if string.find(lowerMsg, "speed") or string.find(lowerMsg, "rush") or string.find(lowerMsg, "boost") then
			pcall(playSound, "rbxassetid://9061556942", 0.5) -- speed boost swoosh
		elseif string.find(lowerMsg, "cash") or string.find(lowerMsg, "purchase") or string.find(lowerMsg, "bought") or string.find(lowerMsg, "spent") or string.find(lowerMsg, "rent") then
			pcall(playSound, "rbxassetid://9059737151", 0.45) -- shop purchase cash register
		end
	end
	pop.Parent = gui
	TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 20, 1, -180),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		pop:Destroy()
	end)

	-- ==========================================
	-- CLIENT-SIDE TRICK ANIMATION (60fps RenderStepped)
	-- ==========================================
	if not (pay and pay > 0) then return end
	local char = plr.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Add a cool neon trail to the root part for visual flair!
	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 80, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 60)),
	})
	trail.Lifetime = 0.45
	trail.Transparency = NumberSequence.new(0, 1)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 2, 0)
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -2, 0)
	a0.Parent = hrp
	a1.Parent = hrp
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Parent = hrp
	task.delay(0.65, function()
		trail:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)

	if _G.StartScooterTrickAnim then
		_G.StartScooterTrickAnim(char, trickName)
	end
end)

-- 60fps Scooter Trick & Riding Movement Animator -------------------------------------------------
do
	local activeTrick = nil
	local smoothSteer = 0
	local smoothSpeed = 0
	local smoothCrouch = 0
	local wasMounted = false
	local wasAirborne = false
	local cachedBase = setmetatable({}, { __mode = "k" })

	local function getBaseC0(motor)
		if not motor then return nil end
		local attr = motor:GetAttribute("RideBaseC0")
		if attr then
			cachedBase[motor] = attr
			return attr
		end
		if not cachedBase[motor] then
			cachedBase[motor] = motor.C0
		end
		return cachedBase[motor]
	end

	-- Character joints are posed through .Transform (layered on top of the resting C0). On newer
	-- rigs some joints (e.g. the IK-driven shoulders/elbows) refuse C0 writes, and one refused
	-- write used to abort the whole frame, so the rider never leaned, crouched or kicked.
	-- Welds (R6 arm grips) have no Transform, so they keep using C0. Every write is guarded.
	local function pose(m, offset)
		if not m or not m.Parent then return end
		pcall(function()
			if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then
				m.Transform = offset
			else
				m.C0 = getBaseC0(m) * offset
			end
		end)
	end
	local function setC0(m, cf)
		if m and cf then pcall(function() m.C0 = cf end) end
	end

	local function restoreWalkC0(char)
		if not char then return end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") or d.Name == "LeftArmGrip" or d.Name == "RightArmGrip" then
				setC0(d, d:GetAttribute("WalkOrigC0") or cachedBase[d])
				if d:IsA("Motor6D") then d.Transform = CFrame.new() end
			end
		end
	end

	local function getJoints(char)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		local scooter = char:FindFirstChild("Scooter")
		local deckRoot = scooter and scooter:FindFirstChild("DeckRoot")
		local barRoot = scooter and scooter:FindFirstChild("BarRoot")
		local deckMount = deckRoot and deckRoot:FindFirstChild("DeckMount")
		local barMount = barRoot and barRoot:FindFirstChild("BarMount")

		local lowerTorso = char:FindFirstChild("LowerTorso")
		local upperTorso = char:FindFirstChild("UpperTorso")
		local torso = char:FindFirstChild("Torso")
		local head = char:FindFirstChild("Head")

		local root = (lowerTorso and lowerTorso:FindFirstChild("Root")) or (hrp and hrp:FindFirstChild("RootJoint"))
		local waist = upperTorso and upperTorso:FindFirstChild("Waist")
		local neck = (head and head:FindFirstChild("Neck")) or (torso and torso:FindFirstChild("Neck"))

		local lUpperArm = char:FindFirstChild("LeftUpperArm")
		local rUpperArm = char:FindFirstChild("RightUpperArm")
		local lLowerArm = char:FindFirstChild("LeftLowerArm")
		local rLowerArm = char:FindFirstChild("RightLowerArm")
		local lShoulder = (lUpperArm and lUpperArm:FindFirstChild("LeftShoulder")) or (torso and torso:FindFirstChild("LeftArmGrip"))
		local rShoulder = (rUpperArm and rUpperArm:FindFirstChild("RightShoulder")) or (torso and torso:FindFirstChild("RightArmGrip"))
		local lElbow = lLowerArm and lLowerArm:FindFirstChild("LeftElbow")
		local rElbow = rLowerArm and rLowerArm:FindFirstChild("RightElbow")

		local lUpperLeg = char:FindFirstChild("LeftUpperLeg")
		local rUpperLeg = char:FindFirstChild("RightUpperLeg")
		local lLowerLeg = char:FindFirstChild("LeftLowerLeg")
		local rLowerLeg = char:FindFirstChild("RightLowerLeg")
		local lHip = (lUpperLeg and lUpperLeg:FindFirstChild("LeftHip")) or (torso and torso:FindFirstChild("Left Hip"))
		local rHip = (rUpperLeg and rUpperLeg:FindFirstChild("RightHip")) or (torso and torso:FindFirstChild("Right Hip"))
		local lKnee = lLowerLeg and lLowerLeg:FindFirstChild("LeftKnee")
		local rKnee = rLowerLeg and rLowerLeg:FindFirstChild("RightKnee")

		return {
			hrp = hrp,
			hum = hum,
			scooter = scooter,
			deckMount = deckMount,
			barMount = barMount,
			deckY = (scooter and scooter:GetAttribute("DeckY")) or -3.0,
			root = root,
			isR6Root = (lowerTorso == nil),
			waist = waist,
			neck = neck,
			lShoulder = lShoulder,
			rShoulder = rShoulder,
			lElbow = lElbow,
			rElbow = rElbow,
			lHip = lHip,
			rHip = rHip,
			isR6Hip = (lUpperLeg == nil),
			lKnee = lKnee,
			rKnee = rKnee,
			lWrist = char:FindFirstChild("LeftHand") and char.LeftHand:FindFirstChild("LeftWrist"),
			rWrist = char:FindFirstChild("RightHand") and char.RightHand:FindFirstChild("RightWrist"),
		}
	end

	local function setIKEnabled(hum, enabled)
		if not hum then return end
		for _, name in ipairs({ "LeftHandGrip", "RightHandGrip" }) do
			local ik = hum:FindFirstChild(name)
			if ik and ik:IsA("IKControl") then
				ik.Enabled = enabled
			end
		end
	end

	-- Hands on the handlebar, solved here instead of by the server's IKControl: with no pole the
	-- IK twisted each upper arm ~95 degrees (arms jutting sideways, shoulders hunched). This is a
	-- plain two-bone solve: yaw + pitch the shoulder at the grip, bend the elbow (back and down)
	-- just enough for the hand to land on it.
	-- a joint's two frames: in Part0's space and in Part1's space (works for both joint types)
	local function jointFrames(m)
		if m:IsA("AnimationConstraint") then
			if m.Attachment0 and m.Attachment1 then
				return m.Attachment0.CFrame, m.Attachment1.CFrame, m.Attachment0.Parent
			end
		elseif m:IsA("Motor6D") then
			return m.C0, m.C1, m.Part0
		end
		return nil
	end
	-- smallest rotation that turns direction a into direction b
	local function rotBetween(a, b)
		a, b = a.Unit, b.Unit
		local dot = math.clamp(a:Dot(b), -1, 1)
		local axis = a:Cross(b)
		if axis.Magnitude < 1e-5 then
			if dot > 0 then return CFrame.new() end
			local perp = math.abs(a.X) < 0.9 and Vector3.xAxis or Vector3.yAxis
			return CFrame.fromAxisAngle(a:Cross(perp).Unit, math.pi)
		end
		return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
	end
	-- the real bone vectors come from the rig's own joint frames (the resting arm is NOT a straight
	-- drop below the shoulder pivot on every avatar), then each bone is rotated onto its solved direction
	local function aimArm(shoulder, elbow, wrist, target)
		if not (shoulder and elbow and wrist and target) then return end
		local sh0, sh1, torso = jointFrames(shoulder)
		local el0, el1 = jointFrames(elbow)
		local wr0, wr1 = jointFrames(wrist)
		if not (sh0 and el0 and wr0 and torso) then return end
		local sp = torso.CFrame * sh0                               -- shoulder pivot, world
		local u0 = sh1:PointToObjectSpace(el0.Position)             -- shoulder -> elbow at rest
		local f0 = el1:PointToObjectSpace((wr0 * wr1:Inverse()).Position) -- elbow -> hand centre at rest
		local L1, L2 = u0.Magnitude, f0.Magnitude
		local t = sp:PointToObjectSpace(target)
		local D = math.clamp(t.Magnitude, math.abs(L1 - L2) + 0.05, L1 + L2 - 0.001)
		local n = t.Unit
		-- elbows bend down, back and a little outward
		local side = sh0.Position.X >= 0 and 1 or -1
		local hint = Vector3.new(side * 0.35, -1, 0.8)
		local m = hint - n * hint:Dot(n)
		if m.Magnitude < 1e-4 then return end
		m = m.Unit
		local cosA = math.clamp((L1 * L1 + D * D - L2 * L2) / (2 * L1 * D), -1, 1)
		local e = n * (L1 * cosA) + m * (L1 * math.sqrt(1 - cosA * cosA)) -- elbow, shoulder frame
		local Ts = rotBetween(u0, e)
		pose(shoulder, Ts)
		local elbowFrame = Ts * sh1:Inverse() * el0
		local Te = rotBetween(f0, elbowFrame:VectorToObjectSpace(n * D - e))
		pose(elbow, Te)
	end
	local function gripTarget(hum, name)
		local ik = hum and hum:FindFirstChild(name)
		local att = ik and ik:IsA("IKControl") and ik.Target
		return att and att:IsA("Attachment") and att.WorldPosition or nil
	end
	local function aimArmsAtGrips(j)
		aimArm(j.lShoulder, j.lElbow, j.lWrist, gripTarget(j.hum, "LeftHandGrip"))
		aimArm(j.rShoulder, j.rElbow, j.rWrist, gripTarget(j.hum, "RightHandGrip"))
	end

	local function resetAllToBase(j)
		for _, k in ipairs({
			"deckMount", "barMount", "root", "waist", "neck",
			"lShoulder", "rShoulder", "lElbow", "rElbow",
			"lHip", "rHip", "lKnee", "rKnee",
		}) do
			local m = j[k]
			if k == "deckMount" or k == "barMount" then
				setC0(m, m and getBaseC0(m))
			else
				pose(m, CFrame.new())
			end
		end
		setIKEnabled(j.hum, false)
	end

	_G.StartScooterTrickAnim = function(char, trickName)
		local dur = 0.56
		if trickName == "Backflip" or trickName == "Frontflip" then
			dur = 0.60
		end
		activeTrick = {
			char = char,
			name = trickName,
			t0 = os.clock(),
			dur = dur,
			spinDir = (math.random() > 0.5) and 1 or -1,
		}
	end

	-- PreSimulation runs after the Animator and IKControl have written this frame's Transforms,
	-- so our poses are the ones that get drawn (in RenderStepped the Animator would overwrite them)
	RunService.PreSimulation:Connect(function(dt)
		if inTerryCutscene then return end
		local char = plr.Character
		if not char then return end
		local isMounted = plr:GetAttribute("Mounted") and (char:FindFirstChild("Scooter") ~= nil)
		if not isMounted then
			if activeTrick then
				local j = getJoints(char)
				resetAllToBase(j)
				activeTrick = nil
			end
			if wasMounted then
				wasMounted = false
				restoreWalkC0(char)
			end
			return
		end
		wasMounted = true

		local j = getJoints(char)
		if not j.hrp or not j.hum then return end

		if activeTrick and activeTrick.char == char then
			local elapsed = os.clock() - activeTrick.t0
			local p = math.clamp(elapsed / activeTrick.dur, 0, 1)
			local wave = math.sin(p * math.pi)
			local ang = p * math.pi * 2
			local name = activeTrick.name

			-- Only release hand IK during No-Hander and Kickflip; for Tailwhip, 360 Spin, Backflip,
			-- and Frontflip, keep hands holding the handlebars as the scooter flips/spins with you!
			local releaseHands = (name == "No-Hander" or name == "Kickflip")
			setIKEnabled(j.hum, false)

			-- Clear default R15/R6 Animate Transform on legs/torso (and arms only when IK is released)
			local clearKeys = releaseHands and {
				"root", "waist", "neck", "lShoulder", "rShoulder",
				"lElbow", "rElbow", "lHip", "rHip", "lKnee", "rKnee",
			} or {
				"root", "waist", "neck", "lHip", "rHip", "lKnee", "rKnee",
			}
			for _, k in ipairs(clearKeys) do
				local m = j[k]
				if m and m:IsA("Motor6D") then
					m.Transform = CFrame.new()
				end
			end

			if name == "Tailwhip" then
				local pivot = CFrame.new(0, j.deckY, -2.2)
				local deckRot = CFrame.Angles(0, ang, 0)
				if j.deckMount then
					setC0(j.deckMount, getBaseC0(j.deckMount) * pivot * deckRot * pivot:Inverse())
				end
				if j.barMount then
					setC0(j.barMount, getBaseC0(j.barMount) * CFrame.Angles(math.rad(-10 * wave), math.rad(22 * math.sin(ang)), math.rad(12 * math.sin(ang))))
				end
				if j.root then
					pose(j.root, CFrame.new(0, 0.85 * wave, 0) * CFrame.Angles(math.rad(-10 * wave), 0, 0))
				end
				if j.waist then
					pose(j.waist, CFrame.Angles(math.rad(-20 * wave), 0, 0))
				end
				if j.lHip and not j.isR6Hip then
					pose(j.lHip, CFrame.Angles(math.rad(65 * wave), 0, math.rad(10 * wave)))
				end
				if j.rHip and not j.isR6Hip then
					pose(j.rHip, CFrame.Angles(math.rad(65 * wave), 0, math.rad(-10 * wave)))
				end
				if j.lKnee then pose(j.lKnee, CFrame.Angles(math.rad(-65 * wave), 0, 0)) end
				if j.rKnee then pose(j.rKnee, CFrame.Angles(math.rad(-65 * wave), 0, 0)) end

			elseif name == "Kickflip" then
				local pivot = CFrame.new(0, j.deckY + 1.1, -0.4)
				local rollRot = CFrame.Angles(0, 0, ang)
				if j.deckMount then
					setC0(j.deckMount, getBaseC0(j.deckMount) * pivot * rollRot * pivot:Inverse())
				end
				if j.barMount then
					setC0(j.barMount, getBaseC0(j.barMount) * pivot * rollRot * pivot:Inverse())
				end
				if j.root then
					pose(j.root, CFrame.new(0, 0.95 * wave, 0) * CFrame.Angles(math.rad(10 * wave), 0, math.rad(16 * wave)))
				end
				if j.waist then
					pose(j.waist, CFrame.Angles(0, 0, math.rad(-20 * wave)))
				end
				if j.lHip and not j.isR6Hip then
					pose(j.lHip, CFrame.Angles(math.rad(58 * wave), 0, math.rad(25 * wave)))
				end
				if j.rHip and not j.isR6Hip then
					pose(j.rHip, CFrame.Angles(math.rad(-35 * wave), math.rad(-15 * wave), math.rad(-68 * wave)))
				end
				if j.lKnee then pose(j.lKnee, CFrame.Angles(math.rad(-55 * wave), 0, 0)) end
				if j.rKnee then pose(j.rKnee, CFrame.Angles(math.rad(-20 * wave), 0, 0)) end
				if j.lShoulder then
					pose(j.lShoulder, CFrame.Angles(math.rad(55 * wave), 0, math.rad(-42 * wave)))
				end
				if j.rShoulder then
					pose(j.rShoulder, CFrame.Angles(math.rad(55 * wave), 0, math.rad(42 * wave)))
				end

			elseif name == "360 Spin" then
				local dir = activeTrick.spinDir
				local spinCF = CFrame.new(0, 0.75 * wave, 0) * CFrame.Angles(0, ang * dir, math.rad(14 * wave * dir))
				if j.root then
					pose(j.root, spinCF)
				end
				if j.deckMount then
					setC0(j.deckMount, getBaseC0(j.deckMount) * spinCF)
				end
				if j.barMount then
					setC0(j.barMount, getBaseC0(j.barMount) * spinCF * CFrame.Angles(0, math.rad(45 * wave * dir), 0))
				end
				if j.waist then
					pose(j.waist, CFrame.Angles(math.rad(-14 * wave), math.rad(25 * wave * dir), 0))
				end
				if j.neck then
					pose(j.neck, CFrame.Angles(0, math.rad(30 * wave * dir), 0))
				end
				if j.lHip and not j.isR6Hip then pose(j.lHip, CFrame.Angles(math.rad(48 * wave), 0, 0)) end
				if j.rHip and not j.isR6Hip then pose(j.rHip, CFrame.Angles(math.rad(48 * wave), 0, 0)) end
				if j.lKnee then pose(j.lKnee, CFrame.Angles(math.rad(-52 * wave), 0, 0)) end
				if j.rKnee then pose(j.rKnee, CFrame.Angles(math.rad(-52 * wave), 0, 0)) end

			elseif name == "Backflip" or name == "Frontflip" then
				local sign = (name == "Backflip") and 1 or -1
				local flipCF = CFrame.new(0, 1.3 * wave, 0) * CFrame.Angles(ang * sign, 0, 0)
				if j.root then
					pose(j.root, flipCF)
				end
				if j.deckMount then
					setC0(j.deckMount, getBaseC0(j.deckMount) * flipCF)
				end
				if j.barMount then
					setC0(j.barMount, getBaseC0(j.barMount) * flipCF)
				end
				if j.waist then
					pose(j.waist, CFrame.Angles(math.rad(26 * wave * sign), 0, 0))
				end
				if j.neck then
					pose(j.neck, CFrame.Angles(math.rad(30 * wave * sign), 0, 0))
				end
				if j.lHip and not j.isR6Hip then pose(j.lHip, CFrame.Angles(math.rad(62 * wave), 0, 0)) end
				if j.rHip and not j.isR6Hip then pose(j.rHip, CFrame.Angles(math.rad(62 * wave), 0, 0)) end
				if j.lKnee then pose(j.lKnee, CFrame.Angles(math.rad(-72 * wave), 0, 0)) end
				if j.rKnee then pose(j.rKnee, CFrame.Angles(math.rad(-72 * wave), 0, 0)) end

			elseif name == "No-Hander" then
				local scooterTilt = CFrame.new(0, 0.5 * wave, 0) * CFrame.Angles(math.rad(22 * wave), 0, 0)
				if j.deckMount then setC0(j.deckMount, getBaseC0(j.deckMount) * scooterTilt) end
				if j.barMount then setC0(j.barMount, getBaseC0(j.barMount) * scooterTilt) end
				if j.root then
					pose(j.root, CFrame.new(0, 0.65 * wave, 0) * CFrame.Angles(math.rad(14 * wave), 0, 0))
				end
				if j.waist then
					pose(j.waist, CFrame.Angles(math.rad(28 * wave), 0, 0))
				end
				if j.neck then
					pose(j.neck, CFrame.Angles(math.rad(18 * wave), 0, 0))
				end
				if j.lShoulder then
					pose(j.lShoulder, CFrame.Angles(math.rad(120 * wave), 0, math.rad(-62 * wave)))
				end
				if j.rShoulder then
					pose(j.rShoulder, CFrame.Angles(math.rad(120 * wave), 0, math.rad(62 * wave)))
				end
				if j.lElbow then pose(j.lElbow, CFrame.Angles(math.rad(24 * wave), 0, 0)) end
				if j.rElbow then pose(j.rElbow, CFrame.Angles(math.rad(24 * wave), 0, 0)) end
				if j.lHip and not j.isR6Hip then pose(j.lHip, CFrame.Angles(math.rad(24 * wave), 0, math.rad(-10 * wave))) end
				if j.rHip and not j.isR6Hip then pose(j.rHip, CFrame.Angles(math.rad(24 * wave), 0, math.rad(10 * wave))) end
			end

			if not releaseHands then
				aimArmsAtGrips(j)
			end
			if p >= 1 then
				resetAllToBase(j)
				smoothCrouch = 0.7
				activeTrick = nil
			end
		else
			-- hands stay on the handlebar grips (solved at the end of this frame by aimArmsAtGrips)
			setIKEnabled(j.hum, false)
			for _, k in ipairs({ "root", "waist", "neck", "lHip", "rHip", "lKnee", "rKnee" }) do
				local m = j[k]
				if m and m:IsA("Motor6D") then
					m.Transform = CFrame.new()
				end
			end

			local vel = j.hrp.AssemblyLinearVelocity
			local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			local angVelY = j.hrp.AssemblyAngularVelocity.Y
			local inAir = (j.hum.FloorMaterial == Enum.Material.Air)
			if wasAirborne and not inAir then
				smoothCrouch = math.max(smoothCrouch, 0.65)
			end
			wasAirborne = inAir

			local targetSteer = math.clamp(angVelY * 0.18, -1, 1) * math.clamp(flatSpeed / 16, 0, 1)
			local targetSpeedFactor = math.clamp(flatSpeed / 34, 0, 1)
			local targetCrouch = inAir and 0.35 or 0
			smoothSteer = smoothSteer + (targetSteer - smoothSteer) * math.min(1, dt * 10)
			smoothSpeed = smoothSpeed + (targetSpeedFactor - smoothSpeed) * math.min(1, dt * 8)
			smoothCrouch = smoothCrouch + (targetCrouch - smoothCrouch) * math.min(1, dt * 7)

			local tNow = os.clock()
			local leanRoll = math.rad(14 * smoothSteer)
			local barYaw = math.rad(20 * smoothSteer)
			local bob = math.sin(tNow * 11) * 0.04 * smoothSpeed
			-- Both rider and scooter lean together so feet NEVER sink through the deck
			local leanCF = CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, leanRoll)

			local pushCycle = (tNow * 1.8) % 1
			local pushWave = (not inAir and smoothSpeed > 0.12 and pushCycle < 0.42)
				and math.sin((pushCycle / 0.42) * math.pi) * smoothSpeed or 0

			if j.root then
				-- body a third of a stud forward on the deck so the hands reach the grips
				pose(j.root, CFrame.new(0, 0, -0.35) * leanCF)
			end
			if j.deckMount then
				setC0(j.deckMount, getBaseC0(j.deckMount) * leanCF)
			end
			if j.barMount then
				setC0(j.barMount, getBaseC0(j.barMount) * leanCF * CFrame.Angles(0, barYaw, 0))
			end
			if j.waist then
				local waistPitch = math.rad(-16 - 6 * smoothSpeed - 12 * smoothCrouch - 5 * pushWave) -- riders lean in over the bar
				pose(j.waist, CFrame.Angles(waistPitch, math.rad(10 * smoothSteer), 0))
			end
			if j.neck then
				local neckPitch = math.rad(12 + 6 * smoothSpeed + 10 * smoothCrouch) -- head up to look ahead past the lean
				pose(j.neck, CFrame.Angles(neckPitch, math.rad(14 * smoothSteer), 0))
			end
			if j.lHip then
				if not j.isR6Hip then
					pose(j.lHip, CFrame.Angles(math.rad(16 * smoothCrouch), 0, 0))
				else
					pose(j.lHip, CFrame.Angles(0, 0, math.rad(16 * smoothCrouch)))
				end
			end
			if j.rHip then
				if not j.isR6Hip then
					pose(j.rHip, CFrame.Angles(math.rad(16 * smoothCrouch - 28 * pushWave), 0, math.rad(-8 * pushWave)))
				else
					pose(j.rHip, CFrame.Angles(0, 0, math.rad(-16 * smoothCrouch + 24 * pushWave)))
				end
			end
			if j.lKnee then
				pose(j.lKnee, CFrame.Angles(math.rad(-18 * smoothCrouch), 0, 0))
			end
			if j.rKnee then
				pose(j.rKnee, CFrame.Angles(math.rad(-18 * smoothCrouch - 22 * pushWave), 0, 0))
			end
			aimArmsAtGrips(j)
		end
	end)
end

-- FISHING minigame: FISH ON! stop the swinging marker inside the green zone ----------------------
local fishFrame = nil
FishGame.OnClientEvent:Connect(function()
	pcall(playSound, "rbxassetid://9061611394", 0.5) -- splash sound on fish hook
	if fishFrame then
		fishFrame:Destroy()
		fishFrame = nil
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.62, 0)
	frame.Size = UDim2.new(0, 400, 0, 170)
	frame.BackgroundColor3 = Color3.fromRGB(20, 40, 60)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	fishFrame = frame
	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(0, 16)
	fCorner.Parent = frame
	local title = Instance.new("TextLabel")
	title.Position = UDim2.new(0, 0, 0, 8)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextSize = 30
	title.TextColor3 = Color3.fromRGB(255, 225, 120)
	title.Text = "FISH ON!"
	title.Parent = frame
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 52)
	bar.Size = UDim2.new(0, 340, 0, 26)
	bar.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
	bar.Parent = frame
	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = bar
	local zoneW = 0.26
	local zoneX = 0.12 + math.random() * (1 - zoneW - 0.24)
	local zone = Instance.new("Frame")
	zone.Position = UDim2.fromScale(zoneX, 0)
	zone.Size = UDim2.fromScale(zoneW, 1)
	zone.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
	zone.Parent = bar
	local zCorner = Instance.new("UICorner")
	zCorner.CornerRadius = UDim.new(0, 8)
	zCorner.Parent = zone
	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Size = UDim2.new(0, 6, 1.3, 0)
	marker.Position = UDim2.fromScale(0.5, -0.15)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.ZIndex = 3
	marker.Parent = bar
	local reelBtn = Instance.new("TextButton")
	reelBtn.AnchorPoint = Vector2.new(0.5, 1)
	reelBtn.Position = UDim2.new(0.5, 0, 1, -12)
	reelBtn.Size = UDim2.new(0, 170, 0, 44)
	reelBtn.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	reelBtn.TextColor3 = Color3.fromRGB(40, 30, 10)
	reelBtn.Font = Enum.Font.LuckiestGuy
	reelBtn.TextSize = 24
	reelBtn.Text = "REEL!  (Space)"
	reelBtn.Parent = frame
	local rCorner = Instance.new("UICorner")
	rCorner.CornerRadius = UDim.new(0, 12)
	rCorner.Parent = reelBtn

	local pos = 0.5
	local t0 = os.clock()
	local moveConn = RunService.RenderStepped:Connect(function()
		pos = 0.5 + 0.5 * math.sin((os.clock() - t0) * 2.4)
		marker.Position = UDim2.fromScale(pos, -0.15)
	end)
	local keyConn = nil
	local done = false
	local function finish(success)
		if done then return end
		done = true
		moveConn:Disconnect()
		if keyConn then keyConn:Disconnect() end
		FishReel:FireServer(success)
		frame:Destroy()
		if fishFrame == frame then fishFrame = nil end
	end
	local function attempt()
		finish(pos >= zoneX and pos <= zoneX + zoneW)
	end
	reelBtn.Activated:Connect(attempt)
	keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Space then
			attempt()
		end
	end)
	task.delay(8, function()
		if not done and frame.Parent then
			finish(false)
		end
	end)
end)

--==============================================================================================
-- WASTED / DEATH SCREEN
--==============================================================================================
local ROASTS = {
	"Really bro?", "Did you even try?", "Skill issue.", "Oof, that was embarrassing.",
	"My grandma plays better than that.", "Try turning your monitor on.", "Was your controller upside down?",
	"Bro forgot how to play.", "Tragic.", "Better luck next time.", "You're built like a soggy noodle.",
	"Is your mouse unplugged?", "Imagine dying to that.", "Just uninstall at this point.",
	"That was painful to watch.", "Do you need a tutorial?", "Even a noob wouldn't do that.",
	"Rest in pieces.", "A spectacular failure.", "You tried... I think.", "Not your best moment.",
	"Wasted.", "You got absolutely deleted.", "F in the chat.", "Bruh.", "Get good.", 
	"I'm not mad, I'm just disappointed.", "Can we get a replay of that?", "That was definitely a choice.",
	"I'd say nice try, but it wasn't.", "Lag... right?", "Your Wi-Fi must be acting up.", 
	"It's okay to cry.", "Maybe try playing with your eyes open?", "Are you allergic to staying alive?",
	"That was a speedrun to the grave.", "Another one bites the dust.", "Yikes.", "Embarrassing.",
	"I've seen bots play better.", "You're a legend... at dying.", "Mission Failed. We'll get 'em next time.",
	"Take a breath and try again.", "You zigged when you should have zagged.", "A tragic end to a tragic life.",
	"You were doing so well... until you died.", "Absolutely cooked.", "You just got sent to the shadow realm.",
	"Go touch some grass.", "Did you drop your keyboard?", "Are you playing with your feet?", 
	"Wow. Just wow.", "That's going in the cringe compilation.", "You really just did that.",
	"Don't worry, nobody saw that.", "Except me. I saw that.", "You need some milk.", "He needs some milk!",
	"Are you practicing how to die?", "Flawless execution... of a death.", "That was a masterpiece of failure.",
	"Did someone unplug your router?", "Have you tried not dying?", "Error 404: Skill not found.",
	"You just got clapped.", "I hope you have insurance.", "That's gonna leave a mark.", 
	"You're making this look hard.", "Are you AFK?", "That was a creative way to go out.",
	"You belong in a museum of failures.", "Is this your first time playing?", "You are the weak link.",
	"Goodbye.", "You will not be remembered.", "A moment of silence for that play.", 
	"You really thought you could do that?", "I'm literally cringing.", "You're the reason there are warning labels.",
	"I'd clap, but I don't want to encourage that.", "That was a tactical death.", "It's all part of the plan, right?",
	"You're built different. (Incorrectly)", "Even gravity is disappointed in you.", "Please tell me you lagged.",
	"My eyes are burning from watching that.", "Do you want a participation trophy?", "At least you're consistent.",
	"Consistently bad.", "You're the tutorial boss.", "I have no words.", "That was historically bad.",
	"You should probably retire.", "Time for a new hobby.", "Are you even trying?", "That was a 10/10... on the fail scale.",
	"I've seen better gameplay from a toaster.", "You're just giving them free kills."
}

local deathGui = Instance.new("ScreenGui")
deathGui.Name = "DeathScreen"
deathGui.ResetOnSpawn = false
deathGui.IgnoreGuiInset = true
deathGui.Parent = plr:WaitForChild("PlayerGui")

local deathBG = Instance.new("Frame")
deathBG.Size = UDim2.new(1, 0, 1, 0)
deathBG.BackgroundColor3 = Color3.new(0, 0, 0)
deathBG.BackgroundTransparency = 1
deathBG.ZIndex = 100
deathBG.Parent = deathGui

local deathText = Instance.new("TextLabel")
deathText.Size = UDim2.new(1, 0, 0, 150)
deathText.Position = UDim2.new(0, 0, 0.5, -120)
deathText.BackgroundTransparency = 1
deathText.Font = Enum.Font.LuckiestGuy
deathText.Text = "DEAD"
deathText.TextColor3 = Color3.fromRGB(220, 20, 20)
deathText.TextStrokeColor3 = Color3.new(0, 0, 0)
deathText.TextStrokeTransparency = 1
deathText.TextScaled = true
deathText.TextTransparency = 1
deathText.ZIndex = 101
deathText.Parent = deathBG

local roastText = Instance.new("TextLabel")
roastText.Size = UDim2.new(1, 0, 0, 45)
roastText.Position = UDim2.new(0, 0, 0.5, 40)
roastText.BackgroundTransparency = 1
roastText.Font = Enum.Font.GothamBold
roastText.Text = ""
roastText.TextColor3 = Color3.fromRGB(255, 255, 255)
roastText.TextStrokeColor3 = Color3.new(0, 0, 0)
roastText.TextStrokeTransparency = 1
roastText.TextScaled = true
roastText.TextTransparency = 1
roastText.ZIndex = 101
roastText.Parent = deathBG

local deathColorCorrection = Instance.new("ColorCorrectionEffect")
deathColorCorrection.Saturation = 0
deathColorCorrection.Contrast = 0
deathColorCorrection.Parent = game:GetService("Lighting")

local isDead = false

local function onDied()
	if true then return end -- superseded by playGTAWasted()
	if isDead then return end
	isDead = true
	
	playSound("rbxassetid://413988628", 1) -- GTA 5 Wasted slowmo sound
	
	-- Stamp animation preparation
	deathText.Size = UDim2.new(1, 0, 0, 600)
	deathText.Position = UDim2.new(0, 0, 0.5, -300)
	deathText.TextTransparency = 1
	deathText.TextStrokeTransparency = 1
	roastText.TextTransparency = 1
	roastText.TextStrokeTransparency = 1
	roastText.Text = ROASTS[math.random(1, #ROASTS)]
	
	-- Darken and grayscale screen
	TweenService:Create(deathBG, TweenInfo.new(0.4), {BackgroundTransparency = 0.45}):Play()
	TweenService:Create(deathColorCorrection, TweenInfo.new(0.5), {Saturation = -1, Contrast = 0.2}):Play()
	
	task.wait(0.2)
	
	-- Slam stamp
	local stampTween = TweenService:Create(deathText, TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Size = UDim2.new(1, 0, 0, 180),
		Position = UDim2.new(0, 0, 0.5, -120),
		TextTransparency = 0,
		TextStrokeTransparency = 0
	})
	stampTween:Play()
	playSound("rbxassetid://138081509", 1) -- OOF / Slam sound
	
	task.wait(0.5)
	-- Fade in roast
	TweenService:Create(roastText, TweenInfo.new(0.5), {TextTransparency = 0, TextStrokeTransparency = 0.3}):Play()
end

local function onSpawn(char)
	if deathGui and deathGui.Parent then deathGui:Destroy() end
	if true then return end
	isDead = false
	-- Reset effects smoothly
	TweenService:Create(deathText, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	TweenService:Create(roastText, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	TweenService:Create(deathBG, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
	TweenService:Create(deathColorCorrection, TweenInfo.new(0.5), {Saturation = 0, Contrast = 0}):Play()
	
	local humanoid = char:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(onDied)
	end
end

if plr.Character then onSpawn(plr.Character) end
plr.CharacterAdded:Connect(onSpawn)
