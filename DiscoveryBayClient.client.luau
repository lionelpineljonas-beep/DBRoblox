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

local VERSION = "v102"
local SPEED_PASS_ID = 0 -- paste the real Game Pass ID here (same one as in DiscoveryBayShop)
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
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

-- Rebirth Button
local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Name = "RebirthBtn"
rebirthBtn.Size = UDim2.new(0, 160, 0, 50)
rebirthBtn.Position = UDim2.new(0, 20, 0.5, -25) -- Left middle
rebirthBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
rebirthBtn.Text = "REBIRTH"
rebirthBtn.Font = Enum.Font.LuckiestGuy
rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthBtn.TextSize = 16
rebirthBtn.Parent = gui

local rCorner = Instance.new("UICorner")
rCorner.CornerRadius = UDim.new(0, 8)
rCorner.Parent = rebirthBtn

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
		local origPos = UDim2.new(0, 20, 0.5, -25)
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
local questHighlight = nil

local questFrame = Instance.new("Frame")
questFrame.Name = "QuestTimerUI"
questFrame.AnchorPoint = Vector2.new(0, 0.5)
questFrame.Position = UDim2.new(0, 20, 0.5, 0)
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
	["Manager Bob"]   = { idle = "Stare",           interact = "Disbelief",       interactTalk = "Grr",            answer = "MrChuckles",     answerTalk = "Puck" },
	["Eggbert"]       = { idle = "GoodIntentioned", interact = "Skeptic",         interactTalk = "JoyousSurprise", answer = "JoyousSurprise", answerTalk = "GoodIntentioned" },
	["Captain Finn"]  = { idle = "CheckIt",         interact = "Winky",           interactTalk = "HappyWink",      answer = "Disbelief",      answerTalk = "Stare" },
	["Rider Rick"]    = { idle = "SureImCool",      interact = "Chill",           interactTalk = "SureImCool",     answer = "ItsGoTime",      answerTalk = "CheckIt" },
	["Callahan"]      = { idle = "Smile",           interact = "GoodIntentioned", interactTalk = "JoyousSurprise", answer = "HappyWink",      answerTalk = "Winky" },
	["Thirsty Terry"] = { idle = "Sniffles",        interact = "Disbelief",       interactTalk = "Sniffles",       answer = "Puck",           answerTalk = "Smile" },
	["Sal"]           = { idle = "Chill",           interact = "MrChuckles",      interactTalk = "Chill",          answer = "HappyWink",      answerTalk = "Winky" },
	["Sensei"]        = { idle = "Grr",             interact = "ItsGoTime",       interactTalk = "Roar",           answer = "Roar",           answerTalk = "Grr" },
	["Ms. Wheeler"]   = { idle = "Smile",           interact = "Winky",           interactTalk = "JoyousSurprise", answer = "JoyousSurprise", answerTalk = "Smile" },
	["Pedestrian"]    = { idle = "Smile",           interact = "GoodIntentioned", interactTalk = "Puck",           answer = "Slickfang",      answerTalk = "Vampire", panic = "Roar" },
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
end

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

local function endCutscene()
	activeTypewriter = nil
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

local function focusCameraOnNPC(npcModel, wideShot)
	local cam = workspace.CurrentCamera
	local head = npcModel and npcModel:FindFirstChild("Head")
	if not cam or not head then return end
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
		local lookTarget = (baseHeadCF * CFrame.new(0, 0, -14)).Position
		local camPos = (baseHeadCF * CFrame.new(10, 4.5, -6)).Position
		targetCF = CFrame.lookAt(camPos, lookTarget)
		targetFOV = 65
	else
		local camPos = (baseHeadCF * CFrame.new(0.65, 0.15, -4.5)).Position
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

