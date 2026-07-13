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

local VERSION = "v41"
local SPEED_PASS_ID = 0 -- paste the real Game Pass ID here (same one as in DiscoveryBayShop)
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("DiscoveryBayRemotes", 60)
if not remotes then return end
local DoTrick = remotes:WaitForChild("DoTrick")
local TrickResult = remotes:WaitForChild("TrickResult")
local ToggleScooter = remotes:WaitForChild("ToggleScooter")
local HatchEgg = remotes:WaitForChild("HatchEgg")
local FishGame = remotes:WaitForChild("FishGame")
local FishReel = remotes:WaitForChild("FishReel")

-- background music: Roblox's own licensed "Lofi Chill A" (free-to-use library track),
-- looping softly from the moment you join
task.spawn(function()
	local SoundService = game:GetService("SoundService")
	local music = Instance.new("Sound")
	music.Name = "DiscoveryBayMusic"
	music.SoundId = "rbxassetid://9043887091"
	music.Looped = true
	music.Volume = 0.35
	music.Parent = SoundService
	music:Play()
	task.delay(10, function()
		if not music.IsLoaded then
			music:Destroy() -- failed to load: leave silence rather than a broken player
		end
	end)
end)

-- HUD ------------------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DiscoveryBayHUD"
gui.ResetOnSpawn = false
gui.Enabled = false -- hidden until the intro's PLAY button is pressed
gui.Parent = plr:WaitForChild("PlayerGui")

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
	title.Font = Enum.Font.FredokaOne
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
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextSize = 20
	subtitle.TextColor3 = Color3.fromRGB(220, 228, 235)
	subtitle.TextStrokeTransparency = 0.6
	subtitle.Text = "California Delta - scooters - " .. VERSION
	subtitle.ZIndex = 8
	subtitle.Parent = introGui

	-- grey loading cover with a spinning bubbly "L" while the town builds
	local loadFrame = Instance.new("Frame")
	loadFrame.Size = UDim2.fromScale(1, 1)
	loadFrame.BackgroundColor3 = Color3.fromRGB(128, 131, 136)
	loadFrame.BorderSizePixel = 0
	loadFrame.ZIndex = 5
	loadFrame.Parent = introGui
	local loadTxt = Instance.new("TextLabel")
	loadTxt.AnchorPoint = Vector2.new(0.5, 0.5)
	loadTxt.Position = UDim2.new(0.5, 0, 0.5, 0)
	loadTxt.Size = UDim2.new(0, 500, 0, 40)
	loadTxt.BackgroundTransparency = 1
	loadTxt.Font = Enum.Font.FredokaOne
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
	spinner.Font = Enum.Font.FredokaOne
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
	-- town ready: drop the spinner but KEEP the flat grey background (no world peek)
	spinConn:Disconnect()
	spinner:Destroy()
	loadTxt:Destroy()

	local playBtn = Instance.new("TextButton")
	playBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	playBtn.Position = UDim2.new(0.5, 0, 0.74, 0)
	playBtn.Size = UDim2.new(0, 260, 0, 84)
	playBtn.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	playBtn.TextColor3 = Color3.fromRGB(40, 30, 10)
	playBtn.Font = Enum.Font.FredokaOne
	playBtn.TextSize = 40
	playBtn.Text = "PLAY"
	playBtn.BackgroundTransparency = 1
	playBtn.TextTransparency = 1
	playBtn.ZIndex = 8 -- above the grey cover
	playBtn.Parent = introGui
	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 18)
	pCorner.Parent = playBtn
	TweenService:Create(playBtn, TweenInfo.new(0.6), {
		BackgroundTransparency = 0, TextTransparency = 0,
	}):Play()

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
	panTitle.Position = UDim2.new(0, 20, 0, 12)
	panTitle.Size = UDim2.new(1, -40, 0, 40)
	panTitle.BackgroundTransparency = 1
	panTitle.Font = Enum.Font.FredokaOne
	panTitle.TextSize = 28
	panTitle.TextColor3 = Color3.fromRGB(250, 205, 30)
	panTitle.ZIndex = 10
	panTitle.Parent = panel
	local panBody = Instance.new("TextLabel")
	panBody.Position = UDim2.new(0, 24, 0, 58)
	panBody.Size = UDim2.new(1, -48, 1, -122)
	panBody.BackgroundTransparency = 1
	panBody.Font = Enum.Font.FredokaOne
	panBody.TextSize = 17
	panBody.TextWrapped = true
	panBody.TextXAlignment = Enum.TextXAlignment.Left
	panBody.TextYAlignment = Enum.TextYAlignment.Top
	panBody.TextColor3 = Color3.new(1, 1, 1)
	panBody.ZIndex = 10
	panBody.Parent = panel
	local panClose = Instance.new("TextButton")
	panClose.AnchorPoint = Vector2.new(0.5, 1)
	panClose.Position = UDim2.new(0.5, 0, 1, -14)
	panClose.Size = UDim2.new(0, 130, 0, 40)
	panClose.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	panClose.TextColor3 = Color3.fromRGB(40, 30, 10)
	panClose.Font = Enum.Font.FredokaOne
	panClose.TextSize = 22
	panClose.Text = "OK"
	panClose.ZIndex = 10
	panClose.Parent = panel
	local pcCorner = Instance.new("UICorner")
	pcCorner.CornerRadius = UDim.new(0, 12)
	pcCorner.Parent = panClose
	panClose.Activated:Connect(function()
		panel.Visible = false
	end)

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
		b.Font = Enum.Font.FredokaOne
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
		if controls then controls:Enable() end
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
money.Font = Enum.Font.FredokaOne
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
mountBtn.Font = Enum.Font.FredokaOne
mountBtn.TextSize = 18
mountBtn.Text = "Get Off  (G)"
mountBtn.Parent = gui
local mtCorner = Instance.new("UICorner")
mtCorner.CornerRadius = UDim.new(0, 10)
mtCorner.Parent = mountBtn

-- map toggle, stacked above the mount button
local mapBtn = Instance.new("TextButton")
mapBtn.Name = "MapToggle"
mapBtn.AnchorPoint = Vector2.new(0, 1)
mapBtn.Position = UDim2.new(0, 16, 1, -116)
mapBtn.Size = UDim2.new(0, 190, 0, 42)
mapBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 90)
mapBtn.TextColor3 = Color3.new(1, 1, 1)
mapBtn.Font = Enum.Font.FredokaOne
mapBtn.TextSize = 18
mapBtn.Text = "Map  (M)"
mapBtn.Parent = gui
local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 10)
mapCorner.Parent = mapBtn

-- Robux shop toggle, stacked above the map button
local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopToggle"
shopBtn.AnchorPoint = Vector2.new(0, 1)
shopBtn.Position = UDim2.new(0, 16, 1, -162)
shopBtn.Size = UDim2.new(0, 190, 0, 42)
shopBtn.BackgroundColor3 = Color3.fromRGB(190, 120, 40)
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.Font = Enum.Font.FredokaOne
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
shopTitle.Font = Enum.Font.FredokaOne
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
shopClose.Font = Enum.Font.FredokaOne
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
passIcon.Font = Enum.Font.FredokaOne
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
passName.Font = Enum.Font.FredokaOne
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
passDesc.Font = Enum.Font.FredokaOne
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
buyBtn.Font = Enum.Font.FredokaOne
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
shopStatus.Font = Enum.Font.FredokaOne
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
verTag.Font = Enum.Font.FredokaOne
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
	{ key = Enum.KeyCode.V, label = "V", name = "Superman",  pay = 8 },
	{ key = Enum.KeyCode.B, label = "B", name = "No-Hander", pay = 5 },
}

local menu = Instance.new("Frame")
menu.Name = "TrickMenu"
menu.AnchorPoint = Vector2.new(1, 1)
menu.Position = UDim2.new(1, -16, 1, -16)
menu.Size = UDim2.new(0, 170, 0, 5 * 40 + 64)
menu.BackgroundTransparency = 1
menu.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Parent = menu

local trickButtons = {}
for _, t in ipairs(TRICKS) do
	local btn = Instance.new("TextButton")
	btn.Name = t.name
	btn.Size = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = Color3.fromRGB(30, 38, 48)
	btn.BackgroundTransparency = 0.2
	btn.TextColor3 = Color3.fromRGB(235, 235, 235)
	btn.Font = Enum.Font.FredokaOne
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
trickBtn.Font = Enum.Font.FredokaOne
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
mapLegend.Font = Enum.Font.FredokaOne
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
clearBtn.Font = Enum.Font.FredokaOne
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
wayLabel.Font = Enum.Font.FredokaOne
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
		dm.Font = Enum.Font.FredokaOne
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
			lbl.Font = Enum.Font.FredokaOne
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
				lbl.Font = Enum.Font.FredokaOne
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
local function requestTrick(name)
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
		tag.Font = Enum.Font.FredokaOne
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
		banner.Font = Enum.Font.FredokaOne
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
	pop.Font = Enum.Font.FredokaOne
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
			pcall(playSound, "rbxassetid://9114222049", 0.5) -- speed boost swoosh
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
	-- CLIENT-SIDE TRICK ANIMATION (Physics Authority)
	-- ==========================================
	local char = plr.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Add a cool neon trail to the root part for visual flair!
	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
	trail.Lifetime = 0.4
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
	task.delay(0.6, function()
		trail:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)

	-- Perform the flip/spin!
	if trickName == "Backflip" then
		task.spawn(function()
			local steps = 18
			for i = 1, steps do
				hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(360 / steps), 0, 0)
				task.wait(0.025)
			end
		end)
	elseif trickName == "Frontflip" then
		task.spawn(function()
			local steps = 18
			for i = 1, steps do
				hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(-360 / steps), 0, 0)
				task.wait(0.025)
			end
		end)
	elseif trickName == "360 Spin" then
		task.spawn(function()
			local dirSign = (math.random() > 0.5 and 1 or -1)
			local steps = 14
			for i = 1, steps do
				hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad((360 * dirSign) / steps), 0)
				task.wait(0.025)
			end
		end)
	elseif trickName == "Tailwhip" or trickName == "Kickflip" then
		local scooterDeck = scooter and scooter:FindFirstChild("Deck")
		local deckMount = scooterDeck and scooterDeck:FindFirstChild("DeckMount")
		if deckMount then
			task.spawn(function()
				local steps = 16
				local isKick = (trickName == "Kickflip")
				local axis = isKick and "z" or "y"
				local origC0 = deckMount.C0
				-- Same pivot offset used by the server
				local dy = -3.0
				local pivot = axis == "y" and CFrame.new(0, dy, -2.2) or CFrame.new(0, dy, 0.2)
				
				for i = 1, steps do
					local a = (i / steps) * math.pi * 2
					local rot = axis == "y" and CFrame.Angles(0, a, 0) or CFrame.Angles(0, 0, a)
					deckMount.C0 = origC0 * pivot * rot * pivot:Inverse()
					task.wait(isKick and 0.03 or 0.028)
				end
				deckMount.C0 = origC0
			end)
		end
	end
end)

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
	title.Font = Enum.Font.FredokaOne
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
	reelBtn.Font = Enum.Font.FredokaOne
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