local function hookNPC(prompt)
	local npcName = prompt.ObjectText
	task.spawn(function()
		local npcModel = prompt.Parent and prompt.Parent.Parent
		if not npcModel then return end
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
			showDialogue("Eggbert", "Psst! Mystery dogs in these eggs. Mostly Mary or Jolene... but one in a HUNDRED hatches Linus. Rent a house first - pups need a home!", {
				{ id = "linus", text = "Who's Linus?" }
			}, function(choiceId)
				if choiceId == "linus" then
					showDialogue("Eggbert", "A golden legend. Pays $100 a pet. I saw him hatch once. Changed my whole life.", {}, nil)
				end
			end)
		elseif npcName == "Captain Finn" then
			showDialogue("Captain Finn", "Ahoy! Grab a rod, grab bait, and cast into ANY water in the bay. When the bobber glows - REEL! I buy every fish in your inventory.", {
				{ id = "secret", text = "Any secret fish?" }
			}, function(choiceId)
				if choiceId == "secret" then
					showDialogue("Captain Finn", "They whisper of THE LIONEL. One cast in a hundred. Worth five hundred bucks. Never landed it myself... yet.", {}, nil)
				end
			end)
		elseif npcName == "Rider Rick" then
			showDialogue("Rider Rick", "Looking to upgrade? The Fast Scooter bumps your base speed up by 20. And yes, it stacks with the Speed Pass. Pure adrenaline.", {
				{ id = "gold", text = "Why gold?" }
			}, function(choiceId)
				if choiceId == "gold" then
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
			if not questActive and not questFound then
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
				setNPCFaceState(npcModel, "answer")
				showDialogue("Thirsty Terry", "You found it! Thank you so much! Here's $200!", {}, nil)
				game:GetService("ReplicatedStorage"):WaitForChild("DiscoveryBayRemotes"):WaitForChild("CompleteQuest"):FireServer("TerrysSoda")
				questActive = false
				questFound = false
				questFrame.Visible = false
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
			showDialogue("Sensei", "Step on the grey mat to begin your training. Seven buttons. Five seconds each. Miss and you PAY. Win, and you feast: $50.", {
				{ id = "advice", text = "Any advice?" }
			}, function(choiceId)
				if choiceId == "advice" then
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
					showDialogue("Pedestrian", "I am very smart, watch this!", {}, nil)
					task.delay(1.1, function()
						if npcModel and npcModel.Parent then setNPCFaceState(npcModel, "panic") end
					end)
					task.delay(4.2, function()
						if npcModel and npcModel.Parent then setNPCFaceState(npcModel, "idle") end
					end)
					task.delay(2.5, function()
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
	panBody.TextColor3 = Color3.fromRGB(60, 70, 80)
	panBody.TextWrapped = true
	panBody.TextXAlignment = Enum.TextXAlignment.Left
	panBody.TextYAlignment = Enum.TextYAlignment.Top
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

local money = Instance.new("TextLabel")
money.Name = "Money"
money.AnchorPoint = Vector2.new(0, 1)
money.Position = UDim2.new(0, 16, 1, -16)
money.Size = UDim2.new(0, 190, 0, 46)
money.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
money.BackgroundTransparency = 0.25
money.TextColor3 = Color3.fromRGB(120, 230, 130)
money.Font = Enum.Font.LuckiestGuy
money.TextSize = 26
money.Text = "$ ..."
money.Parent = gui
local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 10)
mCorner.Parent = money

-- dismount / ride toggle, stacked above the money readout
local mountBtn = Instance.new("TextButton")
mountBtn.Name = "MountToggle"
mountBtn.AnchorPoint = Vector2.new(0, 1)
mountBtn.Position = UDim2.new(0, 16, 1, -70)
mountBtn.Size = UDim2.new(0, 190, 0, 42)
mountBtn.BackgroundColor3 = Color3.fromRGB(70, 160, 220)
mountBtn.TextColor3 = Color3.new(1, 1, 1)
mountBtn.Font = Enum.Font.LuckiestGuy
mountBtn.TextSize = 18
mountBtn.Text = "Get Off  (G)"
mountBtn.Parent = gui
local mtCorner = Instance.new("UICorner")
mtCorner.CornerRadius = UDim.new(0, 10)
mtCorner.Parent = mountBtn

local ClaimPity = remotes:WaitForChild("ClaimPity")

local pityLabel = Instance.new("TextButton")
pityLabel.Name = "PityLabel"
pityLabel.AnchorPoint = Vector2.new(0, 1)
pityLabel.Position = UDim2.new(0, 16, 1, -120)
pityLabel.Size = UDim2.new(0, 190, 0, 36)
pityLabel.BackgroundColor3 = Color3.fromRGB(130, 40, 160)
pityLabel.TextColor3 = Color3.new(1, 1, 1)
pityLabel.Font = Enum.Font.LuckiestGuy
pityLabel.TextSize = 15
pityLabel.Text = "Pity: 90 rolls until Linus"
pityLabel.Parent = gui
local plCorner = Instance.new("UICorner")
plCorner.CornerRadius = UDim.new(0, 8)
plCorner.Parent = pityLabel

local currentPityRollsLeft = 90
UpdatePity.OnClientEvent:Connect(function(rollsLeft)
	currentPityRollsLeft = rollsLeft
	if rollsLeft <= 0 then
		pityLabel.Text = "CLAIM PITY LINUS!"
		pityLabel.BackgroundColor3 = Color3.fromRGB(250, 180, 20)
	else
		pityLabel.Text = "Pity: " .. tostring(rollsLeft) .. " rolls until Linus"
		pityLabel.BackgroundColor3 = Color3.fromRGB(130, 40, 160)
	end
end)

pityLabel.Activated:Connect(function()
	if currentPityRollsLeft <= 0 then
		ClaimPity:FireServer()
	end
end)

-- map toggle, stacked above the pity label
local mapBtn = Instance.new("TextButton")
mapBtn.Name = "MapToggle"
mapBtn.AnchorPoint = Vector2.new(0, 1)
mapBtn.Position = UDim2.new(0, 16, 1, -164)
mapBtn.Size = UDim2.new(0, 190, 0, 42)
mapBtn.BackgroundColor3 = Color3.fromRGB(72, 96, 64)
mapBtn.TextColor3 = Color3.new(1, 1, 1)
mapBtn.Font = Enum.Font.LuckiestGuy
mapBtn.TextSize = 18
mapBtn.Text = "Map  (M)"
mapBtn.Parent = gui
local mbCorner = Instance.new("UICorner")
mbCorner.CornerRadius = UDim.new(0, 10)
mbCorner.Parent = mapBtn

-- inf money debug button
local moneyBtn = Instance.new("TextButton")
moneyBtn.Name = "DebugMoney"
moneyBtn.AnchorPoint = Vector2.new(0, 1)
moneyBtn.Position = UDim2.new(0, 16, 1, -214)
moneyBtn.Size = UDim2.new(0, 190, 0, 36)
moneyBtn.BackgroundColor3 = Color3.fromRGB(20, 120, 40)
moneyBtn.TextColor3 = Color3.new(1, 1, 1)
moneyBtn.Font = Enum.Font.LuckiestGuy
moneyBtn.TextSize = 15
moneyBtn.Text = "Debug: Inf Money"
moneyBtn.Parent = gui
local mb2Corner = Instance.new("UICorner")
mb2Corner.CornerRadius = UDim.new(0, 8)
mb2Corner.Parent = moneyBtn

moneyBtn.Activated:Connect(function()
	if InfiniteMoney then
		InfiniteMoney:FireServer()
	end
end)

-- Robux shop toggle, stacked above the money debug button
local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopToggle"
shopBtn.AnchorPoint = Vector2.new(0, 1)
shopBtn.Position = UDim2.new(0, 16, 1, -258)
shopBtn.Size = UDim2.new(0, 190, 0, 42)
shopBtn.BackgroundColor3 = Color3.fromRGB(190, 120, 40)
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.Font = Enum.Font.LuckiestGuy
shopBtn.TextSize = 18
shopBtn.Text = "Shop"
shopBtn.Parent = gui
local shCorner = Instance.new("UICorner")
shCorner.CornerRadius = UDim.new(0, 10)
shCorner.Parent = shopBtn

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

shopBtn.Activated:Connect(function()
	if gui.Enabled then
		shopPage.Visible = not shopPage.Visible
	end
end)
shopClose.Activated:Connect(function()
	shopPage.Visible = false
end)

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
verTag.Position = UDim2.new(0, 16, 1, -208)
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
		mountBtn.Text = "Ride Scooter  (G)"
		mountBtn.BackgroundColor3 = Color3.fromRGB(80, 190, 120)
	end
end
plr:GetAttributeChangedSignal("Mounted"):Connect(refreshMountBtn)
refreshMountBtn()

-- trick menu: one button per trick + key shortcuts; T = random.
-- (letters, not number keys - Roblox's tool hotbar swallows 1-9 once you own items)
local TRICKS = {
	{ key = Enum.KeyCode.Z, label = "Z", name = "Tailwhip",  pay = 4 },
	{ key = Enum.KeyCode.X, label = "X", name = "Kickflip",  pay = 3 },
	{ key = Enum.KeyCode.C, label = "C", name = "360 Spin",  pay = 6 },
	{ key = Enum.KeyCode.V, label = "V", name = "Backflip",  pay = 10 },
	{ key = Enum.KeyCode.B, label = "B", name = "Frontflip", pay = 10 },
	{ key = Enum.KeyCode.N, label = "N", name = "No-Hander", pay = 5 },
}

local menu = Instance.new("ScrollingFrame")
menu.Name = "TrickMenu"
menu.AnchorPoint = Vector2.new(1, 1)
menu.Position = UDim2.new(1, -16, 1, -16)
menu.Size = UDim2.new(0, 180, 0, 4 * 40 + 64)
menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.ScrollBarThickness = 8
menu.CanvasSize = UDim2.new(0, 0, 0, 7 * 40 + 64)
menu.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Parent = menu

local trickButtons = {}
for _, t in ipairs(TRICKS) do
	local btn = Instance.new("TextButton")
	btn.Name = t.name
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(30, 38, 48)
	btn.BackgroundTransparency = 0.2
	btn.TextColor3 = Color3.fromRGB(235, 235, 235)
	btn.Font = Enum.Font.LuckiestGuy
	btn.TextSize = 16
	btn.Text = t.label .. "  -  " .. t.name .. "  -  $" .. t.pay
	btn.Parent = menu
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn
	trickButtons[t.name] = btn
end

local trickBtn = Instance.new("TextButton")
trickBtn.Name = "RandomTrick"
trickBtn.Size = UDim2.new(1, 0, 0, 52)
trickBtn.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
trickBtn.TextColor3 = Color3.fromRGB(40, 30, 10)
trickBtn.Font = Enum.Font.LuckiestGuy
trickBtn.TextSize = 22
trickBtn.Text = "TRICK!  (T)"
trickBtn.Parent = menu
local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 12)
tCorner.Parent = trickBtn

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
			if cls ~= "s" and cls ~= "k" and made < 2600 then
				for _, seg in ipairs(rm:GetChildren()) do
					if seg.Name == "Seg" and seg:IsA("BasePart") then
						local len = seg.Size.Z
						if cls ~= "r" or len > 60 then
							local lv = seg.CFrame.LookVector
							local line = Instance.new("Frame")
							line.AnchorPoint = Vector2.new(0.5, 0.5)
							line.Position = worldToMap(seg.Position.X, seg.Position.Z)
							line.Size = UDim2.new(0, math.max(2, len * pxPerStud), 0,
								(cls == "r") and 2 or 3)
							line.Rotation = math.deg(math.atan2(lv.Z, lv.X))
							line.BackgroundColor3 = Color3.fromRGB(52, 52, 54)
							line.BorderSizePixel = 0
							line.ZIndex = 2
							line.Parent = mapFrame
							made = made + 1
							if made >= 2600 then break end
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

	local function restoreWalkC0(char)
		if not char then return end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("Motor6D") or d.Name == "LeftArmGrip" or d.Name == "RightArmGrip" then
				local walkC0 = d:GetAttribute("WalkOrigC0") or cachedBase[d]
				if walkC0 then
					d.C0 = walkC0
				end
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

	local function resetAllToBase(j)
		for _, k in ipairs({
			"deckMount", "barMount", "root", "waist", "neck",
			"lShoulder", "rShoulder", "lElbow", "rElbow",
			"lHip", "rHip", "lKnee", "rKnee",
		}) do
			local m = j[k]
			if m and m.Parent then
				local base = getBaseC0(m)
				if base then m.C0 = base end
			end
		end
		setIKEnabled(j.hum, true)
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

	RunService.RenderStepped:Connect(function(dt)
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
			setIKEnabled(j.hum, not releaseHands)

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
					j.deckMount.C0 = getBaseC0(j.deckMount) * pivot * deckRot * pivot:Inverse()
				end
				if j.barMount then
					j.barMount.C0 = getBaseC0(j.barMount) * CFrame.Angles(math.rad(-10 * wave), math.rad(22 * math.sin(ang)), math.rad(12 * math.sin(ang)))
				end
				if j.root then
					j.root.C0 = getBaseC0(j.root) * CFrame.new(0, 0.85 * wave, 0) * CFrame.Angles(math.rad(-10 * wave), 0, 0)
				end
				if j.waist then
					j.waist.C0 = getBaseC0(j.waist) * CFrame.Angles(math.rad(-20 * wave), 0, 0)
				end
				if j.lHip and not j.isR6Hip then
					j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(math.rad(65 * wave), 0, math.rad(10 * wave))
				end
				if j.rHip and not j.isR6Hip then
					j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(math.rad(65 * wave), 0, math.rad(-10 * wave))
				end
				if j.lKnee then j.lKnee.C0 = getBaseC0(j.lKnee) * CFrame.Angles(math.rad(-65 * wave), 0, 0) end
				if j.rKnee then j.rKnee.C0 = getBaseC0(j.rKnee) * CFrame.Angles(math.rad(-65 * wave), 0, 0) end

			elseif name == "Kickflip" then
				local pivot = CFrame.new(0, j.deckY + 1.1, -0.4)
				local rollRot = CFrame.Angles(0, 0, ang)
				if j.deckMount then
					j.deckMount.C0 = getBaseC0(j.deckMount) * pivot * rollRot * pivot:Inverse()
				end
				if j.barMount then
					j.barMount.C0 = getBaseC0(j.barMount) * pivot * rollRot * pivot:Inverse()
				end
				if j.root then
					j.root.C0 = getBaseC0(j.root) * CFrame.new(0, 0.95 * wave, 0) * CFrame.Angles(math.rad(10 * wave), 0, math.rad(16 * wave))
				end
				if j.waist then
					j.waist.C0 = getBaseC0(j.waist) * CFrame.Angles(0, 0, math.rad(-20 * wave))
				end
				if j.lHip and not j.isR6Hip then
					j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(math.rad(58 * wave), 0, math.rad(25 * wave))
				end
				if j.rHip and not j.isR6Hip then
					j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(math.rad(-35 * wave), math.rad(-15 * wave), math.rad(-68 * wave))
				end
				if j.lKnee then j.lKnee.C0 = getBaseC0(j.lKnee) * CFrame.Angles(math.rad(-55 * wave), 0, 0) end
				if j.rKnee then j.rKnee.C0 = getBaseC0(j.rKnee) * CFrame.Angles(math.rad(-20 * wave), 0, 0) end
				if j.lShoulder then
					j.lShoulder.C0 = getBaseC0(j.lShoulder) * CFrame.Angles(math.rad(55 * wave), 0, math.rad(-42 * wave))
				end
				if j.rShoulder then
					j.rShoulder.C0 = getBaseC0(j.rShoulder) * CFrame.Angles(math.rad(55 * wave), 0, math.rad(42 * wave))
				end

			elseif name == "360 Spin" then
				local dir = activeTrick.spinDir
				local spinCF = CFrame.new(0, 0.75 * wave, 0) * CFrame.Angles(0, ang * dir, math.rad(14 * wave * dir))
				if j.root then
					j.root.C0 = getBaseC0(j.root) * spinCF
				end
				if j.deckMount then
					j.deckMount.C0 = getBaseC0(j.deckMount) * spinCF
				end
				if j.barMount then
					j.barMount.C0 = getBaseC0(j.barMount) * spinCF * CFrame.Angles(0, math.rad(45 * wave * dir), 0)
				end
				if j.waist then
					j.waist.C0 = getBaseC0(j.waist) * CFrame.Angles(math.rad(-14 * wave), math.rad(25 * wave * dir), 0)
				end
				if j.neck then
					j.neck.C0 = getBaseC0(j.neck) * CFrame.Angles(0, math.rad(30 * wave * dir), 0)
				end
				if j.lHip and not j.isR6Hip then j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(math.rad(48 * wave), 0, 0) end
				if j.rHip and not j.isR6Hip then j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(math.rad(48 * wave), 0, 0) end
				if j.lKnee then j.lKnee.C0 = getBaseC0(j.lKnee) * CFrame.Angles(math.rad(-52 * wave), 0, 0) end
				if j.rKnee then j.rKnee.C0 = getBaseC0(j.rKnee) * CFrame.Angles(math.rad(-52 * wave), 0, 0) end

			elseif name == "Backflip" or name == "Frontflip" then
				local sign = (name == "Backflip") and 1 or -1
				local flipCF = CFrame.new(0, 1.3 * wave, 0) * CFrame.Angles(ang * sign, 0, 0)
				if j.root then
					j.root.C0 = getBaseC0(j.root) * flipCF
				end
				if j.deckMount then
					j.deckMount.C0 = getBaseC0(j.deckMount) * flipCF
				end
				if j.barMount then
					j.barMount.C0 = getBaseC0(j.barMount) * flipCF
				end
				if j.waist then
					j.waist.C0 = getBaseC0(j.waist) * CFrame.Angles(math.rad(26 * wave * sign), 0, 0)
				end
				if j.neck then
					j.neck.C0 = getBaseC0(j.neck) * CFrame.Angles(math.rad(30 * wave * sign), 0, 0)
				end
				if j.lHip and not j.isR6Hip then j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(math.rad(62 * wave), 0, 0) end
				if j.rHip and not j.isR6Hip then j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(math.rad(62 * wave), 0, 0) end
				if j.lKnee then j.lKnee.C0 = getBaseC0(j.lKnee) * CFrame.Angles(math.rad(-72 * wave), 0, 0) end
				if j.rKnee then j.rKnee.C0 = getBaseC0(j.rKnee) * CFrame.Angles(math.rad(-72 * wave), 0, 0) end

			elseif name == "No-Hander" then
				local scooterTilt = CFrame.new(0, 0.5 * wave, 0) * CFrame.Angles(math.rad(22 * wave), 0, 0)
				if j.deckMount then j.deckMount.C0 = getBaseC0(j.deckMount) * scooterTilt end
				if j.barMount then j.barMount.C0 = getBaseC0(j.barMount) * scooterTilt end
				if j.root then
					j.root.C0 = getBaseC0(j.root) * CFrame.new(0, 0.65 * wave, 0) * CFrame.Angles(math.rad(14 * wave), 0, 0)
				end
				if j.waist then
					j.waist.C0 = getBaseC0(j.waist) * CFrame.Angles(math.rad(28 * wave), 0, 0)
				end
				if j.neck then
					j.neck.C0 = getBaseC0(j.neck) * CFrame.Angles(math.rad(18 * wave), 0, 0)
				end
				if j.lShoulder then
					j.lShoulder.C0 = getBaseC0(j.lShoulder) * CFrame.Angles(math.rad(120 * wave), 0, math.rad(-62 * wave))
				end
				if j.rShoulder then
					j.rShoulder.C0 = getBaseC0(j.rShoulder) * CFrame.Angles(math.rad(120 * wave), 0, math.rad(62 * wave))
				end
				if j.lElbow then j.lElbow.C0 = getBaseC0(j.lElbow) * CFrame.Angles(math.rad(24 * wave), 0, 0) end
				if j.rElbow then j.rElbow.C0 = getBaseC0(j.rElbow) * CFrame.Angles(math.rad(24 * wave), 0, 0) end
				if j.lHip and not j.isR6Hip then j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(math.rad(24 * wave), 0, math.rad(-10 * wave)) end
				if j.rHip and not j.isR6Hip then j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(math.rad(24 * wave), 0, math.rad(10 * wave)) end
			end

			if p >= 1 then
				resetAllToBase(j)
				smoothCrouch = 0.7
				activeTrick = nil
			end
		else
			-- Keep hand IK grips locked onto the handlebars at all times while riding!
			-- NEVER zero Transform on lShoulder/rShoulder/lElbow/rElbow here because IKControl writes its solution to Transform!
			setIKEnabled(j.hum, true)
			for _, k in ipairs({ "root", "waist", "neck", "lHip", "rHip", "lKnee", "rKnee" }) do
				local m = j[k]
				if m and m:IsA("Motor6D") then
					m.Transform = CFrame.new()
				end
			end
			-- Ensure shoulder/elbow C0 stays at base so IKControl solves cleanly to the handlebars
			for _, k in ipairs({ "lShoulder", "rShoulder", "lElbow", "rElbow" }) do
				local m = j[k]
				if m and m.Parent then
					local base = getBaseC0(m)
					if base then m.C0 = base end
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
				j.root.C0 = getBaseC0(j.root) * leanCF
			end
			if j.deckMount then
				j.deckMount.C0 = getBaseC0(j.deckMount) * leanCF
			end
			if j.barMount then
				j.barMount.C0 = getBaseC0(j.barMount) * leanCF * CFrame.Angles(0, barYaw, 0)
			end
			if j.waist then
				local waistPitch = math.rad(-8 * smoothSpeed - 12 * smoothCrouch - 5 * pushWave)
				j.waist.C0 = getBaseC0(j.waist) * CFrame.Angles(waistPitch, math.rad(10 * smoothSteer), 0)
			end
			if j.neck then
				local neckPitch = math.rad(8 * smoothSpeed + 10 * smoothCrouch)
				j.neck.C0 = getBaseC0(j.neck) * CFrame.Angles(neckPitch, math.rad(14 * smoothSteer), 0)
			end
			if j.lHip then
				if not j.isR6Hip then
					j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(math.rad(16 * smoothCrouch), 0, 0)
				else
					j.lHip.C0 = getBaseC0(j.lHip) * CFrame.Angles(0, 0, math.rad(16 * smoothCrouch))
				end
			end
			if j.rHip then
				if not j.isR6Hip then
					j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(math.rad(16 * smoothCrouch - 28 * pushWave), 0, math.rad(-8 * pushWave))
				else
					j.rHip.C0 = getBaseC0(j.rHip) * CFrame.Angles(0, 0, math.rad(-16 * smoothCrouch + 24 * pushWave))
				end
			end
			if j.lKnee then
				j.lKnee.C0 = getBaseC0(j.lKnee) * CFrame.Angles(math.rad(-18 * smoothCrouch), 0, 0)
			end
			if j.rKnee then
				j.rKnee.C0 = getBaseC0(j.rKnee) * CFrame.Angles(math.rad(-18 * smoothCrouch - 22 * pushWave), 0, 0)
			end
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
