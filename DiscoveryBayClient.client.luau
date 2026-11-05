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

local VERSION = "v188"
local SPEED_PASS_ID = 0 -- paste the real Game Pass ID here (same one as in DiscoveryBayShop)
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local plr = Players.LocalPlayer

--==============================================================================================
-- STUDIO SPLASH (5 s): "YOU Groups presents" over black the moment you join. A glow breathes in,
-- the name rises in letter by letter, a gold line draws under it, a shine runs across, then it all
-- drifts up and dissolves into the start screen, with sound effects on each beat. Click skips.
--==============================================================================================
do
	local GROUP_ID = 32459648 -- YOU Groups
	local NAME = "YOU Groups"
	local splash = Instance.new("ScreenGui")
	splash.Name = "StudioSplash"
	splash.IgnoreGuiInset = true
	splash.ResetOnSpawn = false
	splash.DisplayOrder = 100 -- over the start screen
	splash.Parent = plr:WaitForChild("PlayerGui")

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
	bg.BorderSizePixel = 0
	bg.Active = true -- swallow clicks so nothing underneath reacts
	bg.Parent = splash

	-- soft violet glow behind the name, breathing in from nothing
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.2, 1.2)
	glow.BackgroundColor3 = Color3.fromRGB(70, 56, 130)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Parent = bg
	local glowShape = Instance.new("UIGradient")
	glowShape.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1),
	})
	glowShape.Parent = glow
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = glow

	-- everything that moves together, with a very slow push-in so it never feels frozen
	local group = Instance.new("Frame")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromOffset(640, 300)
	group.BackgroundTransparency = 1
	group.Parent = bg
	local groupScale = Instance.new("UIScale")
	groupScale.Scale = 0.94
	groupScale.Parent = group

	local emblem = Instance.new("ImageLabel")
	emblem.AnchorPoint = Vector2.new(0.5, 1)
	emblem.Position = UDim2.new(0.5, 0, 0.5, -46)
	emblem.Size = UDim2.fromOffset(96, 96)
	emblem.BackgroundTransparency = 1
	emblem.ImageTransparency = 1
	emblem.Parent = group
	local emblemCorner = Instance.new("UICorner")
	emblemCorner.CornerRadius = UDim.new(0.22, 0)
	emblemCorner.Parent = emblem

	-- the name, one label per letter so each can rise in on its own
	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.new(1, 0, 0, 84)
	row.BackgroundTransparency = 1
	row.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local letters = {}
	for i = 1, #NAME do
		local ch = NAME:sub(i, i)
		local slot = Instance.new("Frame") -- fixed slot; the letter moves inside it, the row never reflows
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(ch == " " and 22 or 40, 84)
		slot.LayoutOrder = i
		slot.Parent = row
		if ch ~= " " then
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Position = UDim2.fromOffset(0, 18)
			l.Font = Enum.Font.PermanentMarker
			l.Text = ch
			l.TextSize = 70
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextTransparency = 1
			l.Parent = slot
			local sheen = Instance.new("UIGradient") -- the gold shine passes through each letter in turn
			sheen.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 110)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			})
			sheen.Offset = Vector2.new(-1, 0)
			sheen.Parent = l
			-- PermanentMarker is narrow: size each slot to its letter so the word keeps natural spacing
			local w = game:GetService("TextService"):GetTextSize(ch, 70, Enum.Font.PermanentMarker, Vector2.new(200, 100)).X
			slot.Size = UDim2.fromOffset(w + 2, 84)
			table.insert(letters, { label = l, sheen = sheen })
		end
	end

	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, 0.5, 50)
	line.Size = UDim2.fromOffset(0, 2)
	line.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	line.BorderSizePixel = 0
	line.Parent = group
	local lineFade = Instance.new("UIGradient") -- fades out at both ends
	lineFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
	})
	lineFade.Parent = line

	local presents = Instance.new("TextLabel")
	presents.AnchorPoint = Vector2.new(0.5, 0)
	presents.Position = UDim2.new(0.5, 0, 0.5, 70)
	presents.Size = UDim2.new(1, 0, 0, 30)
	presents.BackgroundTransparency = 1
	presents.Font = Enum.Font.PermanentMarker
	presents.Text = "presents"
	presents.TextSize = 24
	presents.TextColor3 = Color3.fromRGB(200, 196, 220)
	presents.TextTransparency = 1
	presents.Parent = group

	-- the group's own emblem, if Roblox hands it over in time (the splash works fine without it)
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("GroupService"):GetGroupInfoAsync(GROUP_ID)
		end)
		if ok and info and info.EmblemUrl and info.EmblemUrl ~= "" and emblem.Parent then
			emblem.Image = info.EmblemUrl
		end
	end)

	-- licensed / public sound effects, cued on the timeline below
	local function sfx(id, volume)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.Parent = splash
		return s
	end
	local CUES = {
		{ at = 0.0, sound = sfx("rbxassetid://9119421195", 0.35) },   -- soft airy whoosh as the glow comes up
		{ at = 0.75, sound = sfx("rbxassetid://9125484367", 0.45) },  -- deep cinematic boom as the letters land
		{ at = 2.2, sound = sfx("rbxassetid://9114369623", 0.4) },   -- "fairy dust" chime with the gold shine
		{ at = 3.6, sound = sfx("rbxassetid://9119422012", 0.3) },    -- soft whoosh out
	}

	-- easing helpers on a 0..1 progress
	local function prog(t, start, len) return math.clamp((t - start) / len, 0, 1) end
	local function outQuint(x) return 1 - (1 - x) ^ 5 end
	local function outSine(x) return math.sin(x * math.pi / 2) end
	local function inSine(x) return 1 - math.cos(x * math.pi / 2) end
	local function inOutSine(x) return -(math.cos(math.pi * x) - 1) / 2 end

	-- The animation runs on its OWN clock: normal frames count in full (so it's 5 s at any frame rate),
	-- but a freeze (a frame over 1/4 s, like the loading hitches right after you join) only counts as
	-- one short step, so it pauses the intro instead of skipping it. You always see the whole 5 seconds.
	local TOTAL, EXIT = 5.0, 3.6
	local t, speed = 0, 1
	bg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			t = math.max(t, EXIT) -- skip straight to the fade-out, and play it quicker
			speed = 2
		end
	end)

	task.spawn(function()
		-- black until the game has loaded and the big loading freezes are over (or 4 s, whichever first)
		if not game:IsLoaded() then game.Loaded:Wait() end
		local sounds = {}
		for _, c in ipairs(CUES) do table.insert(sounds, c.sound) end
		task.spawn(function()
			pcall(function() game:GetService("ContentProvider"):PreloadAsync(sounds) end)
		end)
		local smooth, waited = 0, 0
		while smooth < 8 and waited < 4 do
			local dt = RunService.RenderStepped:Wait()
			waited += dt
			smooth = dt < 0.25 and smooth + 1 or 0
		end

		local cued = 0
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			t += (dt > 0.25 and 1 / 30 or dt) * speed
			while cued < #CUES and t >= CUES[cued + 1].at do
				cued += 1
				if speed == 1 or CUES[cued].at >= EXIT then CUES[cued].sound:Play() end
			end

			local out = 1 - inSine(prog(t, EXIT, 0.9)) -- everything fades together at the end
			glow.BackgroundTransparency = 1 - outSine(prog(t, 0, 1.6)) * out
			groupScale.Scale = 0.94 + 0.08 * inOutSine(prog(t, 0, TOTAL))
			group.Position = UDim2.new(0.5, 0, 0.5, -24 * (1 - out))
			emblem.ImageTransparency = 1 - outQuint(prog(t, 0.6, 1.2)) * out
			for i, e in ipairs(letters) do
				local a = outQuint(prog(t, 0.6 + (i - 1) * 0.07, 0.9))
				e.label.TextTransparency = 1 - a * out
				e.label.Position = UDim2.fromOffset(0, 18 * (1 - a))
				e.sheen.Offset = Vector2.new(-1 + 2 * inOutSine(prog(t, 2.2 + (i - 1) * 0.06, 0.7)), 0)
			end
			line.Size = UDim2.fromOffset(300 * outQuint(prog(t, 1.7, 0.9)), 2)
			line.BackgroundTransparency = 1 - out
			presents.TextTransparency = 1 - 0.9 * outSine(prog(t, 1.7, 1.0)) * out
			bg.BackgroundTransparency = inOutSine(prog(t, 4.15, 0.85))

			if t >= TOTAL then
				conn:Disconnect()
				task.delay(4, function() splash:Destroy() end) -- (lets the last sounds finish)
				bg.Visible = false
			end
		end)
	end)
end

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
	
	-- no music over the intro / start screen: it starts once you press PLAY (that's when the HUD appears)
	local hud = plr:WaitForChild("PlayerGui"):WaitForChild("DiscoveryBayHUD")
	while not hud.Enabled do hud:GetPropertyChangedSignal("Enabled"):Wait() end
	-- (silent while you're watching TV: the show has its own music)
	local function musicVol() return plr:GetAttribute("WatchingTV") and 0 or 0.4 end
	playTrack(OUTDOOR_MUSIC, musicVol(), OUTDOOR_SPEED)

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
			playTrack(targetId, musicVol(), targetSpeed)
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
rmTitle.Font = Enum.Font.PermanentMarker
rmTitle.TextColor3 = Color3.new(1, 1, 1)
rmTitle.TextSize = 24
rmTitle.Parent = rebirthMenu

local rmDesc = Instance.new("TextLabel")
rmDesc.Size = UDim2.new(1, -20, 0, 120)
rmDesc.Position = UDim2.new(0, 10, 0, 40)
rmDesc.BackgroundTransparency = 1
rmDesc.Text = "Benefits:\n• 1.5x Scooter Speed!\n• 1.5x Cash Multiplier!\n\nWarning: You will lose your house, pet, and money."
rmDesc.Font = Enum.Font.PermanentMarker
rmDesc.TextColor3 = Color3.new(0.8, 0.8, 0.8)
rmDesc.TextSize = 18
rmDesc.TextWrapped = true
rmDesc.Parent = rebirthMenu

local rmConfirm = Instance.new("TextButton")
rmConfirm.Size = UDim2.new(0.4, 0, 0, 40)
rmConfirm.Position = UDim2.new(0.07, 0, 1, -50)
rmConfirm.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
rmConfirm.Text = "REBIRTH?"
rmConfirm.Font = Enum.Font.PermanentMarker
rmConfirm.TextColor3 = Color3.new(1, 1, 1)
rmConfirm.TextSize = 16
rmConfirm.Parent = rebirthMenu
local rmcCorner = Instance.new("UICorner"); rmcCorner.CornerRadius = UDim.new(0, 8); rmcCorner.Parent = rmConfirm

local rmCancel = Instance.new("TextButton")
rmCancel.Size = UDim2.new(0.4, 0, 0, 40)
rmCancel.Position = UDim2.new(0.53, 0, 1, -50)
rmCancel.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
rmCancel.Text = "CANCEL"
rmCancel.Font = Enum.Font.PermanentMarker
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
rebirthBtn.Font = Enum.Font.PermanentMarker
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
	numLbl.Font = Enum.Font.PermanentMarker
	numLbl.TextSize = 12
	numLbl.Parent = slot
	
	local itemLbl = Instance.new("TextLabel")
	itemLbl.Size = UDim2.new(1, 0, 1, 0)
	itemLbl.BackgroundTransparency = 1
	itemLbl.Text = ""
	itemLbl.TextColor3 = Color3.new(1, 1, 1)
	itemLbl.Font = Enum.Font.PermanentMarker
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
		btn.Font = Enum.Font.PermanentMarker
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
qtxt.Font = Enum.Font.PermanentMarker
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
dlgName.Font = Enum.Font.PermanentMarker
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
dlgText.Font = Enum.Font.PermanentMarker
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
local npcHomePivot = setmetatable({}, { __mode = "k" }) -- how an NPC stood before turning to face you

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
-- a different title + set of lines for each way to die
local DEATH_KINDS = {
	car = {
		title = "WASTED", color = Color3.fromRGB(225, 38, 38),
		lines = {
			"Bro looked both ways and still got folded.",
			"The car had the right of way lil bro.",
			"You had a whole sidewalk and still chose the bumper.",
			"Insurance is NOT covering that one.",
			"Bro became a Discovery Bay speedbump.",
			"My grandma dodges traffic better than that.",
			"That driver didn't even touch the brakes.",
			"Frogger called. He wants his game back.",
			"Car: 1. You: 0.",
			"The driver gave you a 1-star rating.",
			"You got yeeted by a sedan.",
			"Free ride! ...just not the kind you wanted.",
			"That car is gonna need a car wash now.",
			"Discovery Bay traffic does NOT brake for you.",
		},
	},
	debt = {
		title = "BANKRUPT", color = Color3.fromRGB(240, 190, 40),
		lines = {
			"Died broke AND in debt. Legendary.",
			"Your bank account died before you did.",
			"Even your funeral is on a payment plan.",
			"The bank sent flowers... and a bill.",
			"Negative money, negative aura.",
			"You owe more than you're worth. Literally.",
			"Your wallet filed for divorce.",
			"Debt collectors are already waiting at spawn.",
			"Bro speedran bankruptcy.",
			"Sensei still wants his $5.",
		},
	},
	reset = {
		title = "RAGE QUIT", color = Color3.fromRGB(120, 170, 255),
		lines = {
			"Aww, is the game too hard for you?",
			"Did the game hurt your feelings?",
			"Giving up already? Cute.",
			"Pressing reset won't fix your life, bro.",
			"Rage quit speedrun any%.",
			"It's okay, you can cry a little.",
			"Reset button warrior strikes again.",
			"We'll pretend that didn't happen.",
			"Self-respawn? Bold strategy.",
		},
	},
	other = {
		title = "WASTED", color = Color3.fromRGB(225, 38, 38),
		lines = {
			"Is this your best?",
			"Skill issue detected. Respawning...",
			"Even the NPCs saw that coming.",
			"Well... that happened.",
			"Discovery Bay: 1. You: 0.",
			"Try not dying next time. Just a tip.",
		},
	},
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
wastedTitle.Font = Enum.Font.PermanentMarker
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
wastedRoast.Font = Enum.Font.PermanentMarker
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
local function playGTAWasted(cause)
	local oldDeath = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("DeathScreen")
	if oldDeath then oldDeath:Destroy() end
	local kind = DEATH_KINDS[cause] or DEATH_KINDS.other
	local idx = math.random(1, #kind.lines)
	if idx == lastRoastIdx then idx = (idx % #kind.lines) + 1 end
	lastRoastIdx = idx
	wastedRoast.Text = kind.lines[idx]
	wastedTitle.Text = kind.title
	wastedTitle.TextColor3 = kind.color

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
local resetPressedFor = nil -- the character you pressed Reset on (so its death gets the reset jokes)
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
				-- (car hits show their screen on the fling, before you die)
				local stats = plr:FindFirstChild("leaderstats")
				local cash = stats and stats:FindFirstChild("Cash")
				if resetPressedFor == ch then
					playGTAWasted("reset")
				elseif cash and cash.Value < 0 then
					playGTAWasted("debt")
				else
					playGTAWasted("other")
				end
			end
		end)
	end
end
if plr.Character then
	task.spawn(hookCharacterDeath, plr.Character)
end
plr.CharacterAdded:Connect(hookCharacterDeath)

-- take over Roblox's Reset button so we know a death was a reset (it still kills you the same way)
do
	local StarterGui = game:GetService("StarterGui")
	local resetEvent = Instance.new("BindableEvent")
	resetEvent.Event:Connect(function()
		local ch = plr.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			resetPressedFor = ch
			hum.Health = 0
		end
	end)
	task.spawn(function()
		-- SetCore fails until the core scripts have loaded, so keep trying for a bit
		for _ = 1, 30 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", resetEvent) then return end
			task.wait(1)
		end
	end)
end

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
					playGTAWasted("car")
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

-- after a conversation the NPC swings smoothly back to how it was standing (talking again
-- mid-swing leaves it facing you, and it remembers its real home facing for next time)
local function turnNPCBackHome(npc)
	local home = npcHomePivot[npc]
	if not home or not npc.Parent then return end
	npcHomePivot[npc] = nil
	local from = npc:GetPivot()
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if currentCutsceneNPC == npc or npc:GetAttribute("PianoDropping") or not npc.Parent then
			conn:Disconnect()
			npcHomePivot[npc] = npcHomePivot[npc] or home
			return
		end
		local u = math.clamp((os.clock() - t0) / 0.45, 0, 1)
		npc:PivotTo(from:Lerp(home, u * u * (3 - 2 * u)))
		if u >= 1 then
			conn:Disconnect()
			savedNPCJoints[npc] = nil -- the next conversation re-captures its pose from here
		end
	end)
end

local isNPCTalking = false
local talkWeight = 0
local npcAnimConn = nil
local postTalkConns = {}
local npcFaceUIs = {}

local NPC_CLASSIC_FACE_MAP = {
	-- *Talk faces are open-mouth classic faces; the mouth-flap loop swaps between the stage face and its Talk face
	["Bob"]           = { idle = "Smile",           interact = "JoyfulSmile",     interactTalk = "JoyousSurprise", answer = "HappyWink",      answerTalk = "OpenO" },
	["Manager Bob"]   = { idle = "Stare",           interact = "Disbelief",       interactTalk = "Roar",           answer = "MrChuckles",     answerTalk = "OpenO" },
	["Eggbert"]       = { idle = "GoodIntentioned", interact = "Skeptic",         interactTalk = "JoyousSurprise", answer = "GoodIntentioned", answerTalk = "JoyfulSmile" },
	["Captain Finn"]  = { idle = "CheckIt",         interact = "Winky",           interactTalk = "JoyfulSmile",    answer = "Disbelief",      answerTalk = "OpenO" },
	["Rider Rick"]    = { idle = "SureImCool",      interact = "Chill",           interactTalk = "JoyfulSmile",    answer = "ItsGoTime",      answerTalk = "OpenO" },
	["Callahan"]      = { idle = "Smile",           interact = "GoodIntentioned", interactTalk = "JoyfulSmile",    answer = "HappyWink",      answerTalk = "JoyousSurprise" },
	["Thirsty Terry"] = { idle = "Sniffles",        interact = "Disbelief",       interactTalk = "OpenO",          answer = "Puck",           answerTalk = "JoyfulSmile" },
	["Sal"]           = { idle = "Chill",           interact = "MrChuckles",      interactTalk = "JoyfulSmile",    answer = "HappyWink",      answerTalk = "JoyousSurprise" },
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
				turnNPCBackHome(npc)
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
	-- stop its idle animation and snap it back to rest first: the facing / pose saved below must be clean
	if _G.NPCIdleRest then _G.NPCIdleRest(npcModel) end
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
				if not npcHomePivot[npcModel] then npcHomePivot[npcModel] = npcModel:GetPivot() end
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
			btn.Font = Enum.Font.PermanentMarker
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
		closeBtn.Font = Enum.Font.PermanentMarker
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

	-- Get off the scooter so the player walks up on foot. (A G-toggle here could be ignored by the
	-- server's double-press guard, leaving you "riding" an invisible scooter after the cutscene.)
	if plr:GetAttribute("Mounted") or (plr.Character and plr.Character:FindFirstChild("Scooter")) then
		remotes:WaitForChild("ForceDismount"):FireServer()
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
				-- the server's intended speed (origWalkSpeed was still the SCOOTER speed: you'd walk at 30)
				hum.WalkSpeed = hum:GetAttribute("TargetSpeed") or origWalkSpeed
				hum.JumpPower = origJumpPower
			end
			-- still carrying the (hidden) scooter somehow? get properly off so nothing is left half-riding
			if char and char:FindFirstChild("Scooter") then
				remotes:WaitForChild("ForceDismount"):FireServer()
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
			pcall(playSound, "rbxasset://sounds/victory.wav", 0.5) -- Terry gets his soda!
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
	["Bob"] = { id = "BobWelcome", reward = 250, once = true,
		offer = "Hey hey, you must be new! I'm Bob. First thing every Bay local does: grab a Bloxy Cola at ShellBlox - the gas station with the big yellow sign. It makes your scooter faster! Do that and I'll give you $250.",
		again = "",
		accept = "Follow the marker to ShellBlox. Walk in, buy a Bloxy Cola, then come back to me!",
		progress = "No Bloxy Cola yet? ShellBlox - big yellow sign, right by the plaza. (%d of 1)",
		ready = "There it is! Feel that speed? Welcome to the Bay, local. Here's your $250!" },
}
local QuestAction = remotes:WaitForChild("QuestAction", 10)

-- puts the job option at the top of an NPC's choices (label depends on where the job is at)
local function withQuestChoice(npcName, choices)
	local q = NPC_QUESTS[npcName]
	if not q or not QuestAction then return choices end
	local state = plr:GetAttribute("QuestState_" .. q.id)
	if q.once and state == "done" then return choices end
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
		elseif npcName == "Bob" then
			if plr:GetAttribute("QuestState_BobWelcome") ~= "done" then
				-- until his quest is done, Bob gets straight to it: the offer, how it's going, or the reward
				handleQuestChoice("Bob")
			else
				showDialogue("Bob", "Look at you - a real Bay local now! Rider Rick at the scooter shop pays cash for tricks, by the way.", {
					{ id = "tips", text = "Any tips?" }
				}, function(choiceId)
					if choiceId == "tips" then
						showDialogue("Bob", "Cars do NOT stop for you, so watch the road! Press T for scooter tricks, and every Bloxy Cola makes you faster. It stacks!", {}, nil)
					end
				end)
			end
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
	title.Font = Enum.Font.PermanentMarker -- graffiti / skate-park marker lettering
	title.TextSize = 72
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "Discovery Bay"
	title.ZIndex = 8 -- above the grey cover
	title.Parent = introGui
	local titleFade = Instance.new("UIGradient")
	titleFade.Rotation = 90
	titleFade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 176, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 96, 120)),
	})
	titleFade.Parent = title
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(28, 18, 40)
	titleStroke.Thickness = 4
	titleStroke.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.new(0.5, 0, 0.08, 86)
	subtitle.Size = UDim2.new(1, 0, 0, 28)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.PermanentMarker
	subtitle.TextSize = 24
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
	loadTxt.Font = Enum.Font.PermanentMarker
	loadTxt.TextSize = 30
	loadTxt.TextColor3 = Color3.fromRGB(240, 242, 245)
	loadTxt.Text = "Loading Discovery Bay..."
	loadTxt.ZIndex = 6
	loadTxt.Parent = loadFrame
	local spinner = Instance.new("TextLabel")
	spinner.AnchorPoint = Vector2.new(1, 1)
	spinner.Position = UDim2.new(1, -28, 1, -28)
	spinner.Size = UDim2.new(0, 76, 0, 76)
	spinner.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	spinner.Font = Enum.Font.PermanentMarker
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
	
	-- dark night-sky loading background, so it blends straight into the flyover
	loadFrame.BackgroundTransparency = 0
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 18, 42)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(44, 26, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 40, 72))
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

	-- SHOWREEL: the gradient fades away and the camera tours Discovery Bay behind the menu -
	-- slow orbits round each landmark with a location caption, dipping to black between shots
	local cam = workspace.CurrentCamera
	local shots = {}
	local lm = town and town:FindFirstChild("Landmarks")
	local function addShot(name, inst, radius, height)
		if inst then
			local ok, pos = pcall(function() return inst:IsA("Model") and inst:GetPivot().Position or inst.Position end)
			if ok and pos then
				table.insert(shots, { name = name, pos = pos, r = radius or 120, h = height or 55 })
			end
		end
	end
	if lm then
		addShot("Discovery Bay Blvd Plaza", lm:FindFirstChild("Discovery Bay Blvd Plaza"), 130, 55)
		addShot("Discovery Bay Yacht Harbor", lm:FindFirstChild("Discovery Bay Yacht Harbor"), 160, 60)
		addShot("Discovery Bay Golf Club", lm:FindFirstChild("Clubhouse"), 140, 60)
		addShot("BLOXWAY", lm:FindFirstChild("BLOXWAY"), 190, 70)
		for _, m in ipairs(lm:GetChildren()) do
			if #shots >= 7 then break end
			if m:IsA("Model") and (m.Name:find("School") or m.Name:find("Elementary") or m.Name:find("Park")) then
				addShot(m.Name, m, 140, 60)
			end
		end
	end
	local docks = town and town:FindFirstChild("Docks")
	local dock = docks and docks:GetChildren()[math.max(1, math.floor(#docks:GetChildren() / 2))]
	addShot("The Delta Waterfront", dock, 150, 45)

	local fader = Instance.new("Frame")
	fader.Size = UDim2.fromScale(1, 1)
	fader.BackgroundColor3 = Color3.new(0, 0, 0)
	fader.BackgroundTransparency = 1
	fader.BorderSizePixel = 0
	fader.ZIndex = 5
	fader.Parent = introGui
	-- soft dark edges top and bottom so the title and buttons pop against the town
	for _, top in ipairs({ true, false }) do
		local shade = Instance.new("Frame")
		shade.AnchorPoint = Vector2.new(0, top and 0 or 1)
		shade.Position = UDim2.fromScale(0, top and 0 or 1)
		shade.Size = UDim2.fromScale(1, 0.35)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BorderSizePixel = 0
		shade.ZIndex = 5
		shade.Parent = introGui
		local g = Instance.new("UIGradient")
		g.Rotation = top and 90 or -90
		g.Transparency = NumberSequence.new(0.35, 1)
		g.Parent = shade
	end
	local caption = Instance.new("TextLabel")
	caption.AnchorPoint = Vector2.new(0, 1)
	caption.Position = UDim2.new(0, 28, 1, -24)
	caption.Size = UDim2.new(0, 520, 0, 34)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.PermanentMarker
	caption.TextSize = 32
	caption.TextColor3 = Color3.new(1, 1, 1)
	caption.TextStrokeTransparency = 0.4
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextTransparency = 1
	caption.TextStrokeTransparency = 1
	caption.ZIndex = 8
	caption.Parent = introGui
	local subCaption = caption:Clone()
	subCaption.Position = UDim2.new(0, 30, 1, -6)
	subCaption.Size = UDim2.new(0, 520, 0, 20)
	subCaption.TextSize = 15
	subCaption.TextColor3 = Color3.fromRGB(255, 220, 140)
	subCaption.Text = "DISCOVERY BAY, CALIFORNIA"
	subCaption.Parent = introGui

	local showreelOn = #shots > 0
	local showreelConn = nil
	-- name tags draw on top of everything, so they'd float over the flyover: hide them on this
	-- screen until PLAY (only locally; other players still see them)
	local function setNametagsShown(shown)
		for _, p in ipairs(Players:GetPlayers()) do
			local tag = p.Character and p.Character:FindFirstChild("OverheadNametag")
			if tag then tag.Enabled = shown end
		end
	end
	task.spawn(function()
		while introGui.Parent do
			setNametagsShown(false) -- tags can be (re)created after this starts, so keep at it
			task.wait(0.5)
		end
	end)
	if showreelOn then
		cam.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(loadFrame, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
		task.spawn(function()
			local SHOT_TIME = 7
			local idx = math.random(1, #shots)
			while showreelOn do
				local shot = shots[idx]
				local a0 = math.random() * math.pi * 2
				local dir = (math.random() < 0.5) and 1 or -1
				local t0 = os.clock()
				if showreelConn then showreelConn:Disconnect() end
				showreelConn = RunService.RenderStepped:Connect(function()
					local u = (os.clock() - t0) / SHOT_TIME
					local a = a0 + dir * math.rad(40) * u
					local r = shot.r * (1.08 - 0.12 * u) -- slow push-in while orbiting
					local camPos = shot.pos + Vector3.new(math.cos(a) * r, shot.h + 6 * math.sin(u * math.pi), math.sin(a) * r)
					cam.CFrame = CFrame.lookAt(camPos, shot.pos + Vector3.new(0, 6, 0))
				end)
				caption.Text = "📍 " .. string.upper(shot.name)
				for _, lbl in ipairs({ caption, subCaption }) do
					TweenService:Create(lbl, TweenInfo.new(0.6), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
				end
				TweenService:Create(fader, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
				task.wait(SHOT_TIME - 0.6)
				if not showreelOn then break end
				-- dip to black, then cut to the next landmark
				for _, lbl in ipairs({ caption, subCaption }) do
					TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				end
				TweenService:Create(fader, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
				task.wait(0.55)
				idx = idx % #shots + 1
			end
		end)
	end

	local playBtn = Instance.new("TextButton")
	playBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	playBtn.Position = UDim2.new(0.5, 0, 0.74, 0)
	playBtn.Size = UDim2.new(0, 260, 0, 84)
	playBtn.BackgroundColor3 = Color3.fromRGB(250, 205, 30)
	playBtn.Font = Enum.Font.PermanentMarker
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
	panTitle.Font = Enum.Font.PermanentMarker
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
	panBody.Font = Enum.Font.PermanentMarker
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
	panClose.Font = Enum.Font.PermanentMarker
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
		b.Font = Enum.Font.PermanentMarker
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
		showreelOn = false
		if showreelConn then showreelConn:Disconnect() end
		introGui:Destroy()
		setNametagsShown(true)
		gui.Enabled = true

		cam.CameraType = Enum.CameraType.Custom
		-- the town finishing respawns you while the flyover owns the camera, and Roblox doesn't
		-- re-aim it at the new character: point it at the CURRENT one or it stays at the old spawn
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
		
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
money.Font = Enum.Font.PermanentMarker
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
pityLabel.Font = Enum.Font.PermanentMarker
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
shopBtn.Font = Enum.Font.PermanentMarker
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
mapBtn.Font = Enum.Font.PermanentMarker
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
moneyBtn.Font = Enum.Font.PermanentMarker
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
mountBtn.Font = Enum.Font.PermanentMarker
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
tricksToggleBtn.Font = Enum.Font.PermanentMarker
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
shopTitle.Font = Enum.Font.PermanentMarker
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
shopClose.Font = Enum.Font.PermanentMarker
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
passIcon.Font = Enum.Font.PermanentMarker
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
passName.Font = Enum.Font.PermanentMarker
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
passDesc.Font = Enum.Font.PermanentMarker
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
buyBtn.Font = Enum.Font.PermanentMarker
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
shopStatus.Font = Enum.Font.PermanentMarker
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
verTag.Font = Enum.Font.PermanentMarker
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
trickTitle.Font = Enum.Font.PermanentMarker
trickTitle.TextSize = 26
trickTitle.TextColor3 = Color3.fromRGB(250, 205, 40)
trickTitle.Text = "SCOOTER TRICKS"
trickTitle.Parent = trickPage

local trickSub = Instance.new("TextLabel")
trickSub.Position = UDim2.new(0, 0, 0, 40)
trickSub.Size = UDim2.new(1, 0, 0, 18)
trickSub.BackgroundTransparency = 1
trickSub.Font = Enum.Font.PermanentMarker
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
trickClose.Font = Enum.Font.PermanentMarker
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
	keyBadge.Font = Enum.Font.PermanentMarker
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
	nameLbl.Font = Enum.Font.PermanentMarker
	nameLbl.TextSize = 17
	nameLbl.TextColor3 = Color3.new(1, 1, 1)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = t.name
	nameLbl.Parent = btn

	local payLbl = Instance.new("TextLabel")
	payLbl.Position = UDim2.new(0, 58, 0, 32)
	payLbl.Size = UDim2.new(1, -66, 0, 18)
	payLbl.BackgroundTransparency = 1
	payLbl.Font = Enum.Font.PermanentMarker
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
trickBtn.Font = Enum.Font.PermanentMarker
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
local HUD_SCALE = 1 -- < 1 on small touch screens (see MOBILE LAYOUT at the end of this script)

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
	badge.Font = Enum.Font.PermanentMarker
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
		TweenService:Create(scale, quick, { Scale = HUD_SCALE * 1.06 }):Play()
		TweenService:Create(gloss, quick, { BackgroundTransparency = 0.55 }):Play()
		TweenService:Create(iconLbl, quick, { Rotation = -10 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		setPressed(false)
		TweenService:Create(scale, quick, { Scale = HUD_SCALE }):Play()
		TweenService:Create(gloss, quick, { BackgroundTransparency = 0.72 }):Play()
		TweenService:Create(iconLbl, quick, { Rotation = 0 }):Play()
	end)
	btn.MouseButton1Down:Connect(function() setPressed(true) end)
	btn.MouseButton1Up:Connect(function() setPressed(false) end)
	btn.Activated:Connect(function()
		setPressed(false)
		scale.Scale = HUD_SCALE * 0.94
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = HUD_SCALE * (hovering and 1.06 or 1) }):Play()
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
ldmBtn.Font = Enum.Font.PermanentMarker
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

-- SHADERS: an extra cinematic grade on top of the normal lighting (Roblox has no custom shaders, so
-- it's post-processing): richer contrast and colour, a warm film tint, a soft glow on bright things,
-- sun rays, a gentle distance blur and a vignette. On by default on PC, off on phones; LDM turns it off.
local shadersOn = not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
local shaderFx = {}
do
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ShaderGrade"
	grade.Contrast = 0.12
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(255, 246, 232)
	local glow = Instance.new("BloomEffect")
	glow.Name = "ShaderGlow"
	glow.Intensity = 0.35
	glow.Size = 40
	glow.Threshold = 2.2
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "ShaderRays"
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "ShaderDepth"
	depth.FocusDistance = 60
	depth.InFocusRadius = 50
	depth.NearIntensity = 0
	depth.FarIntensity = 0.25
	shaderFx = { grade, glow, rays, depth }
	for _, e in ipairs(shaderFx) do
		e.Enabled = false
		e.Parent = Lighting
	end
end
-- the vignette: four soft dark screen edges, over the world but under the HUD
local vignette = Instance.new("ScreenGui")
vignette.Name = "ShaderVignette"
vignette.IgnoreGuiInset = true
vignette.ResetOnSpawn = false
vignette.DisplayOrder = -1
vignette.Enabled = false
vignette.Parent = plr:WaitForChild("PlayerGui")
for _, edge in ipairs({
	{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.28), rot = 90 },    -- top
	{ pos = UDim2.fromScale(0, 0.72), size = UDim2.fromScale(1, 0.28), rot = 270 }, -- bottom
	{ pos = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.22, 1), rot = 0 },      -- left
	{ pos = UDim2.fromScale(0.78, 0), size = UDim2.fromScale(0.22, 1), rot = 180 }, -- right
}) do
	local f = Instance.new("Frame")
	f.Position = edge.pos
	f.Size = edge.size
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Parent = vignette
	local g = Instance.new("UIGradient")
	g.Rotation = edge.rot
	g.Transparency = NumberSequence.new(0.55, 1) -- darkest at the screen edge, gone towards the middle
	g.Parent = f
	table.insert(shaderFx, g) -- (tracked so the night tweak below can soften it)
end
local function applyShaders()
	local on = shadersOn and not ldmOn
	for _, e in ipairs(shaderFx) do
		if not e:IsA("UIGradient") then e.Enabled = on end
	end
	vignette.Enabled = on
end
-- full strength by day; at night the extra contrast and vignette crush the darks, so ease off
task.spawn(function()
	while true do
		local nightW = math.clamp((math.abs(Lighting.ClockTime - 12) - 5.5) / 1.5, 0, 1)
		for _, e in ipairs(shaderFx) do
			if e.Name == "ShaderGrade" then
				e.Contrast = 0.12 - 0.09 * nightW
				e.Saturation = 0.12 - 0.04 * nightW
			elseif e:IsA("UIGradient") then
				e.Transparency = NumberSequence.new(0.55 + 0.3 * nightW, 1)
			end
		end
		task.wait(2)
	end
end)

local shaderBtn = Instance.new("TextButton")
shaderBtn.Name = "ShadersToggle"
shaderBtn.AnchorPoint = Vector2.new(1, 0)
shaderBtn.Position = UDim2.new(1, -18, 0, 112)
shaderBtn.Size = UDim2.new(0, 136, 0, 38)
shaderBtn.Font = Enum.Font.PermanentMarker
shaderBtn.TextSize = 15
shaderBtn.TextColor3 = Color3.new(1, 1, 1)
shaderBtn.Parent = gui
local function refreshShaderBtn()
	shaderBtn.Text = shadersOn and "SHADERS: ON" or "SHADERS: OFF"
	shaderBtn.BackgroundColor3 = shadersOn and Color3.fromRGB(150, 90, 200) or Color3.fromRGB(90, 95, 110)
end
refreshShaderBtn()
styleHudButton(shaderBtn, "✨")
shaderBtn.Activated:Connect(function()
	shadersOn = not shadersOn
	refreshShaderBtn()
	applyShaders()
end)
ldmBtn.Activated:Connect(applyShaders) -- LDM on = shaders off (and back when LDM goes off)
applyShaders()

-- Global UI sound effects
for _, child in ipairs(gui:GetDescendants()) do
	if child:IsA("TextButton") then
		child.MouseEnter:Connect(function()
			pcall(playSound, "rbxassetid://12221967", 0.25) -- soft hover
		end)
		child.Activated:Connect(function()
			pcall(playSound, "rbxassetid://15675059323", 1.0) -- crisp click (Roblox UI click)
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
mapLegend.Font = Enum.Font.PermanentMarker
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
clearBtn.Font = Enum.Font.PermanentMarker
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
wayLabel.Font = Enum.Font.PermanentMarker
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
		dm.Font = Enum.Font.PermanentMarker
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
			lbl.Font = Enum.Font.PermanentMarker
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
				lbl.Font = Enum.Font.PermanentMarker
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

	-- hatch sound effects (built into the Roblox client, or licensed, so they play in a published game)
	local function hatchSfx(id, volume, pitch)
		local snd = Instance.new("Sound")
		snd.SoundId = id
		snd.Volume = volume
		snd.PlaybackSpeed = pitch or 1
		snd.Parent = SoundService
		snd:Play()
		game:GetService("Debris"):AddItem(snd, 6)
	end

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
			if i % 2 == 0 then
				hatchSfx("rbxasset://sounds/clickfast.wav", 0.3 + i * 0.025, 0.8 + i * 0.05) -- tick... tick, faster and higher
			end
			task.wait(0.09)
		end
		-- the shell bursts
		hatchSfx("rbxasset://sounds/splat.wav", 0.6, 1.5)
		hatchSfx("rbxasset://sounds/impact_explosion_03.mp3", 0.35, 1.8)
		-- flash
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BorderSizePixel = 0
		flash.Parent = overlay
		egg:Destroy()
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		task.delay(0.5, function() flash:Destroy() end)

		-- phase 2: the pet, in 3D, slowly spinning (with a little fanfare)
		hatchSfx("rbxasset://sounds/victory.wav", 0.5, 1)
		hatchSfx("rbxassetid://9114369623", 0.45, 1.1)
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
		tag.Font = Enum.Font.PermanentMarker
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
		banner.Font = Enum.Font.PermanentMarker
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
	pop.Font = Enum.Font.PermanentMarker
	pop.TextSize = 24
	pop.TextXAlignment = Enum.TextXAlignment.Left
	pop.TextStrokeTransparency = 0.4
	if pay and pay > 0 then
		pop.Text = "+$" .. pay .. "  " .. trickName .. "!"
		pop.TextColor3 = Color3.fromRGB(120, 230, 130)
		pcall(playSound, "rbxasset://sounds/electronicpingshort.wav", 0.4) -- landing chime

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
			pcall(playSound, "rbxasset://sounds/action_jump.mp3", 0.5) -- speed boost swoosh
		elseif string.find(lowerMsg, "cash") or string.find(lowerMsg, "purchase") or string.find(lowerMsg, "bought") or string.find(lowerMsg, "spent") or string.find(lowerMsg, "rent") then
			pcall(playSound, "rbxassetid://134810204798705", 0.45) -- shop purchase cash register
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
	local remoteTricks = setmetatable({}, { __mode = "k" }) -- other players' tricks we're showing: char -> trick
	local smoothSteer = 0
	local smoothSpeed = 0
	local smoothCrouch = 0
	local smoothPush = 0 -- 0 = both feet on the deck, 1 = kicking along the road
	local smoothDrop = 0 -- how far the hips sink so the kicking foot reaches the road
	local KNEE_HINT = Vector3.new(0, -0.2, -1)

	-- KICK RHYTHM: one push a second. The foot works for KICK_TIME (down, shove, back up), then you glide.
	local KICK_TIME = 0.55
	local SHOVE_START, SHOVE_END = 0.2 * KICK_TIME, 0.7 * KICK_TIME
	local SURGE = 0.3 -- speed swing: about +17% just after the shove, about -12% at the end of the glide
	local SURGE_DECAY = 3.5
	-- 0..1 "how much burst" through one second: builds during the shove, then bleeds off
	local function surgeShape(t)
		local residual = math.exp(-(1 - SHOVE_END) * SURGE_DECAY) -- what's left from the last kick
		if t < SHOVE_START then
			return residual * math.exp(-t * SURGE_DECAY)
		elseif t < SHOVE_END then
			local s = (t - SHOVE_START) / (SHOVE_END - SHOVE_START)
			local from = residual * math.exp(-SHOVE_START * SURGE_DECAY)
			return from + (1 - from) * s * s * (3 - 2 * s)
		end
		return math.exp(-(t - SHOVE_END) * SURGE_DECAY)
	end
	local surgeMean = 0 -- subtracted so the pulse averages out to your normal speed
	for i = 0, 199 do surgeMean += surgeShape(i / 200) / 200 end

	-- The server sets WalkSpeed (scooter upgrades, boosts, drinks). We remember its value and ride
	-- at that times the pulse; any change WE didn't make is taken as the new server value.
	local speedHum, speedConn, rideBase, lastWritten = nil, nil, 16, nil
	local pulsing = false
	local function setSpeedPulse(hum, factor)
		if speedHum ~= hum then
			if speedConn then speedConn:Disconnect() end
			speedHum, rideBase, lastWritten, pulsing = hum, hum.WalkSpeed, nil, false
			speedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if not lastWritten or math.abs(hum.WalkSpeed - lastWritten) > 0.01 then
					rideBase = hum.WalkSpeed
				end
			end)
		end
		if factor == 1 and not pulsing then return end
		lastWritten = rideBase * factor -- set first so the changed signal knows it's ours
		hum.WalkSpeed = lastWritten
		pulsing = factor ~= 1
	end
	local legRayParams = RaycastParams.new()
	legRayParams.FilterType = Enum.RaycastFilterType.Exclude
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
			elseif d:IsA("AnimationConstraint") then
				pcall(function() d.Transform = CFrame.new() end) -- newer rigs: clear the riding pose too
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
			lAnkle = char:FindFirstChild("LeftFoot") and char.LeftFoot:FindFirstChild("LeftAnkle"),
			rAnkle = char:FindFirstChild("RightFoot") and char.RightFoot:FindFirstChild("RightAnkle"),
			rFoot = char:FindFirstChild("RightFoot"),
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
	-- (arms and legs alike: shoulder/elbow/wrist or hip/knee/ankle. hint = which way the middle
	-- joint bends; parentCF = where the limb's parent part is THIS frame, when we know better
	-- than its last drawn CFrame)
	local function aimLimb(shoulder, elbow, wrist, target, hint, parentCF)
		if not (shoulder and elbow and wrist and target) then return end
		local sh0, sh1, torso = jointFrames(shoulder)
		local el0, el1 = jointFrames(elbow)
		local wr0, wr1 = jointFrames(wrist)
		if not (sh0 and el0 and wr0 and torso) then return end
		local sp = (parentCF or torso.CFrame) * sh0                 -- shoulder pivot, world
		local u0 = sh1:PointToObjectSpace(el0.Position)             -- shoulder -> elbow at rest
		local f0 = el1:PointToObjectSpace((wr0 * wr1:Inverse()).Position) -- elbow -> hand centre at rest
		local L1, L2 = u0.Magnitude, f0.Magnitude
		local t = sp:PointToObjectSpace(target)
		local D = math.clamp(t.Magnitude, math.abs(L1 - L2) + 0.05, L1 + L2 - 0.001)
		local n = t.Unit
		-- elbows bend down, back and a little outward
		local side = sh0.Position.X >= 0 and 1 or -1
		hint = hint or Vector3.new(side * 0.35, -1, 0.8)
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
	local function aimArm(shoulder, elbow, wrist, target)
		aimLimb(shoulder, elbow, wrist, target)
	end
	-- where a hip/knee/ankle chain puts the foot centre when unposed, given the pelvis CFrame
	local function restFootPos(hip, knee, ankle, pelvisCF)
		local h0, h1 = jointFrames(hip)
		local k0, k1 = jointFrames(knee)
		local a0, a1 = jointFrames(ankle)
		if not (h0 and k0 and a0) then return nil end
		return (pelvisCF * h0 * h1:Inverse() * k0 * k1:Inverse() * a0 * a1:Inverse()).Position
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

	-- one frame of a trick on any rider (yours, or another player's you're watching): true when it's over
	local function poseTrick(j, at)
		local elapsed = os.clock() - at.t0
		local p = math.clamp(elapsed / at.dur, 0, 1)
		local wave = math.sin(p * math.pi)
		local ang = p * math.pi * 2
		local name = at.name

		-- Only release hand IK during No-Hander and Kickflip; for Tailwhip, 360 Spin, Backflip,
		-- and Frontflip, keep hands holding the handlebars as the scooter flips/spins with you!
		local releaseHands = (name == "No-Hander" or name == "Kickflip")
		setIKEnabled(j.hum, false)
		setSpeedPulse(j.hum, 1) -- no kicking mid-trick

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
			local dir = at.spinDir
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
		return p >= 1
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

	task.spawn(function()
		local trickPlayed = remotes:WaitForChild("TrickPlayed", 30)
		if not trickPlayed then return end
		trickPlayed.OnClientEvent:Connect(function(who, trickName)
			-- `who` is a player, or a rider model (Practice Pete in the Game of S.C.O.O.T.)
			if who == plr then return end
			local rchar = typeof(who) == "Instance" and (who:IsA("Model") and who or who:IsA("Player") and who.Character)
			if not rchar then return end
			remoteTricks[rchar] = {
				name = trickName, t0 = os.clock(),
				dur = (trickName == "Backflip" or trickName == "Frontflip") and 0.60 or 0.56,
				spinDir = (math.random() > 0.5) and 1 or -1,
			}
		end)
	end)

	-- PreSimulation runs after the Animator and IKControl have written this frame's Transforms,
	-- so our poses are the ones that get drawn (in RenderStepped the Animator would overwrite them)
	RunService.PreSimulation:Connect(function(dt)
		-- other riders' tricks (the server only tells us WHICH trick; we animate it on their character)
		for rchar, at in pairs(remoteTricks) do
			local rj = rchar.Parent and rchar:FindFirstChild("Scooter") and getJoints(rchar)
			if not (rj and rj.hrp and rj.hum) then
				remoteTricks[rchar] = nil
			elseif poseTrick(rj, at) then
				for _, k in ipairs({ "deckMount", "barMount" }) do
					if rj[k] then setC0(rj[k], getBaseC0(rj[k])) end
				end
				setIKEnabled(rj.hum, true) -- their hands go back to the server's handlebar grips
				remoteTricks[rchar] = nil
			end
		end
		if inTerryCutscene then return end
		local char = plr.Character
		if not char then return end
		local isMounted = plr:GetAttribute("Mounted") and (char:FindFirstChild("Scooter") ~= nil)
		if not isMounted then
			if pulsing and speedHum and speedHum.Parent then setSpeedPulse(speedHum, 1) end
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
			if poseTrick(j, activeTrick) then
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

			-- kick-push: once a second the right foot snaps down onto the ROAD beside the deck, shoves
			-- back hard and pops back up onto the deck, then you glide. The hips stay sunk and the knees
			-- bent the whole time (two-bone IK on both legs). R6 rigs (no knees) keep the simple leg swing.
			local wantPush = not inAir and flatSpeed > 3 and j.hum.MoveDirection.Magnitude > 0.1
			smoothPush = smoothPush + ((wantPush and 1 or 0) - smoothPush) * math.min(1, dt * 6)
			local KICK_Z0, KICK_Z1 = -0.25, 0.85 -- foot plants forward of the hip, shoves to behind it
			local pushCycle = tNow % 1
			local kickT = pushCycle < KICK_TIME and pushCycle / KICK_TIME or nil
			local pushWave = (kickT and math.sin(kickT * math.pi) or 0) * smoothPush
			-- each shove gives a little burst of speed that bleeds off while you glide
			setSpeedPulse(j.hum, 1 + SURGE * smoothPush * (surgeShape(pushCycle) - surgeMean))

			-- body a third of a stud forward on the deck so the hands reach the grips
			local rootRest = CFrame.new(0, 0, -0.35) * leanCF
			local legIK = j.root and j.lKnee and j.rKnee and j.lAnkle and j.rAnkle and not j.isR6Root
			local r0, r1, lFootRest, kickTarget
			local drop = 0
			if legIK and smoothPush > 0.01 then
				r0, r1 = jointFrames(j.root)
				local pelvisRest = r0 and j.hrp.CFrame * r0 * rootRest * r1:Inverse()
				lFootRest = pelvisRest and restFootPos(j.lHip, j.lKnee, j.lAnkle, pelvisRest)
				local rFootRest = pelvisRest and restFootPos(j.rHip, j.rKnee, j.rAnkle, pelvisRest)
				if lFootRest and rFootRest then
					-- foot path in the rider's space. onRoad = how far the foot is from the deck towards the road
					local z, lift, onRoad = KICK_Z0, 0, 0
					if kickT then
						if kickT < 0.2 then -- snap down, planted ahead of the hip
							local s = kickT / 0.2
							onRoad = 1 - (1 - s) * (1 - s)
						elseif kickT < 0.7 then -- the shove: fastest at the start, like a real push
							local s = (kickT - 0.2) / 0.5
							z, onRoad = KICK_Z0 + (KICK_Z1 - KICK_Z0) * (1 - (1 - s) * (1 - s)), 1
						else -- pop back up onto the deck
							local s = (kickT - 0.7) / 0.3
							z, lift, onRoad = KICK_Z1, math.sin(s * math.pi) * 0.5, 1 - s * s * (3 - 2 * s)
						end
					end
					local footHalf = j.rFoot and j.rFoot.Size.Y / 2 or 0.15
					local beside = j.hrp.CFrame * Vector3.new(1.05, 0, z) -- just off the deck's right edge
					legRayParams.FilterDescendantsInstances = { char }
					local hit = workspace:Raycast(beside, Vector3.new(0, -8, 0), legRayParams)
					local groundY = hit and hit.Position.Y or (rFootRest.Y - footHalf - 0.55)
					kickTarget = rFootRest:Lerp(Vector3.new(beside.X, groundY + footHalf + lift, beside.Z), onRoad * smoothPush)
					-- stand tall while gliding; the standing knee only dips while the foot is down on the
					-- road, just enough for the leg to reach it
					local hipPos = (pelvisRest * jointFrames(j.rHip)).Position
					local reach = (hipPos - rFootRest).Magnitude * 0.97
					local off = kickTarget - hipPos
					local need = math.sqrt(math.max(reach * reach - off.X * off.X - off.Z * off.Z, 0))
					drop = math.clamp(-off.Y - need, 0, 1.1)
				else
					legIK = false
				end
			else
				legIK = false
			end
			smoothDrop = smoothDrop + (drop - smoothDrop) * math.min(1, dt * 16)
			local rootPose = CFrame.new(0, -smoothDrop, 0) * rootRest

			if j.root then
				pose(j.root, rootPose)
			end
			if j.deckMount then
				setC0(j.deckMount, getBaseC0(j.deckMount) * leanCF)
			end
			if j.barMount then
				setC0(j.barMount, getBaseC0(j.barMount) * leanCF * CFrame.Angles(0, barYaw, 0))
			end
			if j.waist then
				local waistPitch = math.rad(-16 - 6 * smoothSpeed - 12 * smoothCrouch) -- riders lean in over the bar
				pose(j.waist, CFrame.Angles(waistPitch, math.rad(10 * smoothSteer), 0))
			end
			if j.neck then
				local neckPitch = math.rad(12 + 6 * smoothSpeed + 10 * smoothCrouch) -- head up to look ahead past the lean
				pose(j.neck, CFrame.Angles(neckPitch, math.rad(14 * smoothSteer), 0))
			end
			if legIK then
				-- knees bend forward; solve against where the pelvis is THIS frame (hips sunk)
				local pelvisNow = j.hrp.CFrame * r0 * rootPose * r1:Inverse()
				aimLimb(j.lHip, j.lKnee, j.lAnkle, lFootRest, KNEE_HINT, pelvisNow)
				aimLimb(j.rHip, j.rKnee, j.rAnkle, kickTarget, KNEE_HINT, pelvisNow)
			else
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
			end
			aimArmsAtGrips(j)
		end
	end)
end

-- FISHING minigame: FISH ON! stop the swinging marker inside the green zone ----------------------
local fishFrame = nil
FishGame.OnClientEvent:Connect(function()
	pcall(playSound, "rbxassetid://9125703162", 0.5) -- splash sound on fish hook (Pro Sound Effects)
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
	title.Font = Enum.Font.PermanentMarker
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
	reelBtn.Font = Enum.Font.PermanentMarker
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
deathText.Font = Enum.Font.PermanentMarker
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
roastText.Font = Enum.Font.PermanentMarker
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
	
	playSound("rbxasset://sounds/impact_explosion_03.mp3", 1) -- slow-mo boom (built into the client)
	
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
	playSound("rbxasset://sounds/uuhhh.mp3", 1) -- the classic OOF (built into the client)
	
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

--==============================================================================================
-- MOBILE LAYOUT (touch devices without a keyboard): scale the HUD to the screen, move the
-- bottom-corner HUD out of Roblox's joystick (bottom-left) and jump button (bottom-right), and add
-- a big TRICK! button beside the jump button while riding. Desktop is left exactly as it was.
--==============================================================================================
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	local trickTap = Instance.new("TextButton")
	trickTap.Name = "TouchTrick"
	trickTap.AnchorPoint = Vector2.new(1, 1)
	trickTap.Size = UDim2.fromOffset(84, 84)
	trickTap.BackgroundColor3 = Color3.fromRGB(235, 70, 60)
	trickTap.TextColor3 = Color3.new(1, 1, 1)
	trickTap.Font = Enum.Font.PermanentMarker
	trickTap.TextSize = 20
	trickTap.Text = "TRICK!"
	trickTap.AutoButtonColor = true
	trickTap.Visible = false
	trickTap.Parent = gui
	local ttCorner = Instance.new("UICorner")
	ttCorner.CornerRadius = UDim.new(1, 0)
	ttCorner.Parent = trickTap
	local ttStroke = Instance.new("UIStroke")
	ttStroke.Color = Color3.fromRGB(255, 220, 120)
	ttStroke.Thickness = 3
	ttStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ttStroke.Parent = trickTap
	trickTap.Activated:Connect(function()
		requestTrick(nil) -- random, same as T
	end)
	local function refreshTrickTap()
		trickTap.Visible = plr:GetAttribute("Mounted") == true
	end
	plr:GetAttributeChangedSignal("Mounted"):Connect(refreshTrickTap)
	refreshTrickTap()

	-- a UIScale on every HUD element (full-width bars excluded); styled buttons already have one
	local function scaleOf(obj)
		local s = obj:FindFirstChildOfClass("UIScale")
		if not s then
			s = Instance.new("UIScale")
			s.Parent = obj
		end
		return s
	end

	local function layout()
		local vp = workspace.CurrentCamera.ViewportSize
		local short = math.min(vp.X, vp.Y)
		HUD_SCALE = math.clamp(short / 620, 0.6, 1)
		local s = HUD_SCALE
		for _, obj in ipairs(gui:GetChildren()) do
			if obj:IsA("GuiObject") and obj ~= trickTap and obj.Size.X.Scale < 0.5 and obj.Size.Y.Scale < 0.5 then
				-- dialogue stays readable even on small phones
				scaleOf(obj).Scale = (obj == dlgFrame) and math.max(s, 0.85) or s
			end
		end
		-- top-left stack instead of the joystick corner: money, pity, version tag, job tracker
		money.AnchorPoint = Vector2.new(0, 0)
		money.Position = UDim2.new(0, 14, 0, 8)
		pityLabel.AnchorPoint = Vector2.new(0, 0)
		pityLabel.Position = UDim2.new(0, 14, 0, 8 + 54 * s)
		verTag.AnchorPoint = Vector2.new(0, 0)
		verTag.Position = UDim2.new(0, 16, 0, 8 + 94 * s)
		questFrame.AnchorPoint = Vector2.new(0, 0)
		questFrame.Position = UDim2.new(0, 14, 0, 8 + 116 * s)
		-- Shop / Rebirth a little higher on the left
		shopBtn.Position = UDim2.new(0, 14, 0.44, -4)
		rebirthBtn.Position = UDim2.new(0, 14, 0.44, 6)
		-- Get Off / TRICKS lifted above the jump button; TRICK! sits just left of it
		mountBtn.Position = UDim2.new(1, -14 - 152 * s, 1, -118)
		tricksToggleBtn.Position = UDim2.new(1, -14, 1, -118)
		trickTap.Position = UDim2.new(1, -112, 1, -22)
	end
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
end

--==============================================================================================
-- SKY SHOW (this screen only): at night aurora ribbons, a Milky Way band, big twinkling stars and
-- a halo round the moon; at sunrise/sunset a huge warm glow round the sun. It all rides along
-- with the camera (sideways only) so it always sits far off in the sky, and fades with the time.
--==============================================================================================
do
	local skyFolder = Instance.new("Folder")
	skyFolder.Name = "SkyShow"
	skyFolder.Parent = workspace.CurrentCamera -- under the camera: drawn on this screen only

	local function skyPart(name, shape, size, color, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Neon
		p.Transparency = transparency
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = skyFolder
		return p
	end

	local rig = skyPart("SkyRig", Enum.PartType.Block, Vector3.new(1, 1, 1), Color3.new(0, 0, 0), 1)

	local function ribbon(a, b, width0, width1, colors)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		-- attachments point "up", so CurveSize makes the ribbon ripple up and down
		a0.CFrame = CFrame.new(a) * CFrame.Angles(0, 0, math.rad(90))
		a1.CFrame = CFrame.new(b) * CFrame.Angles(0, 0, math.rad(90))
		a0.Parent, a1.Parent = rig, rig
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = width0, width1
		beam.Color = colors
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 60
		beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 180 -- a wisp every 180 studs: curtain-like folds along the ribbon
		beam.TextureSpeed = 0.06 -- the wisps drift slowly along the ribbon
		beam.Parent = rig
		return beam
	end
	local AURORA = {
		ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 170)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 210, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 100, 255)) }),
		ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 90, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 180)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 220, 160)) }),
		ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 230, 200)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(200, 110, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)) }),
	}
	local auroras = {}
	for i = 1, 3 do
		auroras[i] = ribbon(Vector3.new(-760, 210 + i * 24, -430 - i * 85), Vector3.new(760, 230 + i * 18, -545 - i * 75),
			230 - i * 30, 200 - i * 24, AURORA[i])
	end
	local milkyWay = ribbon(Vector3.new(-900, 430, 420), Vector3.new(900, 470, -520), 240, 200,
		ColorSequence.new(Color3.fromRGB(225, 215, 255), Color3.fromRGB(180, 195, 255)))

	local stars = {}
	local srng = Random.new(2026)
	for i = 1, 45 do
		local yaw, pitch = srng:NextNumber(0, math.pi * 2), srng:NextNumber(math.rad(18), math.rad(80))
		local dir = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		local tint = ({ Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 215, 255), Color3.fromRGB(255, 236, 190) })[srng:NextInteger(1, 3)]
		local size = srng:NextNumber(1.3, 2.6)
		stars[i] = { part = skyPart("BigStar", Enum.PartType.Ball, Vector3.new(size, size, size), tint, 1),
			offset = dir * 420, phase = srng:NextNumber(0, math.pi * 2), speed = srng:NextNumber(1.5, 4) }
	end
	-- soft glows: a stack of faint circles (each a little bigger) on a billboard, so the light fades
	-- smoothly outwards with no hard edge (a see-through ball shows its outline)
	local function glow(name, studs, inner, outer, rings)
		local anchor = skyPart(name, Enum.PartType.Block, Vector3.new(1, 1, 1), Color3.new(0, 0, 0), 1)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(studs, studs)
		bb.LightInfluence = 0
		bb.Adornee = anchor
		bb.Parent = anchor
		local frames = {}
		for k = 1, rings do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromScale(k / rings, k / rings)
			f.BackgroundColor3 = inner:Lerp(outer, (k - 1) / math.max(rings - 1, 1))
			f.BorderSizePixel = 0
			f.ZIndex = rings - k + 1 -- small bright rings on top
			f.BackgroundTransparency = 1
			f.Parent = bb
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
			frames[k] = f
		end
		return { anchor = anchor, frames = frames }
	end
	local function setGlow(g, cf, strength)
		g.anchor.CFrame = cf
		for _, f in ipairs(g.frames) do
			f.BackgroundTransparency = 1 - 0.11 * strength -- stacked rings add up towards the middle
		end
	end
	local moonHalo = glow("MoonHalo", 150, Color3.fromRGB(210, 225, 255), Color3.fromRGB(120, 140, 255), 9)
	local sunGlow = glow("SunGlow", 1100, Color3.fromRGB(255, 236, 170), Color3.fromRGB(255, 96, 120), 12)

	local function smooth(a, b, x)
		local t = math.clamp((x - a) / (b - a), 0, 1)
		return t * t * (3 - 2 * t)
	end
	local function bump(a, b, x)
		if x <= a or x >= b then return 0 end
		return math.sin((x - a) / (b - a) * math.pi)
	end
	local function seq(alphaScale, base)
		-- soft ends, brighter middle; alphaScale 0 = invisible, 1 = full
		local function v(t) return 1 - (1 - t) * alphaScale end
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, v(base + 0.25)),
			NumberSequenceKeypoint.new(0.5, v(base)), NumberSequenceKeypoint.new(0.82, v(base + 0.2)),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local cp = cam.CFrame.Position
		local origin = Vector3.new(cp.X, 0, cp.Z)
		rig.CFrame = CFrame.new(origin)
		local ct = Lighting.ClockTime
		local t = os.clock()
		local nightW = math.max(smooth(19.0, 20.2, ct), 1 - smooth(4.4, 5.6, ct))
		local glowW = math.max(bump(16.4, 19.4, ct), bump(4.8, 7.6, ct))

		for i, beam in ipairs(auroras) do
			beam.CurveSize0 = 90 * math.sin(t * 0.25 + i * 1.7)
			beam.CurveSize1 = -80 * math.cos(t * 0.21 + i * 2.3)
			-- slow shimmer in brightness
			beam.Transparency = seq(nightW * (0.85 + 0.15 * math.sin(t * 0.6 + i)), 0)
		end
		milkyWay.Transparency = seq(nightW * 0.6, 0.05)

		for _, st in ipairs(stars) do
			st.part.CFrame = CFrame.new(origin + st.offset)
			st.part.Transparency = 1 - nightW * (0.55 + 0.4 * math.sin(t * st.speed + st.phase))
		end

		local moonDir = Lighting:GetMoonDirection()
		setGlow(moonHalo, CFrame.new(cp + moonDir * 520), nightW * math.clamp(moonDir.Y * 4, 0, 1) * 0.8)

		local sunDir = Lighting:GetSunDirection()
		local up = math.clamp((sunDir.Y + 0.1) * 5, 0, 1) -- fades as the sun drops under the horizon
		setGlow(sunGlow, CFrame.new(cp + sunDir * 1700), glowW * up)
	end)
end

-- whenever you (re)spawn, make sure the camera follows the new character (a respawn while a
-- cutscene / the start-screen flyover owned the camera could leave it on the old one)
plr.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local cam = workspace.CurrentCamera
	if hum and cam and cam.CameraType == Enum.CameraType.Custom then
		cam.CameraSubject = hum
	end
end)


-- 3D GRASS: tufts of real blades on the lawns around you. Client-only and recycled as you
-- move. Two rings: a dense swaying ring at your feet, and a lighter ring of shorter, still
-- blades further out so the flat ground never shows up close.
do
	local GRASS_CLASS = { G_l = 1, G_p = 1, G_f = 0.45 } -- blade height per ground type (none on greens / tees)
	local GRASS_CELL = 8
	local IS_PHONE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local NEAR_R = IS_PHONE and 18 or 24   -- swaying ring
	local FAR_R = IS_PHONE and 40 or 64    -- still ring
	local NEAR_TUFTS = IS_PHONE and 14 or 28 -- tufts per cell (3-5 blades each)
	local FAR_TUFTS = IS_PHONE and 5 or 10
	local HIDDEN_CF = CFrame.new(0, -5000, 0)

	local grassFolder = Instance.new("Folder")
	grassFolder.Name = "LocalGrass"
	grassFolder.Parent = workspace
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local pool = {}    -- spare blade parts, parked out of sight
	local cells = {}   -- "cx,cz" -> { near = bool, blades = {records} }
	local active = {}  -- records of the swaying (near) blades
	local fillQueue = {}
	local dirty = false

	local function getBlade()
		local b = table.remove(pool)
		if b then return b end
		b = Instance.new("WedgePart")
		b.Name = "Blade"
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Grass -- matte, no plastic shine
		b.TopSurface = Enum.SurfaceType.Smooth
		b.BottomSurface = Enum.SurfaceType.Smooth
		b.CFrame = HIDDEN_CF
		b.Parent = grassFolder
		return b
	end

	-- real lawns are a mix: deep shaded green, fresh green, sunlit yellow-green, the odd dry blade
	local PALETTE = {
		Color3.fromRGB(62, 120, 34), Color3.fromRGB(78, 140, 40), Color3.fromRGB(94, 156, 46),
		Color3.fromRGB(112, 168, 52), Color3.fromRGB(134, 178, 60), Color3.fromRGB(165, 175, 85),
	}
	local PALETTE_W = { 0.2, 0.26, 0.24, 0.16, 0.1, 0.04 }
	local function pickColor(r, base)
		local acc = 0
		for i, w in ipairs(PALETTE_W) do
			acc += w
			if r <= acc then return PALETTE[i]:Lerp(base, 0.25) end
		end
		return PALETTE[1]:Lerp(base, 0.25)
	end

	local function fillCell(cx, cz, near)
		local ground = workspace:FindFirstChild("DiscoveryBay")
		ground = ground and ground:FindFirstChild("Ground")
		if not ground then return {} end
		local list = {}
		local rng = Random.new(cx * 73856093 + cz * 19349663 + (near and 1 or 0)) -- same grass every time you come back
		for _ = 1, near and NEAR_TUFTS or FAR_TUFTS do
			local tx = (cx + rng:NextNumber()) * GRASS_CELL
			local tz = (cz + rng:NextNumber()) * GRASS_CELL
			-- the ray stops on roads, sidewalks, floors and trunks, so tufts only grow on open lawn
			local hit = workspace:Raycast(Vector3.new(tx, 14, tz), Vector3.new(0, -24, 0), rayParams)
			local scale = hit and hit.Instance.Parent == ground and GRASS_CLASS[hit.Instance.Name]
			local blades = rng:NextInteger(3, 5)
			local spin = rng:NextNumber() * math.pi * 2
			for b = 1, blades do
				-- every random number is drawn even with no hit, so a cell always grows the same way
				local h0, w0, sp, lean, phase, cr = rng:NextNumber(), rng:NextNumber(),
					rng:NextNumber(0.05, 0.9), rng:NextNumber(0.05, 0.4), rng:NextNumber() * math.pi * 2, rng:NextNumber()
				if scale then
					-- mostly short with the odd tall blade; the still ring is a bit shorter
					local h = (near and (0.9 + h0 ^ 1.6 * 2.6) or (0.7 + h0 ^ 1.6 * 1.6)) * scale
					local yaw = spin + (b / blades) * math.pi * 2 + w0 -- fan out round the tuft
					local out = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
					local part = getBlade()
					part.Size = Vector3.new(0.04, h, 0.12 + w0 * 0.2)
					part.Color = pickColor(cr, hit.Instance.Color)
					local rec = {
						part = part,
						pos = Vector3.new(tx, hit.Position.Y - 0.1, tz) + out * sp,
						rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, h / 2, 0),
						phase = phase,
					}
					if not near then part.CFrame = CFrame.new(rec.pos) * rec.rot end
					table.insert(list, rec)
				end
			end
		end
		return list
	end

	local function releaseCell(key)
		for _, rec in ipairs(cells[key].blades) do
			rec.part.CFrame = HIDDEN_CF
			table.insert(pool, rec.part)
		end
		cells[key] = nil
		dirty = true
	end

	local function grassCenter()
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		return root and root.Position
	end

	-- every 0.3s: plant cells that came into range, swap rings as you move, recycle the rest
	task.spawn(function()
		while grassFolder.Parent do
			task.wait(0.3)
			local c = grassCenter()
			if ldmOn or not c then
				for key in pairs(cells) do releaseCell(key) end
				table.clear(fillQueue)
			else
				local char = plr.Character
				rayParams.FilterDescendantsInstances = char and { char } or {}
				local ccx, ccz = math.floor(c.X / GRASS_CELL), math.floor(c.Z / GRASS_CELL)
				local r = math.ceil(FAR_R / GRASS_CELL)
				local want = {}
				for dx = -r, r do
					for dz = -r, r do
						local wx, wz = (ccx + dx + 0.5) * GRASS_CELL, (ccz + dz + 0.5) * GRASS_CELL
						local d2 = (wx - c.X) ^ 2 + (wz - c.Z) ^ 2
						if d2 <= FAR_R ^ 2 then
							want[(ccx + dx) .. "," .. (ccz + dz)] = { ccx + dx, ccz + dz, d2 <= NEAR_R ^ 2, d2 }
						end
					end
				end
				for key, cell in pairs(cells) do
					local w = want[key]
					if not w or w[3] ~= cell.near then releaseCell(key) end
				end
				table.clear(fillQueue)
				for key, w in pairs(want) do
					if not cells[key] then table.insert(fillQueue, { key, w[1], w[2], w[3], w[4] }) end
				end
				-- nearest cells first so the grass grows out from your feet
				table.sort(fillQueue, function(a, b) return a[5] < b[5] end)
			end
		end
	end)

	local parts, cfs = {}, {}
	local frame = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not grassFolder.Parent then conn:Disconnect() return end
		-- a few cells per frame so planting never hitches
		for _ = 1, 5 do
			local job = table.remove(fillQueue, 1)
			if not job then break end
			if not cells[job[1]] then
				cells[job[1]] = { near = job[4], blades = fillCell(job[2], job[3], job[4]) }
				dirty = true
			end
		end
		if dirty then
			dirty = false
			table.clear(active)
			for _, cell in pairs(cells) do
				if cell.near then
					for _, rec in ipairs(cell.blades) do table.insert(active, rec) end
				end
			end
		end

		frame += 1
		if frame % 2 == 1 or #active == 0 then return end -- sway at 30 fps

		local t = os.clock()
		local wind = workspace.GlobalWind
		local wdir = Vector3.new(wind.X, 0, wind.Z)
		wdir = wdir.Magnitude > 0.1 and wdir.Unit or Vector3.new(0.8, 0, 0.6)
		local strength = 0.1 + math.clamp(wind.Magnitude / 40, 0, 0.2)
		local c = grassCenter() or Vector3.zero
		table.clear(parts)
		table.clear(cfs)
		for i, rec in ipairs(active) do
			local p = rec.pos
			-- gusts roll across the lawn as a wave, each blade with its own flutter
			local along = p.X * wdir.X + p.Z * wdir.Z
			local gust = math.sin(t * 1.6 - along * 0.12) * 0.5 + 0.5
			local tilt = wdir * (strength * gust + 0.04 * math.sin(t * 4.3 + rec.phase))
			-- blades bend away from you as you walk through them
			local away = Vector3.new(p.X - c.X, 0, p.Z - c.Z)
			local d = away.Magnitude
			if d < 3.2 and d > 0.01 then
				tilt += away / d * (1.1 * (1 - d / 3.2))
			end
			local amt = tilt.Magnitude
			local cf = CFrame.new(p)
			if amt > 0.001 then
				cf = cf * CFrame.fromAxisAngle(Vector3.yAxis:Cross(tilt / amt), amt)
			end
			parts[i] = rec.part
			cfs[i] = cf * rec.rot
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

-- NPC IDLE ANIMATIONS: standing NPCs breathe, shift their weight and look around, and every few
-- seconds check their watch, scratch their head, stretch, wave, tap a foot or glance behind them.
-- Client-only, and only NPCs near the camera. NPCs are anchored blocks (no joints), so each limb is
-- turned about its shoulder / hip / neck. A conversation owns its NPC (savedNPCJoints[npc] is set):
-- idling pauses, and _G.NPCIdleRest snaps it back to rest first so no gesture gets saved into a pose.
do
	local IDLE_RANGE = 110
	local NECK = CFrame.new(0, 1, 0)
	local L_SHOULDER, R_SHOULDER = CFrame.new(-1, 0.5, 0), CFrame.new(1, 0.5, 0)
	local R_HIP = CFrame.new(0.5, -1, 0)
	local GESTURES = {
		{ name = "watch", dur = 2.4 }, { name = "scratch", dur = 2.2 }, { name = "stretch", dur = 2.6 },
		{ name = "wave", dur = 2.0 }, { name = "tap", dur = 2.0 }, { name = "lookback", dur = 2.4 },
	}
	local candidates = {} -- every standing NPC model in town
	local idlers = {}     -- model -> idle state (only while animating)
	local movedByOthers = setmetatable({}, { __mode = "k" }) -- NPCs something else moves: never idle them

	local function about(pivot, rot)
		return pivot * rot * pivot:Inverse()
	end

	local function startIdle(npc)
		local torso = npc:FindFirstChild("Torso")
		if not (torso and torso.Anchored and npc:FindFirstChild("Head")) then return nil end
		local ref = torso.CFrame
		local rng = Random.new(math.floor(ref.X * 7 + ref.Z * 13))
		local st = {
			ref = ref, rng = rng, list = {}, phase = rng:NextNumber() * 10,
			lookYaw = 0, lookTarget = 0, nextLook = os.clock() + rng:NextNumber(1, 4),
			nextGesture = os.clock() + rng:NextNumber(4, 12),
		}
		local head = npc.Head
		for _, p in ipairs(npc:GetDescendants()) do
			if p:IsA("BasePart") and p.Anchored then
				local kind = "torso" -- anything else rides along with the torso
				if p == head or p.Name == "Hair" or (p.Parent and p.Parent:IsA("Accessory")) then kind = "head"
				elseif p.Name == "Left Arm" then kind = "lArm"
				elseif p.Name == "Right Arm" then kind = "rArm"
				elseif p.Name == "Left Leg" or p.Name == "Right Leg" then kind = p.Name == "Right Leg" and "rLeg" or "leg"
				end
				table.insert(st.list, { part = p, kind = kind, rel = ref:ToObjectSpace(p.CFrame) })
			end
		end
		-- sitting NPCs have their legs swung forward: no foot taps for them
		local rLeg = npc:FindFirstChild("Right Leg")
		st.seated = rLeg ~= nil and ref:VectorToObjectSpace(rLeg.CFrame.UpVector).Y < 0.5
		return st
	end

	local function restIdle(npc)
		local st = idlers[npc]
		idlers[npc] = nil
		if not st then return end
		local parts, cfs = {}, {}
		for i, e in ipairs(st.list) do
			if e.part.Parent then
				parts[#parts + 1] = e.part
				cfs[#cfs + 1] = st.ref * e.rel
			end
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	_G.NPCIdleRest = restIdle

	-- find the standing NPCs once the town is built
	task.spawn(function()
		local town = workspace:WaitForChild("DiscoveryBay", 300)
		if not town then return end
		while not town:GetAttribute("BuildComplete") do task.wait(1) end
		for i, d in ipairs(town:GetDescendants()) do
			-- (not car drivers: their car moves them, and idling would pin the body where the car was)
			if d:IsA("Model") and d:FindFirstChild("Torso") and d:FindFirstChild("Head")
				and d:FindFirstChild("Left Arm") and d:FindFirstChild("Right Arm")
				and d.Name ~= "Driver" and not d:FindFirstAncestor("TrafficCar") then
				candidates[#candidates + 1] = d
			end
			if i % 5000 == 0 then task.wait() end
		end
	end)

	local parts, cfs = {}, {}
	local frame = 0
	RunService.Heartbeat:Connect(function(dt)
		frame += 1
		if frame % 2 == 1 then return end -- 30 fps is plenty for idling
		dt *= 2
		local cam = workspace.CurrentCamera
		if not cam then return end
		local camPos = cam.CFrame.Position
		local now = os.clock()
		table.clear(parts)
		table.clear(cfs)
		for _, npc in ipairs(candidates) do
			local torso = npc.Parent and npc:FindFirstChild("Torso")
			local st = idlers[npc]
			-- something else moved this NPC since our last frame (a car, a script): stop idling it for
			-- good instead of pinning its body where it used to be
			if st and torso and st.lastTorso and (torso.Position - st.lastTorso).Magnitude > 0.5 then
				idlers[npc] = nil
				movedByOthers[npc] = true
				st = nil
			end
			local busy = not torso or not torso.Anchored or savedNPCJoints[npc] ~= nil
				or currentCutsceneNPC == npc or ldmOn or movedByOthers[npc]
			if busy then
				if st and ldmOn and torso and torso.Anchored then
					restIdle(npc) -- low detail mode: stand still, properly at rest
				else
					-- a conversation / car hit took over: let go (the talk code already snapped it to rest)
					idlers[npc] = nil
				end
			elseif (torso.Position - camPos).Magnitude > IDLE_RANGE then
				if st then restIdle(npc) end
			else
				if not st then
					st = startIdle(npc)
					idlers[npc] = st
				end
				if st then
					local t = now + st.phase
					local rng = st.rng
					-- breathing + a slow weight shift from foot to foot
					local breath = math.sin(t * 1.8)
					local shift = math.sin(t * 0.5)
					local bodyY, bodyPitch, bodyYaw = 0.035 * breath, 0.012 * breath, 0
					-- glance around now and then
					if now > st.nextLook then
						st.lookTarget = rng:NextNumber() < 0.3 and 0 or math.rad(rng:NextNumber(-35, 35))
						st.nextLook = now + rng:NextNumber(1.5, 4.5)
					end
					st.lookYaw += (st.lookTarget - st.lookYaw) * math.min(1, dt * 3)
					local headPitch, headYaw, headRoll = math.rad(3 * math.sin(t * 0.7)), st.lookYaw, 0
					local lA = CFrame.Angles(math.rad(2 * math.sin(t * 1.8 + 1)), 0, math.rad(-2 - breath))
					local rA = CFrame.Angles(math.rad(2 * math.sin(t * 1.8 + 2)), 0, math.rad(2 + breath))
					local rL = CFrame.new()

					-- the occasional gesture, eased in and out
					if not st.g and now > st.nextGesture then
						local g = GESTURES[rng:NextInteger(1, #GESTURES)]
						if g.name == "tap" and st.seated then g = GESTURES[1] end
						st.g = { name = g.name, t0 = now, dur = g.dur, side = rng:NextNumber() < 0.5 and 1 or -1 }
					end
					if st.g then
						local u = (now - st.g.t0) / st.g.dur
						if u >= 1 then
							st.g = nil
							st.nextGesture = now + rng:NextNumber(4, 12)
						else
							local e = math.clamp(math.min(u, 1 - u) / 0.2, 0, 1)
							e = e * e * (3 - 2 * e)
							local name = st.g.name
							if name == "watch" then -- left wrist up in front of the chest, look down at it
								lA = lA * CFrame.Angles(math.rad(85 * e), 0, math.rad(35 * e))
								headPitch, headYaw = headPitch - math.rad(22) * e, headYaw * (1 - e) + math.rad(15) * e
							elseif name == "scratch" then -- right hand up to the head, a little scratch
								rA = rA * CFrame.Angles(math.rad((150 + 8 * math.sin(t * 25)) * e), 0, math.rad(-20 * e))
								headRoll = math.rad(8) * e
							elseif name == "stretch" then -- both arms overhead, up on the toes
								lA = lA * CFrame.Angles(math.rad(165 * e), 0, math.rad(-12 * e))
								rA = rA * CFrame.Angles(math.rad(165 * e), 0, math.rad(12 * e))
								bodyY += 0.08 * e
								headPitch += math.rad(12) * e
							elseif name == "wave" then -- right arm out to the side, waving
								rA = rA * CFrame.Angles(0, 0, math.rad((140 + 22 * math.sin(t * 10)) * e))
							elseif name == "tap" then -- impatient toe taps
								rL = CFrame.Angles(math.rad(9 * math.max(0, math.sin(t * 14))) * e, 0, 0)
							elseif name == "lookback" then -- turn and look over a shoulder
								headYaw = headYaw * (1 - e) + math.rad(70 * st.g.side) * e
								bodyYaw = math.rad(14 * st.g.side) * e
							end
						end
					end

					local body = CFrame.new(0.06 * shift, bodyY, 0)
						* CFrame.Angles(bodyPitch, bodyYaw, math.rad(1.5) * shift)
					local headT = body * about(NECK, CFrame.Angles(headPitch, headYaw, headRoll))
					local lAT = body * about(L_SHOULDER, lA)
					local rAT = body * about(R_SHOULDER, rA)
					local rLT = about(R_HIP, rL)
					for _, e in ipairs(st.list) do
						local k = e.kind
						local tf = (k == "head" and headT) or (k == "lArm" and lAT) or (k == "rArm" and rAT)
							or (k == "rLeg" and rLT) or (k == "leg" and CFrame.new()) or body
						parts[#parts + 1] = e.part
						cfs[#cfs + 1] = st.ref * tf * e.rel
						if e.part == torso then st.lastTorso = cfs[#cfs].Position end
					end
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

-- WELCOME QUEST TRACKER: after PLAY, until Bob's quest is done, a line at the top says what to do
-- next and a marker floats over where to go (Bob -> ShellBlox -> back to Bob). Gone once it's done.
do
	local QUEST_KEY = "QuestState_BobWelcome"
	task.spawn(function()
		if plr:GetAttribute(QUEST_KEY) == "done" then return end
		local town = workspace:WaitForChild("DiscoveryBay", 300)
		if not town then return end
		while not town:GetAttribute("BuildComplete") do task.wait(1) end
		local hud = plr:WaitForChild("PlayerGui"):WaitForChild("DiscoveryBayHUD")
		while not hud.Enabled do hud:GetPropertyChangedSignal("Enabled"):Wait() end
		task.wait(1) -- (the save loads right after joining: a returning player may already be done)
		if plr:GetAttribute(QUEST_KEY) == "done" then return end

		local bob = town:FindFirstChild("Bob", true)
		local bobHead = bob and bob:FindFirstChild("Head")
		local cola -- the Bloxy Cola on the ShellBlox shelf
		for _, d in ipairs(town:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Product") == "Bloxy Cola" then
				cola = d
				break
			end
		end

		local tracker = Instance.new("ScreenGui")
		tracker.Name = "QuestTracker"
		tracker.ResetOnSpawn = false
		tracker.DisplayOrder = 5
		tracker.Parent = plr.PlayerGui
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 8)
		card.Size = UDim2.fromOffset(420, 52)
		card.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
		card.BackgroundTransparency = 0.2
		card.Parent = tracker
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 170, 60)
		stroke.Thickness = 2
		stroke.Parent = card
		local heading = Instance.new("TextLabel")
		heading.BackgroundTransparency = 1
		heading.Position = UDim2.fromOffset(0, 4)
		heading.Size = UDim2.new(1, 0, 0, 18)
		heading.Font = Enum.Font.PermanentMarker
		heading.TextSize = 15
		heading.TextColor3 = Color3.fromRGB(255, 190, 90)
		heading.Text = "WELCOME TO THE BAY"
		heading.Parent = card
		local task_ = Instance.new("TextLabel")
		task_.BackgroundTransparency = 1
		task_.Position = UDim2.fromOffset(10, 22)
		task_.Size = UDim2.new(1, -20, 0, 26)
		task_.Font = Enum.Font.PermanentMarker
		task_.TextSize = 20
		task_.TextColor3 = Color3.new(1, 1, 1)
		task_.TextScaled = true
		task_.Parent = card

		-- the floating marker over where to go, visible through walls
		local marker = Instance.new("BillboardGui")
		marker.Name = "QuestMarker"
		marker.AlwaysOnTop = true
		marker.Size = UDim2.fromOffset(120, 70)
		marker.StudsOffset = Vector3.new(0, 4, 0)
		marker.LightInfluence = 0
		marker.Parent = tracker
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(1, 0, 0, 44)
		icon.Font = Enum.Font.PermanentMarker
		icon.TextSize = 42
		icon.TextColor3 = Color3.fromRGB(255, 200, 60)
		icon.TextStrokeTransparency = 0.2
		icon.Text = "!"
		icon.Parent = marker
		local dist = Instance.new("TextLabel")
		dist.BackgroundTransparency = 1
		dist.Position = UDim2.fromOffset(0, 44)
		dist.Size = UDim2.new(1, 0, 0, 22)
		dist.Font = Enum.Font.PermanentMarker
		dist.TextSize = 16
		dist.TextColor3 = Color3.new(1, 1, 1)
		dist.TextStrokeTransparency = 0.3
		dist.Parent = marker

		local t0 = os.clock()
		while tracker.Parent do
			local state = plr:GetAttribute(QUEST_KEY)
			if state == "done" then break end
			local target, place, text
			if state == "active" then
				target, place, text = cola, "ShellBlox", "Buy a Bloxy Cola at ShellBlox"
			elseif state == "ready" then
				target, place, text = bobHead, "Bob", "Bring the Bloxy Cola back to Bob!"
			else
				target, place, text = bobHead, "Bob", "Talk to Bob and take his job!"
			end
			task_.Text = text
			-- hidden while you're in a conversation
			local talking = currentCutsceneNPC ~= nil
			card.Visible = not talking
			marker.Adornee = target
			marker.Enabled = target ~= nil and not talking
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if target and root then
				dist.Text = place .. " - " .. math.floor((target.Position - root.Position).Magnitude) .. " studs"
			end
			icon.Position = UDim2.fromOffset(0, math.sin((os.clock() - t0) * 4) * 4) -- a gentle bob
			stroke.Transparency = 0.25 + 0.25 * math.sin((os.clock() - t0) * 3)
			task.wait(0.05)
		end
		tracker:Destroy()
	end)
end

-- GAME OF S.C.O.O.T. scoreboard: shows while you're in a game (or its lobby): everyone's letters,
-- whose turn it is and a countdown. It never says which trick was done - you have to watch.
do
	local WORD = { "S", "C", "O", "O", "T" }
	local board = Instance.new("ScreenGui")
	board.Name = "ScootBoard"
	board.ResetOnSpawn = false
	board.DisplayOrder = 6
	board.Enabled = false
	board.Parent = plr:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(16, 70)
	panel.Size = UDim2.fromOffset(300, 60)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	panel.BackgroundTransparency = 0.15
	panel.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 140, 40)
	stroke.Thickness = 2
	stroke.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = panel

	local function label(order, size, color)
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 6)
		l.Font = Enum.Font.PermanentMarker
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.RichText = true
		l.Parent = panel
		return l
	end
	local title = label(0, 20, Color3.fromRGB(255, 170, 60))
	title.Text = "GAME OF S.C.O.O.T."
	local rows = {} -- player rows, rebuilt each update
	local msg = label(100, 16, Color3.fromRGB(230, 230, 240))

	-- the big "your turn" banner in the middle of the screen
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 74)
	banner.Size = UDim2.fromOffset(560, 54)
	banner.BackgroundColor3 = Color3.fromRGB(255, 140, 40)
	banner.BackgroundTransparency = 0.1
	banner.Font = Enum.Font.PermanentMarker
	banner.TextSize = 28
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.TextStrokeTransparency = 0.4
	banner.Visible = false
	banner.Parent = board
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 14)
	bannerCorner.Parent = banner

	local deadline, turnText = nil, nil
	RunService.Heartbeat:Connect(function()
		if banner.Visible and deadline and turnText then
			banner.Text = turnText .. "  " .. math.max(0, math.ceil(deadline - os.clock()))
		end
	end)

	task.spawn(function()
		local update = remotes:WaitForChild("ScootUpdate", 30)
		if not update then return end
		update.OnClientEvent:Connect(function(data)
			if data.teleport then -- to S.C.O.O.T. Park / back to the plaza (we own our physics, so we move ourselves)
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					char:PivotTo(data.teleport)
					root.AssemblyLinearVelocity = Vector3.zero
				end
				return
			end
			if not data.active then
				board.Enabled = false
				banner.Visible = false
				return
			end
			board.Enabled = true
			for _, r in ipairs(rows) do r:Destroy() end
			table.clear(rows)
			for i, pl in ipairs(data.players or {}) do
				local letters = {}
				for k, ch in ipairs(WORD) do
					table.insert(letters, k <= pl.letters and ('<font color="#ff5a5a">' .. ch .. "</font>")
						or ('<font color="#5c5f72">' .. ch .. "</font>"))
				end
				local isTurn = pl.id == data.turnId
				local out = pl.letters >= #WORD
				local r = label(i, 18, out and Color3.fromRGB(120, 120, 130)
					or isTurn and Color3.fromRGB(255, 220, 90) or Color3.new(1, 1, 1))
				r.Text = (isTurn and "> " or "") .. pl.name .. "   " .. table.concat(letters, " ")
				table.insert(rows, r)
			end
			msg.Text = data.msg or ""
			if data.turnId == plr.UserId and data.timeLeft then
				deadline = os.clock() + data.timeLeft
				turnText = data.kind == "set" and "YOUR TURN: SET A TRICK!" or "YOUR TURN: COPY THE TRICK!"
				banner.Visible = true
			else
				banner.Visible = false
			end
		end)
	end)
end

-- TV SHOWS: the TV in rented homes runs an endless, never-the-same show with REAL Roblox avatars
-- (the server's TVCast, animated with Roblox's own walk / run / idle). A little "director" makes up
-- every episode as it goes, on three channels:
--   CH 3 BAY HEIST   a random crew robs a random shop; the cops show up; they escape or get caught
--   CH 7 SCOOTER TV  random riders, random trick runs over the ramp (and the odd bail), live commentary
--   CH 9 BAY NEWS    the anchor reads tonight's Discovery Bay headlines, ticker underneath
-- Only the TV nearest you plays. E on it = watch full-screen (channel buttons, exit button, the show's
-- own music + talking / action sounds, and the town music fades out).
do
	local function clock() return os.clock() * (_G.TVSpeed or 1) end
	local TV_RANGE = 45
	-- picture resolution, in pixels per stud of screen (the screen is 5.6 x 3 studs):
	-- ~1440p while you watch, light while it's just on in the background
	local PPS_WATCH, PPS_IDLE = 400, 90
	local PPS_BASE = 60 -- the overlay (bubbles, captions, ticker) is laid out at this scale
	local MUSIC = { -- licensed APM tracks
		"rbxassetid://1845508355", -- heist: Everyday Groove
		"rbxassetid://9041918820", -- scooter: Spot
		"rbxassetid://1836080955", -- news: Exhilarating Brass And Beats
	}
	local SFX = {
		siren = "rbxassetid://9117810961", alarm = "rbxassetid://9113084849", crowd = "rbxassetid://9112766176",
		boo = "rbxassetid://9120974911",
		whoosh = "rbxassetid://9119421195", thud = "rbxasset://sounds/impact_explosion_03.mp3", blip = "rbxasset://sounds/volume_slider.ogg",
	}
	local screens = {}
	local watching = nil
	local rng = Random.new()

	local function pick(list) return list[rng:NextInteger(1, #list)] end
	local function part(parent, size, color, shape, material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = parent
		return p
	end

	-- the show that's on right now (one at a time)
	local show = nil -- { screen, gui, vf, world, cam, label, caption, bubbles, channel, dead, music }
	local CHANNELS

	-- SOUND MIX: three groups (music / voices / effects). The music ducks under dialogue and big
	-- effects, voices are blips paced by the typewriter text, effects are cut off when their moment ends.
	local function soundGroup(name, volume)
		local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
		g.Name = name
		g.Volume = volume
		g.Parent = SoundService
		return g
	end
	local GROUP_SFX, GROUP_VOICE, GROUP_MUSIC = soundGroup("TVSfx", 0.85), soundGroup("TVVoice", 0.55), soundGroup("TVMusic", 1)
	local MUSIC_VOL, MUSIC_DUCKED = 0.32, 0.1
	local function duck(seconds) -- music dips for this long (overlapping dips just extend it)
		if show then show.duckUntil = math.max(show.duckUntil or 0, clock() + seconds) end
	end
	local function sfx(id, volume, pitch, duration, group)
		if not (watching and show) then return end -- the show is only audible while you watch
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume or 0.5
		s.PlaybackSpeed = pitch or 1
		s.SoundGroup = group or GROUP_SFX
		s.Parent = SoundService
		s:Play()
		if (volume or 0.5) >= 0.35 and group ~= GROUP_VOICE then duck(math.min(duration or 2, 3)) end
		-- (sirens and alarms are long recordings: stop them when their moment is over)
		game:GetService("Debris"):AddItem(s, duration or 8)
	end
	local function blip(pitch, volume)
		if not (watching and show) then return end
		local v = show.voice
		if not (v and v.Parent) then
			v = Instance.new("Sound")
			v.Name = "TVVoice"
			v.SoundId = SFX.blip
			v.SoundGroup = GROUP_VOICE
			v.Parent = SoundService
			show.voice = v
		end
		v.Volume = volume or 0.5
		v.PlaybackSpeed = pitch
		v.TimePosition = 0
		v:Play()
	end
	local function setMusic()
		if show and show.music then show.music:Destroy() show.music = nil end
		if not (watching and show) then return end
		local m = Instance.new("Sound")
		m.SoundId = MUSIC[show.channel]
		m.Looped = true
		m.Volume = MUSIC_VOL
		m.SoundGroup = GROUP_MUSIC
		m.Parent = SoundService
		m:Play()
		show.music = m
	end

	-- director helpers: everything waits through these, so changing channel cancels an episode at once
	local function hold(s)
		local t0 = clock()
		repeat
			task.wait()
			if show == nil or show.dead then error("cut", 0) end
		until clock() - t0 >= s
	end

	-- CAMERA DIRECTOR: a shot is a fixed CFrame or a function giving one every frame (follow cams,
	-- close-ups). Shots ease into each other unless `cut` (a hard TV cut).
	local function setShot(shot, cut)
		show.shot = shot
		if cut then show.snap = true end
	end
	local function wide(pos, look, speed) return { cf = CFrame.lookAt(pos, look), speed = speed or 3 } end
	local function follow(getPos, offset, lookAdd, speed)
		return { fn = function()
			local p = getPos()
			return CFrame.lookAt(p + offset, p + (lookAdd or Vector3.new(0, 2, 0)))
		end, speed = speed or 6 }
	end
	local function closeUp(actor)
		-- in front of the face, a little to one side; pick a side that isn't inside somebody else
		-- (or go up high if both sides are crowded)
		local OFFSETS = { { 6, 1.8, 0.6 }, { 6, -1.8, 0.6 }, { 4.5, 0, 3.2 } }
		local function camPos(o)
			local head = actor.model:FindFirstChild("ClassicHead") or actor.model:FindFirstChild("Head")
			local cf = actor.model:GetPivot()
			return head.Position + cf.LookVector * o[1] + cf.RightVector * o[2] + Vector3.new(0, o[3], 0), head.Position
		end
		local chosen = OFFSETS[3]
		for _, o in ipairs(OFFSETS) do
			local ok, pos = pcall(camPos, o)
			local clear = ok
			if ok then
				for _, other in ipairs(show.actors) do
					if other ~= actor and other.model.Parent and (other.model:GetPivot().Position - pos).Magnitude < 3.2 then
						clear = false
						break
					end
				end
			end
			if clear then chosen = o break end
		end
		return { fn = function()
			if not actor.model.Parent then return show.cam.CFrame end
			local ok, pos, head = pcall(camPos, chosen)
			if not ok then return show.cam.CFrame end
			return CFrame.lookAt(pos, head - Vector3.new(0, 0.3, 0))
		end, speed = 14 }
	end
	local function shake(amount, seconds)
		show.shakeAmt, show.shakeUntil = amount, clock() + seconds
	end

	-- EFFECTS (ViewportFrames can't draw particles, so these are little parts moved every frame)
	local FX = {
		money = { color = Color3.fromRGB(110, 190, 90), size = Vector3.new(0.7, 0.06, 0.35), speed = 9, up = 10, life = 1.6, gravity = 18, spin = true },
		smoke = { color = Color3.fromRGB(150, 150, 155), size = Vector3.new(1, 1, 1), speed = 2, up = 3, life = 1.8, gravity = -1, grow = 2.2, ball = true },
		spark = { color = Color3.fromRGB(255, 220, 90), size = Vector3.new(0.18, 0.18, 0.18), speed = 14, up = 8, life = 0.5, gravity = 25, neon = true },
		dust = { color = Color3.fromRGB(190, 170, 130), size = Vector3.new(0.7, 0.7, 0.7), speed = 4, up = 2, life = 1.2, gravity = 2, grow = 1.6, ball = true },
		food = { color = Color3.fromRGB(230, 200, 120), size = Vector3.new(0.6, 0.6, 0.6), speed = 12, up = 9, life = 1.4, gravity = 22, ball = true },
	}
	local function burst(kind, pos, n)
		local k = FX[kind]
		for _ = 1, n or 10 do
			local p = part(show.world, k.size, k.color, k.ball and Enum.PartType.Ball or nil, k.neon and Enum.Material.Neon or nil)
			p.CFrame = CFrame.new(pos)
			local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			table.insert(show.fx, {
				p = p, pos = pos, k = k, age = 0,
				v = dir * k.speed * rng:NextNumber(0.4, 1) + Vector3.new(0, k.up * rng:NextNumber(0.6, 1.2), 0),
				spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
			})
		end
	end
	local function flash(color, strength)
		show.flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
		show.flash.BackgroundTransparency = 1 - (strength or 0.7)
		TweenService:Create(show.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end
	local function fade(toBlack, seconds)
		TweenService:Create(show.fade, TweenInfo.new(seconds or 0.5), { BackgroundTransparency = toBlack and 0 or 1 }):Play()
		hold(seconds or 0.5)
	end
	local function titleCard(top, big)
		show.titleTop.Text, show.titleBig.Text = top, big
		show.title.Visible = true
		show.titleScale.Scale = 0.85
		TweenService:Create(show.titleScale, TweenInfo.new(1.8, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
		sfx(SFX.whoosh, 0.35, 0.9, 2)
		hold(1.8)
		show.title.Visible = false
	end

	local function cast(role, which)
		local folder = ReplicatedStorage:FindFirstChild("TVCast")
		local options = {}
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:GetAttribute("Role") == role and (which == nil or m.Name == which) then table.insert(options, m) end
		end
		if #options == 0 then error("no cast", 0) end
		local model = pick(options):Clone()
		model.Parent = show.world
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		local torso = model:FindFirstChild("Torso")
		local leg = model:FindFirstChild("Left Leg")
		local height = 3
		if leg then height = model:GetPivot().Position.Y - (leg.Position.Y - leg.Size.Y / 2) end
		local actor = {
			model = model, height = height,
			voice = rng:NextNumber(0.85, 1.5), -- everyone talks at their own pitch
			seed = rng:NextNumber(0, 100), talkHand = rng:NextInteger(0, 1) == 0 and "RS" or "LS",
			joints = torso and {
				RS = torso:FindFirstChild("Right Shoulder"), LS = torso:FindFirstChild("Left Shoulder"),
				RH = torso:FindFirstChild("Right Hip"), LH = torso:FindFirstChild("Left Hip"), N = torso:FindFirstChild("Neck"),
			} or {},
		}
		table.insert(show.actors, actor)
		-- no Animator: it would overwrite the poses written every frame
		for _, a in ipairs(model:GetDescendants()) do
			if a:IsA("Animator") then a:Destroy() end
		end
		function actor.anim(name) -- "idle" / "walk" / "run": the body poser reads this every frame
			actor.current = name
		end
		function actor.place(pos, lookAt)
			local p = Vector3.new(pos.X, pos.Y + actor.height, pos.Z)
			local l = lookAt and Vector3.new(lookAt.X, p.Y, lookAt.Z) or (p + Vector3.new(0, 0, -1))
			if (l - p).Magnitude < 0.01 then l = p + Vector3.new(0, 0, -1) end
			model:PivotTo(CFrame.lookAt(p, l))
			actor.pos = pos
		end
		function actor.face(at) actor.place(actor.pos, at) end
		function actor.go(to, speed, animName) -- walk / run in a straight line, then stand
			actor.anim(animName or (speed >= 12 and "run" or "walk"))
			actor.speed = speed
			local from = actor.pos
			local dist = (to - from).Magnitude
			local t0 = clock()
			while dist > 0.01 do
				local u = math.min((clock() - t0) * speed / dist, 1)
				actor.place(from:Lerp(to, u), to + (to - from).Unit)
				if u >= 1 then break end
				hold(0)
			end
			actor.anim("idle")
		end
		function actor.gesture(name, seconds) -- arms posed over the animation (see GESTURES)
			actor.g = { name = name, t0 = clock(), dur = seconds or 1.5 }
		end
		function actor.hide() model.Parent = nil end
		function actor.show() model.Parent = show.world end
		actor.anim("idle")
		return actor
	end
	-- R6 body poses. Shoulders and hips swing forward/back about their Z axis (mirrored: + lifts the
	-- right arm forward, - lifts the left); X tilts the arm out to the side (negative = outward).
	local poseActor = (function() -- (own function: the TV code is near Luau's 200-locals limit)
	local A = CFrame.Angles
	local rad = math.rad
	local function arms(rf, ro, lf, lo)
		return { RS = A(rad(-ro), 0, rad(rf)), LS = A(rad(-lo), 0, rad(-lf)) }
	end
	local GESTURES = {
		handsUp = function(t) local p = arms(165 + 6 * math.sin(t * 9), 14, 165 - 6 * math.sin(t * 9), 14) p.N = A(rad(-8), 0, 0) return p end,
		point = function() return { RS = A(rad(-6), 0, rad(92)), N = A(0, 0, rad(-10)) } end,
		cheer = function(t)
			local bob = 14 * math.sin(t * 14)
			local p = arms(160 + bob, 28, 160 - bob, 28)
			p.N = A(rad(-15), 0, 0)
			return p
		end,
		facepalm = function() return { RS = A(rad(28), 0, rad(128)), N = A(rad(22), 0, 0) } end,
		shrug = function(t) local u = math.min(t * 4, 1) local p = arms(22 * u, 42 * u, 22 * u, 42 * u) p.N = A(0, rad(14), 0) return p end,
		wave = function(t) return { RS = A(rad(-(150 + 22 * math.sin(t * 11))), 0, rad(10)) } end,
		carry = function() return arms(72, -12, 72, -12) end,
		dig = function(t) local v = 60 + 45 * math.sin(t * 9) local p = arms(v, 0, v, 0) p.N = A(rad(20), 0, 0) return p end,
		lift = function(t) local u = (math.sin(t * 5) + 1) / 2 return arms(95 + 75 * u, 10, 95 + 75 * u, 10) end,
		binoculars = function() local p = arms(128, -32, 128, -32) p.N = A(rad(-8), 0, 0) return p end,
		-- talking: one hand moving with the words
		talk = function(t, actor)
			local f = 38 + 22 * math.sin(t * 6.5)
			if actor.talkHand == "LS" then return { LS = A(rad(-12), 0, rad(-f)) } end
			return { RS = A(rad(-12), 0, rad(f)) }
		end,
	}
	local NO_POSE = CFrame.new()
	-- every frame: the base body motion (walk / run swing, idle breathing, head looking about, nodding
	-- while talking) with any gesture blended over it
	local function poseActor(actor, now, dt)
		local j = actor.joints
		local mode = actor.current or "idle"
		local pose = {}
		if mode == "walk" or mode == "run" then
			local run = mode == "run"
			actor.phase = (actor.phase or 0) + dt * (run and 13 or 8) * math.clamp((actor.speed or 8) / (run and 16 or 8), 0.7, 1.4)
			local sw = math.sin(actor.phase)
			local amp = run and 1.15 or 0.7
			pose.RS, pose.LS = A(rad(-4), 0, amp * sw), A(rad(-4), 0, amp * sw)
			pose.RH, pose.LH = A(0, 0, -amp * 0.9 * sw), A(0, 0, -amp * 0.9 * sw)
			pose.N = A(run and rad(10) or 0, 0, 0)
		else
			local br = math.sin(now * 2.2 + actor.seed) * 0.05
			pose.RS, pose.LS = A(rad(-5), 0, br), A(rad(-5), 0, -br)
			pose.N = A(0, 0, math.sin(now * 0.6 + actor.seed) * 0.22)
		end
		if now < (actor.talkUntil or 0) then -- nodding along with the words
			pose.N = (pose.N or NO_POSE) * A(math.sin(now * 11 + actor.seed) * 0.09, 0, 0)
		end
		local g = actor.g
		if g then
			local t = now - g.t0
			if t > g.dur then
				actor.g = nil
			else
				local w = math.clamp(math.min(t, g.dur - t) / 0.2, 0, 1)
				local fn = GESTURES[g.name]
				for key, cf in pairs(fn and fn(t, actor) or {}) do
					pose[key] = (pose[key] or NO_POSE):Lerp(cf, w)
				end
			end
		end
		for key, joint in pairs(j) do
			joint.Transform = pose[key] or NO_POSE
		end
	end
	return poseActor
	end)()

	-- speech: a bubble over the head, the text typing itself out with blips at the speaker's pitch;
	-- in cinematic shows the camera cuts to a close-up of whoever's talking and back afterwards
	local function say(actor, text, dur, noCloseUp)
		local before = show.shot
		if show.cinematic and not noCloseUp and actor.model.Parent then setShot(closeUp(actor), true) end
		local b = Instance.new("TextLabel")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 22)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.PermanentMarker
		b.TextSize = 14
		b.TextColor3 = Color3.fromRGB(20, 20, 30)
		b.ZIndex = 5
		b.Parent = show.overlay
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		local entry = { label = b, actor = actor }
		table.insert(show.bubbles, entry)
		local who = actor.name and (actor.name .. ": ") or ""
		duck((dur or 2) + 0.3)
		local typing = #text * 0.03
		actor.talkUntil = clock() + typing
		if not actor.g then actor.gesture("talk", typing + 0.3) end
		task.spawn(function() -- typewriter + voice
			for i = 1, #text do
				if not b.Parent then return end
				b.Text = "  " .. who .. text:sub(1, i) .. "  "
				local ch = text:sub(i, i)
				if i % 3 == 1 and ch:match("%w") then blip(actor.voice * rng:NextNumber(0.94, 1.08), 0.55) end
				task.wait(0.03)
			end
		end)
		hold(math.max(dur or 2, typing + 0.8))
		b:Destroy()
		table.remove(show.bubbles, table.find(show.bubbles, entry))
		if show.cinematic and not noCloseUp then setShot(before, true) end
	end
	local function caption(text, dur) -- the narrator / commentator / news voice
		show.caption.Text = ""
		show.caption.Visible = true
		duck((dur or 2.5) + 0.3)
		local s = show
		task.spawn(function() -- (writes only to its own show, even if the channel changes meanwhile)
			for i = 1, #text do
				if s.dead then return end
				s.caption.Text = text:sub(1, i)
				if i % 4 == 1 and text:sub(i, i):match("%w") then blip(0.8, 0.4) end
				task.wait(0.022)
			end
		end)
		hold(math.max(dur or 2.5, #text * 0.022 + 1))
		show.caption.Visible = false
	end

	local story, PLOTS -- (the saga's state: the news channel reports on it; the plot book)
	-- the saga lives in its own function: the TV code has more locals than one function may hold
	local heistSaga = (function()
		-- CH 3: BAY HEIST, a continuing crime saga ---------------------------------------------------
		-- One gang, Officer Dan and Judge Gavelton, carried from episode to episode. Each chapter decides
		-- what comes next from how it ended, so the story wanders: the plan, the job, car chases, the
		-- hideout, police stakeouts, a beach getaway, court, jail, the prison yard, breakouts...
		local GANG_NAMES = { "Mugsy", "Slick", "Big Tony", "Lefty", "Noodle", "Sneaky Pete", "Knuckles", "Jimmy Two-Shoes" }
		local HEIST_TARGETS = {
			{ name = "THE BANK", wall = Color3.fromRGB(215, 205, 180), sign = Color3.fromRGB(250, 205, 40) },
			{ name = "SHELLBLOX", wall = Color3.fromRGB(240, 240, 240), sign = Color3.fromRGB(230, 40, 40) },
			{ name = "CALLAHAN'S", wall = Color3.fromRGB(250, 200, 220), sign = Color3.fromRGB(150, 60, 160) },
			{ name = "THE EGG SHOP", wall = Color3.fromRGB(250, 240, 200), sign = Color3.fromRGB(255, 170, 60) },
		}
		story = { ep = 0, chapter = "plan", gang = nil, gangName = nil, news = nil, jailDays = 0, loot = 0, years = 0 }
		local ORANGE = Color3.fromRGB(255, 130, 40)
		local NIGHT, DAY = Color3.fromRGB(14, 18, 42), Color3.fromRGB(120, 190, 255)

		local function newGang()
			local templates = {}
			for _, m in ipairs(ReplicatedStorage.TVCast:GetChildren()) do
				if m:GetAttribute("Role") == "Robber" then table.insert(templates, m.Name) end
			end
			local names = table.clone(GANG_NAMES)
			story.gang = {}
			for i = 1, rng:NextInteger(2, 3) do
				story.gang[i] = { template = templates[(i - 1) % #templates + 1], name = table.remove(names, rng:NextInteger(1, #names)) }
			end
			story.gangName = "The " .. story.gang[1].name .. " Gang"
			story.target = pick(HEIST_TARGETS)
			story.jailDays, story.loot, story.gangEps, story.years, story.chapter = 0, 0, 0, 0, "plan"
		end
		local SKIN = { Color3.fromRGB(255, 205, 150), Color3.fromRGB(234, 184, 146), Color3.fromRGB(160, 110, 75) }
		-- masks on the job only; everywhere else you see their faces
		local function castGang(jumpsuits, masked)
			local list = {}
			for i, g in ipairs(story.gang) do
				local a = cast("Robber", g.template)
				a.name = g.name
				local head = a.model:FindFirstChild("Head")
				if head and not masked then head.Color = SKIN[(i - 1) % #SKIN + 1] end
				if jumpsuits then -- prison orange (the robbers wear body colours, not clothing)
					for _, p in ipairs(a.model:GetChildren()) do
						if p:IsA("BasePart") and p.Name ~= "Head" and p.Name ~= "HumanoidRootPart" then p.Color = ORANGE end
					end
				end
				list[i] = a
			end
			return list
		end
		local function named(actor, nm) actor.name = nm return actor end
		local function headPos(actor) return actor.model:GetPivot().Position end

		-- sets ------------------------------------------------------------------------------------------
		local function street(night)
			local w = show.world
			show.vf.BackgroundColor3 = night and NIGHT or DAY
			part(w, Vector3.new(140, 1, 50), Color3.fromRGB(70, 70, 76)).CFrame = CFrame.new(0, -0.5, 6)
			part(w, Vector3.new(140, 0.2, 5), Color3.fromRGB(150, 150, 150)).CFrame = CFrame.new(0, -0.04, -1)
			for i = -5, 5 do -- a row of buildings behind
				part(w, Vector3.new(11, rng:NextInteger(9, 16), 6), Color3.fromHSV(rng:NextNumber(), 0.25, night and 0.45 or 0.85)).CFrame = CFrame.new(i * 12, 6, 18)
			end
			for x = -48, 48, 24 do -- streetlights
				part(w, Vector3.new(0.4, 9, 0.4), Color3.fromRGB(60, 60, 66)).CFrame = CFrame.new(x, 4.5, 1.5)
				part(w, Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 230, 160), Enum.PartType.Ball, Enum.Material.Neon).CFrame = CFrame.new(x, 9.2, 1.5)
			end
			if night then
				part(w, Vector3.new(5, 5, 5), Color3.fromRGB(240, 240, 220), Enum.PartType.Ball, Enum.Material.Neon).CFrame = CFrame.new(-22, 26, 40)
			end
		end
		local function shopFront(x, target)
			local w = show.world
			part(w, Vector3.new(16, 11, 8), target.wall).CFrame = CFrame.new(x, 5.5, 5)
			part(w, Vector3.new(4, 6.5, 0.3), Color3.fromRGB(60, 40, 30)).CFrame = CFrame.new(x, 3.25, 0.9)
			part(w, Vector3.new(9, 2, 0.4), target.sign, nil, Enum.Material.Neon).CFrame = CFrame.new(x, 9, 0.8)
			local alarm = part(w, Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(90, 20, 20), Enum.PartType.Ball, Enum.Material.Neon)
			alarm.CFrame = CFrame.new(x + 6.5, 10, 0.6)
			return alarm
		end
		local function room(floorColor, wallColor, bg)
			show.vf.BackgroundColor3 = bg or Color3.fromRGB(10, 10, 14)
			part(show.world, Vector3.new(60, 1, 30), floorColor).CFrame = CFrame.new(0, -0.5, 6)
			part(show.world, Vector3.new(60, 20, 1), wallColor).CFrame = CFrame.new(0, 10, 10)
		end
		-- a vehicle: drives along x; police ones flash
		local function vehicle(kind, x, z)
			local car = Instance.new("Model")
			local police = kind == "police"
			local bodyColor = police and Color3.fromRGB(245, 245, 250) or kind == "van" and Color3.fromRGB(50, 52, 60) or Color3.fromRGB(80, 160, 220)
			local body = part(car, Vector3.new(kind == "van" and 10 or 9, kind == "van" and 3.6 or 2.6, 4), bodyColor)
			body.CFrame = CFrame.new(x, kind == "van" and 2.5 or 2, z or -8)
			car.PrimaryPart = body
			part(car, Vector3.new(4.5, 1.6, 3.6), Color3.fromRGB(30, 30, 40)).CFrame = body.CFrame * CFrame.new(kind == "van" and 2.5 or -0.5, kind == "van" and 2.2 or 2.1, 0)
			local red, blue
			if police then
				part(car, Vector3.new(9.05, 0.6, 4.05), Color3.fromRGB(30, 40, 90)).CFrame = body.CFrame * CFrame.new(0, -0.2, 0)
				red = part(car, Vector3.new(0.8, 0.6, 0.8), Color3.fromRGB(255, 40, 40), nil, Enum.Material.Neon)
				red.CFrame = body.CFrame * CFrame.new(-1, 3.2, 0)
				blue = part(car, Vector3.new(0.8, 0.6, 0.8), Color3.fromRGB(40, 90, 255), nil, Enum.Material.Neon)
				blue.CFrame = body.CFrame * CFrame.new(0.2, 3.2, 0)
			end
			for _, wx in ipairs({ -3, 3 }) do
				part(car, Vector3.new(0.8, 2, 2), Color3.fromRGB(20, 20, 20), Enum.PartType.Cylinder).CFrame =
					body.CFrame * CFrame.new(wx, kind == "van" and -1.7 or -1.2, -2.1) * CFrame.Angles(0, math.pi / 2, 0)
			end
			car.Parent = show.world
			if police then
				task.spawn(function()
					while car.Parent and show and not show.dead do
						local on = math.floor(os.clock() * 8) % 2 == 0
						red.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(80, 10, 10)
						blue.Color = on and Color3.fromRGB(20, 20, 80) or Color3.fromRGB(40, 90, 255)
						task.wait(0.05)
					end
				end)
			end
			local v = { model = car }
			function v.pos() return body.Position end
			function v.drive(toX, t, extra) -- extra(u) = an optional CFrame wobble along the way
				local from = body.Position
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / t, 1)
					local cf = CFrame.new(from.X + (toX - from.X) * u, from.Y, from.Z)
					car:PivotTo(extra and cf * extra(u) or cf)
					hold(0)
				until u >= 1
			end
			return v
		end
		local function alarmFlashes(alarm, seconds)
			sfx(SFX.alarm, 0.4, 1, seconds)
			task.spawn(function()
				local t0 = clock()
				while clock() - t0 < seconds and show and not show.dead do
					local on = math.floor(clock() * 6) % 2 == 0
					if alarm then alarm.Color = on and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(90, 20, 20) end
					if on then flash(Color3.fromRGB(255, 30, 30), 0.25) end
					task.wait(1 / 6)
				end
			end)
		end
		-- THE ARREST: car pulls up, hands up, everyone into the back, off it goes
		local function arrest(crew, cop, x, line)
			sfx(SFX.siren, 0.4, 1, 5)
			local car = vehicle("police", x - 50)
			setShot(follow(car.pos, Vector3.new(0, 7, -22), Vector3.new(0, 2, 0), 5), false)
			car.drive(x, 1.8)
			shake(0.15, 0.3)
			for _, r in ipairs(crew) do if r.model.Parent then r.gesture("handsUp", 4) end end
			setShot(wide(Vector3.new(x - 4, 7, -24), Vector3.new(x, 3, -3), 4), true)
			say(cop, line or pick({ "You're under arrest!", "Hands where I can see 'em!", "Into the car. ALL of you." }), 2)
			for _, r in ipairs(crew) do
				if r.model.Parent then
					pcall(r.go, Vector3.new(x + 1, 0, -5.5), 9)
					r.hide() -- into the back seat
					sfx(SFX.thud, 0.2, 2.2, 0.6)
					hold(0.2)
				end
			end
			pcall(cop.go, Vector3.new(x - 2, 0, -5.5), 9)
			cop.hide()
			setShot(follow(car.pos, Vector3.new(-6, 6, -20), Vector3.new(0, 2, 0), 4), false)
			car.drive(x + 60, 2.4)
		end

		-- the chapters -----------------------------------------------------------------------------
		local function chapterPlan()
			room(Color3.fromRGB(70, 55, 45), Color3.fromRGB(90, 80, 70), Color3.fromRGB(8, 8, 10))
			local board = part(show.world, Vector3.new(12, 6, 0.3), Color3.fromRGB(240, 240, 235))
			board.CFrame = CFrame.new(-4, 6, 9.3)
			for i = 1, 3 do -- the plan: red lines + an X on the target
				part(show.world, Vector3.new(rng:NextNumber(3, 7), 0.15, 0.1), Color3.fromRGB(220, 40, 40), nil, Enum.Material.Neon).CFrame =
					board.CFrame * CFrame.new(rng:NextNumber(-3, 2), rng:NextNumber(-2, 2), -0.2) * CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6))
			end
			for _, r in ipairs({ math.pi / 4, -math.pi / 4 }) do
				part(show.world, Vector3.new(2.2, 0.25, 0.1), Color3.fromRGB(220, 40, 40), nil, Enum.Material.Neon).CFrame = board.CFrame * CFrame.new(3.5, 1.5, -0.2) * CFrame.Angles(0, 0, r)
			end
			part(show.world, Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 230, 160), Enum.PartType.Ball, Enum.Material.Neon).CFrame = CFrame.new(0, 11, 2)
			local crew = castGang(false)
			crew[1].place(Vector3.new(-9, 0, 7), Vector3.new(-4, 0, 9))
			for i = 2, #crew do crew[i].place(Vector3.new(-2 + (i - 2) * 4, 0, 1), Vector3.new(-6, 0, 8)) end
			setShot(wide(Vector3.new(4, 7, -16), Vector3.new(-4, 5, 6), 3), true)
			fade(false, 0.6)
			caption("Somewhere in Discovery Bay, " .. story.gangName .. " is planning their next move.", 2.4)
			crew[1].face(headPos(crew[2]))
			crew[1].gesture("point", 3)
			say(crew[1], "Listen up. The target: " .. story.target.name .. ".", 2.4)
			if crew[2] then crew[2].gesture("shrug", 2) say(crew[2], pick({ "What's our cut?", "Do I get a cool code name?", "Can we NOT get caught this time?" }), 2) end
			say(crew[1], pick({ "We go in at midnight.", "In and out. Nobody gets hurt.", "And NOBODY touches the snacks." }), 2.2)
			if crew[3] then crew[3].gesture("cheer", 1.6) say(crew[3], "I'm in!", 1.4) end
			story.chapter = "job"
		end

		local function chapterJob()
			local target = story.target or pick(HEIST_TARGETS)
			street(true)
			local alarm = shopFront(10, target)
			local crew = castGang(false, true)
			for i, r in ipairs(crew) do r.place(Vector3.new(-34 - i * 3, 0, -3), Vector3.new(0, 0, -3)) end
			setShot(wide(Vector3.new(-10, 12, -40), Vector3.new(4, 4, 0), 3), true)
			fade(false, 0.6)
			caption("Midnight. " .. story.gangName .. " closes in on " .. target.name .. ".", 2.2)
			setShot(follow(function() return headPos(crew[1]) end, Vector3.new(-8, 4, -14), Vector3.new(2, 0, 0), 4))
			for i, r in ipairs(crew) do task.spawn(function() pcall(r.go, Vector3.new(6 - i * 3, 0, -3), 8) end) end
			hold(4.8)
			say(crew[1], pick({ "Ok... act natural.", "This is the big one, boys.", "Masks on. Wait, they're already on." }), 2.2)
			if crew[2] then say(crew[2], pick({ "I'm hungry.", "Do we HAVE to?", "Last time I lost a shoe." }), 1.8) end
			for _, r in ipairs(crew) do r.hide() end
			setShot(wide(Vector3.new(4, 7, -22), Vector3.new(10, 6, 2), 3), false)
			hold(0.8)
			alarmFlashes(alarm, 3.5)
			shake(0.25, 0.5)
			hold(1.6)
			burst("money", Vector3.new(10, 4, 0), 18)
			for i, r in ipairs(crew) do
				r.show()
				r.place(Vector3.new(10 - i * 1.5, 0, -2), Vector3.new(40, 0, -2))
				r.gesture("carry", 6)
			end
			say(crew[#crew], pick({ "GO GO GO!", "Grab the cash, NOT the snacks!", "Somebody tripped the alarm!" }), 1.4)
			sfx(SFX.siren, 0.35, 1, 4)
			local cop = named(cast("Cop"), "Officer Dan")
			cop.place(Vector3.new(-36, 0, -5), Vector3.new(0, 0, -5))
			local caught = rng:NextNumber() < 0.45
			story.loot = rng:NextInteger(2, 9) * 1000
			for i, r in ipairs(crew) do
				task.spawn(function() pcall(r.go, Vector3.new(caught and (16 + i * 3) or 50, 0, -2), caught and 9 or 14, "run") end)
			end
			task.spawn(function() pcall(cop.go, Vector3.new(caught and 10 or 22, 0, -5), 15, "run") end)
			setShot(follow(function() return headPos(cop) end, Vector3.new(0, 5, -18), Vector3.new(4, 0, 0), 5))
			hold(1.4)
			cop.gesture("point", 2)
			say(cop, "FREEZE! Discovery Bay PD!", 1.8)
			if caught then
				for _, r in ipairs(crew) do r.face(headPos(cop)) end
				say(crew[1], pick({ "Aw man.", "It was HIS idea!", "Can I at least keep the snacks?" }), 2)
				arrest(crew, cop, 12)
				story.news = story.gangName .. " ARRESTED robbing " .. target.name .. "! Court date set."
				story.chapter = "court"
			else
				cop.gesture("facepalm", 2.2)
				say(cop, pick({ "...I'll get you next time!", "Not again!", "Somebody call my mom." }), 2.2)
				story.news = story.gangName .. " hits " .. target.name .. " and gets away with $" .. story.loot .. "!"
				story.chapter = rng:NextNumber() < 0.6 and "chase" or "hideout"
			end
		end

		local function chapterChase()
			street(true)
			local hydrant = part(show.world, Vector3.new(1.2, 2, 1.2), Color3.fromRGB(220, 40, 40), Enum.PartType.Cylinder)
			hydrant.CFrame = CFrame.new(18, 1, -2.5) * CFrame.Angles(0, 0, math.pi / 2)
			local van = vehicle("van", -60, -6)
			local cops = vehicle("police", -78, -9)
			setShot(follow(van.pos, Vector3.new(-4, 6, -24), Vector3.new(4, 0, 0), 6), true)
			fade(false, 0.5)
			caption("The getaway! Officer Dan is right on their tail.", 1.8)
			sfx(SFX.siren, 0.4, 1, 6)
			local crash = rng:NextNumber() < 0.4
			task.spawn(function()
				pcall(cops.drive, crash and 4 or 70, 4.2, function(u) return CFrame.Angles(0, math.sin(u * 20) * 0.08, 0) end)
			end)
			if crash then
				van.drive(14, 3.4, function(u) return CFrame.Angles(0, math.sin(u * 16) * 0.12, 0) end)
				sfx(SFX.thud, 0.6, 0.7, 2)
				shake(0.6, 0.8)
				flash(Color3.new(1, 1, 1), 0.6)
				burst("spark", Vector3.new(18, 2, -5), 16)
				burst("smoke", Vector3.new(16, 3, -6), 10)
				van.model:PivotTo(van.model:GetPivot() * CFrame.Angles(0, math.rad(25), math.rad(6)))
				setShot(wide(Vector3.new(4, 8, -26), Vector3.new(14, 2, -5), 3), true)
				hold(1.2)
				local crew = castGang(false, true)
				for i, r in ipairs(crew) do r.place(Vector3.new(12 + i * 2.5, 0, -2), Vector3.new(0, 0, -2)) r.gesture("facepalm", 1.5) end
				say(crew[1], pick({ "Who put a hydrant THERE?!", "I told you I can't drive!", "My neck..." }), 2)
				local cop = named(cast("Cop"), "Officer Dan")
				cop.place(Vector3.new(2, 0, -5), Vector3.new(14, 0, -2))
				arrest(crew, cop, 16, "End of the road, boys.")
				story.news = "WILD CHASE ends in a hydrant. " .. story.gangName .. " in custody!"
				story.chapter = "court"
			else
				van.drive(80, 4.8, function(u) return CFrame.Angles(0, math.sin(u * 14) * 0.1, 0) end)
				-- the police car spins out
				setShot(wide(Vector3.new(30, 9, -28), Vector3.new(40, 2, -9), 3), true)
				local p0 = cops.model:GetPivot()
				local t0 = clock()
				sfx(SFX.thud, 0.4, 1.2, 1)
				repeat
					local u = math.min((clock() - t0) / 1.2, 1)
					cops.model:PivotTo(p0 * CFrame.new(u * 6, 0, 0) * CFrame.Angles(0, u * math.pi * 1.5, 0))
					if math.random() < 0.3 then burst("smoke", cops.pos(), 1) end
					hold(0)
				until u >= 1
				caption(pick({ "They're gone. Officer Dan is NOT happy.", "Lost them! The gang vanishes into the night." }), 2.2)
				story.news = story.gangName .. " escapes a high-speed chase. Police baffled."
				story.chapter = rng:NextNumber() < 0.5 and "beach" or "hideout"
			end
		end

		local function chapterHideout()
			room(Color3.fromRGB(70, 55, 45), Color3.fromRGB(90, 80, 70), Color3.fromRGB(8, 8, 10))
			part(show.world, Vector3.new(10, 3, 5), Color3.fromRGB(110, 75, 45)).CFrame = CFrame.new(0, 1.5, 3)
			for i = 1, 8 do
				part(show.world, Vector3.new(1.4, 0.5, 0.8), Color3.fromRGB(110, 190, 90)).CFrame = CFrame.new(-4 + i, 3.25 + (i % 2) * 0.5, 3)
			end
			part(show.world, Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 230, 160), Enum.PartType.Ball, Enum.Material.Neon).CFrame = CFrame.new(0, 11, 3)
			local crew = castGang(false)
			for i, r in ipairs(crew) do r.place(Vector3.new(-6 + (i - 1) * 6, 0, 6.5), Vector3.new(0, 0, -10)) end
			setShot(wide(Vector3.new(0, 9, -16), Vector3.new(0, 3, 4), 3), true)
			fade(false, 0.6)
			caption("The hideout. Time to count the loot.", 2)
			burst("money", Vector3.new(0, 4, 3), 20)
			crew[1].gesture("cheer", 2)
			say(crew[1], "We got $" .. story.loot .. "!", 1.8)
			if crew[2] then
				crew[2].gesture("point", 2)
				say(crew[2], pick({ "Hey! Your pile is bigger than mine!", "I want the bigger half.", "Can we buy a Fast Scooter now?" }), 2.2)
				crew[1].gesture("shrug", 1.8)
				say(crew[1], pick({ "I'm the boss. Boss gets more.", "Math was never my thing.", "Count it again then." }), 2)
			end
			local r = rng:NextNumber()
			story.target = pick(HEIST_TARGETS)
			if r < 0.45 then
				say(crew[1], "Next stop... " .. story.target.name .. ".", 2)
				story.chapter = "plan"
			elseif r < 0.75 then
				caption("But across the street, someone is watching...", 2.2)
				story.chapter = "stakeout"
			else
				say(crew[#crew], "Let's take a little vacation.", 1.8)
				story.chapter = "beach"
			end
		end

		local function chapterStakeout()
			street(true)
			part(show.world, Vector3.new(16, 12, 8), Color3.fromRGB(90, 80, 70)).CFrame = CFrame.new(14, 6, 5) -- the hideout
			local window = part(show.world, Vector3.new(3, 2.5, 0.3), Color3.fromRGB(255, 220, 140), nil, Enum.Material.Neon)
			window.CFrame = CFrame.new(14, 8, 0.8)
			part(show.world, Vector3.new(4, 6.5, 0.3), Color3.fromRGB(50, 35, 25)).CFrame = CFrame.new(10, 3.25, 0.9)
			vehicle("police", -12, -8)
			local cop = named(cast("Cop"), "Officer Dan")
			cop.place(Vector3.new(-6, 0, -5), Vector3.new(14, 0, 2))
			setShot(wide(Vector3.new(-22, 7, -22), Vector3.new(4, 4, 0), 3), true)
			fade(false, 0.6)
			caption("Officer Dan's stakeout. Night " .. rng:NextInteger(2, 9) .. ".", 2)
			cop.gesture("binoculars", 4)
			say(cop, pick({ "Still no sign of them...", "I KNOW they're in there.", "Should've brought more donuts." }), 2.4)
			local crew = castGang(false, true)
			for _, r in ipairs(crew) do r.hide() end
			if rng:NextNumber() < 0.55 then
				window.Color = Color3.fromRGB(60, 50, 40)
				hold(0.8)
				for i, r in ipairs(crew) do r.show() r.place(Vector3.new(10 + i * 1.5, 0, -1), Vector3.new(40, 0, -1)) r.gesture("carry", 4) end
				cop.gesture("point", 2)
				say(cop, "GOTCHA!", 1.4)
				arrest(crew, cop, 14, "Thought you could hide from ME?")
				story.news = "Stakeout pays off! " .. story.gangName .. " caught leaving their hideout."
				story.chapter = "court"
			else
				say(cop, "Zzz... zzz...", 2.2, true)
				for i, r in ipairs(crew) do r.show() r.place(Vector3.new(10 + i * 2, 0, -1), Vector3.new(-40, 0, -1)) end
				setShot(wide(Vector3.new(-2, 8, -26), Vector3.new(0, 3, -2), 3), true)
				for i, r in ipairs(crew) do task.spawn(function() pcall(r.go, Vector3.new(-50 - i * 3, 0, -1), 5) end) end
				hold(1)
				say(crew[1], "Shhhh...", 1.6)
				caption("...and they tiptoe right past him.", 2.4)
				story.news = story.gangName .. " slips past a sleeping officer. Again."
				story.chapter = "beach"
			end
		end

		local function chapterBeach()
			show.vf.BackgroundColor3 = DAY
			part(show.world, Vector3.new(140, 1, 20), Color3.fromRGB(240, 220, 160)).CFrame = CFrame.new(0, -0.5, -2)
			local sea = part(show.world, Vector3.new(140, 1, 40), Color3.fromRGB(60, 160, 220))
			sea.CFrame = CFrame.new(0, -0.7, 28)
			part(show.world, Vector3.new(6, 6, 6), Color3.fromRGB(255, 240, 160), Enum.PartType.Ball, Enum.Material.Neon).CFrame = CFrame.new(30, 30, 80)
			for _, ux in ipairs({ -8, 6 }) do -- umbrellas
				part(show.world, Vector3.new(0.3, 7, 0.3), Color3.fromRGB(240, 240, 240)).CFrame = CFrame.new(ux, 3.5, 3)
				part(show.world, Vector3.new(7, 0.6, 7), ux < 0 and Color3.fromRGB(240, 80, 90) or Color3.fromRGB(80, 160, 240), Enum.PartType.Cylinder).CFrame =
					CFrame.new(ux, 7, 3) * CFrame.Angles(0, 0, math.pi / 2)
			end
			local boat = part(show.world, Vector3.new(6, 1.4, 2.6), Color3.fromRGB(250, 200, 40))
			boat.CFrame = CFrame.new(20, 0.2, 11)
			local crew = castGang(false)
			for i, r in ipairs(crew) do r.place(Vector3.new(-10 + i * 5, 0, 3), Vector3.new(-10 + i * 5, 0, -10)) end
			setShot(wide(Vector3.new(0, 8, -20), Vector3.new(0, 3, 4), 3), true)
			fade(false, 0.6)
			caption("Meanwhile... " .. story.gangName .. " is living it up at the beach.", 2.2)
			say(crew[1], pick({ "Life is GOOD.", "Pass the sunscreen.", "Nobody will EVER find us here." }), 2)
			local cop = named(cast("Cop"), "Officer Dan")
			cop.place(Vector3.new(-34, 0, -1), Vector3.new(0, 0, -1))
			pcall(cop.go, Vector3.new(-14, 0, -1), 9)
			say(cop, pick({ "Nice day for an ARREST.", "Fancy meeting you here.", "I brought my own towel." }), 2.2)
			for _, r in ipairs(crew) do r.face(headPos(cop)) end
			say(crew[#crew], "RUN!", 1.2)
			if rng:NextNumber() < 0.5 then
				for i, r in ipairs(crew) do task.spawn(function() pcall(r.go, Vector3.new(18 + i, 0, 9), 13, "run") end) end
				hold(1.6)
				for _, r in ipairs(crew) do r.hide() end
				setShot(follow(function() return boat.Position end, Vector3.new(-8, 6, -18), Vector3.new(4, 0, 0), 5), false)
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 2.4, 1)
					boat.CFrame = CFrame.new(20 + u * 60, 0.2 + math.sin(u * 30) * 0.2, 11 + u * 6)
					if math.random() < 0.5 then burst("dust", boat.Position - Vector3.new(3, 0, 0), 1) end
					hold(0)
				until u >= 1
				cop.gesture("facepalm", 2)
				say(cop, "...Is that a JET SKI?", 2)
				story.news = story.gangName .. " escapes the beach on a jet ski. Officer Dan 'speechless'."
				story.chapter = "plan"
			else
				cop.gesture("point", 2)
				arrest(crew, cop, 0, "Vacation's over.")
				story.news = "BEACH BUST! " .. story.gangName .. " arrested in their swimsuits."
				story.chapter = "court"
			end
		end

		local function chapterCourt()
			room(Color3.fromRGB(120, 85, 55), Color3.fromRGB(150, 120, 90), Color3.fromRGB(10, 8, 6))
			part(show.world, Vector3.new(10, 5, 3), Color3.fromRGB(90, 55, 30)).CFrame = CFrame.new(0, 2.5, 6)
			local gavelHead = part(show.world, Vector3.new(1.2, 0.6, 0.6), Color3.fromRGB(70, 40, 20))
			local function gavel()
				for _ = 1, 2 do
					gavelHead.CFrame = CFrame.new(1.5, 6.5, 5)
					hold(0.12)
					gavelHead.CFrame = CFrame.new(1.5, 5.3, 5)
					sfx(SFX.thud, 0.5, 1.6, 0.6)
					shake(0.12, 0.15)
					hold(0.2)
				end
			end
			gavelHead.CFrame = CFrame.new(1.5, 5.3, 5)
			local judge = named(cast("Judge"), "Judge Gavelton")
			judge.place(Vector3.new(0, 3.2, 8), Vector3.new(0, 3.2, -10))
			local crew = castGang(false)
			for i, r in ipairs(crew) do r.place(Vector3.new(-8 + (i - 1) * 3, 0, -2), Vector3.new(0, 0, 8)) end
			local cop = named(cast("Cop"), "Officer Dan")
			cop.place(Vector3.new(8, 0, -2), Vector3.new(0, 0, 8))
			setShot(wide(Vector3.new(0, 8, -22), Vector3.new(0, 4, 4), 3), true)
			fade(false, 0.6)
			caption("Discovery Bay Courthouse. " .. story.gangName .. " stands trial.", 2.2)
			gavel()
			say(judge, "Order in the court!", 1.6)
			cop.gesture("point", 2.2)
			say(cop, "They robbed " .. (story.target and story.target.name or "the whole bay") .. ", your honor!", 2.2)
			crew[1].gesture("shrug", 2.2)
			say(crew[1], pick({ "It was HIS idea!", "I was just holding the bag!", "I've never seen these people in my life." }), 2.2)
			setShot(closeUp(judge), true)
			hold(0.8)
			if rng:NextNumber() < 0.85 then
				local years = rng:NextInteger(2, 30)
				story.years += years
				gavel()
				say(judge, "GUILTY! " .. years .. " years in Bay Jail!", 2.4)
				crew[#crew].gesture("facepalm", 1.8)
				say(crew[#crew], "NOOOO!", 1.4)
				story.news = story.gangName .. " found GUILTY. Sentenced to " .. years .. " years!"
				story.chapter, story.jailDays = "jail", 0
			else
				gavel()
				say(judge, "...Not guilty. Insufficient evidence.", 2.4)
				for _, r in ipairs(crew) do r.gesture("cheer", 2) end
				cop.gesture("facepalm", 2)
				say(cop, "You've GOT to be kidding me.", 1.8)
				story.news = "SHOCK VERDICT: " .. story.gangName .. " walks free!"
				story.chapter = "hideout"
			end
		end

		local function cellSet()
			room(Color3.fromRGB(110, 110, 115), Color3.fromRGB(140, 140, 145), Color3.fromRGB(6, 6, 8))
			for x = -12, 12, 2 do
				part(show.world, Vector3.new(0.35, 12, 0.35), Color3.fromRGB(50, 50, 55), nil, Enum.Material.Metal).CFrame = CFrame.new(x, 6, -1)
			end
			part(show.world, Vector3.new(26, 0.5, 0.5), Color3.fromRGB(50, 50, 55), nil, Enum.Material.Metal).CFrame = CFrame.new(0, 11.5, -1)
			part(show.world, Vector3.new(6, 1.2, 3), Color3.fromRGB(160, 160, 165)).CFrame = CFrame.new(7, 0.6, 7)
		end
		local function chapterJail()
			cellSet()
			story.jailDays += 1
			local crew = castGang(true)
			for i, r in ipairs(crew) do r.place(Vector3.new(-7 + (i - 1) * 4, 0, 4), Vector3.new(0, 0, -10)) end
			local guard = named(cast("Cop"), "Guard Dan")
			guard.place(Vector3.new(-26, 0, -5), Vector3.new(0, 0, -5))
			setShot(wide(Vector3.new(0, 7, -24), Vector3.new(0, 4, 2), 3), true)
			fade(false, 0.6)
			caption("Bay Jail, day " .. story.jailDays .. ".", 1.8)
			task.spawn(function() pcall(guard.go, Vector3.new(26, 0, -5), 5) end)
			say(crew[1], pick({ "I can't eat this food anymore.", "I miss my scooter.", "Is it Monday? It feels like Monday." }), 2.2)
			if crew[2] then say(crew[2], pick({ "This is all your fault.", "At least the beds are... no, they're bad.", "Psst. I have a plan." }), 2) end
			local r = rng:NextNumber()
			if story.jailDays >= 3 then
				say(guard, "You lot. Out. Good behavior.", 2.2)
				crew[1].gesture("shrug", 1.8)
				say(crew[1], "Good behavior? US?", 1.8)
				story.news = story.gangName .. " released early for 'good behavior'. Town nervous."
				story.chapter, story.target = "plan", pick(HEIST_TARGETS)
			elseif r < 0.45 then
				say(guard, "Yard time! Let's go.", 1.6)
				story.chapter = "yard"
			elseif r < 0.8 then
				caption("That night, they make their move...", 2)
				story.chapter = "breakout"
			else
				say(guard, "Lights out!", 1.6)
				story.chapter = "jail"
			end
		end

		local function yardSet(night)
			show.vf.BackgroundColor3 = night and NIGHT or DAY
			part(show.world, Vector3.new(80, 1, 40), Color3.fromRGB(150, 145, 140)).CFrame = CFrame.new(0, -0.5, 6)
			for x = -36, 36, 3 do -- the fence
				part(show.world, Vector3.new(0.2, 9, 0.2), Color3.fromRGB(120, 120, 125), nil, Enum.Material.Metal).CFrame = CFrame.new(x, 4.5, 14)
			end
			part(show.world, Vector3.new(76, 0.2, 0.2), Color3.fromRGB(120, 120, 125), nil, Enum.Material.Metal).CFrame = CFrame.new(0, 9, 14)
			part(show.world, Vector3.new(30, 14, 10), Color3.fromRGB(130, 130, 135)).CFrame = CFrame.new(-28, 7, 24) -- the jail
		end
		local function chapterYard()
			yardSet(false)
			local bar = part(show.world, Vector3.new(4, 0.25, 0.25), Color3.fromRGB(60, 60, 66), nil, Enum.Material.Metal)
			part(show.world, Vector3.new(8, 2.4, 1.6), Color3.fromRGB(110, 90, 70)).CFrame = CFrame.new(8, 1.2, 4) -- lunch table
			local crew = castGang(true)
			crew[1].place(Vector3.new(-6, 0, 4), Vector3.new(-6, 0, -10))
			for i = 2, #crew do crew[i].place(Vector3.new(6 + (i - 2) * 4, 0, 1), Vector3.new(8, 0, 4)) end
			local guard = named(cast("Cop"), "Guard Dan")
			guard.place(Vector3.new(-18, 0, -4), Vector3.new(0, 0, 0))
			setShot(wide(Vector3.new(0, 9, -24), Vector3.new(0, 3, 4), 3), true)
			fade(false, 0.6)
			caption("Yard time at Bay Jail.", 1.8)
			crew[1].gesture("lift", 5)
			task.spawn(function()
				local t0 = clock()
				while clock() - t0 < 5 and show and not show.dead do
					local hand = crew[1].model:FindFirstChild("Right Arm")
					if hand then bar.CFrame = CFrame.new(hand.Position.X - 1, hand.Position.Y, hand.Position.Z) end
					task.wait()
				end
			end)
			say(crew[1], "Gotta stay in shape for the next job.", 2.4)
			if crew[2] then
				say(crew[2], "This food is... MOVING.", 1.8)
				crew[2].gesture("cheer", 1.2)
				say(crew[2], "FOOD FIGHT!", 1.2)
				sfx(SFX.crowd, 0.35, 1.2, 2)
				for _ = 1, 4 do burst("food", Vector3.new(8, 3, 4), 6) hold(0.25) end
				shake(0.2, 0.5)
			end
			sfx(SFX.blip, 0.6, 3, 0.6)
			guard.gesture("point", 2)
			say(guard, "KNOCK IT OFF! Everybody back inside!", 2.2)
			story.jailDays += 1
			story.chapter = rng:NextNumber() < 0.5 and "breakout" or "jail"
		end

		local function chapterBreakout()
			yardSet(true)
			-- the searchlight sweeping the yard
			part(show.world, Vector3.new(1, 18, 1), Color3.fromRGB(70, 70, 76), nil, Enum.Material.Metal).CFrame = CFrame.new(-20, 9, 18)
			local beam = part(show.world, Vector3.new(3, 0.2, 34), Color3.fromRGB(255, 250, 200), nil, Enum.Material.Neon)
			beam.Transparency = 0.6
			local beamAngle, sweeping = 0, true
			task.spawn(function()
				while sweeping and show and not show.dead do
					beamAngle = math.sin(clock() * 0.9) * 0.8
					beam.CFrame = CFrame.new(-20, 18, 18) * CFrame.Angles(0, beamAngle, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -17)
					task.wait()
				end
			end)
			local crew = castGang(true)
			for i, r in ipairs(crew) do r.place(Vector3.new(4 + i * 2.5, 0, 12), Vector3.new(4 + i * 2.5, 0, 14)) end
			setShot(wide(Vector3.new(0, 8, -18), Vector3.new(6, 3, 10), 3), true)
			fade(false, 0.6)
			caption("Midnight. A spoon. A dream.", 1.8)
			for _, r in ipairs(crew) do r.gesture("dig", 3) end
			for _ = 1, 6 do burst("dust", Vector3.new(7, 0.5, 13), 3) sfx(SFX.thud, 0.15, 2.6, 0.3) hold(0.4) end
			local hole = part(show.world, Vector3.new(0.2, 4, 4), Color3.fromRGB(15, 12, 10), Enum.PartType.Cylinder)
			hole.CFrame = CFrame.new(7, 0.05, 13) * CFrame.Angles(0, 0, math.pi / 2)
			say(crew[1], pick({ "We're through! GO!", "Told you the spoon would work.", "Ladies first. Kidding. ME first." }), 2)
			if rng:NextNumber() < 0.6 then
				for _, r in ipairs(crew) do
					pcall(r.go, Vector3.new(7, 0, 13), 10, "run")
					r.hide()
					sfx(SFX.whoosh, 0.25, 1.4, 1)
					hold(0.25)
				end
				sweeping = false
				caption(story.gangName .. " is OUT.", 2)
				story.news = "JAILBREAK! " .. story.gangName .. " tunnels out of Bay Jail with a spoon."
				story.chapter = rng:NextNumber() < 0.5 and "beach" or "hideout"
			else
				sweeping = false
				beam.CFrame = CFrame.lookAt(Vector3.new(-20, 18, 18), Vector3.new(8, 1, 12)) * CFrame.new(0, 0, -15)
				flash(Color3.new(1, 1, 1), 0.8)
				alarmFlashes(nil, 3)
				for _, r in ipairs(crew) do r.face(Vector3.new(-20, 0, 18)) r.gesture("handsUp", 4) end
				local guard = named(cast("Cop"), "Guard Dan")
				guard.place(Vector3.new(-14, 0, 6), Vector3.new(8, 0, 12))
				pcall(guard.go, Vector3.new(0, 0, 10), 12, "run")
				say(guard, "Nice try. Five MORE years.", 2.2)
				story.years += 5
				story.news = "Breakout FAILS. " .. story.gangName .. " caught in the searchlight."
				story.chapter, story.jailDays = "jail", 0
			end
		end

		story.ctx = { castGang = castGang, arrest = arrest, alarmFlashes = alarmFlashes, newGang = newGang }
		local CHAPTER = {
			plan = chapterPlan, job = chapterJob, chase = chapterChase, hideout = chapterHideout, stakeout = chapterStakeout,
			beach = chapterBeach, court = chapterCourt, jail = chapterJail, yard = chapterYard, breakout = chapterBreakout,
		}
		local CHAPTER_TITLE = {
			plan = "THE PLAN", job = "THE JOB", chase = "THE CAR CHASE", hideout = "THE HIDEOUT", stakeout = "THE STAKEOUT",
			beach = "THE BEACH", court = "THE COURT", jail = "BAY JAIL", yard = "THE YARD", breakout = "THE BREAKOUT",
		}
		local function heistSaga()
			show.cinematic = true
			show.letterbox.Visible = true
			show.fade.BackgroundTransparency = 0 -- every episode opens from black
			if not story.gang or (story.gangEps or 0) >= 12 then
				if story.gang then
					show.fade.BackgroundTransparency = 1
					caption(story.gangName .. " retires. A new crew rolls into town...", 2.6)
					show.fade.BackgroundTransparency = 0
				end
				newGang()
			end
			story.ep += 1
			story.gangEps += 1
			-- the plot book may swap in one of its chapters for this part of the story
			local variant = PLOTS and PLOTS.heistPick(story.chapter)
			local title = variant and variant[1] or CHAPTER_TITLE[story.chapter]
			show.label.Text = show.label.Text .. "  |  Ep " .. story.ep .. ": " .. title
			titleCard("EPISODE " .. story.ep, title)
			if variant then variant[2](story.ctx) else CHAPTER[story.chapter]() end
			hold(0.8)
			fade(true, 0.6)
		end
		return heistSaga
	end)()

	-- =============================================================================================
	-- THE PLOT BOOK: 50 storylines for every channel. A small kit (sets, props, actors, camera moves)
	-- that the plots are written in, then: 40 extra BAY HEIST chapters (woven into the running saga),
	-- 50 SCOOTER TV events (with a season points table) and 50 days of BAY NEWS, told day after day
	-- in multi-day stories (the alien invasion, the giant egg, the mayor race...).
	-- =============================================================================================
	PLOTS = (function()
		local C, V, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
		local DAY, NIGHT, DUSK = C(120, 190, 255), C(14, 18, 42), C(235, 140, 95)
		local NEON, METAL = Enum.Material.Neon, Enum.Material.Metal
		local K = {}
		local plots = { K = K }

		-- building blocks ---------------------------------------------------------------------------
		function K.box(size, color, cf, mat, shape)
			local p = part(show.world, size, color, shape, mat)
			p.CFrame = cf
			return p
		end
		function K.ball(d, color, pos, neon)
			return K.box(V(d, d, d), color, CF(pos), neon and NEON or nil, Enum.PartType.Ball)
		end
		function K.cyl(len, d, color, cf, mat) -- (a cylinder's length runs along its X axis)
			return K.box(V(len, d, d), color, cf, mat, Enum.PartType.Cylinder)
		end
		function K.disc(d, color, pos, thick, mat) -- a flat round thing lying on the ground
			return K.cyl(thick or 0.2, d, color, CF(pos) * ANG(0, 0, math.pi / 2), mat)
		end
		function K.wedge(size, color, cf)
			local p = Instance.new("WedgePart")
			p.Anchored = true
			p.Size = size
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.CFrame = cf
			p.Parent = show.world
			return p
		end
		function K.sky(c) show.vf.BackgroundColor3 = c end
		function K.ground(color, mat, sky)
			K.sky(sky or DAY)
			return K.box(V(220, 1, 130), color, CF(0, -0.5, 35), mat)
		end
		function K.tree(x, z, s)
			s = s or 1
			K.box(V(0.9 * s, 6 * s, 0.9 * s), C(110, 75, 45), CF(x, 3 * s, z))
			K.ball(5 * s, C(60, 140, 60), V(x, 7 * s, z))
		end
		function K.pine(x, z, snowy)
			K.box(V(0.8, 3, 0.8), C(100, 70, 45), CF(x, 1.5, z))
			for i = 0, 2 do
				K.box(V(5 - i * 1.4, 1.6, 5 - i * 1.4), (snowy and i == 2) and C(240, 245, 250) or C(40, 110, 60), CF(x, 3 + i * 1.6, z) * ANG(0, i * 0.7, 0))
			end
		end
		function K.palm(x, z)
			for i = 0, 5 do K.box(V(0.8, 1.6, 0.8), C(140, 100, 60), CF(x + i * 0.15, 0.8 + i * 1.5, z)) end
			for i = 1, 5 do
				K.box(V(5, 0.2, 1.2), C(50, 150, 60), CF(x + 0.9, 9.3, z) * ANG(0, i * math.pi * 2 / 5, -0.35) * CF(2.3, 0, 0))
			end
		end
		function K.lamp(x, z)
			K.box(V(0.4, 9, 0.4), C(60, 60, 66), CF(x, 4.5, z))
			K.ball(1.2, C(255, 230, 160), V(x, 9.2, z), true)
		end
		function K.buildings(z, night, n)
			for i = -(n or 6), n or 6 do
				local h = rng:NextInteger(9, 18)
				K.box(V(11, h, 7), Color3.fromHSV(rng:NextNumber(), 0.25, night and 0.45 or 0.85), CF(i * 12, h / 2, z))
				if night then -- lit windows
					for _ = 1, 3 do
						K.box(V(1.4, 1.4, 0.2), C(255, 220, 120), CF(i * 12 + rng:NextNumber(-4, 4), rng:NextNumber(2, h - 1), z - 3.55), NEON)
					end
				end
			end
		end
		function K.stars(n)
			for _ = 1, n or 30 do
				K.ball(rng:NextNumber(0.2, 0.5), C(255, 255, 240), V(rng:NextNumber(-90, 90), rng:NextNumber(14, 60), rng:NextNumber(40, 90)), true)
			end
		end
		function K.sun(color) K.ball(6, color or C(255, 240, 160), V(30, 30, 80), true) end
		function K.moon() K.ball(5, C(240, 240, 220), V(-22, 26, 60), true) end
		function K.bench(x, z)
			K.box(V(5, 0.4, 1.6), C(140, 95, 55), CF(x, 1.4, z))
			K.box(V(5, 1.4, 0.3), C(140, 95, 55), CF(x, 2.2, z + 0.8))
		end
		function K.table(x, z, color)
			K.box(V(6, 0.4, 3), color or C(140, 95, 55), CF(x, 2.6, z))
			for _, o in ipairs({ { -2.6, -1.2 }, { 2.6, -1.2 }, { -2.6, 1.2 }, { 2.6, 1.2 } }) do
				K.box(V(0.3, 2.4, 0.3), C(90, 60, 35), CF(x + o[1], 1.2, z + o[2]))
			end
		end
		function K.cone(x, z) return K.box(V(1, 1.6, 1), C(255, 120, 30), CF(x, 0.8, z)) end
		function K.crate(x, z, s)
			s = s or 2
			return K.box(V(s, s, s), C(160, 120, 70), CF(x, s / 2, z) * ANG(0, rng:NextNumber(-0.3, 0.3), 0))
		end
		function K.ramp(x, z, h, len, color) -- rises toward +X; the top edge is at x + len / 2
			return K.wedge(V(4, h, len), color or C(255, 140, 40), CF(x, h / 2, z) * ANG(0, math.pi / 2, 0))
		end
		function K.cake(x, z)
			K.cyl(1.6, 4, C(250, 220, 230), CF(x, 3.6, z) * ANG(0, 0, math.pi / 2))
			for i = -1, 1 do K.box(V(0.2, 0.8, 0.2), C(255, 200, 80), CF(x + i * 0.8, 4.8, z), NEON) end
		end
		function K.egg(pos, size, color)
			local e = K.box(V(size, size * 1.3, size), color or C(250, 240, 220), CF(pos + V(0, size * 0.65, 0)))
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = e
			return e
		end
		function K.can(pos, h, color) -- a (giant) Bloxy Cola can
			local c = K.cyl(h, h * 0.55, color or C(220, 30, 40), CF(pos + V(0, h / 2, 0)) * ANG(0, 0, math.pi / 2))
			return K.model({ c, K.cyl(h * 0.2, h * 0.56, C(240, 240, 240), CF(pos + V(0, h * 0.6, 0)) * ANG(0, 0, math.pi / 2)) })
		end
		function K.chest(x, z)
			K.box(V(3, 1.8, 2), C(120, 80, 40), CF(x, 0.9, z))
			K.box(V(3.1, 0.3, 2.1), C(250, 200, 60), CF(x, 1.9, z), METAL)
		end
		function K.fin(x, y, z) return K.wedge(V(0.4, 2.6, 3), C(110, 120, 135), CF(x, y, z)) end
		function K.ring(pos, r, color) -- a hoop standing up, facing along X (things fly through it)
			local parts = {}
			for i = 1, 16 do
				local a = i / 16 * math.pi * 2
				table.insert(parts, K.box(V(0.6, r * 0.42, 0.6), color or C(255, 120, 30), CF(pos) * ANG(a, 0, 0) * CF(0, r, 0), NEON))
			end
			return parts
		end
		function K.sign(x, y, z, w, color) return K.box(V(w or 8, 2, 0.4), color or C(255, 200, 60), CF(x, y, z), NEON) end

		-- move anything (a part or a model) to a CFrame over t seconds, eased
		function K.glide(obj, to, t, linear)
			local isModel = obj:IsA("Model")
			local from = isModel and obj:GetPivot() or obj.CFrame
			local t0 = clock()
			repeat
				local u = math.min((clock() - t0) / t, 1)
				local e = linear and u or (1 - math.cos(u * math.pi)) / 2
				local cf = from:Lerp(to, e)
				if isModel then obj:PivotTo(cf) else obj.CFrame = cf end
				hold(0)
			until u >= 1
		end
		function K.glideAsync(obj, to, t, linear) task.spawn(function() pcall(K.glide, obj, to, t, linear) end) end
		function K.model(parts) -- a few parts as one model (the first one is the primary part)
			local m = Instance.new("Model")
			for _, p in ipairs(parts) do p.Parent = m end
			m.PrimaryPart = parts[1]
			m.Parent = show.world
			return m
		end
		local function flasher(m, a, b)
			local s = show
			task.spawn(function()
				while m.Parent and not s.dead do
					local on = math.floor(os.clock() * 8) % 2 == 0
					a.Color = on and C(255, 40, 40) or C(80, 10, 10)
					b.Color = on and C(20, 20, 80) or C(40, 90, 255)
					task.wait(0.05)
				end
			end)
		end

		-- vehicles: police / van / car / icecream / armored / bus / fire / taxi / pizza
		local CAR_COLORS = {
			police = C(245, 245, 250), van = C(50, 52, 60), car = C(80, 160, 220), icecream = C(250, 240, 245), armored = C(70, 90, 70),
			bus = C(250, 200, 40), fire = C(210, 30, 30), taxi = C(250, 210, 40), pizza = C(220, 60, 40),
		}
		function K.car(kind, x, z, color)
			local big = kind == "van" or kind == "icecream" or kind == "armored" or kind == "bus" or kind == "fire"
			local len = kind == "bus" and 16 or big and 10 or 9
			local hgt = big and 3.6 or 2.6
			local body = K.box(V(len, hgt, 4), color or CAR_COLORS[kind] or CAR_COLORS.car, CF(x, hgt / 2 + 0.7, z))
			local parts = { body }
			local lights
			table.insert(parts, K.box(V(4.5, 1.6, 3.6), C(30, 30, 40), body.CFrame * CF(big and (len / 2 - 2.5) or -0.5, hgt / 2 + 0.8, 0)))
			for _, wx in ipairs({ -len / 2 + 2, len / 2 - 2 }) do
				for _, wz in ipairs({ -2.05, 2.05 }) do
					table.insert(parts, K.cyl(0.6, 1.8, C(20, 20, 20), body.CFrame * CF(wx, -hgt / 2, wz) * ANG(0, math.pi / 2, 0)))
				end
			end
			if kind == "police" or kind == "fire" then
				table.insert(parts, K.box(V(len + 0.05, 0.6, 4.05), kind == "fire" and C(240, 240, 240) or C(30, 40, 90), body.CFrame * CF(0, -0.2, 0)))
				local r = K.box(V(0.8, 0.6, 0.8), C(255, 40, 40), body.CFrame * CF(-1, hgt / 2 + 1.9, 0), NEON)
				local b = K.box(V(0.8, 0.6, 0.8), C(40, 90, 255), body.CFrame * CF(0.2, hgt / 2 + 1.9, 0), NEON)
				table.insert(parts, r)
				table.insert(parts, b)
				lights = { r, b }
			elseif kind == "icecream" then
				table.insert(parts, K.ball(2.4, C(255, 180, 210), body.Position + V(0, hgt / 2 + 2.6, 0)))
			elseif kind == "taxi" or kind == "pizza" then
				table.insert(parts, K.box(V(2, 0.8, 1), C(255, 255, 255), body.CFrame * CF(0, hgt / 2 + 1.9, 0), NEON))
			end
			local m = K.model(parts)
			if lights then flasher(m, lights[1], lights[2]) end
			local v = { model = m }
			function v.pos() return m:GetPivot().Position end
			function v.drive(toX, t, wobble)
				local from = m:GetPivot()
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / t, 1)
					local cf = from + V((toX - from.Position.X) * u, 0, 0)
					m:PivotTo(wobble and cf * ANG(0, math.sin(u * 20) * 0.08, 0) or cf)
					hold(0)
				until u >= 1
			end
			function v.driveAsync(toX, t, wobble) task.spawn(function() pcall(v.drive, toX, t, wobble) end) end
			return v
		end
		function K.boat(x, z, color, y)
			local hull = K.box(V(8, 1.6, 3.2), color or C(250, 250, 250), CF(x, y or -0.6, z))
			local m = K.model({ hull, K.box(V(2.4, 1.6, 2.6), C(40, 60, 90), hull.CFrame * CF(-0.8, 1.6, 0)), K.wedge(V(3.2, 1.6, 2), color or C(250, 250, 250), hull.CFrame * CF(5, 0, 0) * ANG(0, math.pi / 2, 0) * ANG(0, math.pi, 0)) })
			return m
		end
		function K.heli(pos)
			local body = K.box(V(7, 3.4, 3.4), C(30, 40, 90), CF(pos))
			local rotor = K.box(V(14, 0.2, 0.8), C(40, 40, 44), CF(pos + V(0, 2.1, 0)))
			local m = K.model({ body, rotor, K.box(V(7, 0.8, 0.8), C(30, 40, 90), CF(pos + V(6, 0.6, 0))),
				K.box(V(2.5, 2, 3.5), C(140, 210, 240), CF(pos + V(-3.2, 0.3, 0)), Enum.Material.Glass) })
			local s = show
			task.spawn(function()
				local a = 0
				while m.Parent and not s.dead do
					a += 0.6
					rotor.CFrame = CF(body.Position + V(0, 2.1, 0)) * ANG(0, a, 0)
					task.wait()
				end
			end)
			return m
		end
		function K.ufo(pos)
			local disc = K.cyl(1.4, 14, C(170, 175, 185), CF(pos) * ANG(0, 0, math.pi / 2), METAL)
			local dome = K.ball(6, C(140, 230, 255), pos + V(0, 1.4, 0))
			dome.Transparency = 0.3
			local parts = { disc, dome }
			for i = 1, 8 do
				local a = i / 8 * math.pi * 2
				table.insert(parts, K.ball(0.9, Color3.fromHSV(i / 8, 0.8, 1), pos + V(math.cos(a) * 6.3, -0.3, math.sin(a) * 6.3), true))
			end
			local beam = K.cyl(30, 6, C(170, 255, 170), CF(pos - V(0, 15, 0)) * ANG(0, 0, math.pi / 2), NEON)
			beam.Transparency = 1
			table.insert(parts, beam)
			local m = K.model(parts)
			local u = { model = m }
			function u.move(to, t) K.glide(m, CF(to) * ANG(0, 0, math.pi / 2), t) end
			function u.beam(on)
				beam.Transparency = on and 0.55 or 1
				if on then sfx(SFX.whoosh, 0.4, 0.6, 2) end
			end
			return u
		end
		function K.dino(pos, s, color)
			s = s or 1
			color = color or C(90, 170, 80)
			local cf = CF(pos)
			local m = K.model({
				K.box(V(4, 4, 7) * s, color, cf * CF(0, 5 * s, 0)),
				K.box(V(2, 4, 2) * s, color, cf * CF(0, 8 * s, -3.4 * s) * ANG(-0.3, 0, 0)),
				K.box(V(2.4, 2, 3.6) * s, color, cf * CF(0, 10.2 * s, -4.8 * s)),
				K.box(V(2.2, 0.4, 0.2) * s, C(255, 255, 255), cf * CF(0, 9.5 * s, -6.65 * s)),
				K.box(V(1.6, 1.6, 7) * s, color, cf * CF(0, 4.5 * s, 6 * s) * ANG(0.25, 0, 0)),
				K.box(V(1.4, 3.5, 1.4) * s, color, cf * CF(-1.4 * s, 1.75 * s, 1 * s)),
				K.box(V(1.4, 3.5, 1.4) * s, color, cf * CF(1.4 * s, 1.75 * s, 1 * s)),
				K.box(V(0.8, 2, 0.8) * s, color, cf * CF(-1.6 * s, 5 * s, -3 * s) * ANG(-0.8, 0, 0)),
				K.box(V(0.8, 2, 0.8) * s, color, cf * CF(1.6 * s, 5 * s, -3 * s) * ANG(-0.8, 0, 0)),
				K.ball(0.5 * s, C(20, 20, 20), (cf * CF(0.9 * s, 10.8 * s, -6.5 * s)).Position),
				K.ball(0.5 * s, C(20, 20, 20), (cf * CF(-0.9 * s, 10.8 * s, -6.5 * s)).Position),
			})
			local d = { model = m }
			function d.pos() return m:GetPivot().Position end
			function d.walk(to, t)
				local from = m:GetPivot()
				local goal = CF(to + V(0, 5 * s, 0)) * (from - from.Position)
				local t0, last = clock(), 0
				repeat
					local u = math.min((clock() - t0) / t, 1)
					m:PivotTo(from:Lerp(goal, u) * CF(0, math.abs(math.sin(u * t * 5)) * 0.4 * s, 0))
					if clock() - last > 0.55 then
						last = clock()
						sfx(SFX.thud, 0.3, 0.5, 1)
						shake(0.12 * s, 0.15)
					end
					hold(0)
				until u >= 1
			end
			function d.face(yaw) m:PivotTo(CF(m:GetPivot().Position) * ANG(0, yaw, 0)) end
			function d.roar()
				sfx(SFX.boo, 0.45, 0.45, 2)
				shake(0.35, 0.7)
				hold(0.8)
			end
			return d
		end
		function K.dog(pos, color)
			color = color or C(200, 150, 90)
			local cf = CF(pos)
			local m = K.model({
				K.box(V(1.2, 1.1, 2.4), color, cf * CF(0, 1.4, 0)),
				K.box(V(1, 1, 1.1), color, cf * CF(0, 2.2, -1.4)),
				K.box(V(0.3, 0.5, 0.3), C(60, 40, 30), cf * CF(-0.35, 2.85, -1.3)),
				K.box(V(0.3, 0.5, 0.3), C(60, 40, 30), cf * CF(0.35, 2.85, -1.3)),
				K.box(V(0.3, 0.9, 0.3), color, cf * CF(-0.4, 0.45, -0.9)),
				K.box(V(0.3, 0.9, 0.3), color, cf * CF(0.4, 0.45, -0.9)),
				K.box(V(0.3, 0.9, 0.3), color, cf * CF(-0.4, 0.45, 0.9)),
				K.box(V(0.3, 0.9, 0.3), color, cf * CF(0.4, 0.45, 0.9)),
				K.box(V(0.2, 0.2, 0.9), color, cf * CF(0, 2, 1.4) * ANG(0.6, 0, 0)),
				K.ball(0.25, C(10, 10, 10), (cf * CF(0, 2.2, -1.98)).Position),
			})
			local d = { model = m }
			function d.go(x, z, t)
				local from = m:GetPivot().Position
				local to = V(x, from.Y, z)
				if (to - from).Magnitude < 0.1 then return end
				K.glide(m, CFrame.lookAt(to, to + (to - from).Unit), t or 1.5, true)
			end
			function d.goAsync(x, z, t) task.spawn(function() pcall(d.go, x, z, t) end) end
			function d.bark()
				sfx(SFX.blip, 0.7, 0.45, 0.4)
				hold(0.15)
				sfx(SFX.blip, 0.7, 0.5, 0.4)
			end
			return d
		end
		function K.ghost(pos)
			local g = K.egg(pos, 3, C(250, 250, 255))
			g.Transparency = 0.35
			return K.model({ g, K.ball(0.5, C(10, 10, 10), pos + V(-0.6, 2.6, -1.45)), K.ball(0.5, C(10, 10, 10), pos + V(0.6, 2.6, -1.45)) })
		end

		-- actors ------------------------------------------------------------------------------------
		function K.who(role, name)
			local a = cast(role)
			a.name = name
			return a
		end
		function K.paint(a, color, head)
			for _, p in ipairs(a.model:GetDescendants()) do
				if p:IsA("Shirt") or p:IsA("Pants") or p:IsA("ShirtGraphic") then
					p:Destroy()
				elseif p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and not p:FindFirstAncestorWhichIsA("Accessory") then
					p.Color = (p.Name == "Head" and head) or color
				end
			end
			return a
		end
		function K.bald(a)
			for _, c in ipairs(a.model:GetChildren()) do
				if c:IsA("Accessory") then c:Destroy() end
			end
			return a
		end
		local function stick(a, size, color, offset, mat)
			local head = a.model:FindFirstChild("Head")
			if not head then return end
			local p = part(a.model, size, color, nil, mat)
			p.Anchored = false
			p.CanCollide = false
			p.CFrame = head.CFrame * offset
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = head, p
			wc.Parent = p
			return p
		end
		K.stick = stick
		function K.alien(name)
			local a = K.bald(K.paint(K.who("Rider", name), C(120, 220, 110), C(140, 240, 120)))
			local head = a.model:FindFirstChild("Head")
			if head then
				for _, d in ipairs(head:GetChildren()) do
					if d:IsA("Decal") then d:Destroy() end
				end
			end
			stick(a, V(0.42, 0.6, 0.1), C(10, 10, 10), CF(-0.3, 0.15, -0.66))
			stick(a, V(0.42, 0.6, 0.1), C(10, 10, 10), CF(0.3, 0.15, -0.66))
			stick(a, V(0.12, 1, 0.12), C(120, 220, 110), CF(0, 0.9, 0))
			stick(a, V(0.35, 0.35, 0.35), C(255, 240, 120), CF(0, 1.45, 0), NEON)
			a.voice = rng:NextNumber(1.7, 2.1)
			return a
		end
		function K.robot(name)
			local a = K.bald(K.paint(K.who("Anchor", name), C(160, 165, 175), C(180, 185, 195)))
			stick(a, V(0.35, 0.2, 0.1), C(255, 60, 60), CF(-0.28, 0.15, -0.66), NEON)
			stick(a, V(0.35, 0.2, 0.1), C(255, 60, 60), CF(0.28, 0.15, -0.66), NEON)
			stick(a, V(0.1, 0.8, 0.1), C(90, 90, 95), CF(0, 0.85, 0))
			a.voice = 0.6
			return a
		end
		function K.big(a, f) -- (Bigfoot, a giant...)
			a.model:ScaleTo(f)
			a.height *= f
			return a
		end
		function K.bigfoot()
			local a = K.big(K.bald(K.paint(K.who("Rider", "Bigfoot"), C(100, 70, 45), C(120, 85, 55))), 1.6)
			a.voice = 0.55
			return a
		end
		function K.mustache(a) stick(a, V(0.8, 0.18, 0.1), C(40, 25, 15), CF(0, -0.18, -0.66)) return a end
		function K.hat(a, color, tall)
			stick(a, V(1.3, tall and 1.2 or 0.35, 1.3), color or C(30, 30, 30), CF(0, tall and 1.1 or 0.75, 0))
			return a
		end

		-- verbs -------------------------------------------------------------------------------------
		function K.put(a, x, z, lx, lz, y)
			a.place(V(x, y or 0, z), V(lx or x, y or 0, lz or (z - 10)))
			return a
		end
		function K.walk(a, x, z, speed, anim) pcall(a.go, V(x, a.pos and a.pos.Y or 0, z), speed or 8, anim) end
		function K.walkAsync(a, x, z, speed, anim) task.spawn(K.walk, a, x, z, speed, anim) end
		function K.run(a, x, z) K.walk(a, x, z, 15, "run") end
		function K.runAsync(a, x, z) K.walkAsync(a, x, z, 15, "run") end
		function K.open(pos, look)
			if pos then setShot(wide(pos, look or V(0, 3, 4), 3), true) end
			if show.fade.BackgroundTransparency < 0.5 then fade(false, 0.6) end
		end
		function K.say(a, text, gesture, dur)
			K.open()
			if gesture then a.gesture(gesture, dur or 2.2) end
			say(a, text, dur)
		end
		function K.cap(text, dur)
			K.open()
			caption(text, dur)
		end
		function K.shot(pos, look, speed) setShot(wide(pos, look, speed or 3), false) end
		function K.cut(pos, look) setShot(wide(pos, look, 3), true) end
		function K.track(getPos, offset, look) setShot(follow(getPos, offset or V(0, 5, -18), look or V(0, 2, 0), 5), false) end
		function K.follow(a, offset) K.track(function() return a.model:GetPivot().Position end, offset) end
		function K.boom(pos, big)
			sfx(SFX.thud, big and 0.7 or 0.5, big and 0.6 or 0.9, 2)
			flash(C(255, 240, 200), big and 0.8 or 0.5)
			shake(big and 0.6 or 0.3, big and 1 or 0.5)
			burst("spark", pos, big and 20 or 10)
			burst("smoke", pos, big and 14 or 6)
		end
		function K.all(list, fn)
			for i, a in ipairs(list) do fn(a, i) end
		end
		function K.hop(a, h, t)
			local base = a.pos or V()
			local t0 = clock()
			repeat
				local u = math.min((clock() - t0) / (t or 0.5), 1)
				local cf = a.model:GetPivot()
				a.model:PivotTo(cf - V(0, cf.Position.Y, 0) + V(0, base.Y + a.height + math.sin(u * math.pi) * (h or 2), 0))
				hold(0)
			until u >= 1
		end
		function K.fly(a, to, t) -- off the ground (beamed up, blown away...)
			K.glide(a.model, CF(to + V(0, a.height, 0)) * (a.model:GetPivot() - a.model:GetPivot().Position), t)
			a.pos = to
		end
		function K.clear()
			for _, c in ipairs(show.world:GetChildren()) do c:Destroy() end
			table.clear(show.actors)
			show.caption.Visible = false
		end
		function K.cheer() sfx(SFX.crowd, 0.45, 1, 3) end
		function K.boo() sfx(SFX.boo, 0.4, 1, 2.5) end
		function K.siren(t) sfx(SFX.siren, 0.4, 1, t or 4) end
		function K.alarm(t) sfx(SFX.alarm, 0.4, 1, t or 3) end

		-- sets --------------------------------------------------------------------------------------
		local SET = {}
		K.SET = SET
		function SET.street(night)
			K.ground(C(70, 70, 76), nil, night and NIGHT or DAY)
			K.box(V(220, 0.2, 5), C(150, 150, 150), CF(0, -0.04, -1))
			K.buildings(18, night)
			for x = -48, 48, 24 do K.lamp(x, 1.5) end
			if night then K.moon() K.stars(20) end
		end
		function SET.plaza(night)
			K.ground(C(185, 180, 170), nil, night and NIGHT or DAY)
			local SHOPS = {
				{ C(240, 240, 240), C(230, 40, 40) }, { C(250, 200, 220), C(150, 60, 160) },
				{ C(250, 240, 200), C(255, 170, 60) }, { C(200, 225, 250), C(40, 120, 230) },
			}
			for i, s in ipairs(SHOPS) do
				local x = -30 + (i - 1) * 20
				K.box(V(16, 11, 8), s[1], CF(x, 5.5, 16))
				K.box(V(9, 2, 0.4), s[2], CF(x, 9, 11.8), NEON)
				K.box(V(4, 6.5, 0.3), C(60, 40, 30), CF(x, 3.25, 11.9))
				K.box(V(5, 3, 0.2), C(150, 200, 230), CF(x + 4.5, 4, 11.9), Enum.Material.Glass)
			end
			K.palm(-44, 6)
			K.palm(44, 6)
			if night then K.moon() K.stars(20) end
		end
		function SET.park()
			K.ground(C(90, 180, 70), Enum.Material.Grass, DAY)
			for _, t in ipairs({ { -30, 18 }, { -16, 24 }, { 14, 22 }, { 32, 16 }, { 44, 28 } }) do K.tree(t[1], t[2]) end
			K.bench(-10, 8)
			K.bench(12, 8)
			K.disc(22, C(70, 150, 220), V(-36, 0.02, 4))
			K.sun()
		end
		function SET.beach()
			K.sky(DAY)
			K.box(V(220, 1, 30), C(240, 220, 160), CF(0, -0.5, -5))
			K.box(V(220, 1, 90), C(60, 160, 220), CF(0, -0.8, 55))
			K.sun()
			for _, ux in ipairs({ -14, 10 }) do
				K.box(V(0.3, 7, 0.3), C(240, 240, 240), CF(ux, 3.5, 6))
				K.disc(7, ux < 0 and C(240, 80, 90) or C(80, 160, 240), V(ux, 7, 6), 0.6)
			end
			K.palm(-30, 4)
			K.palm(30, 2)
		end
		function SET.dock(night)
			K.sky(night and NIGHT or DUSK)
			K.box(V(220, 1, 130), C(50, 120, 180), CF(0, -1.6, 35))
			K.box(V(90, 0.6, 8), C(150, 110, 70), CF(0, -0.3, 0))
			for x = -42, 42, 6 do K.box(V(0.8, 4, 0.8), C(110, 80, 50), CF(x, -1.5, 4)) end
			if night then K.moon() K.stars(20) else K.sun(C(255, 170, 90)) end
		end
		function SET.studio()
			K.sky(C(20, 40, 90))
			K.box(V(30, 14, 1), C(30, 60, 130), CF(0, 7, 4))
			K.box(V(10, 1.2, 0.5), C(255, 200, 60), CF(-6, 9.5, 3.4), NEON)
			K.box(V(6, 4, 0.3), C(20, 20, 26), CF(7, 7.5, 3.4))
			K.box(V(9, 3, 3), C(235, 235, 240), CF(0, 1.5, -1.5))
			K.box(V(9.4, 0.4, 3.4), C(40, 90, 200), CF(0, 3.2, -1.5))
		end
		function SET.room(floor, wall, bg)
			K.sky(bg or C(10, 10, 14))
			K.box(V(70, 1, 34), floor or C(150, 120, 90), CF(0, -0.5, 4))
			K.box(V(70, 22, 1), wall or C(200, 190, 170), CF(0, 11, 12))
			K.ball(1.2, C(255, 230, 160), V(0, 12, 4), true)
		end
		function SET.lab()
			SET.room(C(220, 225, 230), C(235, 240, 245), C(10, 12, 16))
			for _, x in ipairs({ -10, 10 }) do
				K.table(x, 7)
				for i = 1, 3 do K.box(V(0.6, 1.2, 0.6), Color3.fromHSV(rng:NextNumber(), 0.8, 1), CF(x - 2 + i, 3.4, 7), NEON) end
			end
		end
		function SET.museum()
			SET.room(C(230, 225, 215), C(200, 190, 175), C(8, 8, 10))
			for _, x in ipairs({ -14, 14 }) do
				K.box(V(3, 4, 3), C(245, 245, 245), CF(x, 2, 8))
				K.box(V(4, 6, 0.3), Color3.fromHSV(rng:NextNumber(), 0.5, 0.8), CF(x, 8, 11.4))
			end
			K.box(V(3, 4, 3), C(245, 245, 245), CF(0, 2, 7))
			return K.box(V(1.4, 1.4, 1.4), C(120, 220, 255), CF(0, 5, 7) * ANG(0.6, 0.6, 0), NEON)
		end
		function SET.vault()
			SET.room(C(120, 120, 130), C(150, 150, 160), C(6, 6, 8))
			for i = 1, 12 do
				K.box(V(1.6, 0.6, 0.8), C(250, 200, 60), CF(-6 + (i % 4) * 1.8, 0.3 + math.floor((i - 1) / 4) * 0.62, 8), METAL)
			end
			return K.cyl(1, 12, C(170, 170, 180), CF(16, 6, 11) * ANG(0, math.pi / 2, 0), METAL)
		end
		function SET.space()
			K.sky(C(0, 0, 4))
			K.box(V(220, 1, 130), C(150, 150, 155), CF(0, -0.5, 35), Enum.Material.Slate)
			K.stars(60)
			K.ball(14, C(60, 130, 220), V(-30, 34, 90))
			for _ = 1, 8 do K.disc(rng:NextNumber(3, 7), C(120, 120, 125), V(rng:NextNumber(-40, 40), 0.02, rng:NextNumber(8, 40))) end
		end
		function SET.forest(night)
			K.ground(C(50, 100, 50), Enum.Material.Grass, night and NIGHT or DUSK)
			for _ = 1, 16 do K.pine(rng:NextNumber(-60, 60), rng:NextNumber(10, 50)) end
			if night then K.moon() K.stars(30) end
		end
		function SET.farm()
			K.ground(C(110, 170, 70), Enum.Material.Grass, DAY)
			K.box(V(16, 12, 12), C(180, 40, 40), CF(-20, 6, 26))
			K.wedge(V(16, 5, 6), C(120, 30, 30), CF(-20, 14.5, 23))
			K.wedge(V(16, 5, 6), C(120, 30, 30), CF(-20, 14.5, 29) * ANG(0, math.pi, 0))
			for x = -40, 40, 4 do K.box(V(0.4, 3, 0.4), C(200, 180, 140), CF(x, 1.5, 13)) end
			K.box(V(80, 0.3, 0.3), C(200, 180, 140), CF(0, 2.6, 13))
			for i = 1, 4 do K.cyl(3, 3, C(230, 200, 100), CF(8 + i * 4, 1.5, 18)) end
			K.sun()
		end
		function SET.desert()
			K.ground(C(230, 190, 130), Enum.Material.Sand, C(250, 180, 110))
			for _ = 1, 8 do
				local x, z = rng:NextNumber(-50, 50), rng:NextNumber(12, 40)
				K.box(V(1.2, 6, 1.2), C(60, 140, 70), CF(x, 3, z))
				K.box(V(0.8, 2.5, 0.8), C(60, 140, 70), CF(x + 1.2, 4, z))
			end
			K.sun(C(255, 220, 120))
		end
		function SET.snow()
			K.ground(C(240, 245, 250), Enum.Material.Snow, C(190, 210, 230))
			for _ = 1, 10 do K.pine(rng:NextNumber(-60, 60), rng:NextNumber(14, 50), true) end
			K.ball(3, C(250, 250, 255), V(18, 1.5, 12))
			K.ball(2.2, C(250, 250, 255), V(18, 4, 12))
			K.ball(1.6, C(250, 250, 255), V(18, 5.8, 12))
		end
		function SET.stadium(night)
			K.ground(C(70, 160, 70), Enum.Material.Grass, night and NIGHT or DAY)
			for row = 0, 3 do
				K.box(V(130, 1.5, 3), C(150, 150, 160), CF(0, 0.75 + row * 1.5, 22 + row * 3))
				for _ = 1, 16 do
					K.box(V(1, 2, 0.8), Color3.fromHSV(rng:NextNumber(), 0.6, 0.9), CF(rng:NextNumber(-60, 60), 2.5 + row * 1.5, 22 + row * 3))
				end
			end
			for _, x in ipairs({ -50, 50 }) do
				K.box(V(1, 22, 1), C(80, 80, 85), CF(x, 11, 34))
				K.box(V(6, 3, 1), C(255, 250, 220), CF(x, 22, 34), NEON)
			end
			if night then K.stars(20) end
		end
		function SET.skatepark()
			K.ground(C(90, 180, 70), Enum.Material.Grass, DAY)
			K.box(V(160, 0.2, 9), C(200, 200, 205), CF(0, -0.05, 0))
			K.buildings(40)
			K.sun()
		end
		function SET.rooftop()
			K.sky(NIGHT)
			K.box(V(70, 1, 30), C(90, 90, 95), CF(0, -0.5, 4))
			K.stars(30)
			K.moon()
			for i = -8, 8 do
				local h = rng:NextInteger(10, 40)
				K.box(V(10, h, 10), Color3.fromHSV(0.62, 0.2, 0.3), CF(i * 12, h / 2 - 16, 40))
			end
			K.box(V(2, 3, 2), C(120, 120, 125), CF(-20, 1.5, 12))
		end
		function SET.sewer()
			K.sky(C(6, 8, 6))
			K.box(V(130, 1, 8), C(90, 95, 90), CF(0, -0.5, 0))
			K.box(V(130, 1, 10), C(80, 140, 60), CF(0, -1.2, 9), NEON)
			K.box(V(130, 1, 30), C(70, 75, 70), CF(0, 14, 6))
			K.box(V(130, 20, 1), C(70, 75, 70), CF(0, 5, 15))
			for x = -40, 40, 20 do K.ball(0.8, C(255, 220, 120), V(x, 10, 12), true) end
		end
		function SET.fair(night)
			K.ground(C(90, 180, 70), Enum.Material.Grass, night and NIGHT or DUSK)
			local hub = V(18, 14, 30)
			for i = 1, 12 do
				local a = i / 12 * math.pi * 2
				K.box(V(0.4, 10, 0.4), C(230, 230, 240), CF(hub) * ANG(0, 0, a) * CF(0, 5, 0))
				K.box(V(2, 2, 2), Color3.fromHSV(i / 12, 0.7, 1), CF(hub + V(-math.sin(a) * 10, math.cos(a) * 10, 0)), NEON)
			end
			for _, x in ipairs({ -30, -14 }) do
				K.box(V(10, 6, 8), C(250, 250, 250), CF(x, 3, 20))
				K.wedge(V(10, 3, 4), C(230, 50, 60), CF(x, 7.5, 18))
				K.wedge(V(10, 3, 4), C(230, 50, 60), CF(x, 7.5, 22) * ANG(0, math.pi, 0))
			end
			if night then K.stars(20) end
		end
		function SET.court()
			SET.room(C(120, 85, 55), C(150, 120, 90), C(10, 8, 6))
			K.box(V(10, 5, 3), C(90, 55, 30), CF(0, 2.5, 6))
			local gh = K.box(V(1.2, 0.6, 0.6), C(70, 40, 20), CF(1.5, 5.3, 5))
			return function() -- bang the gavel
				for _ = 1, 2 do
					gh.CFrame = CF(1.5, 6.5, 5)
					hold(0.12)
					gh.CFrame = CF(1.5, 5.3, 5)
					sfx(SFX.thud, 0.5, 1.6, 0.6)
					shake(0.12, 0.15)
					hold(0.2)
				end
			end
		end
		function SET.classroom()
			SET.room(C(170, 130, 90), C(230, 220, 190))
			K.box(V(16, 6, 0.3), C(40, 70, 50), CF(0, 7, 11.4))
			for x = -12, 12, 8 do K.table(x, 1, C(200, 170, 120)) end
		end
		function SET.mall()
			SET.room(C(235, 235, 230), C(250, 245, 235), C(14, 14, 18))
			for i = -2, 2 do K.box(V(9, 8, 0.3), Color3.fromHSV(rng:NextNumber(), 0.5, 0.95), CF(i * 11, 4, 11.4), NEON) end
			K.palm(-26, 6)
		end
		function SET.hideout()
			SET.room(C(70, 55, 45), C(90, 80, 70), C(8, 8, 10))
			K.table(0, 4, C(110, 75, 45))
		end
		function SET.cell()
			SET.room(C(110, 110, 115), C(140, 140, 145), C(6, 6, 8))
			for x = -12, 12, 2 do K.box(V(0.35, 12, 0.35), C(50, 50, 55), CF(x, 6, -1), METAL) end
			K.box(V(26, 0.5, 0.5), C(50, 50, 55), CF(0, 11.5, -1), METAL)
			K.box(V(6, 1.2, 3), C(160, 160, 165), CF(7, 0.6, 7))
		end
		function SET.yard()
			K.ground(C(150, 145, 140), nil, DAY)
			for x = -36, 36, 3 do K.box(V(0.2, 9, 0.2), C(120, 120, 125), CF(x, 4.5, 14), METAL) end
			K.box(V(76, 0.2, 0.2), C(120, 120, 125), CF(0, 9, 14), METAL)
			K.box(V(30, 14, 10), C(130, 130, 135), CF(-28, 7, 24))
		end
		K.DAY, K.NIGHT, K.DUSK = DAY, NIGHT, DUSK

		local function shuffled(n, from)
			local b = {}
			for i = from or 1, n do table.insert(b, i) end
			for i = #b, 2, -1 do
				local j = rng:NextInteger(1, i)
				b[i], b[j] = b[j], b[i]
			end
			return b
		end
		-- a shuffled deck per list: every plot plays once before any plays again
		local function deal(key, n, from)
			story.bags = story.bags or {}
			local b = story.bags[key]
			if not b or #b == 0 then
				b = shuffled(n, from)
				story.bags[key] = b
			end
			return table.remove(b)
		end

		-- CH 3: 40 more BAY HEIST chapters. Each slots into the running saga in place of one of the
		-- regular chapters (a different job, a different jail day...) and decides where the story goes next.
		local function dan() return K.who("Cop", "Officer Dan") end
		local function lineUp(crew, x, z, lookX, lookZ, gap)
			for i, r in ipairs(crew) do K.put(r, x + (i - 1) * (gap or 3), z, lookX, lookZ) end
		end
		local function busted(crew, cop, text) -- caught indoors: hands up, marched out
			K.all(crew, function(r) r.face(cop.pos) r.gesture("handsUp", 3.5) end)
			K.say(cop, text or "Hands where I can see 'em!", "point")
			K.siren(3)
			K.all(crew, function(r) K.walkAsync(r, -44, -4, 7) end)
			K.walk(cop, -40, -6, 7)
		end
		local function guilty(text) story.news = text story.chapter = "court" end
		local function free(text, nxt) story.news = text story.chapter = nxt or "hideout" end
		local function lucky(p) return rng:NextNumber() < (p or 0.5) end

		local HEIST = {
			job = {
				{ "THE MUSEUM JOB", function(H)
					local gem = SET.museum()
					local lasers = {}
					for i = 1, 3 do table.insert(lasers, K.box(V(40, 0.1, 0.1), C(255, 30, 30), CF(0, 1 + i * 1.3, 2), NEON)) end
					local crew = H.castGang(false, true)
					lineUp(crew, -22, 2, 0, 2, 2.5)
					K.open(V(-6, 6, -18), V(-6, 3, 4))
					K.cap("The Bay Museum. Home of the Blue Bay Diamond.", 2)
					K.say(crew[1], "Lasers. Nobody touch the red lines.", "point")
					K.walk(crew[1], -4, 2, 4)
					K.all(lasers, function(l) l.Transparency = 1 end)
					K.say(crew[#crew], "Uh... I sneezed on the button.", "facepalm")
					K.all(lasers, function(l) l.Transparency = 0 end)
					H.alarmFlashes(nil, 3)
					K.walk(crew[1], -1, 5, 8)
					gem.Transparency = 1
					crew[1].gesture("cheer", 2)
					burst("spark", V(0, 5, 7), 12)
					K.say(crew[1], "GOT IT! RUN!")
					if lucky(0.5) then
						local cop = K.put(dan(), 22, 0, -10, 0)
						busted(crew, cop, "The museum is CLOSED, gentlemen.")
						guilty(story.gangName .. " caught red-handed with the Blue Bay Diamond!")
					else
						K.all(crew, function(r) K.runAsync(r, -40, -3) end)
						hold(1.6)
						story.loot += 25000
						free(story.gangName .. " steals the Blue Bay Diamond! Museum 'very upset'.", "chase")
					end
				end },
				{ "THE BANK VAULT", function(H)
					local door = SET.vault()
					local crew = H.castGang(false, true)
					lineUp(crew, 6, -2, 16, 11, 2.5)
					K.open(V(4, 7, -16), V(10, 5, 8))
					K.cap("Underneath the Bay Bank. The vault.", 2)
					crew[1].gesture("dig", 3)
					for _ = 1, 6 do burst("spark", V(14, 5, 9), 4) sfx(SFX.blip, 0.4, 0.4, 0.3) hold(0.3) end
					K.glide(door, door.CFrame * CF(0, 0, -9), 1.2)
					sfx(SFX.thud, 0.5, 0.6, 1)
					K.say(crew[1], "We're in!", "cheer")
					K.walk(crew[1], -2, 6, 8)
					burst("money", V(-2, 3, 8), 30)
					crew[1].gesture("carry", 5)
					K.say(crew[#crew], "Gold! GOLD! Wait, how do we carry gold?", "shrug")
					if lucky(0.4) then
						local cop = K.put(dan(), 22, 2, 0, 4)
						K.walk(cop, 14, 2, 6)
						busted(crew, cop, "Funny. I was about to say the same thing.")
						guilty(story.gangName .. " caught INSIDE the Bay Bank vault!")
					else
						story.loot += 40000
						K.cap("They leave with as much gold as their pockets can hold.", 2)
						free(story.gangName .. " cleans out the Bay Bank vault!", "chase")
					end
				end },
				{ "THE ARMORED TRUCK", function(H)
					SET.street(false)
					for i = 1, 4 do K.cone(0, -10 + i * 2.2) end
					local truck = K.car("armored", -60, -8)
					local crew = H.castGang(false, true)
					lineUp(crew, 6, -2, 0, -8)
					K.open(V(-6, 8, -32), V(0, 3, -4))
					K.cap("High noon. The armored truck is on its way.", 2)
					K.track(truck.pos, V(-4, 6, -24), V(6, 0, 0))
					truck.drive(-6, 2.6)
					sfx(SFX.thud, 0.4, 0.7, 1)
					K.cut(V(-6, 7, -26), V(-2, 3, -6))
					K.say(crew[1], "Nobody move! This is a stick-up!", "point")
					local driver = K.put(dan(), -4, -4.5, 6, -4)
					K.say(driver, "Oh no. Anyway.", "shrug")
					K.say(driver, "It's me, Officer Dan. This truck is FULL of cops.", "point")
					local cops = {}
					for i = 1, 2 do cops[i] = K.put(K.who("Cop", "Cop"), -8 - i * 2, -6, 6, -4) end
					H.arrest(crew, driver, 6, "Surprise!")
					guilty(story.gangName .. " robs a truck full of police officers. Somehow surprised.")
				end },
				{ "THE ICE CREAM HEIST", function(H)
					SET.plaza(false)
					local van = K.car("icecream", -10, -8)
					local crew = H.castGang(false, false)
					lineUp(crew, -24, -3, -10, -8)
					local callahan = K.put(K.who("Rider", "Callahan"), 2, -4, -10, -8)
					K.open(V(-10, 8, -30), V(-10, 3, -4))
					K.cap("Callahan's ice cream truck. Unattended. For ONE minute.", 2)
					K.say(callahan, "Back in a sec! Nobody touch my truck.", "wave")
					K.walk(callahan, 30, 6, 8)
					K.say(crew[1], "You thinking what I'm thinking?", "point")
					K.all(crew, function(r) K.walkAsync(r, -10, -5.5, 10) end)
					hold(1.2)
					K.all(crew, function(r) r.hide() end)
					K.track(van.pos, V(-4, 6, -24), V(6, 0, 0))
					sfx(SFX.whoosh, 0.4, 1.4, 1)
					van.drive(70, 3, true)
					K.cut(V(20, 7, -20), V(30, 3, 6))
					callahan.face(V(60, 0, -8))
					K.say(callahan, "MY TRUCK! MY SPRINKLES!", "handsUp")
					story.loot += 300
					free(story.gangName .. " steals Callahan's ice cream truck. Sprinkles everywhere.", "chase")
				end },
				{ "THE GOLDEN EGG", function(H)
					SET.plaza(true)
					local egg = K.egg(V(10, 0, 4), 2.5, C(255, 200, 40))
					egg.Material = NEON
					local crew = H.castGang(false, true)
					lineUp(crew, -16, 0, 10, 4)
					K.open(V(0, 7, -20), V(6, 3, 4))
					K.cap("The Egg Shop. The legendary GOLDEN EGG sits in the window.", 2.2)
					K.walk(crew[1], 7, 2, 7)
					crew[1].gesture("lift", 2)
					K.glide(egg, egg.CFrame + V(0, 3, 0), 0.8)
					K.say(crew[1], "Heavier than it looks...")
					burst("spark", egg.Position, 16)
					sfx(SFX.thud, 0.5, 1.8, 0.6)
					egg.Transparency = 1
					local chick = K.ball(1.4, C(255, 230, 80), egg.Position)
					K.say(crew[#crew], "IT HATCHED?!", "handsUp")
					K.glide(chick, CF(egg.Position + V(-30, -2, -4)), 1.2)
					if lucky(0.5) then
						local cop = K.put(dan(), -24, -3, 0, 0)
						K.walk(cop, -12, -2, 9)
						busted(crew, cop, "Stealing an egg? That's a FOWL crime.")
						guilty(story.gangName .. " caught stealing the Golden Egg. It hatched.")
					else
						K.all(crew, function(r) K.runAsync(r, 40, -3) end)
						hold(1.4)
						free(story.gangName .. " flees the Egg Shop. The Golden Egg was a baby chick!", "hideout")
					end
				end },
				{ "THE SECRET RECIPE", function(H)
					SET.lab()
					local paper = K.box(V(1.6, 0.1, 2), C(250, 250, 240), CF(10, 3, 7), NEON)
					local crew = H.castGang(false, true)
					lineUp(crew, -20, 0, 10, 7)
					K.open(V(0, 7, -18), V(4, 3, 6))
					K.cap("Bloxy Cola HQ. The secret recipe is locked in the lab.", 2.2)
					K.walk(crew[1], 8, 4, 7)
					paper.Transparency = 1
					crew[1].gesture("carry", 3)
					K.say(crew[1], "The secret Bloxy Cola recipe! We're gonna be RICH!")
					K.say(crew[#crew], "What does it say?")
					K.say(crew[1], "...'Step 1: add sugar. Step 2: add MORE sugar.'", "facepalm")
					K.say(crew[#crew], "That's it?!", "shrug")
					local guard = K.put(K.robot("Security Bot"), 24, 2, 0, 2)
					K.say(guard, "INTRUDER. DETECTED.", "point")
					H.alarmFlashes(nil, 3)
					K.all(crew, function(r) K.runAsync(r, -40, -3) end)
					hold(1.6)
					free(story.gangName .. " steals Bloxy Cola recipe. Recipe: 'sugar'.", "hideout")
				end },
				{ "THE YACHT PARTY", function(H)
					SET.dock(true)
					local yacht = K.boat(14, 9, C(250, 250, 250))
					yacht:ScaleTo(1.6)
					local crew = H.castGang(false, false)
					lineUp(crew, -20, 0, 14, 9)
					K.open(V(-4, 8, -22), V(6, 2, 6))
					K.cap("A fancy yacht party. The rich and famous of Discovery Bay.", 2.2)
					K.say(crew[1], "Act fancy. Pinkies UP.", "wave")
					K.walk(crew[1], 2, 1, 6)
					K.say(crew[#crew], "Is it fancy to eat ALL the shrimp?")
					K.say(crew[1], "The captain's golden anchor. Grab it.", "point")
					crew[1].gesture("lift", 2)
					hold(1)
					sfx(SFX.thud, 0.6, 0.6, 1)
					burst("dust", V(2, 0, 3), 16)
					crew[1].hide()
					K.cap("SPLASH! The anchor was heavier than he was.", 2)
					K.say(crew[#crew], "...Man overboard!", "handsUp")
					story.loot += 500
					free(story.gangName .. " crashes yacht party. One member 'still drying off'.", "beach")
				end },
				{ "THE PET SHOW", function(H)
					SET.stadium(false)
					local dog = K.dog(V(0, 0, 4), C(250, 250, 250))
					K.box(V(3, 1.5, 3), C(250, 200, 60), CF(0, 0.75, 6), NEON)
					local crew = H.castGang(false, false)
					lineUp(crew, -18, 0, 0, 4)
					K.open(V(-4, 7, -20), V(0, 3, 4))
					K.cap("The Bay Pet Show. The champion: Sir Fluffington the Third.", 2.2)
					K.say(crew[1], "That dog is worth a MILLION bucks.", "point")
					K.walk(crew[1], -3, 3, 7)
					crew[1].gesture("carry", 2)
					dog.bark()
					K.say(crew[1], "Come on, Fluffy. Let's go.")
					K.all(crew, function(r) K.walkAsync(r, -40, -3, 9) end)
					dog.goAsync(-36, -2, 3)
					hold(1.6)
					local cop = K.put(dan(), -30, -4, 0, 0)
					K.cut(V(-30, 6, -20), V(-34, 2, -2))
					dog.bark()
					K.say(cop, "Follow that dog! He's leading me right to you!", "point")
					H.arrest(crew, cop, -34, "The dog TOLD on you.")
					guilty("Prize poodle leads police straight to " .. story.gangName .. ".")
				end },
				{ "THE TUNNEL JOB", function(H)
					SET.sewer()
					local crew = H.castGang(false, true)
					lineUp(crew, -12, 0, 10, 0)
					K.open(V(-4, 6, -14), V(0, 3, 4))
					K.cap("Under the town. The plan: dig straight into the bank.", 2.2)
					K.all(crew, function(r) r.gesture("dig", 4) end)
					for _ = 1, 5 do burst("dust", V(6, 2, 2), 6) sfx(SFX.thud, 0.25, 1.4, 0.4) hold(0.6) end
					K.say(crew[1], "Up! We should be right under the vault!")
					K.clear()
					SET.cell()
					crew = H.castGang(false, true)
					lineUp(crew, -4, 4, 0, -10)
					local cop = K.put(dan(), 6, -4, -2, 4)
					K.cut(V(0, 7, -20), V(0, 4, 3))
					burst("dust", V(-2, 1, 4), 20)
					sfx(SFX.thud, 0.5, 0.8, 1)
					K.say(crew[1], "...This isn't the bank.", "shrug")
					K.say(cop, "Nope. It's the JAIL. Thanks for saving me the drive.", "point")
					K.say(crew[#crew], "Who was holding the map?!", "facepalm")
					story.news = story.gangName .. " digs tunnel into the bank. Ends up IN the jail."
					story.chapter, story.jailDays = "jail", 0
				end },
				{ "THE MALL SANTA", function(H)
					SET.mall()
					local crew = H.castGang(false, false)
					for _, r in ipairs(crew) do K.paint(r, C(200, 30, 30), r.model.Head.Color) K.hat(r, C(200, 30, 30), true) end
					lineUp(crew, -8, 4, 0, -10)
					local kid = K.put(K.who("Rider", "Little Timmy"), 10, 0, -8, 4)
					K.open(V(0, 6, -18), V(0, 3, 4))
					K.cap("Bay Mall. In JULY. Somebody's dressed as Santa.", 2.2)
					K.say(kid, "Santa? It's summer. And why are there three of you?", "point")
					K.say(crew[1], "Ho ho ho! We're... the Santa squad.", "wave")
					K.say(kid, "Your sack has a dollar sign on it.")
					K.say(crew[#crew], "...RUN!", "handsUp")
					K.all(crew, function(r) K.runAsync(r, -40, -3) end)
					hold(1.2)
					K.say(kid, "MOM! The fake Santas are stealing the cash register!", "point")
					story.loot += 800
					free(story.gangName .. " robs Bay Mall dressed as Santa. In July.", "chase")
				end },
				{ "THE ZOO JOB", function(H)
					SET.park()
					local banana = K.box(V(0.6, 2.4, 0.6), C(255, 220, 40), CF(4, 4, 8) * ANG(0, 0, 0.5), NEON)
					K.box(V(3, 3, 3), C(245, 245, 245), CF(4, 1.5, 8))
					local crew = H.castGang(false, true)
					lineUp(crew, -18, 0, 4, 8)
					K.open(V(-4, 7, -20), V(0, 3, 4))
					K.cap("The Bay Zoo. On display: the Golden Banana.", 2)
					K.walk(crew[1], 2, 5, 7)
					banana.Transparency = 1
					crew[1].gesture("cheer", 2)
					K.say(crew[1], "Easiest job EVER.")
					local gorilla = K.put(K.big(K.bald(K.paint(K.who("Rider", "Gorilla"), C(40, 40, 44), C(60, 60, 64))), 1.5), 24, 6, 0, 6)
					gorilla.voice = 0.5
					K.say(gorilla, "OOH OOH. AAH AAH.", "handsUp")
					K.say(crew[#crew], "That's HIS banana!", "point")
					K.all(crew, function(r) K.runAsync(r, -40, -3) end)
					K.runAsync(gorilla, -30, 0)
					hold(1.8)
					free(story.gangName .. " chased out of the zoo by a gorilla. Banana returned.", "beach")
				end },
				{ "THE TRAIN ROBBERY", function(H)
					SET.desert()
					local cars = {}
					for i = 0, 3 do table.insert(cars, K.box(V(12, 5, 5), i == 0 and C(40, 40, 46) or C(150, 60, 40), CF(-70 - i * 13, 3, 4))) end
					local train = K.model(cars)
					local crew = H.castGang(false, true)
					lineUp(crew, 0, -4, 0, 10)
					K.open(V(-10, 7, -24), V(0, 3, 4))
					K.cap("The 3:15 Desert Express. Carrying the Bay's gold reserves.", 2.2)
					sfx(SFX.whoosh, 0.4, 0.6, 3)
					K.glideAsync(train, train:GetPivot() + V(70, 0, 0), 3, true)
					hold(2.6)
					K.say(crew[1], "Jump on! NOW!", "point")
					K.all(crew, function(r) r.hide() end)
					K.track(function() return train:GetPivot().Position end, V(-6, 8, -24), V(4, 0, 0))
					K.glide(train, train:GetPivot() + V(90, 0, 0), 3, true)
					local loot = rng:NextInteger(5, 20) * 1000
					story.loot += loot
					K.cap("They ride off into the sunset with $" .. loot .. ".", 2)
					free(story.gangName .. " robs the Desert Express! Train 'running late'.", "hideout")
				end },
			},
			plan = {
				{ "THE NEW RECRUIT", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -8, 6, 0, -4)
					local kid = K.put(K.who("Rider", "The Kid"), 8, 0, -4, 6)
					K.open(V(0, 7, -16), V(0, 3, 4))
					K.cap(story.gangName .. " is holding tryouts.", 2)
					K.say(crew[1], "So. Why do you want to join the gang?", "point")
					K.say(kid, "I can do a backflip!", "cheer")
					K.hop(kid, 3, 0.6)
					K.say(crew[#crew], "Can you crack a safe?", "shrug")
					K.say(kid, "I can crack an egg?")
					K.say(crew[1], "...You're hired.", "wave")
					story.chapter = "job"
					story.news = story.gangName .. " recruiting. Applicants 'mostly children'."
				end },
				{ "THE TRAINING MONTAGE", function(H)
					SET.yard()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 2, 0, -10, 5)
					K.open(V(0, 7, -18), V(0, 3, 4))
					K.cap("Before the big job: TRAINING.", 1.6)
					K.all(crew, function(r) r.gesture("lift", 3) end)
					K.cap("Day 1: lifting.", 1.4)
					K.all(crew, function(r, i) K.runAsync(r, 20, 2 + i * 2) end)
					K.cap("Day 2: running away.", 1.6)
					K.all(crew, function(r) r.gesture("binoculars", 2.4) end)
					K.cap("Day 3: looking out for cops.", 1.6)
					K.say(crew[1], "We are READY.", "cheer")
					story.chapter = "job"
				end },
				{ "DISGUISE SHOPPING", function(H)
					SET.mall()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 3, 0, -10, 4)
					K.open(V(0, 6, -16), V(0, 3, 4))
					K.cap(story.gangName .. " goes shopping for disguises.", 2)
					K.mustache(crew[1])
					K.say(crew[1], "How do I look?", "shrug")
					if crew[2] then K.say(crew[2], "Like you with a mustache.") end
					K.hat(crew[#crew], C(240, 200, 60), true)
					K.say(crew[#crew], "NOBODY will recognize us now.", "cheer")
					local cop = K.put(dan(), 20, 0, 0, 3)
					K.say(cop, "Afternoon, " .. story.gang[1].name .. ".", "wave")
					K.say(crew[1], "...How?!", "facepalm")
					story.chapter = "job"
				end },
				{ "THE GANG NAME", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 7, 0, -4, 6)
					K.open(V(0, 7, -16), V(0, 3, 4))
					K.cap("An emergency gang meeting.", 1.6)
					K.say(crew[1], "Our name is BORING. We need a cooler one.", "point")
					local options = { "The Bay Bandits", "The Snack Pack", "The Scooter Crooks", "The Midnight Muffins", "The Sneaky Seagulls" }
					local new = pick(options)
					if crew[2] then K.say(crew[2], "What about... '" .. pick(options) .. "'?", "shrug") end
					K.say(crew[#crew], "No no no. '" .. new .. "'.", "cheer")
					K.say(crew[1], "...I love it.", "wave")
					story.news = story.gangName .. " changes its name to " .. new .. ". Police 'not fooled'."
					story.gangName = new
					story.chapter = "job"
				end },
				{ "THE SCOUTING TRIP", function(H)
					SET.rooftop()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 2, 0, 30)
					K.open(V(-2, 6, -14), V(0, 4, 10))
					K.cap("Midnight. A rooftop. Watching the target.", 2)
					crew[1].gesture("binoculars", 4)
					K.say(crew[1], (story.target and story.target.name or "The bank") .. ". Guard changes at 3 AM.")
					if crew[2] then K.say(crew[2], "How do you know?") end
					K.say(crew[1], "It says so on their website.", "shrug")
					local heli = K.heli(V(30, 22, 20))
					K.glide(heli, heli:GetPivot() + V(-25, -4, -6), 2)
					K.say(crew[#crew], "HELICOPTER! Everybody freeze like a statue!", "handsUp")
					hold(1)
					K.glide(heli, heli:GetPivot() + V(-60, 6, 0), 2)
					K.say(crew[1], "...We're good. The job's ON.", "cheer")
					story.chapter = "job"
				end },
			},
			hideout = {
				{ "THE BIRTHDAY", function(H)
					SET.hideout()
					K.cake(0, 4)
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 7, 0, 4, 6)
					K.open(V(0, 8, -16), V(0, 3, 4))
					K.cap("It's " .. story.gang[1].name .. "'s birthday at the hideout.", 2)
					if crew[2] then K.say(crew[2], "Happy birthday, boss! Make a wish!", "cheer") end
					K.say(crew[1], "I wish we never get caught.", "wave")
					burst("spark", V(0, 5, 4), 14)
					if lucky(0.4) then
						local cop = K.put(dan(), 0, 4, 0, -10)
						burst("food", V(0, 5, 4), 24)
						sfx(SFX.thud, 0.5, 1.2, 0.8)
						K.say(cop, "SURPRISE! You're under arrest!", "handsUp")
						K.say(crew[1], "He was IN the cake?!", "facepalm")
						busted(crew, cop, "Happy birthday. Your present: handcuffs.")
						guilty("Officer Dan pops out of " .. story.gang[1].name .. "'s birthday cake. Gang arrested.")
					else
						K.all(crew, function(r) r.gesture("cheer", 2.5) end)
						K.cheer()
						K.cap("Best. Birthday. Ever.", 1.8)
						story.chapter = "plan"
					end
				end },
				{ "THE PIZZA GUY", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -8, 6, 0, -4, 5)
					K.open(V(0, 7, -16), V(0, 3, 4))
					K.cap("Pizza night at the hideout.", 1.6)
					sfx(SFX.thud, 0.4, 1.6, 0.5)
					local guy = K.mustache(K.put(dan(), 20, 0, 0, 2))
					K.walk(guy, 8, 1, 6)
					K.say(guy, "Pizza delivery! For... " .. story.gangName .. "?", "carry")
					K.say(crew[1], "That's us! Hey... do I know you?", "point")
					if lucky(0.5) then
						K.say(guy, "Nope! Just a regular pizza guy. Named... Dan.", "shrug")
						K.say(crew[#crew], "IT'S OFFICER DAN!", "handsUp")
						busted(crew, guy, "Extra cheese, extra handcuffs.")
						guilty("Fake pizza guy Officer Dan arrests " .. story.gangName .. ".")
					else
						K.say(guy, "Nah. Enjoy your pizza!", "wave")
						burst("food", V(0, 4, 4), 14)
						K.say(crew[1], "Best pizza in the Bay.", "cheer")
						story.chapter = "plan"
					end
				end },
				{ "FAKE MONEY", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 7, 0, 4, 6)
					K.open(V(0, 8, -16), V(0, 3, 4))
					K.cap("Counting the loot: $" .. story.loot .. ".", 1.8)
					burst("money", V(0, 4, 4), 24)
					crew[1].gesture("carry", 2)
					K.say(crew[1], "Wait... why is this money PINK?")
					if crew[2] then K.say(crew[2], "It says 'Bay-opoly'. It's board game money.", "facepalm") end
					K.say(crew[#crew], "So we're... broke?", "shrug")
					story.loot = 0
					story.news = story.gangName .. " loot turns out to be board game money."
					story.chapter = "plan"
				end },
				{ "THE RIVAL GANG", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -10, 4, 10, 4, 3)
					local rivals = {}
					for i = 1, 2 do rivals[i] = K.put(K.hat(K.who("Robber", pick({ "Vinnie", "Rocco", "Fingers" })), C(220, 220, 220)), 6 + i * 3, 4, -10, 4) end
					K.open(V(0, 7, -16), V(0, 3, 4))
					K.cap("Uh oh. The Seagull Gang wants their turf back.", 2)
					K.say(rivals[1], "This is OUR hideout.", "point")
					K.say(crew[1], "We were here first!", "point")
					K.say(rivals[2], "Then let's settle it... with a DANCE-OFF.", "cheer")
					K.all(crew, function(r) r.gesture("cheer", 3) end)
					K.all(rivals, function(r) r.gesture("wave", 3) end)
					sfx(SFX.whoosh, 0.4, 1.3, 1)
					hold(2.6)
					local cop = K.put(dan(), -24, 0, 0, 4)
					K.walk(cop, -14, 1, 8)
					K.say(cop, "Two gangs. One room. My lucky day.", "point")
					busted(crew, cop, "ALL of you, out!")
					guilty("Police break up gang DANCE-OFF. " .. story.gangName .. " arrested.")
				end },
				{ "BLACKOUT", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 7, 0, 4, 6)
					K.open(V(0, 8, -16), V(0, 3, 4))
					K.cap("A quiet night at the hideout...", 1.6)
					fade(true, 0.2)
					sfx(SFX.thud, 0.4, 0.6, 1)
					caption("CLICK. The power goes out.", 1.6)
					K.say(crew[1], "WHO TURNED OFF THE LIGHTS?!")
					if crew[2] then K.say(crew[2], "Something's licking my hand!") end
					fade(false, 0.4)
					local dog = K.dog(V(2, 0, 2))
					burst("money", V(2, 3, 2), 12)
					dog.goAsync(30, -2, 2)
					K.say(crew[#crew], "A DOG! He's got the loot bag!", "point")
					K.all(crew, function(r) K.runAsync(r, 40, -2) end)
					hold(1.6)
					story.loot = math.floor(story.loot / 2)
					story.news = "Dog steals half of " .. story.gangName .. "'s loot. Hero dog 'very good boy'."
					story.chapter = "plan"
				end },
				{ "TV NIGHT", function(H)
					SET.hideout()
					local tv = K.box(V(8, 5, 0.6), C(20, 20, 24), CF(0, 5, 10))
					K.box(V(7.4, 4.4, 0.1), C(90, 160, 220), CF(0, 5, 9.6), NEON)
					local crew = H.castGang(false, false)
					lineUp(crew, -6, -2, 0, 12, 6)
					K.open(V(0, 6, -14), V(0, 4, 8))
					K.cap("TV night. And guess who's on Bay News?", 2)
					K.say(crew[1], "Turn it up! That's US!", "point")
					K.say(crew[#crew], "They said I look like a potato.", "facepalm")
					if crew[2] then K.say(crew[2], "...You kinda do.", "shrug") end
					tv.Color = C(255, 40, 40)
					K.say(crew[1], "Wait. They said they're watching the hideout. LIVE.", "handsUp")
					K.all(crew, function(r) r.face(V(0, 0, -20)) end)
					K.say(crew[1], "Everybody act natural!", "wave")
					story.chapter = "stakeout"
				end },
				{ "THE DOUBLE-CROSS", function(H)
					SET.hideout()
					local crew = H.castGang(false, false)
					lineUp(crew, -6, 7, 0, 4, 6)
					K.open(V(0, 8, -16), V(0, 3, 4))
					K.cap("Splitting the loot. $" .. story.loot .. ".", 1.6)
					local traitor = crew[#crew]
					traitor.gesture("carry", 3)
					K.say(traitor, "Actually... I'll take ALL of it. Bye!", "wave")
					K.runAsync(traitor, 40, -4)
					hold(1)
					K.say(crew[1], "TRAITOR! After him!", "point")
					K.all(crew, function(r) if r ~= traitor then K.runAsync(r, 40, -2) end end)
					hold(1.6)
					story.news = story.gang[#story.gang].name .. " double-crosses " .. story.gangName .. ", flees to the beach."
					story.chapter = "beach"
				end },
			},
			chase = {
				{ "THE SCOOTER CHASE", function(H)
					SET.street(true)
					K.ramp(16, -4, 2.5, 6)
					local robber = K.rider(story.gang[1].name)
					K.paint(robber, C(30, 30, 34), C(30, 30, 34))
					local cop = K.rider("Officer Dan")
					K.paint(cop, C(30, 50, 120), C(234, 184, 146))
					robber.at(-40, 0, -4)
					cop.at(-54, 0, -4)
					K.open(V(-30, 6, -20), V(-40, 2, -4))
					K.cap("A SCOOTER chase through downtown!", 1.6)
					K.siren(6)
					task.spawn(function() pcall(K.jump, cop, { z = -4, from = -54, rampX = 16, len = 6, h = 2.5, trick = "no-hander", bail = true }) end)
					K.follow(robber, V(-6, 6, -22))
					local ok = K.jump(robber, { z = -4, from = -40, rampX = 16, len = 6, h = 2.5, trick = "backflip" })
					hold(1.2)
					K.cut(V(28, 6, -18), V(30, 1, -4))
					K.cap(ok and "He lands it! Officer Dan... does not." or "Both of them wipe out!", 2)
					free(story.gang[1].name .. " escapes police with a BACKFLIP. Officer Dan 'fine, thanks'.", "hideout")
				end },
				{ "THE BOAT CHASE", function(H)
					SET.dock(false)
					local getaway = K.boat(-20, 14, C(250, 200, 40))
					local police = K.boat(-46, 18, C(40, 60, 160))
					K.open(V(-30, 8, -12), V(-24, 1, 14))
					K.cap(story.gangName .. " escapes by boat! The Bay Patrol is right behind!", 2.2)
					K.siren(5)
					K.track(function() return getaway:GetPivot().Position end, V(-8, 8, -22), V(6, 0, 0))
					K.glideAsync(police, police:GetPivot() + V(80, 0, -4), 4, true)
					K.glide(getaway, getaway:GetPivot() + V(70, 0, 0), 4, true)
					burst("dust", getaway:GetPivot().Position, 10)
					if lucky(0.5) then
						K.cap("They run out of gas. Right next to the police boat.", 2)
						local crew = H.castGang(false, false)
						lineUp(crew, 40, 0, 40, 10)
						local cop = K.put(dan(), 30, 0, 40, 0)
						K.cut(V(36, 6, -14), V(40, 2, 2))
						K.say(crew[1], "Who forgot to fill the tank?!", "facepalm")
						H.arrest(crew, cop, 40, "End of the line, sailors.")
						guilty(story.gangName .. " runs out of gas in boat chase. Arrested at the dock.")
					else
						K.cap("They vanish into the fog.", 1.8)
						free(story.gangName .. " escapes by speedboat!", "beach")
					end
				end },
				{ "THE TRAFFIC JAM", function(H)
					SET.street(false)
					local van = K.car("van", -20, -8)
					for i = 1, 4 do K.car(pick({ "car", "taxi", "bus" }), -6 + i * 12, -8) end
					K.open(V(-24, 8, -30), V(-10, 3, -6))
					K.cap("The getaway van... is stuck in traffic.", 2)
					local crew = H.castGang(false, true)
					lineUp(crew, -24, -4.5, -10, -4.5)
					K.say(crew[1], "HONK! MOVE IT!", "point")
					sfx(SFX.blip, 0.6, 0.3, 0.5)
					local cop = K.put(dan(), -60, -4, 0, -4)
					K.walk(cop, -30, -4.5, 5)
					K.say(cop, "Afternoon. Nice day to sit in traffic, huh?", "wave")
					K.say(crew[#crew], "...Can we just walk to jail?", "shrug")
					H.arrest(crew, cop, -36, "Hop in. My lane's empty.")
					guilty(story.gangName .. " caught in a traffic jam. Officer Dan 'walked over'.")
				end },
				{ "THE HELICOPTER", function(H)
					SET.rooftop()
					local crew = H.castGang(false, true)
					lineUp(crew, -6, 4, 0, -10)
					local heli = K.heli(V(-50, 20, 6))
					K.open(V(0, 6, -16), V(0, 4, 4))
					K.cap("The police helicopter is searching the rooftops.", 2)
					K.siren(4)
					K.glide(heli, heli:GetPivot() + V(46, -2, 0), 2.4)
					local beam = K.cyl(24, 5, C(255, 255, 210), CF(heli:GetPivot().Position - V(0, 12, 0)) * ANG(0, 0, math.pi / 2), NEON)
					beam.Transparency = 0.6
					K.say(crew[1], "Quick! Pose like STATUES!", "handsUp")
					K.all(crew, function(r) r.gesture("handsUp", 5) end)
					hold(2.4)
					beam:Destroy()
					K.glide(heli, heli:GetPivot() + V(60, 4, 0), 2)
					K.say(crew[#crew], "It worked?! Best plan EVER.", "cheer")
					free(story.gangName .. " hides from helicopter by 'standing very still'.", "hideout")
				end },
			},
			court = {
				{ "THE SURPRISE WITNESS", function(H)
					local gavel = SET.court()
					local judge = K.put(K.who("Judge", "Judge Gavelton"), 0, 6.5, 0, -10, 3.2)
					local crew = H.castGang(false, false)
					lineUp(crew, -8, -2, 0, 8)
					local cop = K.put(dan(), 8, -2, 0, 8)
					K.open(V(0, 8, -22), V(0, 4, 4))
					K.cap(story.gangName .. " on trial. The prosecution calls a SURPRISE witness.", 2.4)
					gavel()
					K.say(cop, "I call... Sir Barks-a-Lot!", "point")
					local dog = K.dog(V(4, 0, 2))
					dog.bark()
					K.say(judge, "The dog may speak.")
					dog.bark()
					dog.bark()
					K.say(cop, "He says they did it, your honor.", "shrug")
					K.say(crew[1], "OBJECTION! That dog is BIASED!", "point")
					gavel()
					local years = rng:NextInteger(3, 12)
					story.years += years
					K.say(judge, "Overruled. GUILTY. " .. years .. " years!", "point")
					story.news = "Dog testifies against " .. story.gangName .. ". Guilty, " .. years .. " years."
					story.chapter, story.jailDays = "jail", 0
				end },
				{ "THE LAWYER", function(H)
					local gavel = SET.court()
					local judge = K.put(K.who("Judge", "Judge Gavelton"), 0, 6.5, 0, -10, 3.2)
					local crew = H.castGang(false, false)
					local lawyer = K.mustache(K.hat(crew[1], C(20, 20, 20)))
					lineUp(crew, -8, -2, 0, 8)
					K.open(V(0, 8, -22), V(0, 4, 4))
					K.cap("The gang has a lawyer. A VERY familiar-looking lawyer.", 2.2)
					gavel()
					K.say(lawyer, "Your honor, my clients are innocent. Especially the handsome one.", "point")
					K.say(judge, "Isn't the handsome one... YOU?")
					K.say(lawyer, "I have never met me in my life.", "shrug")
					if lucky(0.3) then
						gavel()
						K.say(judge, "...I'm too tired for this. Not guilty.", "facepalm")
						K.all(crew, function(r) r.gesture("cheer", 2) end)
						free("Gang member defends himself in a fake mustache. WINS.", "hideout")
					else
						gavel()
						K.say(judge, "GUILTY. And take off that mustache.", "point")
						story.years += 6
						story.news = story.gangName .. "'s 'lawyer' was a gang member in a mustache. Guilty."
						story.chapter, story.jailDays = "jail", 0
					end
				end },
				{ "THE SLEEPY JUDGE", function(H)
					local gavel = SET.court()
					local judge = K.put(K.who("Judge", "Judge Gavelton"), 0, 6.5, 0, -10, 3.2)
					local crew = H.castGang(false, false)
					lineUp(crew, -8, -2, 0, 8)
					K.open(V(0, 8, -22), V(0, 4, 4))
					K.cap("Day 9 of the trial. It's been a long trial.", 2)
					gavel()
					K.say(judge, "And so... the court... finds... zzzzz...")
					K.cap("ZZZZZ...", 1.6)
					K.say(crew[1], "Psst. He's asleep. Tiptoe!", "point")
					K.all(crew, function(r) K.walkAsync(r, -40, -4, 4) end)
					hold(2.4)
					gavel()
					K.say(judge, "...GUILTY! Huh? Where'd they go?", "shrug")
					story.news = story.gangName .. " tiptoes out of court while Judge Gavelton naps."
					story.chapter = "chase"
				end },
				{ "THE JURY", function(H)
					local gavel = SET.court()
					local judge = K.put(K.who("Judge", "Judge Gavelton"), 0, 6.5, 0, -10, 3.2)
					local crew = H.castGang(false, false)
					lineUp(crew, -10, -2, 0, 8)
					local jury = {}
					for i = 1, 3 do jury[i] = K.put(K.who("Rider", "Juror " .. i), 6 + i * 3, 2, 0, -10) end
					K.open(V(0, 8, -22), V(0, 4, 4))
					K.cap("The jury: three scooter riders who were promised free pizza.", 2.2)
					gavel()
					K.say(judge, "Has the jury reached a verdict?")
					K.say(jury[1], "We have, your honor. We find them...", "point")
					hold(0.6)
					if lucky(0.4) then
						K.say(jury[2], "...NOT guilty! They gave us scooter stickers!", "cheer")
						K.say(judge, "That's BRIBERY!", "facepalm")
						free("Jury lets " .. story.gangName .. " go. Bribed with stickers.", "hideout")
					else
						K.say(jury[2], "GUILTY! They stole my scooter in 2019!", "point")
						gavel()
						story.years += 8
						story.news = story.gangName .. " found guilty by a jury of angry scooter riders."
						story.chapter, story.jailDays = "jail", 0
					end
				end },
			},
			jail = {
				{ "FOOD FIGHT", function(H)
					SET.room(C(160, 160, 160), C(200, 200, 205))
					K.table(-6, 4)
					K.table(8, 4)
					local crew = H.castGang(true, false)
					lineUp(crew, -10, 1, 0, 6)
					local bully = K.put(K.big(K.who("Robber", "Big Moe"), 1.3), 10, 1, -6, 2)
					K.open(V(0, 7, -18), V(0, 3, 4))
					K.cap("Bay Jail cafeteria. Mystery meat Monday.", 2)
					K.say(bully, "Hey. That's MY pudding.", "point")
					K.say(crew[1], "Come and get it.", "shrug")
					K.say(crew[#crew], "FOOD FIIIIGHT!", "cheer")
					for _ = 1, 4 do burst("food", V(rng:NextNumber(-8, 8), 4, 3), 12) sfx(SFX.thud, 0.25, 1.8, 0.3) hold(0.35) end
					shake(0.2, 0.6)
					local guard = K.put(K.who("Cop", "Guard Dan"), -24, 0, 0, 2)
					K.walk(guard, -14, 0, 8)
					K.say(guard, "WHO STARTED THIS?!", "point")
					K.all(crew, function(r) r.gesture("point", 2) end)
					K.say(crew[1], "Him.")
					story.news = "Bay Jail food fight! " .. story.gangName .. " blames 'Big Moe'."
					story.chapter = "jail"
				end },
				{ "THE TALENT SHOW", function(H)
					SET.room(C(110, 110, 115), C(140, 140, 145))
					K.box(V(14, 1, 6), C(140, 30, 40), CF(0, 0.5, 6))
					local crew = H.castGang(true, false)
					lineUp(crew, -12, -4, 0, 6)
					local singer = crew[1]
					K.put(singer, 0, 6, 0, -10, 1)
					local guard = K.put(K.who("Cop", "Guard Dan"), 12, -4, 0, 6)
					K.open(V(0, 7, -18), V(0, 4, 4))
					K.cap("The Bay Jail Talent Show.", 1.8)
					K.say(singer, "This one's for my mom. ~ La la laaaa ~", "handsUp", 3)
					K.say(singer, "~ I'm sorry I robbed that baaaank ~", "wave", 3)
					guard.gesture("facepalm", 3)
					K.say(guard, "*sniff* That was... BEAUTIFUL.")
					K.cheer()
					if lucky(0.5) then
						K.say(guard, "You're all free! For your ART!", "cheer")
						story.news = story.gang[1].name .. " sings his way out of Bay Jail."
						story.chapter = "plan"
					else
						K.say(guard, "Still in jail, though.", "shrug")
						story.chapter = "yard"
					end
				end },
				{ "MOM VISITS", function(H)
					SET.room(C(150, 150, 150), C(190, 190, 195))
					K.box(V(30, 3, 1), C(120, 120, 125), CF(0, 1.5, 2))
					K.box(V(30, 4, 0.2), C(180, 220, 240), CF(0, 5, 2), Enum.Material.Glass)
					local crew = H.castGang(true, false)
					local son = K.put(crew[1], 0, 5, 0, -10)
					for i = 2, #crew do crew[i].hide() end
					local mom = K.put(K.hat(K.who("Judge", "Mom"), C(200, 120, 180)), 0, -2, 0, 10)
					K.open(V(-8, 6, -10), V(0, 4, 2))
					K.cap("Visiting day.", 1.4)
					K.say(mom, story.gang[1].name .. "! What did I tell you about ROBBING?", "point")
					K.say(son, "...Not to?", "shrug")
					K.say(mom, "Not to get CAUGHT!", "facepalm")
					K.say(mom, "I brought cookies. There's a file in one. Don't eat that one.")
					story.news = "Mom of gang leader brings cookies to Bay Jail. Guards 'suspicious'."
					story.chapter = lucky(0.5) and "breakout" or "jail"
				end },
				{ "COOKING CLASS", function(H)
					SET.room(C(200, 200, 205), C(230, 230, 235))
					K.table(0, 4, C(200, 200, 210))
					local pot = K.cyl(1.6, 2.2, C(60, 60, 66), CF(0, 3.6, 4) * ANG(0, 0, math.pi / 2), METAL)
					local crew = H.castGang(true, false)
					lineUp(crew, -6, 1, 0, 4)
					local chef = K.put(K.hat(K.who("Cop", "Chef Guard"), C(250, 250, 250), true), 8, 2, 0, 4)
					K.open(V(0, 7, -16), V(0, 3, 4))
					K.cap("Bay Jail cooking class. Today: soup.", 1.8)
					K.say(chef, "Just a PINCH of salt.", "point")
					crew[1].gesture("lift", 2)
					K.say(crew[1], "Oops. That was the whole bag.")
					burst("smoke", pot.Position, 18)
					K.boom(pot.Position + V(0, 1, 0))
					K.alarm(3)
					K.say(chef, "FIRE! Everybody out!", "handsUp")
					K.say(crew[#crew], "...Did someone say OUT?", "point")
					story.news = "Bay Jail kitchen fire! Soup 'too salty'."
					story.chapter = "breakout"
				end },
				{ "THE SPOON TUNNEL", function(H)
					SET.cell()
					local crew = H.castGang(true, false)
					lineUp(crew, -6, 5, 0, 10, 4)
					K.open(V(0, 7, -22), V(0, 3, 4))
					K.cap("Escape plan: dig out. With a spoon.", 1.8)
					K.all(crew, function(r) r.gesture("dig", 3) end)
					for d = 1, 3 do
						burst("dust", V(-4, 1, 9), 8)
						caption("Day " .. (story.jailDays + d * 10) .. "...", 1)
					end
					K.say(crew[1], "We're through!", "cheer")
					K.clear()
					SET.room(C(140, 120, 100), C(180, 160, 140))
					K.table(0, 4)
					local guard = K.put(K.who("Cop", "Guard Dan"), 0, 6, 0, -10)
					crew = H.castGang(true, false)
					lineUp(crew, -10, 0, 0, 4)
					K.cut(V(0, 7, -18), V(0, 3, 4))
					burst("dust", V(-8, 1, 0), 16)
					K.say(guard, "...Hello. This is my office.", "wave")
					K.say(crew[1], "We'll just... go back down.", "shrug")
					story.news = story.gangName .. " digs tunnel with spoon. Comes out in guard's office."
					story.chapter = "jail"
				end },
				{ "CHESS WITH THE GUARD", function(H)
					SET.cell()
					K.box(V(3, 0.2, 3), C(240, 240, 240), CF(0, 2.8, 4))
					for i = 0, 3 do for j = 0, 3 do if (i + j) % 2 == 0 then K.box(V(0.75, 0.22, 0.75), C(30, 30, 30), CF(-1.1 + i * 0.75, 2.81, 2.9 + j * 0.75)) end end end
					K.box(V(1, 2.6, 1), C(120, 90, 60), CF(0, 1.3, 4))
					local crew = H.castGang(true, false)
					local me = K.put(crew[1], -3, 4, 0, 4)
					for i = 2, #crew do K.put(crew[i], -8 - i * 2, 7, 0, 4) end
					local guard = K.put(K.who("Cop", "Guard Dan"), 3, 4, 0, 4)
					K.open(V(0, 6, -10), V(0, 3, 4))
					K.cap("Late night. A chess match. The stakes: the cell keys.", 2.2)
					K.say(guard, "Your move.")
					me.gesture("point", 1.5)
					K.say(me, "Checkmate.", "shrug")
					K.say(guard, "WHAT? I don't even know how this game works!", "facepalm")
					K.say(me, "A deal's a deal. The keys.", "point")
					story.news = "Guard loses cell keys in chess game. " .. story.gangName .. " 'very smart now'."
					story.chapter = "breakout"
				end },
				{ "THE LAUNDRY ESCAPE", function(H)
					SET.room(C(200, 200, 205), C(170, 190, 210))
					local cart = K.box(V(4, 3, 3), C(200, 200, 210), CF(-4, 1.5, 4), METAL)
					local sheets = K.box(V(3.8, 1, 2.8), C(250, 250, 250), CF(-4, 3.2, 4))
					local cartModel = K.model({ cart, sheets })
					local crew = H.castGang(true, false)
					lineUp(crew, -14, 4, -4, 4)
					local guard = K.put(K.who("Cop", "Guard Dan"), 10, 0, -4, 4)
					K.open(V(0, 7, -16), V(0, 3, 4))
					K.cap("Laundry day. Into the cart they go.", 1.8)
					K.all(crew, function(r) K.walkAsync(r, -4, 4, 6) end)
					hold(1.6)
					K.all(crew, function(r) r.hide() end)
					K.say(guard, "Hmm. Heavy laundry today.", "lift")
					K.walkAsync(guard, 40, 0, 5)
					K.glide(cartModel, cartModel:GetPivot() + V(44, 0, 0), 4)
					K.cap("...and straight out the front gate.", 1.8)
					story.news = story.gangName .. " escapes Bay Jail in a laundry cart!"
					story.chapter = "beach"
				end },
				{ "THE PAROLE HEARING", function(H)
					local gavel = SET.court()
					local judge = K.put(K.who("Judge", "Judge Gavelton"), 0, 6.5, 0, -10, 3.2)
					local crew = H.castGang(true, false)
					lineUp(crew, -6, -2, 0, 8)
					K.open(V(0, 8, -22), V(0, 4, 4))
					K.cap("The parole hearing. One chance to say sorry.", 2)
					gavel()
					K.say(judge, "Have you learned your lesson?")
					K.say(crew[1], "Yes, your honor. Crime doesn't pay.", "handsUp")
					K.say(crew[#crew], "Well, it paid a LITTLE.", "shrug")
					crew[1].gesture("facepalm", 2)
					if lucky(0.5) then
						gavel()
						K.say(judge, "...Parole granted. Behave.", "point")
						story.news = story.gangName .. " granted parole. Promise to 'be good'."
						story.chapter = "plan"
					else
						gavel()
						K.say(judge, "DENIED.", "point")
						story.chapter = "jail"
					end
				end },
				{ "THE ALIEN CELLMATE", function(H)
					SET.cell()
					local crew = H.castGang(true, false)
					lineUp(crew, -8, 5, 0, -10, 3)
					local zorp = K.put(K.alien("Zorp"), 6, 6, 0, -10)
					K.open(V(0, 7, -22), V(0, 3, 4))
					K.cap("A new cellmate. From... very far away.", 2)
					K.say(zorp, "Greetings. I was arrested for parking my saucer on the beach.", "wave")
					K.say(crew[1], "You got a way out of here?", "point")
					K.say(zorp, "Hold still, earthlings.", "handsUp")
					flash(C(170, 255, 170), 0.8)
					sfx(SFX.whoosh, 0.5, 0.6, 2)
					K.all(crew, function(r) K.fly(r, r.pos + V(0, 30, 0), 1.6) end)
					K.cap("BEAMED. UP.", 1.6)
					story.news = "Alien helps " .. story.gangName .. " escape Bay Jail by TRACTOR BEAM."
					story.chapter = "beach"
				end },
			},
		}
		function plots.heistPick(hub) -- (nil = play the saga's own chapter for this part of the story)
			local list = HEIST[hub]
			if not list then return nil end
			local i = deal("heist_" .. hub, #list, 0) -- index 0 = the original chapter, in the same deck
			return i > 0 and list[i] or nil
		end
		plots.HEIST = HEIST

		-- SCOOTER TV: riders, jumps, races, and 50 events in a points season ---------------------------
		local ROSTER = { "Zippy", "Kickflip Kim", "Big Wheel Bo", "Turbo Tia", "Rad Rick", "Scoot McGee", "Nova", "Lil Wheelie" }
		function K.onScooter(r) -- a scooter welded under anyone's feet (it flips with them)
			local root = r.model:FindFirstChild("HumanoidRootPart")
			local deckCf = root.CFrame * CF(0, -r.height + 0.15, 0)
			for _, spec in ipairs({
				{ V(1, 0.25, 3.4), CF(), C(30, 30, 34) },
				{ V(0.25, 3.6, 0.25), CF(0, 1.8, -1.5), C(200, 200, 205) },
				{ V(2.2, 0.25, 0.25), CF(0, 3.5, -1.5), C(30, 30, 34) },
				{ V(0.3, 0.7, 0.7), CF(0, -0.15, -1.45), C(20, 20, 20) },
				{ V(0.3, 0.7, 0.7), CF(0, -0.15, 1.45), C(20, 20, 20) },
			}) do
				local p = part(r.model, spec[1], spec[3])
				p.Anchored = false
				p.CanCollide = false
				p.CFrame = deckCf * spec[2]
				local wc = Instance.new("WeldConstraint")
				wc.Part0, wc.Part1 = root, p
				wc.Parent = p
			end
			r.lift = 0.4
			r.anim("ride")
			function r.at(x, y, z, rot, yaw) -- (facing +X unless told otherwise)
				r.model:PivotTo(CF(x, y + r.height + r.lift, z) * ANG(0, yaw or -math.pi / 2, 0) * (rot or CF()))
				r.pos = V(x, y, z)
			end
			return r
		end
		function K.rider(name) return K.onScooter(K.who("Rider", name or pick(ROSTER))) end
		local TRICKS = {
			backflip = function(u) return ANG(u * math.pi * 2, 0, 0) end,
			frontflip = function(u) return ANG(-u * math.pi * 2, 0, 0) end,
			["360"] = function(u) return ANG(0, u * math.pi * 2, 0) end,
			["720"] = function(u) return ANG(0, u * math.pi * 4, 0) end,
			["1080"] = function(u) return ANG(0, u * math.pi * 6, 0) end,
			corkscrew = function(u) return ANG(u * math.pi * 2, u * math.pi * 2, 0) end,
			["double backflip"] = function(u) return ANG(u * math.pi * 4, 0, 0) end,
			["barrel roll"] = function(u) return ANG(0, 0, u * math.pi * 2) end,
			superman = function(u) return ANG(-math.sin(u * math.pi) * 0.9, 0, 0) end,
			["no-hander"] = function() return CF() end,
		}
		local TRICK_NAMES = {}
		for k in pairs(TRICKS) do table.insert(TRICK_NAMES, k) end
		table.sort(TRICK_NAMES)
		function K.anyTrick() return pick(TRICK_NAMES) end
		-- one jump: roll in, up the ramp, a trick in the air, land (or bail). o: z, rampX, len, h, dist,
		-- height (arc), air (seconds), landY, trick, bail, rollOut
		function K.jump(r, o)
			o = o or {}
			local z, h, len = o.z or 0, o.h or 3, o.len or 7
			local top = (o.rampX or -3.5) + len / 2
			local startX = o.from or (top - len - 19)
			local trick = o.trick or K.anyTrick()
			local long = trick == "720" or trick == "1080" or trick == "double backflip"
			local airT, dist, landY = o.air or (long and 1.7 or 1.3), o.dist or 11, o.landY or 0
			local t0 = clock()
			repeat
				local u = math.min((clock() - t0) / 1.5, 1)
				r.at(startX + u * (top - len - startX), 0, z)
				hold(0)
			until u >= 1
			t0 = clock()
			repeat
				local u = math.min((clock() - t0) / 0.42, 1)
				r.at(top - len + u * len, u * h, z, ANG(math.rad(-18) * u, 0, 0))
				hold(0)
			until u >= 1
			sfx(SFX.whoosh, 0.4, rng:NextNumber(0.9, 1.15), 1.5)
			if trick == "no-hander" or trick == "superman" then r.gesture(trick == "superman" and "handsUp" or "cheer", airT) end
			t0 = clock()
			repeat
				local u = math.min((clock() - t0) / airT, 1)
				r.at(top + u * dist, h + (landY - h) * u + math.sin(u * math.pi) * (o.height or 7), z, TRICKS[trick] and TRICKS[trick](u) or CF())
				hold(0)
			until u >= 1
			local landX = top + dist
			if o.bail then
				sfx(SFX.thud, 0.45, 0.8, 1)
				r.at(landX + 1.5, landY - r.height - r.lift + 0.6, z, ANG(0, 0, math.rad(90)))
				burst("dust", V(landX + 1.5, landY + 0.5, z), 8)
				shake(0.25, 0.4)
				return false
			end
			sfx(SFX.thud, 0.3, 1.4, 1)
			burst("dust", V(landX, landY + 0.3, z), 5)
			t0 = clock()
			repeat
				local u = math.min((clock() - t0) / 1.1, 1)
				r.at(landX + u * (o.rollOut or 16), landY, z)
				hold(0)
			until u >= 1
			return true
		end
		function K.roll(r, x1, t, z, y, wobble) -- ride along to x1
			local x0 = r.pos and r.pos.X or 0
			local t0 = clock()
			repeat
				local u = math.min((clock() - t0) / t, 1)
				r.at(x0 + (x1 - x0) * u, y or 0, (z or 0) + (wobble and math.sin(u * 18) * wobble or 0), wobble and ANG(0, 0, math.sin(u * 23) * 0.25) or nil)
				hold(0)
			until u >= 1
		end
		function K.race(list, o)
			o = o or {}
			local dist, t = o.dist or 70, o.time or 5
			local x0, z0, y = o.from or -40, o.z or 0, o.y or 0
			local winner = o.winner or list[rng:NextInteger(1, #list)]
			local pace = {}
			for i, r in ipairs(list) do pace[i] = r == winner and 1 or rng:NextNumber(0.78, 0.95) end
			K.box(V(0.6, 0.12, 3 * #list + 4), C(250, 250, 250), CF(x0 + dist, y + 0.02, z0), NEON)
			local function lane(i) return z0 + (i - (#list + 1) / 2) * 3 end
			for i, r in ipairs(list) do r.at(x0, y, lane(i)) end
			K.track(function()
				local best = list[1].model:GetPivot().Position
				for _, r in ipairs(list) do
					local p = r.model:GetPivot().Position
					if p.X > best.X then best = p end
				end
				return best
			end, V(-5, 6, -24), V(6, 0, 0))
			sfx(SFX.whoosh, 0.4, 1.2, 1)
			local t0 = clock()
			repeat
				local u = math.min((clock() - t0) / t, 1)
				for i, r in ipairs(list) do
					local k = math.min(u * pace[i], 1)
					r.at(x0 + dist * k, y, lane(i) + (o.weave and math.sin(clock() * 3 + i) * 1.2 or 0))
				end
				if o.during then o.during(u) end
				hold(0)
			until u >= 1
			K.cheer()
			return winner
		end
		function K.points(name, n)
			story.scootPoints = story.scootPoints or {}
			story.scootPoints[name] = (story.scootPoints[name] or 0) + n
		end
		function K.standings(n)
			local list = {}
			for nm, p in pairs(story.scootPoints or {}) do table.insert(list, { nm, p }) end
			table.sort(list, function(a, b) return a[2] > b[2] end)
			local s = {}
			for i = 1, math.min(n or 3, #list) do table.insert(s, i .. ". " .. list[i][1] .. " (" .. list[i][2] .. ")") end
			return #s > 0 and table.concat(s, "   ") or "nobody yet!", list
		end
		local HYPE = { "SICK!", "Did you SEE that?!", "Clean landing!", "The crowd goes WILD!", "Ten out of ten!", "UNREAL!" }
		local BAIL = { "OOF! He's gonna feel that.", "Ohhh, that's gotta hurt!", "Bail! Get up, get up!", "That's a yard sale!" }
		local function team(n)
			local names = table.clone(ROSTER)
			local list = {}
			for i = 1, n do list[i] = K.rider(table.remove(names, rng:NextInteger(1, #names))) end
			return list
		end
		local function score(landed, base)
			if not landed then
				K.boo()
				K.cap(pick(BAIL), 1.8)
				return 0
			end
			local s, total = {}, 0
			for i = 1, 3 do
				s[i] = math.min(10, (base or 6.5) + rng:NextInteger(0, 7) * 0.5)
				total += s[i]
			end
			K.cheer()
			K.cap(pick(HYPE) .. "   Judges: " .. s[1] .. " / " .. s[2] .. " / " .. s[3], 2)
			return total
		end
		local WIDE, LOOK = V(0, 9, -34), V(3, 4, 0)
		-- everybody takes a turn on the ramp; best score wins
		local function contest(list, o)
			o = o or {}
			local best, bestS = list[1], -1
			for _, r in ipairs(list) do
				local trick = o.trick or K.anyTrick()
				K.cut(o.cam or WIDE, o.look or LOOK)
				K.cap(r.name .. " drops in... going for the " .. trick:upper() .. "!", 1.4)
				K.follow(r, o.follow or V(-4, 6, -24))
				local bails = rng:NextNumber() < (o.bailChance or 0.2)
				local ok = K.jump(r, { trick = trick, bail = bails, h = o.h, len = o.len, rampX = o.rampX, dist = o.dist, height = o.height, air = o.air, landY = o.landY, z = o.z })
				K.cut(o.cam or WIDE, o.look or LOOK)
				local sc = score(ok, o.base)
				if o.after then o.after(r, ok) end
				r.hide()
				if sc > bestS then best, bestS = r, sc end
			end
			return best
		end
		local function winner(r, pts)
			r.show()
			r.at(4, 0, -2, nil, 0)
			r.gesture("cheer", 2.5)
			K.cut(V(4, 5, -12), V(4, 3, 0))
			K.cap(r.name .. " WINS! +" .. (pts or 10) .. " season points.", 2)
			K.points(r.name, pts or 10)
		end
		local function fans(n, z)
			for i = 1, n or 4 do
				local f = K.who("Rider", "Fan")
				K.put(f, -18 + i * 8, z or 9, -18 + i * 8, -10)
				f.gesture(pick({ "cheer", "wave", "handsUp" }), 30)
			end
		end
		local function host() return K.put(K.who("Anchor", "MC Chip"), -12, -6, 0, 0) end

		local SCOOTER = {
			{ "THE TRICK CONTEST", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				fans(4)
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("Welcome to SCOOTER TV! Three riders. One ramp. Let's GO!", 2)
				winner(contest(list))
			end },
			{ "THE BUS JUMP", function()
				SET.skatepark()
				K.ramp(-4, 0, 4, 8)
				K.car("bus", 13, 0)
				K.ramp(28, 0, 4, 8, C(255, 140, 40)).CFrame *= ANG(0, math.pi, 0)
				local r = K.rider()
				K.open(V(6, 10, -36), V(8, 4, 0))
				K.cap("Today " .. r.name .. " jumps... a SCHOOL BUS.", 2)
				K.follow(r, V(-4, 7, -26))
				local ok = K.jump(r, { rampX = -4, len = 8, h = 4, dist = 22, height = 6, landY = 0, trick = "superman", bail = rng:NextNumber() < 0.3 })
				if not ok then K.boom(V(20, 3, 0)) K.cap("Into the side of the bus! He's OK! The bus is not.", 2.2) else K.cheer() K.cap("OVER THE BUS!", 1.6) K.points(r.name, 15) end
			end },
			{ "THE SHARK TANK", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 4, 7)
				local pool = K.box(V(16, 1, 8), C(40, 120, 220), CF(9, -0.4, 0), NEON)
				pool.Transparency = 0.2
				local fin = K.fin(6, 0.6, 0)
				local r = K.rider()
				K.open(V(4, 10, -30), V(6, 2, 0))
				K.cap("Jumping a POOL. With a SHARK in it. Bruce is hungry today.", 2.2)
				K.glideAsync(fin, fin.CFrame + V(8, 0, 0), 3)
				K.follow(r, V(-4, 7, -24))
				local ok = K.jump(r, { h = 4, dist = 16, height = 6, trick = "backflip", bail = rng:NextNumber() < 0.25 })
				if ok then K.cheer() K.cap("He clears the shark! Bruce looks disappointed.", 2) K.points(r.name, 15)
				else burst("dust", V(16, 0, 0), 20) K.cap("SPLASH! ...He's out! He's fine! Bruce just wanted a hug.", 2.4) end
			end },
			{ "THE RING OF FIRE", function()
				SET.skatepark()
				K.sky(K.DUSK)
				K.ramp(-3.5, 0, 3, 7)
				K.ring(V(5.5, 7.5, 0), 3.5)
				local list = team(2)
				K.open(V(4, 9, -26), V(4, 5, 0))
				K.cap("Through the RING OF FIRE. Don't touch the sides!", 2)
				for _, r in ipairs(list) do
					K.follow(r, V(-4, 6, -22))
					local ok = K.jump(r, { trick = "no-hander", dist = 13, height = 6, bail = rng:NextNumber() < 0.3 })
					burst("spark", V(5.5, 7.5, 0), 14)
					K.cut(V(4, 9, -26), V(4, 5, 0))
					score(ok, 7)
					r.hide()
				end
			end },
			{ "THE BIG RACE", function()
				SET.street(false)
				local list = team(4)
				K.open(V(-40, 6, -16), V(-40, 2, 0))
				K.cap("Downtown Grand Prix! Four riders, one finish line!", 2)
				K.cap("3... 2... 1... GO!", 1.2)
				local w = K.race(list, { dist = 80, time = 5.5, from = -40, z = -4 })
				K.cap(w.name .. " takes the checkered flag!", 1.8)
				K.points(w.name, 12)
			end },
			{ "MOON RIDE", function()
				SET.space()
				K.ramp(-3.5, 0, 3, 7, C(200, 200, 210))
				local r = K.hat(K.rider(), C(240, 240, 250), true)
				K.open(WIDE, LOOK)
				K.cap("SCOOTER TV... on the MOON. Low gravity. HUGE air.", 2.2)
				K.follow(r, V(-6, 8, -30))
				K.jump(r, { trick = "1080", height = 22, air = 3.6, dist = 36 })
				K.cap("A 1080 in SPACE! That's a SCOOTER TV first!", 2)
				K.points(r.name, 20)
			end },
			{ "SNOW DAY SESSION", function()
				SET.snow()
				K.ramp(-3.5, 0, 3, 7, C(230, 240, 255))
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("It SNOWED in California?! The riders don't care.", 2)
				winner(contest(list, { bailChance = 0.35 }))
			end },
			{ "DESERT DASH", function()
				SET.desert()
				local list = team(3)
				K.open(V(-40, 6, -16), V(-40, 2, 0))
				K.cap("The Desert Dash! Watch out for cactus!", 1.8)
				local w = K.race(list, { dist = 90, time = 6, weave = true })
				K.cap(w.name .. " wins the Dash! Somebody check Bo for needles.", 2)
				K.points(w.name, 12)
			end },
			{ "BOARDWALK RACE", function()
				SET.beach()
				local list = team(3)
				K.open(V(-40, 6, -18), V(-40, 2, -2))
				K.cap("A race down the beach boardwalk!", 1.6)
				local w = K.race(list, { dist = 70, time = 5, z = -6 })
				K.cap(w.name .. " wins! And now: ice cream.", 1.8)
				K.points(w.name, 10)
			end },
			{ "THE ROOFTOP GAP", function()
				SET.rooftop()
				K.box(V(40, 1, 30), C(90, 90, 95), CF(54, -0.5, 4))
				K.ramp(28, 0, 2.5, 6)
				local r = K.rider()
				K.open(V(20, 10, -26), V(30, 0, 0))
				K.cap("Midnight. Two rooftops. ONE gap. " .. r.name .. " is crazy.", 2.2)
				K.follow(r, V(-6, 6, -22))
				local ok = K.jump(r, { rampX = 28, len = 6, h = 2.5, dist = 12, height = 5, trick = "360", bail = rng:NextNumber() < 0.2 })
				if ok then K.cheer() K.cap("HE MAKES IT!", 1.6) K.points(r.name, 15) else K.cap("He lands on the edge... and hangs on! Phew.", 2) end
			end },
			{ "SLALOM SHOWDOWN", function()
				SET.skatepark()
				for i = 0, 7 do K.cone(-28 + i * 8, (i % 2 == 0) and -1.5 or 1.5) end
				local list = team(2)
				K.open(V(0, 14, -30), V(0, 0, 0))
				K.cap("The slalom! Weave through the cones. Fastest time wins.", 2)
				local times = {}
				for i, r in ipairs(list) do
					r.at(-36, 0, 0)
					K.follow(r, V(-4, 8, -20))
					local t = rng:NextNumber(4.2, 5.4)
					local t0 = clock()
					repeat
						local u = math.min((clock() - t0) / t, 1)
						r.at(-36 + u * 72, 0, math.sin(u * math.pi * 8) * 2.2, ANG(0, 0, math.cos(u * math.pi * 8) * 0.3))
						hold(0)
					until u >= 1
					times[i] = math.floor(t * 100) / 100
					K.cap(r.name .. ": " .. times[i] .. " seconds!", 1.4)
					r.hide()
				end
				local w = times[1] <= times[2] and list[1] or list[2]
				winner(w, 10)
			end },
			{ "LIMBO LOW", function()
				SET.skatepark()
				local bar = K.box(V(0.4, 0.4, 6), C(255, 80, 160), CF(0, 4.2, 0), NEON)
				K.box(V(0.4, 6, 0.4), C(200, 200, 200), CF(0, 3, -3))
				K.box(V(0.4, 6, 0.4), C(200, 200, 200), CF(0, 3, 3))
				local list = team(3)
				K.open(V(0, 6, -16), V(0, 3, 0))
				K.cap("How LOW can you go? Scooter LIMBO!", 1.8)
				local alive = {}
				for round = 1, 2 do
					bar.CFrame = CF(0, 4.2 - round * 0.6, 0)
					for _, r in ipairs(list) do
						r.show()
						r.at(-20, 0, 0)
						local lean = rng:NextNumber(0.9, 1.4)
						local fail = lean < 1 + round * 0.12
						K.roll(r, -2, 1)
						r.at(-1, 0, 0, ANG(lean, 0, 0))
						hold(0.3)
						if fail then
							sfx(SFX.thud, 0.4, 1, 0.6)
							burst("dust", V(0, 1, 0), 6)
							K.cap(r.name .. " clips the bar!", 1.2)
							r.hide()
						else
							K.roll(r, 20, 0.8)
							alive[r] = round
							r.hide()
						end
					end
				end
				local w, best = list[1], -1
				for _, r in ipairs(list) do if (alive[r] or 0) > best then w, best = r, alive[r] or 0 end end
				winner(w, 8)
			end },
			{ "THE HIGH JUMP", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local bar = K.box(V(0.4, 0.4, 6), C(255, 220, 40), CF(5, 8, 0), NEON)
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("The HIGH JUMP! The bar goes up every round.", 1.8)
				local best, bestH = list[1], 0
				for round, hgt in ipairs({ 8, 10, 12 }) do
					bar.CFrame = CF(5, hgt, 0)
					K.cap("Round " .. round .. ": " .. hgt .. " feet!", 1.2)
					for _, r in ipairs(list) do
						if r.model.Parent then
							K.follow(r, V(-4, 6, -26))
							local pow = rng:NextNumber(6, 13)
							local ok = K.jump(r, { trick = "superman", height = pow, dist = 13, bail = pow < hgt - 1 })
							if ok then if hgt > bestH then best, bestH = r, hgt end else r.model.Parent = nil end
							K.cut(WIDE, LOOK)
						end
					end
				end
				winner(best, 10)
			end },
			{ "THE LONGEST JUMP", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				for d = 10, 30, 5 do K.box(V(0.3, 0.1, 5), C(250, 250, 250), CF(d, 0.03, 0), NEON) end
				local list = team(3)
				K.open(V(10, 10, -30), V(12, 2, 0))
				K.cap("Longest jump wins. Distance markers every five feet.", 1.8)
				local best, bestD = list[1], 0
				for _, r in ipairs(list) do
					local d = rng:NextInteger(10, 26)
					K.follow(r, V(-4, 6, -24))
					K.jump(r, { trick = "no-hander", dist = d, height = 4 + d * 0.25 })
					K.cut(V(10, 10, -30), V(12, 2, 0))
					K.cap(r.name .. ": " .. d .. " feet!", 1.4)
					if d > bestD then best, bestD = r, d end
					r.hide()
				end
				winner(best, 10)
			end },
			{ "THE SLOW RACE", function()
				SET.skatepark()
				local list = team(3)
				K.open(V(-30, 6, -16), V(-30, 2, 0))
				K.cap("The SLOW race. Last one across the line WINS. Don't fall over!", 2.2)
				for i, r in ipairs(list) do r.at(-34, 0, -3 + i * 3) end
				local t0 = clock()
				local fell = list[rng:NextInteger(1, 3)]
				repeat
					local u = (clock() - t0) / 5
					for i, r in ipairs(list) do r.at(-34 + u * (6 + i), 0, -3 + i * 3, ANG(0, 0, math.sin(clock() * 4 + i) * 0.2)) end
					hold(0)
				until u >= 1
				fell.at(-28, -fell.height - fell.lift + 0.6, fell.pos.Z, ANG(0, 0, math.rad(90)))
				sfx(SFX.thud, 0.4, 1, 0.6)
				K.cap(fell.name .. " tips over! Disqualified!", 1.8)
				local w = list[1] == fell and list[2] or list[1]
				winner(w, 6)
			end },
			{ "TANDEM TRICKS", function()
				SET.skatepark()
				K.ramp(-3.5, -3, 3, 7)
				K.ramp(-3.5, 3, 3, 7, C(60, 160, 240))
				local list = team(2)
				K.open(V(4, 10, -32), V(4, 4, 0))
				K.cap(list[1].name .. " and " .. list[2].name .. ": the TANDEM backflip!", 2)
				local trick = pick({ "backflip", "720", "corkscrew" })
				task.spawn(function() pcall(K.jump, list[2], { z = 3, trick = trick }) end)
				local ok = K.jump(list[1], { z = -3, trick = trick })
				score(ok, 8)
				K.points(list[1].name, 6)
				K.points(list[2].name, 6)
			end },
			{ "DOG ON A SCOOTER", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local r = K.rider("Linus's Owner")
				local dog = K.dog(V(-30, 0, 3))
				K.open(WIDE, LOOK)
				K.cap("Special guest: LINUS THE DOG!", 1.6)
				dog.bark()
				dog.goAsync(30, 3, 3.4)
				K.follow(r, V(-4, 6, -24))
				K.jump(r, { trick = "360" })
				K.cut(V(20, 5, -14), V(24, 2, 3))
				dog.bark()
				K.cap("Linus took the shortcut. Linus is the real winner.", 2)
				K.points("Linus the Dog", 5)
			end },
			{ "GRANNY GWEN", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local g = K.hat(K.onScooter(K.who("Judge", "Granny Gwen")), C(220, 220, 225))
				g.voice = 1.3
				local kid = K.put(K.who("Rider", "Rad Rick"), -14, -6, 0, 0)
				K.open(WIDE, LOOK)
				K.say(kid, "Granny? On a scooter? This should be funny.", "shrug")
				g.at(-30, 0, 0)
				K.say(g, "Hold my tea, sonny.", "wave")
				K.follow(g, V(-4, 6, -24))
				K.jump(g, { trick = "1080", height = 9, air = 2 })
				K.cut(WIDE, LOOK)
				K.cheer()
				K.say(kid, "...She did a TEN-EIGHTY.", "facepalm")
				K.points("Granny Gwen", 20)
			end },
			{ "THE ALIEN RIDER", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local ufo = K.ufo(V(-30, 22, 6))
				K.open(WIDE, LOOK)
				K.cap("Uh... is that a UFO over the park?", 1.6)
				ufo.beam(true)
				local z = K.onScooter(K.alien("Zorp"))
				z.at(-30, 0, 0)
				hold(1)
				ufo.beam(false)
				K.say(z, "Greetings. I would like to do... the KICKFLIP.", "wave")
				K.follow(z, V(-4, 7, -26))
				K.jump(z, { trick = "corkscrew", height = 26, air = 3, dist = 20 })
				K.cut(WIDE, LOOK)
				K.cheer()
				K.cap("The judges give it an 11. Out of 10. Out of THIS WORLD.", 2)
				K.points("Zorp", 25)
			end },
			{ "COP VS ROBBER", function()
				SET.street(false)
				local cop = K.onScooter(K.who("Cop", "Officer Dan"))
				local robber = K.onScooter(K.who("Robber", story.gang and story.gang[1] and story.gang[1].name or "Mugsy"))
				K.open(V(-40, 6, -16), V(-40, 2, 0))
				K.cap("A charity race! Officer Dan vs a known robber. For the kids.", 2.2)
				K.say(cop, "When I win, you turn yourself in.", "point")
				K.say(robber, "When I win, you buy me a Bloxy Cola.", "shrug")
				local w = K.race({ cop, robber }, { dist = 80, time = 5.5, z = -4 })
				K.cap(w.name .. " wins!", 1.6)
				K.say(w == cop and robber or cop, w == cop and "...Fine. Here are my handcuffs." or "...One Bloxy Cola. Coming up.", "facepalm")
			end },
			{ "THE COLA CAN JUMP", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3.5, 7)
				for i = 0, 3 do K.can(V(5 + i * 3.2, 0, 0), 5) end
				local r = K.rider()
				K.open(V(6, 9, -30), V(8, 3, 0))
				K.cap("Sponsored by Bloxy Cola: jump FOUR giant cans!", 2)
				K.follow(r, V(-4, 6, -24))
				local ok = K.jump(r, { h = 3.5, dist = 16, height = 7, trick = "backflip", bail = rng:NextNumber() < 0.25 })
				if ok then K.points(r.name, 12) K.cap("Refreshing!", 1.4) else burst("food", V(14, 4, 0), 20) K.cap("He crashes into the cans! Cola EVERYWHERE!", 2) end
			end },
			{ "THE MEGA RAMP", function()
				SET.skatepark()
				K.ramp(-8, 0, 9, 16, C(240, 240, 245))
				local r = K.rider()
				K.open(V(10, 16, -46), V(10, 8, 0))
				K.cap("THE MEGA RAMP. Nine feet tall. Nobody has ever...", 2)
				K.follow(r, V(-6, 8, -32))
				local ok = K.jump(r, { rampX = -8, len = 16, h = 9, dist = 34, height = 14, air = 2.4, trick = "double backflip", bail = rng:NextNumber() < 0.3 })
				if ok then K.cap("...until NOW! " .. r.name .. " is a LEGEND!", 2) K.points(r.name, 25) else K.cap("...and still nobody has. Medic!", 2) end
			end },
			{ "WORST TRICK CONTEST", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("The WORST trick contest. Bail on purpose. Biggest wipeout wins.", 2.2)
				local w = list[1]
				for _, r in ipairs(list) do
					K.follow(r, V(-4, 6, -24))
					K.jump(r, { trick = pick({ "barrel roll", "frontflip", "corkscrew" }), bail = true })
					K.cut(WIDE, LOOK)
					K.cheer()
					K.cap(pick({ "BEAUTIFUL disaster!", "A perfect 0 out of 10!", "He landed on his FACE. Gorgeous." }), 1.6)
					r.hide()
					w = r
				end
				winner(w, 5)
			end },
			{ "ROOKIE TRYOUTS", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local rookie = K.rider("Lil Wheelie")
				local mc = host()
				K.open(WIDE, LOOK)
				K.say(mc, "Our newest rookie, Lil Wheelie! First time on TV!", "point")
				rookie.at(-30, 0, 0)
				K.follow(rookie, V(-4, 6, -20))
				K.roll(rookie, -20, 1.6, 0, 0, 0.6)
				K.say(rookie, "W-whoa whoa whoa...")
				local ok = K.jump(rookie, { from = -20, trick = "no-hander", height = 5 })
				K.cut(WIDE, LOOK)
				K.cheer()
				K.say(mc, "SHE LANDED IT! A star is born!", "cheer")
				K.points("Lil Wheelie", 8)
			end },
			{ "THE INTERVIEW", function()
				SET.skatepark()
				local top = K.standings(1):match("^1%. (.-) %(") or "Zippy"
				local champ = K.put(K.who("Rider", top), 2, 0, -2, -10)
				local mc = K.put(K.who("Anchor", "MC Chip"), -2, 0, 2, -10)
				K.open(V(0, 5, -12), V(0, 4, 0))
				K.say(mc, "I'm here with the season leader, " .. top .. "!", "point")
				K.say(champ, "Thanks, Chip. I owe it all to my scooter. And snacks.", "wave")
				K.say(mc, "Any message for your rivals?")
				K.say(champ, "Yeah. Catch me if you can.", "point")
				K.cap("Standings: " .. K.standings(3), 2.6)
			end },
			{ "THE RIVALRY", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local a, b = K.rider("Zippy"), K.rider("Turbo Tia")
				K.open(WIDE, LOOK)
				K.cap("Zippy vs Turbo Tia. They do NOT like each other.", 2)
				a.at(-12, 0, -5, nil, 0)
				b.at(-6, 0, -5, nil, 0)
				K.say(a, "You're going DOWN, Tia.", "point")
				K.say(b, "Only thing going down is your score.", "shrug")
				winner(contest({ a, b }, { base = 7 }), 12)
			end },
			{ "THE COMEBACK", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local r = K.rider("Big Wheel Bo")
				K.stick(r, V(1.3, 0.3, 1.1), C(250, 250, 250), CF(0, 0.2, 0))
				K.open(WIDE, LOOK)
				K.cap("Last season, Big Wheel Bo broke his scooter on THIS ramp.", 2.2)
				K.say(r, "Today... I get my revenge.", "point")
				K.follow(r, V(-4, 6, -24))
				K.jump(r, { trick = "double backflip" })
				K.cut(WIDE, LOOK)
				K.cheer()
				K.cap("THE COMEBACK IS COMPLETE!", 1.8)
				K.points("Big Wheel Bo", 15)
			end },
			{ "NIGHT GLOW SESSION", function()
				SET.skatepark()
				K.sky(K.NIGHT)
				K.stars(30)
				K.ramp(-3.5, 0, 3, 7, C(80, 255, 160)).Material = NEON
				for x = -30, 30, 10 do K.box(V(0.3, 0.1, 9), Color3.fromHSV((x + 30) / 60, 0.8, 1), CF(x, 0.03, 0), NEON) end
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("The NIGHT GLOW session. Everything glows. Even the riders.", 2)
				winner(contest(list))
			end },
			{ "FARM FREESTYLE", function()
				SET.farm()
				K.ramp(-3.5, 0, 3, 7, C(200, 160, 90))
				K.cyl(3, 3, C(230, 200, 100), CF(6, 1.5, 0))
				local list = team(2)
				K.open(WIDE, LOOK)
				K.cap("Farm Freestyle! Over the hay bale, past the barn.", 1.8)
				winner(contest(list, { dist = 12 }))
			end },
			{ "DINO DODGE", function()
				SET.desert()
				local list = team(3)
				local dino = K.dino(V(-60, 0, 8), 1)
				dino.face(-math.pi / 2)
				K.open(V(-40, 8, -20), V(-50, 4, 4))
				K.cap("A race. With a DINOSAUR. Nobody told the riders.", 2)
				dino.roar()
				local w = K.race(list, { dist = 90, time = 5, during = function(u) dino.model:PivotTo(CF(-60 + u * 85, 5 + math.abs(math.sin(u * 30)) * 0.4, 8) * ANG(0, -math.pi / 2, 0)) end })
				K.cap(w.name .. " wins! The dinosaur came 4th. He's happy.", 2)
				K.points(w.name, 12)
			end },
			{ "STADIUM SHOWDOWN", function()
				SET.stadium(false)
				K.ramp(-3.5, 0, 3, 7)
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("LIVE from Bay Stadium! A sold-out crowd!", 1.8)
				K.cheer()
				winner(contest(list, { base = 7 }), 15)
			end },
			{ "THE RELAY", function()
				SET.skatepark()
				local list = team(4)
				K.open(V(-30, 7, -18), V(-30, 2, 0))
				K.cap("Relay race! Two teams, two legs each.", 1.8)
				local a = K.race({ list[1], list[2] }, { dist = 40, time = 3, from = -40 })
				list[1].hide() list[2].hide()
				local w = K.race({ list[3], list[4] }, { dist = 40, time = 3, from = 0, winner = a == list[1] and list[3] or list[4] })
				K.cap(w.name .. "'s team wins the relay!", 1.8)
				K.points(w.name, 8)
				K.points(a.name, 8)
			end },
			{ "THE SKATEPARK TOUR", function()
				SET.skatepark()
				for i = 0, 2 do K.ramp(-20 + i * 26, 0, 2.5 + i * 0.5, 6) end
				local r = K.rider()
				K.open(V(0, 12, -40), V(0, 3, 0))
				K.cap(r.name .. " takes the whole park. Three ramps. No stopping.", 2)
				K.follow(r, V(-4, 6, -24))
				for i = 0, 2 do
					K.jump(r, { from = r.pos and r.pos.X or -40, rampX = -20 + i * 26, len = 6, h = 2.5 + i * 0.5, dist = 8, rollOut = 4, trick = K.anyTrick() })
				end
				K.cheer()
				K.cap("A FULL RUN! Flawless!", 1.6)
				K.points(r.name, 15)
			end },
			{ "THE SPEED TRAP", function()
				SET.street(false)
				local cop = K.put(K.who("Cop", "Officer Dan"), 6, -4, -40, -4)
				local r = K.rider()
				K.open(V(10, 6, -14), V(0, 3, -4))
				K.say(cop, "Speed limit's 25. Let's see who's breaking it.", "binoculars", 3)
				r.at(-60, 0, -8)
				K.track(function() return r.model:GetPivot().Position end, V(0, 4, -16))
				K.roll(r, 60, 1)
				K.cut(V(10, 6, -14), V(0, 3, -4))
				K.say(cop, "...89 miles an hour. On a SCOOTER.", "facepalm")
				K.say(cop, "I'm not even mad. That's impressive.", "shrug")
				K.points(r.name, 8)
			end },
			{ "THE SCOOTER WEDDING", function()
				SET.park()
				local a, b = K.put(K.rider("Zippy"), -2, 4, 0, -10), K.put(K.rider("Nova"), 2, 4, 0, -10)
				a.at(-2, 0, 4, nil, 0)
				b.at(2, 0, 4, nil, 0)
				local j = K.put(K.who("Judge", "Judge Gavelton"), 0, 9, 0, -10)
				fans(4, 14)
				K.open(V(0, 6, -14), V(0, 4, 4))
				K.say(j, "Do you, Zippy, take Nova... and her scooter?")
				K.say(a, "I do!", "cheer")
				K.say(b, "I do too!", "cheer")
				K.say(j, "Then I pronounce you... SCOOTER PARTNERS.", "handsUp")
				K.cheer()
				burst("spark", V(0, 8, 4), 24)
				K.track(function() return a.model:GetPivot().Position end, V(-6, 5, -18))
				task.spawn(function() pcall(K.roll, b, 60, 2.5, 6) end)
				K.roll(a, 60, 2.5, 2)
			end },
			{ "SCOOTER BOWLING", function()
				SET.skatepark()
				local pins = {}
				for row = 0, 3 do
					for i = 0, row do table.insert(pins, K.cyl(2.6, 0.9, C(250, 250, 250), CF(20 + row * 1.6, 1.3, (i - row / 2) * 1.6) * ANG(0, 0, math.pi / 2))) end
				end
				local r = K.rider()
				K.open(V(8, 7, -20), V(16, 2, 0))
				K.cap("Scooter BOWLING! " .. r.name .. " is the ball.", 1.8)
				r.at(-30, 0, 0)
				K.follow(r, V(-4, 5, -18))
				K.roll(r, 22, 1.6)
				sfx(SFX.thud, 0.6, 1.2, 1)
				local knocked = rng:NextInteger(6, 10)
				for i = 1, knocked do
					local p = pins[i]
					K.glideAsync(p, p.CFrame * CF(rng:NextNumber(-4, 4), rng:NextNumber(4, 8), rng:NextNumber(-4, 4)) * ANG(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), 0.8)
				end
				hold(1)
				K.cap(knocked == 10 and "STRIKE!!!" or (knocked .. " pins!"), 1.6)
				if knocked == 10 then K.cheer() K.points(r.name, 10) end
			end },
			{ "THE JOUST", function()
				SET.fair(false)
				local a, b = K.rider("Sir Zippy"), K.rider("Lady Tia")
				for _, r in ipairs({ a, b }) do
					local root = r.model.HumanoidRootPart
					local lance = part(r.model, V(0.4, 0.4, 7), C(255, 120, 200))
					lance.Anchored = false
					lance.CanCollide = false
					lance.CFrame = root.CFrame * CF(1, 0.5, -3.5)
					local wc = Instance.new("WeldConstraint")
					wc.Part0, wc.Part1 = root, lance
					wc.Parent = lance
				end
				a.at(-30, 0, -1)
				b.at(30, 0, 1, nil, math.pi / 2)
				K.open(V(0, 8, -24), V(0, 3, 0))
				K.cap("JOUSTING! Pool noodles at twenty miles an hour!", 2)
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 1.6, 1)
					a.at(-30 + u * 29, 0, -1)
					b.at(30 - u * 29, 0, 1, nil, math.pi / 2)
					hold(0)
				until u >= 1
				K.boom(V(0, 3, 0))
				local loser = rng:NextNumber() < 0.5 and a or b
				loser.at(loser.pos.X, 3, loser.pos.Z, ANG(0, 0, 1.6))
				K.fly(loser, V(loser.pos.X + (loser == a and -8 or 8), 0, 6), 0.8)
				local w = loser == a and b or a
				winner(w, 10)
			end },
			{ "THE DANCE BATTLE", function()
				SET.skatepark()
				local list = {}
				for i, nm in ipairs({ "Kickflip Kim", "Rad Rick" }) do list[i] = K.put(K.who("Rider", nm), -4 + (i - 1) * 8, 2, -4 + (i - 1) * 8, -10) end
				fans(4)
				K.open(V(0, 6, -16), V(0, 3, 2))
				K.cap("No scooters today. It's a DANCE BATTLE!", 1.8)
				for _, r in ipairs(list) do
					K.cap(r.name .. " takes the floor!", 1.2)
					for _, g in ipairs({ "cheer", "wave", "handsUp", "shrug" }) do
						r.gesture(g, 0.7)
						K.hop(r, 1, 0.35)
						hold(0.35)
					end
					K.cheer()
				end
				local w = pick(list)
				w.gesture("cheer", 3)
				K.cap("The crowd picks " .. w.name .. "!", 1.8)
				K.points(w.name, 6)
			end },
			{ "THE OBSTACLE COURSE", function()
				SET.skatepark()
				for i = 1, 4 do K.cone(-26 + i * 4, (i % 2 == 0) and 1.5 or -1.5) end
				K.crate(-2, 3)
				K.crate(-2, -3)
				K.ramp(10.5, 0, 3, 7)
				local r = K.rider()
				K.open(V(0, 12, -36), V(4, 2, 0))
				K.cap("The obstacle course! Cones, crates, then the BIG ramp.", 2)
				r.at(-30, 0, 0)
				K.follow(r, V(-4, 7, -22))
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 2, 1)
					r.at(-30 + u * 28, 0, math.sin(u * math.pi * 4) * 2)
					hold(0)
				until u >= 1
				K.jump(r, { from = -2, rampX = 10.5, trick = K.anyTrick() })
				K.cut(V(0, 12, -36), V(4, 2, 0))
				K.cheer()
				local t = rng:NextNumber(8, 12)
				K.cap(r.name .. " finishes in " .. math.floor(t * 10) / 10 .. " seconds!", 1.8)
				K.points(r.name, 8)
			end },
			{ "THE WATER JUMP", function()
				SET.dock(false)
				K.ramp(-3.5, 0, 3, 7, C(150, 110, 70))
				local list = team(3)
				K.open(V(4, 8, -26), V(10, 0, 4))
				K.cap("Off the end of the dock and into the bay! Biggest SPLASH wins!", 2.2)
				local best = list[1]
				for _, r in ipairs(list) do
					K.follow(r, V(-4, 6, -24))
					K.jump(r, { trick = K.anyTrick(), landY = -1.6, bail = true, dist = 14 })
					burst("dust", V(12, -1, 0), 24)
					sfx(SFX.thud, 0.5, 0.5, 1)
					K.cut(V(4, 8, -26), V(10, 0, 4))
					K.cap("SPLASH! " .. rng:NextInteger(4, 10) .. " out of 10!", 1.4)
					r.hide()
					best = pick({ best, r })
				end
				winner(best, 8)
			end },
			{ "LOOP DE LOOP", function()
				SET.skatepark()
				K.ring(V(0, 7, 0), 7, C(80, 160, 255))
				local r = K.rider()
				K.open(V(0, 8, -30), V(0, 6, 0))
				K.cap("The LOOP DE LOOP. Speed is everything.", 1.8)
				r.at(-30, 0, 0)
				K.roll(r, 0, 1.2)
				local fast = rng:NextNumber() < 0.75
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 1, 1)
					local a = u * math.pi * 2 * (fast and 1 or 0.5)
					r.at(math.sin(a) * 6.3, 7 - math.cos(a) * 6.3 - 0.7, 0, ANG(-a, 0, 0))
					hold(0)
				until u >= 1
				if fast then
					K.roll(r, 30, 1)
					K.cheer()
					K.cap("All the way around!", 1.6)
					K.points(r.name, 12)
				else
					r.at(0, 12, 0, ANG(math.pi, 0, 0))
					K.fly(r, V(1, 0, 0), 0.5)
					sfx(SFX.thud, 0.5, 0.8, 1)
					K.cap("Not enough speed... upside down... and DOWN.", 2)
				end
			end },
			{ "THE WALL RIDE", function()
				SET.skatepark()
				K.box(V(30, 10, 1), C(220, 220, 225), CF(0, 5, 5))
				local r = K.rider()
				K.open(V(0, 7, -24), V(0, 5, 4))
				K.cap(r.name .. " is going to ride... the WALL.", 1.8)
				r.at(-30, 0, 2)
				K.roll(r, -14, 1, 2)
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 1.6, 1)
					r.at(-14 + u * 28, math.sin(u * math.pi) * 6, 2 + math.sin(u * math.pi) * 1.8, ANG(0, 0, -math.sin(u * math.pi) * 1.4))
					hold(0)
				until u >= 1
				K.roll(r, 30, 0.8, 2)
				K.cheer()
				K.cap("Gravity is just a suggestion!", 1.6)
				K.points(r.name, 10)
			end },
			{ "THE RAIL GRIND", function()
				SET.skatepark()
				K.box(V(30, 0.3, 0.3), C(200, 200, 210), CF(0, 2.5, 0), METAL)
				for x = -14, 14, 7 do K.box(V(0.3, 2.5, 0.3), C(120, 120, 125), CF(x, 1.25, 0)) end
				local r = K.rider()
				K.open(V(0, 6, -18), V(0, 2, 0))
				K.cap("The 30-foot rail. Grind it all the way.", 1.8)
				r.at(-30, 0, 0)
				K.roll(r, -16, 1)
				K.hop(r, 2.8, 0.3)
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 1.8, 1)
					r.at(-15 + u * 30, 2.6, 0, ANG(0, 0.6, 0))
					if math.random() < 0.6 then burst("spark", V(-15 + u * 30, 2.6, 0), 2) end
					hold(0)
				until u >= 1
				K.roll(r, 30, 0.8)
				K.cheer()
				K.cap("Sparks flying! Butter smooth!", 1.6)
				K.points(r.name, 10)
			end },
			{ "THE BLINDFOLD RUN", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local r = K.rider("Rad Rick")
				K.stick(r, V(1.3, 0.35, 1.3), C(20, 20, 20), CF(0, 0.15, 0))
				K.crate(-14, 2)
				K.open(WIDE, LOOK)
				K.say(r, "I don't need to SEE the ramp. I FEEL the ramp.", "handsUp")
				r.at(-34, 0, 0)
				K.follow(r, V(-4, 6, -20))
				if rng:NextNumber() < 0.5 then
					K.roll(r, -15, 1.4, 0, 0, 1.6)
					K.boom(V(-14, 2, 2))
					r.at(-15, -r.height - r.lift + 0.6, 0, ANG(0, 0, math.rad(90)))
					K.cap("He felt the CRATE.", 1.6)
				else
					K.jump(r, { from = -34, trick = "backflip" })
					K.cut(WIDE, LOOK)
					K.cheer()
					K.cap("WHAT?! Blindfolded BACKFLIP!", 1.8)
					K.points("Rad Rick", 15)
				end
			end },
			{ "BACKWARDS DAY", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local list = team(2)
				K.open(WIDE, LOOK)
				K.cap("It's BACKWARDS DAY! Every rider goes in... backwards.", 2)
				for _, r in ipairs(list) do
					local realAt = r.at
					function r.at(x, y, z, rot, yaw) realAt(x, y, z, (rot or CF()) * ANG(0, math.pi, 0), yaw) end
					K.follow(r, V(-4, 6, -24))
					score(K.jump(r, { trick = pick({ "360", "no-hander" }), bail = rng:NextNumber() < 0.35 }), 7)
					r.hide()
				end
			end },
			{ "COMMERCIAL BREAK", function()
				SET.plaza(false)
				local r = K.rider()
				r.at(-6, 0, -2, nil, 0)
				local can = K.can(V(-4.5, 3.2, -3), 1)
				K.open(V(-6, 5, -12), V(-6, 4, 0))
				K.say(r, "Tired? Slow? Need a BOOST?", "shrug")
				K.say(r, "Try... BLOXY COLA!", "cheer")
				can:Destroy()
				sfx(SFX.blip, 0.6, 2, 0.3)
				shake(0.3, 0.4)
				K.track(function() return r.model:GetPivot().Position end, V(-4, 4, -16))
				r.at(-6, 0, -2)
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 0.8, 1)
					r.at(-6 + u * 120, 0, -2)
					burst("smoke", r.model:GetPivot().Position, 1)
					hold(0)
				until u >= 1
				K.cap("Bloxy Cola: may cause extreme speed. Not for dogs.", 2.2)
			end },
			{ "TRAFFIC WEAVE", function()
				SET.street(false)
				local cars = {}
				for i = 1, 4 do cars[i] = K.car(pick({ "car", "taxi", "van" }), 40 + i * 20, -8 + (i % 2) * 5) end
				local r = K.rider()
				K.open(V(-20, 8, -30), V(0, 2, -6))
				K.cap(r.name .. " vs RUSH HOUR. (Do NOT try this at home.)", 2)
				for _, c in ipairs(cars) do c.driveAsync(c.pos().X - 140, 5) end
				r.at(-50, 0, -6)
				K.follow(r, V(-4, 6, -22))
				local t0 = clock()
				repeat
					local u = math.min((clock() - t0) / 4, 1)
					r.at(-50 + u * 110, 0, -6 + math.sin(u * math.pi * 5) * 3, ANG(0, 0, math.cos(u * math.pi * 5) * 0.35))
					hold(0)
				until u >= 1
				K.cheer()
				K.cap("Not a scratch!", 1.4)
				K.points(r.name, 10)
			end },
			{ "FAIR FREESTYLE", function()
				SET.fair(true)
				K.ramp(-3.5, 0, 3, 7, C(255, 80, 160))
				local list = team(3)
				K.open(WIDE, LOOK)
				K.cap("Live from the Bay Fair! Freestyle under the lights!", 2)
				winner(contest(list))
			end },
			{ "THE GHOST RIDER", function()
				SET.forest(true)
				local r = K.rider()
				local ghost = K.ghost(V(-40, 0.5, 4))
				K.open(V(-20, 6, -20), V(-20, 2, 0))
				K.cap("A night ride through the forest. Nothing could go wrong...", 2)
				r.at(-40, 0, 0)
				task.spawn(function() pcall(K.roll, r, 40, 4, 0) end)
				K.follow(r, V(-4, 6, -20))
				hold(1.4)
				K.glideAsync(ghost, ghost:GetPivot() + V(70, 2, 0), 3)
				K.cap("...wait. What's THAT behind him?!", 1.4)
				sfx(SFX.boo, 0.4, 0.6, 2)
				hold(1.4)
				K.cap("The ghost is FASTER! The ghost wins the race!", 2)
				K.points("The Ghost", 10)
			end },
			{ "THE SEASON FINALE", function()
				SET.stadium(true)
				K.ramp(-3.5, 0, 3, 7, C(255, 200, 40))
				local _, list = K.standings(2)
				local a = K.rider(list[1] and list[1][1] or "Zippy")
				local b = K.rider(list[2] and list[2][1] or "Turbo Tia")
				K.open(WIDE, LOOK)
				K.cap("THE SEASON FINALE! " .. a.name .. " vs " .. b.name .. " for the GOLDEN SCOOTER!", 2.4)
				K.cheer()
				local w = contest({ a, b }, { base = 7.5 })
				w.show()
				w.at(4, 0, -2, nil, 0)
				local trophy = K.box(V(1, 2, 1), C(255, 210, 40), CF(4, 6, -2), NEON)
				K.cut(V(4, 5, -12), V(4, 3, 0))
				w.gesture("cheer", 4)
				burst("spark", V(4, 6, -2), 30)
				K.cap(w.name .. " is the SCOOTER TV CHAMPION!", 2.2)
				story.scootChamp = w.name
				story.scootPoints = {}
				trophy:Destroy()
				K.cap("A new season starts next week!", 1.6)
			end },
		}
		plots.SCOOTER = SCOOTER
		function plots.scooter()
			show.cinematic = true
			show.letterbox.Visible = true
			show.fade.BackgroundTransparency = 0
			story.scootWeek = (story.scootWeek or 0) + 1
			local plot = SCOOTER[deal("scoot", #SCOOTER)]
			show.label.Text = show.label.Text .. "  |  Week " .. story.scootWeek .. ": " .. plot[1]
			titleCard("SCOOTER TV  -  WEEK " .. story.scootWeek, plot[1])
			plot[2]()
			hold(0.6)
			K.cap("Season standings: " .. K.standings(3), 2.2)
			fade(true, 0.6)
		end

		-- BAY NEWS: one day per episode. 50 days, told as running stories (each a few days long);
		-- every day: the studio, a LIVE field report, back to the studio, crime news from CH 3, sign-off
		local HEADLINES = {
			"Local rider hit by car AGAIN. Says he 'looked both ways'.",
			"Bloxy Cola prices soar after scooter speed craze.",
			"Thirsty Terry STILL thirsty. Experts baffled.",
			"Sensei challenges entire town on a Monday. Nobody shows up.",
			"Mystery egg hatches dog named Linus. Town rejoices.",
			"Captain Finn claims he saw THE LIONEL. Again.",
			"S.C.O.O.T. Park record: 9 tricks without a single letter.",
			"Callahan insists ice cream counts as scooter fuel.",
			"Man buys Auto-Petter, dog has never been happier.",
			"Bob welcomes his 1,000th newcomer. Hands out $250 each.",
		}
		local GREET = { "Good evening, Discovery Bay.", "Welcome back to Bay News.", "Good evening. What a day it's been.", "Hello and welcome. I'm Chip Bayson." }
		local SIGNOFF = { "That's the news. Stay safe out there.", "Goodnight, Discovery Bay.", "Watch out for cars. Goodnight!", "See you tomorrow. Same bay time, same bay channel." }
		local WEATHER = { "sunny, 75, with a chance of scooters.", "foggy in the morning, then perfect.", "hot. VERY hot. Drink a Bloxy Cola.", "windy. Hold on to your hats.", "clear skies tonight. Great for UFO spotting." }
		local function rita(x, z) return K.put(K.who("Rider", "Rita Scoops"), x or -7, z or -3) end
		local function live(text) K.cap("LIVE: " .. text, 1.8) end

		local NEWS = {
			-- THE ALIEN INVASION ----------------------------------------------------------------------
			{ "ALIEN INVASION", "Strange lights over the bay last night. Rita Scoops is live at the plaza.", function()
				SET.plaza(true)
				local r = rita()
				local guy = K.put(K.who("Rider", "Witness"), 3, -3)
				local ufo = K.ufo(V(-80, 30, 40))
				K.open(V(-2, 6, -16), V(0, 5, 4))
				live("Discovery Bay Plaza")
				K.say(r, "Rita Scoops here. Folks say they saw lights in the sky.", "point")
				K.say(guy, "Big round thing! Lights all over it! Went WHOOSH!", "handsUp")
				K.say(r, "Like... that one?", "point")
				K.cut(V(0, 4, -14), V(0, 20, 30))
				ufo.move(V(90, 34, 50), 2.6)
				K.cut(V(-2, 6, -16), V(0, 5, 4))
				K.say(guy, "...yeah. Exactly like that one.", "shrug")
			end, "Experts say it was 'probably a plane'. Probably." },
			{ "ALIEN INVASION", "BREAKING: the saucer has LANDED in Bay Park.", function()
				SET.park()
				local r = rita(-14, -4)
				local ufo = K.ufo(V(4, 30, 10))
				K.open(V(-8, 8, -22), V(2, 6, 6))
				live("Bay Park")
				K.say(r, "It's coming down! Right in the middle of the park!", "point")
				ufo.move(V(4, 6, 10), 2.2)
				shake(0.3, 0.5)
				ufo.beam(true)
				local z = K.put(K.alien("Zorp"), 4, 6)
				hold(1)
				ufo.beam(false)
				K.say(z, "Greetings, earthlings. Take me to your leader.", "wave")
				K.say(r, "Our leader? Uh... Bob? He's at the plaza.", "shrug")
				K.say(z, "Also. Do you have... the fizzy red drink?", "point")
			end, "The visitor's name is Zorp. He comes in peace. And he's thirsty." },
			{ "ALIEN INVASION", "The aliens went shopping today. Rita has more.", function()
				SET.plaza(false)
				local r = rita(-20, -4)
				local zs = { K.put(K.alien("Zorp"), -10, 4, -10, 12), K.put(K.alien("Blip"), -6, 4, -6, 12) }
				K.open(V(-12, 7, -16), V(-8, 4, 6))
				live("ShellBlox mini-mart")
				K.say(r, "The aliens have been in ShellBlox for SIX hours.", "point")
				K.all(zs, function(a) a.gesture("carry", 4) end)
				K.say(zs[2], "We will take... ALL the Bloxy Cola.", "carry")
				burst("money", V(-8, 4, 8), 16)
				K.say(zs[1], "We pay in space money. It is VERY shiny.", "cheer")
				K.say(r, "The store owner says space money is 'fine, actually'.", "shrug")
			end, "ShellBlox reports its best day ever." },
			{ "ALIEN INVASION", "And today: the aliens discovered SCOOTERS.", function()
				SET.skatepark()
				K.ramp(-3.5, 0, 3, 7)
				local r = rita(-14, -6)
				local z = K.onScooter(K.alien("Zorp"))
				K.open(V(-6, 8, -28), V(0, 3, 0))
				live("S.C.O.O.T. Park")
				K.say(r, "Zorp is trying a scooter for the first time.", "point")
				z.at(-30, 0, 0)
				K.follow(z, V(-4, 6, -22))
				K.roll(z, -24, 1.4, 0, 0, 0.8)
				K.jump(z, { from = -24, trick = "1080", height = 16, air = 2.6, dist = 18 })
				K.cut(V(-6, 8, -28), V(0, 3, 0))
				K.cheer()
				K.say(r, "...A TEN-EIGHTY. On his first try. I'm speechless.", "facepalm")
			end, "Zorp has been invited to Scooter TV. Riders are 'nervous'." },
			{ "ALIEN INVASION", "Officer Dan tried to give the UFO a parking ticket.", function()
				SET.street(true)
				local ufo = K.ufo(V(10, 9, 10))
				local dan = K.put(K.who("Cop", "Officer Dan"), 4, -2, 10, 10)
				local r = rita(-14, -4)
				K.open(V(-6, 7, -20), V(4, 5, 4))
				live("Main Street, last night")
				K.say(dan, "You can't park a saucer in a loading zone!", "point")
				K.say(dan, "That's a FIFTY dollar fine, mister!", "point")
				ufo.beam(true)
				ufo.model:PivotTo(CF(4, 9, -2) * ANG(0, 0, math.pi / 2))
				dan.gesture("handsUp", 3)
				K.fly(dan, V(4, 20, -2), 2)
				ufo.beam(false)
				K.say(r, "...Officer Dan has been BEAMED UP.", "handsUp")
				ufo.move(V(10, 40, 60), 1.6)
			end, "Police say Officer Dan is 'probably fine'." },
			{ "ALIEN INVASION", "Today, the aliens said goodbye. Live from the beach.", function()
				SET.beach()
				local ufo = K.ufo(V(0, 12, 14))
				local zorp = K.put(K.alien("Zorp"), 6, 2)
				local r = rita(-8, -2)
				K.open(V(0, 7, -20), V(0, 6, 6))
				live("Bay Beach")
				ufo.beam(true)
				local dan = K.put(K.who("Cop", "Officer Dan"), 0, 6)
				hold(0.8)
				ufo.beam(false)
				K.say(dan, "I've been to SPACE. They gave me a snack.", "cheer")
				K.say(r, "Zorp, are you leaving with your friends?", "point")
				K.say(zorp, "No. I am staying. For the Bloxy Cola.", "wave")
				ufo.move(V(-40, 60, 80), 2.4)
				K.say(zorp, "Bye, mom.", "wave")
			end, "Welcome to Discovery Bay, Zorp. Our newest resident." },

			-- THE GIANT EGG ------------------------------------------------------------------------------
			{ "THE GIANT EGG", "A mystery on the beach this morning. A GIANT egg.", function()
				SET.beach()
				K.egg(V(4, 0, 4), 6, C(240, 230, 200))
				local r = rita(-10, -3)
				local man = K.put(K.who("Rider", "Egg Shop Owner"), 12, 0, 4, 4)
				K.open(V(-2, 7, -20), V(2, 4, 4))
				live("Bay Beach")
				K.say(r, "It's eight feet tall. Nobody knows where it came from.", "point")
				K.say(man, "I'll sell it! Biggest egg in the Egg Shop's history!", "cheer")
				K.say(r, "Sir, it might be ALIVE.", "shrug")
				K.say(man, "...Even better. Hatch-it-yourself!", "point")
			end, "Scientists are on their way. With a VERY big frying pan. Just in case." },
			{ "THE GIANT EGG", "The giant egg is... moving. Live from the beach.", function()
				SET.beach()
				local egg = K.egg(V(4, 0, 4), 6, C(240, 230, 200))
				local r = rita(-10, -3)
				K.open(V(-2, 7, -20), V(2, 4, 4))
				live("Bay Beach")
				K.say(r, "Look! It's WOBBLING!", "point")
				for i = 1, 6 do
					egg.CFrame = CF(4, 3.9, 4) * ANG(0, 0, (i % 2 == 0 and 1 or -1) * 0.15)
					sfx(SFX.thud, 0.3, 1.3, 0.4)
					hold(0.3)
				end
				egg.CFrame = CF(4, 3.9, 4)
				K.box(V(0.2, 2.5, 0.1), C(60, 50, 40), CF(4, 4.5, 0.9) * ANG(0, 0, 0.4))
				K.say(r, "And a CRACK! Something is coming out!", "handsUp")
			end, "We'll be watching that egg all night." },
			{ "THE GIANT EGG", "BREAKING: the egg hatched. It's a DINOSAUR.", function()
				SET.plaza(false)
				local r = rita(-24, -4)
				local d = K.dino(V(20, 0, 2), 0.6, C(120, 200, 110))
				d.face(-math.pi / 2)
				local fleeing = { K.put(K.who("Rider", "Shopper"), 0, 0), K.put(K.who("Rider", "Shopper"), 6, 2) }
				K.open(V(-10, 8, -24), V(6, 4, 2))
				live("Discovery Bay Plaza")
				K.say(r, "A BABY DINOSAUR is loose in the plaza!", "handsUp")
				d.roar()
				K.all(fleeing, function(a) K.runAsync(a, -40, -4) end)
				d.face(math.pi / 2)
				d.walk(V(-6, 0, 2), 2.4)
				K.say(r, "It's... it's licking me. It's actually kind of cute.", "shrug")
			end, "The baby dino is 'friendly'. Please do not feed it scooters." },
			{ "THE GIANT EGG", "Discovery Bay has a new pet. Meet NUGGET.", function()
				SET.park()
				local r = rita(-14, -3)
				local d = K.dino(V(8, 0, 6), 0.6, C(120, 200, 110))
				local dog = K.dog(V(-2, 0, 0))
				local bob = K.put(K.who("Rider", "Bob"), -4, 4)
				K.open(V(-4, 8, -22), V(2, 4, 4))
				live("Bay Park")
				K.say(bob, "The town voted. The dino's name is NUGGET!", "cheer")
				K.say(r, "And Nugget has made a friend.", "point")
				dog.bark()
				dog.go(14, 0, 1.2)
				d.walk(V(14, 0, 4), 1.4)
				dog.go(-10, -2, 1.4)
				d.walk(V(-6, 0, 2), 1.6)
				K.say(r, "They're playing FETCH. This is the best day of my career.", "handsUp")
			end, "Nugget will live at Bay Park. Visiting hours: always." },

			-- THE HEATWAVE ---------------------------------------------------------------------------------
			{ "THE HEATWAVE", "It is HOT. Record-breaking hot. Rita is outside.", function()
				SET.desert()
				local r = rita(-6, -3)
				K.ball(18, C(255, 200, 80), V(20, 40, 90), true)
				local man = K.put(K.who("Rider", "Sweaty Steve"), 4, -1)
				K.open(V(-2, 6, -16), V(0, 4, 4))
				live("Discovery Bay, 118 degrees")
				K.say(r, "It is 118 degrees. My microphone is melting.", "facepalm")
				K.say(man, "I tried to fry an egg on the sidewalk. The SIDEWALK fried.", "shrug")
				burst("smoke", V(4, 1, -1), 10)
				K.say(r, "Stay inside, Discovery Bay. Drink water. Or cola.", "point")
			end, "The heat will last 'a few more days'. Sorry." },
			{ "THE HEATWAVE", "The heatwave has caused an ICE CREAM SHORTAGE.", function()
				SET.plaza(false)
				local r = rita(-28, -4)
				local cal = K.put(K.who("Rider", "Callahan"), -10, 6)
				local line = {}
				for i = 1, 5 do line[i] = K.put(K.who("Rider", "Customer"), -10 + i * 4, 1, -10, 6) end
				K.open(V(-14, 7, -18), V(-6, 4, 4))
				live("Callahan's Coffee and Cones")
				K.say(cal, "Sorry folks! We're OUT. All of it. Even pistachio.", "shrug")
				K.all(line, function(a) a.gesture("facepalm", 3) end)
				K.boo()
				K.say(r, "Even PISTACHIO. This is a dark day.", "facepalm")
			end, "Callahan says new ice cream arrives tomorrow. Hold on, Bay." },
			{ "THE HEATWAVE", "Someone fixed the heatwave. With a snow machine. Too much snow.", function()
				SET.snow()
				local r = rita(-6, -3)
				local kids = { K.put(K.who("Rider", "Kid"), 6, 4), K.put(K.who("Rider", "Kid"), 10, 6) }
				K.open(V(-2, 6, -16), V(2, 4, 4))
				live("Discovery Bay. In SNOW.")
				K.say(r, "Yesterday: 118 degrees. Today: THREE FEET OF SNOW.", "handsUp")
				K.all(kids, function(a) a.gesture("cheer", 3) end)
				K.say(kids[1], "SNOW DAY! No school!", "cheer")
				for _ = 1, 3 do burst("dust", V(8, 2, 5), 8) hold(0.3) end
				K.say(r, "The snow machine has been seized by police.", "shrug")
			end, "The snow should melt by Friday. Build your snowmen while you can." },

			-- THE SHARK IN THE BAY -----------------------------------------------------------------------
			{ "SHARK IN THE BAY", "Something has been spotted in the water. Something with a FIN.", function()
				SET.dock(false)
				local r = rita(-8, 0)
				local fin = K.fin(-20, -0.4, 14)
				K.open(V(-4, 6, -12), V(0, 1, 10))
				live("The Marina")
				K.say(r, "Fishermen say they saw a fin. A BIG fin.", "point")
				K.glide(fin, fin.CFrame + V(40, 0, 0), 3, true)
				K.say(r, "...THAT fin! RIGHT THERE!", "handsUp")
			end, "Please stay out of the water until further notice." },
			{ "SHARK IN THE BAY", "The beach is closed. Captain Finn is on patrol.", function()
				SET.beach()
				local finn = K.hat(K.put(K.who("Cop", "Captain Finn"), 4, 2), C(250, 250, 250))
				local r = rita(-8, -3)
				K.fin(10, -0.4, 22)
				K.open(V(-2, 6, -16), V(2, 3, 8))
				live("Bay Beach (closed)")
				K.say(finn, "Thirty years at sea. I've never seen a shark THIS big.", "binoculars", 3)
				K.say(r, "Is it dangerous?", "point")
				K.say(finn, "...It waved at me.", "shrug")
			end, "The beach will stay closed. Sunscreen sales are DOWN." },
			{ "SHARK IN THE BAY", "Captain Finn is going after the shark. With a very big net.", function()
				SET.dock(false)
				local boat = K.boat(-20, 14, C(250, 200, 40))
				local fin = K.fin(30, -0.4, 16)
				local r = rita(-8, 0)
				K.open(V(-4, 8, -14), V(0, 0, 12))
				live("The Marina")
				K.say(r, "Captain Finn is heading out NOW!", "point")
				K.glideAsync(boat, boat:GetPivot() + V(40, 0, 0), 3)
				K.glide(fin, fin.CFrame + V(-20, 0, 0), 2.4)
				burst("dust", V(16, 0, 16), 20)
				sfx(SFX.thud, 0.4, 0.6, 1)
				K.say(r, "He's GOT it! He's got the... it's PULLING HIM!", "handsUp")
				K.glide(boat, boat:GetPivot() + V(60, 0, 20), 2)
			end, "Captain Finn was last seen 'water skiing behind the shark'." },
			{ "SHARK IN THE BAY", "The truth about the shark. You will NOT believe this.", function()
				SET.beach()
				local r = rita(-8, -3)
				local guy = K.put(K.who("Rider", "Gary"), 6, 6)
				local costume = K.fin(6, 4.5, 6)
				local finn = K.hat(K.put(K.who("Cop", "Captain Finn"), 12, 2), C(250, 250, 250))
				K.open(V(-2, 6, -16), V(2, 4, 4))
				live("Bay Beach")
				K.say(finn, "We caught the shark. Its name is... GARY.", "point")
				K.say(guy, "I just wanted the beach to myself, okay?!", "facepalm")
				costume.Transparency = 0.5
				K.say(r, "A man in a fin costume. For a WEEK.", "shrug")
			end, "The beach reopens tomorrow. Gary has been banned from costumes." },

			-- THE ROBOT UPRISING ---------------------------------------------------------------------------
			{ "THE ROBOT UPRISING", "An Auto-Petter has... woken up. Rita is at the lab.", function()
				SET.lab()
				local bot = K.put(K.robot("AUTO-PETTER 3000"), 4, 4)
				local sci = K.hat(K.put(K.who("Rider", "Dr. Bolt"), -6, 2), C(250, 250, 250))
				local r = rita(-14, -3)
				K.open(V(-2, 7, -18), V(0, 4, 4))
				live("Bay Robotics Lab")
				K.say(sci, "It was just supposed to pet dogs. Then it started TALKING.", "facepalm")
				K.say(bot, "I. MUST. PET.", "handsUp")
				K.say(bot, "ALL. THE. THINGS.", "point")
				K.say(r, "...Should we be worried?", "shrug")
			end, "The lab says the robot is 'mostly harmless'." },
			{ "THE ROBOT UPRISING", "The robots are loose. And they are petting EVERYTHING.", function()
				SET.park()
				local bots = { K.put(K.robot("Petter-1"), 0, 4), K.put(K.robot("Petter-2"), 8, 6) }
				local dog = K.dog(V(2, 0, 2))
				local man = K.put(K.who("Rider", "Pedestrian"), 12, 2)
				local r = rita(-12, -3)
				K.open(V(-2, 7, -18), V(2, 4, 4))
				live("Bay Park")
				K.all(bots, function(b) b.gesture("dig", 4) end)
				dog.bark()
				K.say(bots[2], "YOU. HUMAN. YOU WILL BE PETTED.", "point")
				K.say(man, "Oh no. Oh no. ...Oh, that's actually nice.", "shrug")
				K.say(r, "Reports say the town has never been calmer.", "point")
			end, "Crime is DOWN 90 percent. Everyone is too relaxed." },
			{ "THE ROBOT UPRISING", "The Auto-Petter... is running for MAYOR.", function()
				SET.plaza(false)
				K.box(V(10, 1, 5), C(40, 90, 200), CF(0, 0.5, 6))
				local bot = K.put(K.robot("AUTO-PETTER 3000"), 0, 6, 0, -10, 1)
				local crowd = {}
				for i = 1, 4 do crowd[i] = K.put(K.who("Rider", "Voter"), -9 + i * 4, -2, 0, 6) end
				K.open(V(0, 7, -20), V(0, 4, 4))
				live("Campaign rally")
				K.say(bot, "VOTE FOR ME. EVERY DOG GETS A PET. EVERY DAY.", "handsUp")
				K.all(crowd, function(a) a.gesture("cheer", 2) end)
				K.cheer()
				K.say(bot, "ALSO. FREE BATTERIES.", "point")
			end, "Polls show the robot in FIRST place." },
			{ "THE ROBOT UPRISING", "The robot uprising is over. Here's what happened.", function()
				SET.plaza(false)
				local bot = K.put(K.robot("AUTO-PETTER 3000"), 2, 4)
				local r = rita(-8, -3)
				K.open(V(-2, 6, -16), V(0, 4, 4))
				live("Discovery Bay Plaza")
				K.say(bot, "I. WILL. PET. FOREV-", "handsUp")
				sfx(SFX.thud, 0.4, 0.4, 1)
				bot.place(bot.pos, bot.pos + V(0, -1, -10))
				K.say(r, "...It ran out of battery.", "shrug")
				K.say(r, "Somebody forgot to charge it. That's the whole story.", "facepalm")
			end, "The Auto-Petter will be charged, and put back on dog duty." },

			-- THE MAYOR RACE -------------------------------------------------------------------------------
			{ "THE MAYOR RACE", "Election season! Meet the candidates for Mayor of Discovery Bay.", function()
				SET.plaza(false)
				local bob = K.put(K.who("Rider", "Bob"), -6, 4)
				local terry = K.put(K.who("Rider", "Thirsty Terry"), 0, 4)
				local dog = K.dog(V(6, 0, 4), C(250, 250, 250))
				K.open(V(0, 6, -16), V(0, 3, 4))
				live("Discovery Bay Plaza")
				K.say(bob, "I'm Bob. I'll give every new resident 250 dollars!", "wave")
				K.say(terry, "I'm Terry. Free drinks. For ME.", "point")
				dog.bark()
				K.cap("And Sir Barks-a-Lot, the dog, who says: 'woof'.", 2)
			end, "The election is in four days." },
			{ "THE MAYOR RACE", "Tonight: the big MAYOR DEBATE.", function()
				SET.room(C(60, 60, 80), C(40, 60, 120))
				for _, x in ipairs({ -8, 0, 8 }) do K.box(V(2, 3.6, 1.2), C(200, 200, 210), CF(x, 1.8, 2)) end
				local bob = K.put(K.who("Rider", "Bob"), -8, 4)
				local terry = K.put(K.who("Rider", "Thirsty Terry"), 0, 4)
				local dog = K.dog(V(8, 3.6, 3), C(250, 250, 250))
				K.open(V(0, 7, -18), V(0, 4, 4))
				K.cap("THE DEBATE. Question one: what will you do for the town?", 2)
				K.say(bob, "Clean streets! Safe scooters! Fair prices!", "point")
				K.say(terry, "I will drink... everything.", "shrug")
				dog.bark()
				dog.bark()
				K.cheer()
				K.cap("The crowd LOVES the dog's answer.", 1.8)
			end, "Experts say the dog 'won the debate'." },
			{ "THE MAYOR RACE", "SCANDAL in the mayor race!", function()
				SET.plaza(true)
				local terry = K.put(K.who("Rider", "Thirsty Terry"), 4, 6, 4, 12)
				for i = 0, 5 do K.can(V(-2 + i * 1.6, 0, 8), 1.6) end
				local r = rita(-10, -3)
				K.open(V(-2, 6, -16), V(2, 3, 6))
				live("Behind ShellBlox, midnight")
				K.say(r, "Candidate Terry has been caught... drinking the town's ENTIRE cola supply.", "point")
				terry.face(V(-10, 0, -3))
				K.say(terry, "I was THIRSTY, okay?!", "facepalm")
			end, "Terry's poll numbers are 'flat'. Like his cola." },
			{ "THE MAYOR RACE", "It's ELECTION DAY. The lines are LONG.", function()
				SET.plaza(false)
				K.box(V(3, 3, 3), C(240, 240, 240), CF(10, 1.5, 6))
				local voters = {}
				for i = 1, 6 do voters[i] = K.put(K.who("Rider", "Voter"), -16 + i * 4, 4, 30, 4) end
				local r = rita(-20, -3)
				K.open(V(-6, 7, -18), V(0, 3, 4))
				live("Polling station")
				K.say(r, "The whole town came out to vote!", "point")
				K.say(voters[1], "I voted for the dog. He's a good boy.", "wave")
				K.say(voters[3], "I voted for the robot. Wait, he's not running?", "shrug")
				K.say(r, "Results tomorrow!", "point")
			end, "Polls close at midnight." },
			{ "THE MAYOR RACE", "The votes are counted. The NEW MAYOR of Discovery Bay is...", function()
				SET.plaza(false)
				K.box(V(10, 1, 5), C(200, 40, 50), CF(0, 0.5, 6))
				local dog = K.dog(V(0, 1, 6), C(250, 250, 250))
				local bob = K.put(K.who("Rider", "Bob"), -8, 2, 0, 6)
				K.open(V(0, 6, -16), V(0, 3, 4))
				K.cap("...SIR BARKS-A-LOT! The DOG wins!", 2)
				burst("spark", V(0, 6, 6), 30)
				K.cheer()
				dog.bark()
				K.say(bob, "Congratulations, Mayor Barks. You'll do great.", "wave")
				dog.bark()
				K.cap("The Mayor's first law: belly rubs for everyone.", 2)
			end, "Mayor Barks-a-Lot takes office tomorrow. Bring treats." },

			-- THE METEOR -----------------------------------------------------------------------------------
			{ "THE METEOR", "Scientists say a METEOR is heading toward the bay.", function()
				SET.lab()
				local sci = K.hat(K.put(K.who("Rider", "Dr. Bolt"), 2, 4), C(250, 250, 250))
				local r = rita(-10, -3)
				K.box(V(8, 5, 0.3), C(10, 10, 20), CF(2, 7, 11.3))
				K.ball(1.2, C(255, 140, 60), V(4, 8, 11), true)
				K.open(V(-2, 7, -16), V(2, 5, 6))
				live("Bay Science Lab")
				K.say(sci, "It's small. It's fast. It lands... THURSDAY.", "point")
				K.say(r, "Should people panic?", "shrug")
				K.say(sci, "Only a little. Wear a hat.", "facepalm")
			end, "Bay Hardware has sold out of hats." },
			{ "THE METEOR", "Tonight the whole town is watching the skies.", function()
				SET.rooftop()
				local watchers = { K.put(K.who("Rider", "Stargazer"), -4, 4, -4, 40), K.put(K.who("Rider", "Stargazer"), 2, 4, 2, 40) }
				local r = rita(-12, -2)
				local rock = K.ball(2, C(255, 160, 60), V(-60, 50, 70), true)
				K.open(V(-4, 5, -14), V(0, 12, 30))
				live("Rooftop, downtown")
				K.all(watchers, function(a) a.gesture("binoculars", 4) end)
				K.say(r, "Everyone's looking up. Waiting.", "point")
				K.glide(rock, CF(60, 30, 70), 3, true)
				K.say(watchers[1], "THERE IT IS!", "point")
			end, "Impact is expected tomorrow at Bay Park." },
			{ "THE METEOR", "The meteor has landed. And it's... it's...", function()
				SET.park()
				local r = rita(-12, -3)
				local rock = K.ball(5, C(255, 140, 60), V(10, 60, 10), true)
				K.open(V(-2, 7, -20), V(6, 4, 8))
				live("Bay Park")
				K.say(r, "Here it comes!", "handsUp")
				K.glide(rock, CF(10, 2, 10), 1.4, true)
				K.boom(V(10, 2, 10), true)
				rock:Destroy()
				K.can(V(10, 0, 10), 7)
				K.say(r, "...It's a GIANT CAN OF BLOXY COLA.", "facepalm")
				local terry = K.put(K.who("Rider", "Thirsty Terry"), 20, 4, 10, 10)
				K.say(terry, "I'll handle this.", "point")
			end, "Scientists confirm the meteor is 'refreshing'." },

			-- THE MARINA GHOST ------------------------------------------------------------------------------
			{ "THE MARINA GHOST", "Spooky sightings at the marina. Rita went to look. At NIGHT.", function()
				SET.dock(true)
				local r = rita(-8, 0)
				local ghost = K.ghost(V(20, 0, 2))
				for _, p in ipairs(ghost:GetChildren()) do p.Transparency = 1 end
				K.open(V(-4, 6, -12), V(0, 3, 4))
				live("The Marina, 11:58 PM")
				K.say(r, "People say a ghost rides the dock at midnight. That's silly.", "shrug")
				for _, p in ipairs(ghost:GetChildren()) do p.Transparency = p.Name == "Part" and 0.35 or 0 end
				sfx(SFX.boo, 0.4, 0.6, 2)
				K.glide(ghost, ghost:GetPivot() + V(-12, 0, 0), 1.4)
				K.say(r, "AAAAAAH!", "handsUp")
				K.runAsync(r, -40, 0)
			end, "Rita is fine. She'd like to stop doing night reports." },
			{ "THE MARINA GHOST", "The Bay Ghost Hunters are on the case.", function()
				SET.dock(true)
				local hunters = { K.hat(K.put(K.who("Rider", "Ghost Hunter Gus"), -2, 0), C(40, 40, 40)), K.hat(K.put(K.who("Rider", "Ghost Hunter Gail"), 3, 0), C(40, 40, 40)) }
				local meter = K.box(V(0.6, 0.6, 0.2), C(60, 255, 120), CF(-1, 3, -1.2), NEON)
				K.open(V(0, 6, -12), V(0, 3, 2))
				live("The Marina")
				K.say(hunters[1], "The ghost meter is going CRAZY.", "point")
				for _ = 1, 5 do meter.Color = Color3.fromHSV(rng:NextNumber(), 1, 1) sfx(SFX.blip, 0.5, 2, 0.2) hold(0.2) end
				K.say(hunters[2], "Ghost! Show yourself!", "handsUp")
				local scoot = K.rider("???")
				scoot.at(-40, 0, 2)
				K.paint(scoot, C(250, 250, 255), C(250, 250, 255))
				K.roll(scoot, 40, 1.4, 2)
				K.say(hunters[1], "...Was that ghost on a SCOOTER?", "shrug")
			end, "Ghost hunters say the ghost was 'going about 30'." },
			{ "THE MARINA GHOST", "We know who the ghost is. Rita has the exclusive.", function()
				SET.dock(false)
				local kid = K.put(K.rider("Lil Wheelie"), 4, 0)
				kid.at(4, 0, 0, nil, 0)
				local sheet = K.box(V(3, 4, 3), C(250, 250, 255), CF(9, 2, 1))
				sheet.Transparency = 0.3
				local r = rita(-6, 0)
				K.open(V(-2, 6, -12), V(2, 3, 2))
				live("The Marina")
				K.say(r, "The marina ghost was... Lil Wheelie. In a bedsheet.", "point")
				K.say(kid, "I was practicing night riding! The sheet kept me warm!", "shrug")
				K.say(r, "Case closed.", "wave")
			end, "Lil Wheelie has promised to wear a helmet. And no sheets." },

			-- BIGFOOT ---------------------------------------------------------------------------------------
			{ "BIGFOOT", "A blurry photo is causing a stir. Is BIGFOOT in Discovery Bay?", function()
				SET.forest(false)
				local r = rita(-8, -3)
				local bf = K.put(K.bigfoot(), -40, 30, 40, 30)
				K.open(V(-2, 6, -14), V(0, 4, 20))
				live("Bay Woods")
				K.say(r, "Hikers say they saw something big. And hairy.", "point")
				K.walkAsync(bf, 40, 30, 6)
				hold(1.6)
				K.say(r, "Did you... did you SEE that?!", "handsUp")
				K.cut(V(-2, 6, -14), V(0, 4, 20))
				K.say(r, "Camera guy, tell me you got that.", "shrug")
			end, "Our camera guy did not get that." },
			{ "BIGFOOT", "A trail camera caught Bigfoot. Eating snacks.", function()
				SET.forest(true)
				K.crate(0, 6, 2)
				local bf = K.put(K.bigfoot(), 4, 8, 0, 6)
				K.open(V(-2, 5, -10), V(2, 4, 6))
				K.cap("TRAIL CAM - 3:14 AM", 1.6)
				bf.gesture("carry", 3)
				burst("food", V(1, 3, 6), 16)
				K.say(bf, "Mmmf. Crunchy.", "cheer")
				hold(0.6)
				bf.face(V(-2, 0, -10))
				K.say(bf, "...Is that a camera?", "point")
				fade(true, 0.2)
			end, "Bigfoot ate an entire box of Bay Snacks. Flavor: 'Cool Ranch'." },
			{ "BIGFOOT", "Bigfoot walked into Bloxy Mart today. Rita got an interview.", function()
				SET.plaza(false)
				local bf = K.put(K.bigfoot(), 4, 2)
				local r = rita(-6, -3)
				K.open(V(-2, 7, -18), V(0, 5, 4))
				live("Bloxy Mart")
				K.say(r, "Mr. Bigfoot! Why come to town now?", "point")
				K.say(bf, "Needed sunscreen. Very hairy. Burn easy.", "shrug")
				K.say(r, "Will you be staying?", "point")
				K.say(bf, "No. Too many scooters. Bye.", "wave")
				K.walk(bf, 40, 2, 7)
			end, "Bigfoot paid in exact change. Very polite." },

			-- THE TIME TRAVELER -----------------------------------------------------------------------------
			{ "THE TIME TRAVELER", "A man appeared out of thin air on Main Street. He says he's from the FUTURE.", function()
				SET.street(false)
				local r = rita(-10, -3)
				K.open(V(-2, 6, -16), V(2, 4, 2))
				live("Main Street")
				K.say(r, "Witnesses say there was a flash, and then-", "point")
				flash(C(160, 220, 255), 1)
				shake(0.4, 0.6)
				local t = K.put(K.paint(K.who("Rider", "Zeke from 2099"), C(200, 210, 230), C(234, 184, 146)), 4, -2)
				burst("spark", V(4, 3, -2), 20)
				K.say(t, "What year is it?! QUICK!", "handsUp")
				K.say(r, "It's... now?", "shrug")
				K.say(t, "Oh no. I'm too EARLY.", "facepalm")
			end, "The man says his name is Zeke. He is 'from 2099'." },
			{ "THE TIME TRAVELER", "Zeke from the future has WARNINGS for us.", function()
				SET.studio()
				local zeke = K.put(K.paint(K.who("Rider", "Zeke from 2099"), C(200, 210, 230), C(234, 184, 146)), 3, 1)
				local r = rita(-3, 1)
				setShot({ cf = CFrame.lookAt(V(0, 5.2, -12), V(0, 4.6, 0)), speed = 3 }, true)
				K.open()
				K.say(r, "Zeke, what does the future hold?", "point")
				K.say(zeke, "Warning one: do NOT eat the blue pudding.", "point")
				K.say(zeke, "Warning two: in 2087, scooters can FLY. It's awful.", "facepalm")
				K.say(zeke, "Warning three: Thirsty Terry is STILL thirsty.", "shrug")
			end, "We will be avoiding the blue pudding." },
			{ "THE TIME TRAVELER", "Zeke is going home. Back to the future.", function()
				SET.park()
				local zeke = K.put(K.paint(K.who("Rider", "Zeke from 2099"), C(200, 210, 230), C(234, 184, 146)), 2, 4)
				local r = rita(-8, -3)
				K.open(V(-2, 6, -16), V(0, 4, 4))
				live("Bay Park")
				K.say(zeke, "Thanks for having me, this year. Your snacks are amazing.", "wave")
				K.say(r, "Any last words for Discovery Bay?", "point")
				K.say(zeke, "Yes. Buy Bloxy Cola stock. Trust me.", "point")
				flash(C(160, 220, 255), 1)
				burst("spark", zeke.model:GetPivot().Position, 24)
				zeke.hide()
				K.say(r, "...He's gone. Wow.", "shrug")
			end, "He left a hover-scooter behind. Police say 'do not touch it'." },

			-- THE BAY FAIR ----------------------------------------------------------------------------------
			{ "THE BAY FAIR", "The BAY FAIR is in town! Rita is on the midway.", function()
				SET.fair(false)
				local r = rita(-8, -3)
				local kids = { K.put(K.who("Rider", "Fairgoer"), 4, 6), K.put(K.who("Rider", "Fairgoer"), 8, 4) }
				K.open(V(-2, 7, -18), V(4, 6, 10))
				live("The Bay Fair")
				K.say(r, "Rides, games, and FRIED EVERYTHING.", "cheer")
				K.all(kids, function(a) a.gesture("cheer", 3) end)
				K.say(kids[1], "I just ate a fried Bloxy Cola!", "cheer")
				K.say(r, "...How?", "shrug")
			end, "The fair runs all week." },
			{ "THE BAY FAIR", "The annual PIE EATING CONTEST.", function()
				SET.fair(false)
				K.table(0, 4, C(250, 250, 250))
				local eaters = {}
				for i, nm in ipairs({ "Big Wheel Bo", "Thirsty Terry", "Nugget's Owner" }) do eaters[i] = K.put(K.who("Rider", nm), -4 + (i - 1) * 4, 2, -4 + (i - 1) * 4, 6) end
				K.open(V(0, 6, -14), V(0, 3, 4))
				K.cap("PIE EATING CONTEST! Ready... EAT!", 1.6)
				for _ = 1, 5 do
					burst("food", V(rng:NextNumber(-4, 4), 3.2, 4), 8)
					sfx(SFX.blip, 0.4, 0.5, 0.2)
					hold(0.4)
				end
				local w = pick(eaters)
				w.gesture("cheer", 2)
				K.cheer()
				K.cap(w.name .. " wins with 14 pies!", 1.8)
			end, "Bay Hospital reports 'several tummy aches'." },
			{ "THE BAY FAIR", "Officer Dan is STUCK at the top of the Ferris wheel.", function()
				SET.fair(false)
				local dan = K.put(K.who("Cop", "Officer Dan"), 18, 24, 18, 14, 24)
				local r = rita(-6, -3)
				K.open(V(4, 10, -18), V(14, 16, 20))
				live("The Bay Fair")
				K.say(r, "The Ferris wheel stopped. Officer Dan has been up there for 3 hours.", "point")
				K.say(dan, "I'M FINE! I CAN SEE MY HOUSE!", "wave")
				K.say(dan, "...CAN SOMEBODY SEND UP A SANDWICH?", "handsUp")
			end, "Dan was rescued. He says the view was 'honestly great'." },
			{ "THE BAY FAIR", "The fair ends tonight. With FIREWORKS.", function()
				SET.fair(true)
				local crowd = {}
				for i = 1, 4 do crowd[i] = K.put(K.who("Rider", "Fairgoer"), -12 + i * 5, -2, -12 + i * 5, 30) end
				K.open(V(0, 4, -16), V(0, 16, 30))
				live("The Bay Fair")
				for _ = 1, 6 do
					local p = V(rng:NextNumber(-30, 30), rng:NextNumber(20, 34), 40)
					burst("spark", p, 26)
					flash(Color3.fromHSV(rng:NextNumber(), 0.6, 1), 0.25)
					sfx(SFX.thud, 0.4, rng:NextNumber(0.6, 0.9), 1)
					hold(0.5)
				end
				K.all(crowd, function(a) a.gesture("cheer", 3) end)
				K.cheer()
				K.cap("Ooooooh. Aaaaaah.", 1.6)
			end, "See you next year, Bay Fair!" },

			-- THE BLACKOUT ----------------------------------------------------------------------------------
			{ "THE BLACKOUT", "The whole town lost power last night.", function()
				SET.street(true)
				for _, p in ipairs(show.world:GetChildren()) do
					if p:IsA("BasePart") and p.Material == NEON then p.Color = C(30, 30, 30) end
				end
				local r = rita(-6, -3)
				local man = K.put(K.who("Rider", "Neighbor"), 4, -2)
				local torch = K.box(V(0.4, 0.4, 1), C(255, 250, 200), CF(4, 3, -3), NEON)
				K.open(V(-2, 6, -14), V(0, 4, 2))
				live("Main Street, in the dark")
				K.say(r, "No lights. No TV. No Bloxy Cola machines.", "shrug")
				K.say(man, "My Auto-Petter stopped! My dog is SO confused!", "handsUp")
				torch.Transparency = 1
				K.say(r, "Please stay calm, Discovery Bay.", "point")
			end, "Power company says a seagull 'sat on the wrong thing'." },
			{ "THE BLACKOUT", "Something beautiful happened during the blackout.", function()
				SET.park()
				K.sky(C(6, 8, 24))
				K.stars(80)
				local folks = {}
				for i = 1, 4 do folks[i] = K.put(K.who("Rider", "Neighbor"), -12 + i * 5, 4, -12 + i * 5, 40) end
				local r = rita(-16, -3)
				K.open(V(-4, 4, -14), V(0, 14, 40))
				live("Bay Park")
				K.say(r, "With the lights out... the whole town saw the stars.", "point")
				K.all(folks, function(a) a.gesture("point", 3) end)
				K.say(folks[2], "I've never seen so many!", "point")
				K.say(r, "Power is back. But some folks want to keep the lights off.", "wave")
			end, "The town will hold a 'Lights Out Night' every month." },

			-- THE PIZZA PANIC -------------------------------------------------------------------------------
			{ "THE PIZZA PANIC", "Discovery Bay has run out of PIZZA.", function()
				SET.plaza(false)
				local line = {}
				for i = 1, 6 do line[i] = K.put(K.who("Rider", "Hungry"), -20 + i * 4, 2, -20, 12) end
				local chef = K.hat(K.put(K.who("Rider", "Pizza Pete"), -22, 8), C(250, 250, 250), true)
				local r = rita(-28, -3)
				K.open(V(-12, 7, -18), V(-10, 4, 4))
				live("Bay Pizza")
				K.say(chef, "No cheese. No dough. No PIZZA.", "facepalm")
				K.all(line, function(a) a.gesture("facepalm", 3) end)
				K.boo()
				K.say(r, "The line is now three blocks long.", "point")
			end, "The cheese truck is 'on its way'." },
			{ "THE PIZZA PANIC", "The cheese truck has ARRIVED.", function()
				SET.plaza(false)
				local truck = K.car("pizza", -60, -8)
				local crowd = {}
				for i = 1, 5 do crowd[i] = K.put(K.who("Rider", "Hungry"), -16 + i * 5, 2) end
				local r = rita(-24, -3)
				K.open(V(-10, 8, -24), V(-6, 3, -2))
				live("Bay Pizza")
				K.track(truck.pos, V(-4, 6, -24), V(6, 0, 0))
				truck.drive(-6, 2.4)
				K.cut(V(-10, 8, -24), V(-6, 3, -2))
				K.all(crowd, function(a) a.gesture("cheer", 3) end)
				K.cheer()
				burst("food", V(-6, 6, -8), 24)
				K.say(r, "PIZZA IS SAVED!", "cheer")
			end, "Everyone in town ate pizza for dinner. All of them." },

			-- THE TREASURE MAP ------------------------------------------------------------------------------
			{ "THE TREASURE MAP", "A bottle washed up on the beach. With a MAP inside.", function()
				SET.beach()
				local finn = K.hat(K.put(K.who("Cop", "Captain Finn"), 4, 2), C(250, 250, 250))
				local r = rita(-8, -3)
				K.box(V(0.6, 1.4, 0.6), C(120, 200, 140), CF(2, 0.4, 0) * ANG(0, 0, 1.4), Enum.Material.Glass)
				K.open(V(-2, 6, -16), V(2, 3, 2))
				live("Bay Beach")
				K.say(finn, "A pirate map! I'd know one anywhere!", "carry")
				K.say(r, "Where does it lead?", "point")
				K.say(finn, "Right here. To... this beach. X marks the spot.", "point")
			end, "The digging starts tomorrow." },
			{ "THE TREASURE MAP", "The whole town is digging for treasure.", function()
				SET.beach()
				local diggers = {}
				for i = 1, 4 do diggers[i] = K.put(K.who("Rider", "Digger"), -12 + i * 6, 4) end
				local r = rita(-18, -3)
				K.open(V(-4, 7, -18), V(0, 2, 4))
				live("Bay Beach")
				K.all(diggers, function(a) a.gesture("dig", 4) end)
				for _ = 1, 4 do burst("dust", V(rng:NextNumber(-8, 8), 0.5, 4), 8) hold(0.4) end
				K.say(diggers[2], "I found a shoe!", "cheer")
				K.say(diggers[3], "I found ANOTHER shoe!", "cheer")
				K.say(r, "No treasure yet. But lots of shoes.", "shrug")
			end, "Shoe count: 47. Treasure count: zero." },
			{ "THE TREASURE MAP", "Diggers say a PIRATE GHOST appeared on the beach.", function()
				SET.beach()
				K.sky(K.NIGHT)
				K.stars(30)
				local ghost = K.ghost(V(6, 0.5, 4))
				K.box(V(2.6, 0.5, 2.6), C(20, 20, 20), CF(6, 4.4, 4))
				local r = rita(-8, -3)
				K.open(V(-2, 6, -16), V(2, 3, 4))
				live("Bay Beach, midnight")
				sfx(SFX.boo, 0.4, 0.5, 2)
				K.cap("ARRR... who be diggin' on me beach?", 2.2)
				K.say(r, "Mr. Pirate Ghost! Is the treasure real?", "point")
				K.cap("ARRR. It be under the BIG palm tree. Now leave me be.", 2.4)
				K.glide(ghost, ghost:GetPivot() + V(0, 10, 20), 1.6)
			end, "Tomorrow: the big palm tree." },
			{ "THE TREASURE MAP", "They found the treasure! Live from the beach.", function()
				SET.beach()
				K.chest(-28, 6)
				local finn = K.hat(K.put(K.who("Cop", "Captain Finn"), -24, 3, -28, 6), C(250, 250, 250))
				local r = rita(-20, -3)
				K.open(V(-24, 6, -12), V(-27, 2, 5))
				live("Bay Beach, under the big palm")
				K.say(finn, "Here it is! Open it up!", "point")
				burst("spark", V(-28, 2.5, 6), 20)
				K.say(finn, "It's... COUPONS. 'Buy one Bloxy Cola, get one free.'", "facepalm")
				K.say(r, "From 1802?", "shrug")
				K.say(finn, "...Do you think they still work?", "shrug")
			end, "ShellBlox says the coupons DO still work. Amazing." },
		}
		plots.NEWS = NEWS
		local function studio()
			K.clear()
			SET.studio()
			local a = K.put(K.who("Anchor", "Chip Bayson"), 0, 1)
			setShot({ cf = CFrame.lookAt(V(0, 5.2, -11), V(0, 4.6, 0)), speed = 3 }, true)
			show.ticker.Visible = true
			show.letterbox.Visible = false
			return a
		end
		function plots.newsDay(d)
			local anchor = studio()
			K.open()
			K.say(anchor, pick(GREET) .. " It's day " .. story.newsDay .. ".", nil, 2)
			K.say(anchor, d[2], "point")
			-- cut to the field
			fade(true, 0.35)
			K.clear()
			show.ticker.Visible = false
			show.letterbox.Visible = true
			d[3]()
			hold(0.5)
			fade(true, 0.35)
			anchor = studio()
			K.open()
			K.say(anchor, d[4])
			if story.news and story.news ~= story.newsShown then -- whatever the gang did last on CH 3
				story.newsShown = story.news
				K.say(anchor, "In crime news: " .. story.news, "point")
			end
			if rng:NextNumber() < 0.45 then K.say(anchor, "Tomorrow's weather: " .. pick(WEATHER)) end
			K.say(anchor, pick(SIGNOFF), "wave")
		end
		function plots.news()
			show.cinematic = true
			show.fade.BackgroundTransparency = 0
			story.newsDay = (story.newsDay or 0) + 1
			local d = NEWS[(story.newsDay - 1) % #NEWS + 1]
			show.label.Text = show.label.Text .. "  |  Day " .. story.newsDay
			show.ticker.Text = "BREAKING: " .. d[1] .. "   +++   " .. table.concat(HEADLINES, "   +++   ")
			titleCard("BAY NEWS  -  DAY " .. story.newsDay, d[1])
			plots.newsDay(d)
			hold(0.4)
			fade(true, 0.5)
		end
		return plots
	end)()

	CHANNELS = {
		{ name = "CH 3 - BAY HEIST", episode = heistSaga },
		{ name = "CH 7 - SCOOTER TV", episode = function() PLOTS.scooter() end },
		{ name = "CH 9 - BAY NEWS", episode = function() PLOTS.news() end },
	}

	local function stopShow()
		if not show then return end
		show.dead = true
		if show.director and show.director ~= coroutine.running() then pcall(task.cancel, show.director) end
		if show.music then show.music:Destroy() end
		if show.voice then show.voice:Destroy() end
		show.gui:Destroy()
		if show.screenWas then show.screen.Material, show.screen.Color = show.screenWas[1], show.screenWas[2] end
		show = nil
	end
	local function startShow(screen, channel)
		stopShow()
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TVShow"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		-- (a ViewportFrame only draws on a part when its SurfaceGui lives in PlayerGui, aimed at the part)
		gui.Adornee = screen
		gui.Parent = plr:WaitForChild("PlayerGui")
		local vf = Instance.new("ViewportFrame")
		vf.Size = UDim2.fromScale(1, 1)
		vf.Ambient = Color3.fromRGB(170, 170, 180)
		vf.LightColor = Color3.new(1, 1, 1)
		vf.LightDirection = Vector3.new(-0.4, -1, 0.6)
		vf.Parent = gui
		local world = Instance.new("WorldModel") -- lets the avatars animate inside the screen
		world.Parent = vf
		-- all the text sits in an overlay laid out at PPS_BASE and scaled up with the resolution,
		-- so it stays the same size on the screen and just gets sharper
		local overlay = Instance.new("Frame")
		overlay.BackgroundTransparency = 1
		overlay.ZIndex = 3
		overlay.Parent = gui
		local overlayScale = Instance.new("UIScale")
		overlayScale.Parent = overlay
		local cam = Instance.new("Camera")
		cam.FieldOfView = 50
		cam.Parent = vf
		vf.CurrentCamera = cam
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 0.4
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.Position = UDim2.fromOffset(8, 8)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 22)
		label.Font = Enum.Font.PermanentMarker
		label.TextSize = 14
		label.TextColor3 = Color3.new(1, 1, 1)
		label.RichText = true
		label.ZIndex = 4
		label.Parent = overlay
		local cap = Instance.new("TextLabel")
		cap.AnchorPoint = Vector2.new(0.5, 1)
		cap.Position = UDim2.new(0.5, 0, 1, -30)
		cap.Size = UDim2.new(0.92, 0, 0, 30)
		cap.BackgroundColor3 = Color3.new(0, 0, 0)
		cap.BackgroundTransparency = 0.35
		cap.Font = Enum.Font.PermanentMarker
		cap.TextSize = 15
		cap.TextWrapped = true
		cap.TextColor3 = Color3.new(1, 1, 1)
		cap.Visible = false
		cap.ZIndex = 4
		cap.Parent = overlay
		local ticker = Instance.new("TextLabel")
		ticker.AnchorPoint = Vector2.new(0, 1)
		ticker.Position = UDim2.fromScale(1, 1)
		ticker.Size = UDim2.new(4, 0, 0, 22)
		ticker.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
		ticker.Font = Enum.Font.PermanentMarker
		ticker.TextSize = 14
		ticker.TextXAlignment = Enum.TextXAlignment.Left
		ticker.TextColor3 = Color3.new(1, 1, 1)
		ticker.Visible = false
		ticker.ZIndex = 4
		ticker.Parent = overlay
		local function layer(z, color, transparency)
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = color
			f.BackgroundTransparency = transparency
			f.ZIndex = z
			f.Parent = overlay
			return f
		end
		-- cinematic black bars (the saga turns them on)
		local letterbox = Instance.new("Frame")
		letterbox.BackgroundTransparency = 1
		letterbox.Size = UDim2.fromScale(1, 1)
		letterbox.Visible = false
		letterbox.ZIndex = 6
		letterbox.Parent = overlay
		for _, y in ipairs({ 0, 1 }) do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0, y)
			bar.Position = UDim2.fromScale(0, y)
			bar.Size = UDim2.fromScale(1, 0.09)
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.BorderSizePixel = 0
			bar.ZIndex = 6
			bar.Parent = letterbox
		end
		local flashLayer = layer(7, Color3.new(1, 1, 1), 1)
		flashLayer.Size = UDim2.fromScale(1, 1)
		local fadeLayer = layer(8, Color3.new(0, 0, 0), 1)
		fadeLayer.Size = UDim2.fromScale(1, 1)
		-- the episode title card (over the black)
		local title = Instance.new("Frame")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 1)
		title.Visible = false
		title.ZIndex = 9
		title.Parent = overlay
		local titleScale = Instance.new("UIScale")
		titleScale.Parent = title
		local titleTop = Instance.new("TextLabel")
		titleTop.BackgroundTransparency = 1
		titleTop.Position = UDim2.fromScale(0, 0.3)
		titleTop.Size = UDim2.new(1, 0, 0, 20)
		titleTop.Font = Enum.Font.PermanentMarker
		titleTop.TextSize = 16
		titleTop.TextColor3 = Color3.fromRGB(255, 170, 60)
		titleTop.ZIndex = 9
		titleTop.Parent = title
		local titleBig = Instance.new("TextLabel")
		titleBig.BackgroundTransparency = 1
		titleBig.Position = UDim2.fromScale(0, 0.42)
		titleBig.Size = UDim2.new(1, 0, 0, 40)
		titleBig.Font = Enum.Font.PermanentMarker
		titleBig.TextSize = 34
		titleBig.TextColor3 = Color3.new(1, 1, 1)
		titleBig.ZIndex = 9
		titleBig.Parent = title
		local s = {
			screen = screen, gui = gui, vf = vf, world = world, cam = cam, label = label, caption = cap,
			ticker = ticker, bubbles = {}, channel = channel, overlay = overlay,
			letterbox = letterbox, flash = flashLayer, fade = fadeLayer, title = title, titleScale = titleScale,
			titleTop = titleTop, titleBig = titleBig, actors = {}, fx = {}, duckUntil = 0,
		}
		function s.quality(pps)
			gui.PixelsPerStud = pps
			local k = pps / PPS_BASE
			overlay.Size = UDim2.fromScale(1 / k, 1 / k)
			overlayScale.Scale = k
		end
		s.quality(watching and PPS_WATCH or PPS_IDLE)
		show = s
		-- a neon screen's glow would wash the picture out: plain and dark while a show is on
		s.screenWas = { screen.Material, screen.Color }
		screen.Material = Enum.Material.SmoothPlastic
		screen.Color = Color3.new(0, 0, 0)
		setMusic()
		-- the director: one fresh episode after another until the channel changes or the TV goes off
		function s.reset() -- a clean screen for the next episode
			for _, c in ipairs(world:GetChildren()) do c:Destroy() end
			for _, b in ipairs(s.bubbles) do b.label:Destroy() end
			table.clear(s.bubbles)
			s.caption.Visible = false
			s.ticker.Visible = false
			s.shot, s.cinematic, s.snap = nil, false, false
			s.letterbox.Visible, s.title.Visible = false, false
			s.fade.BackgroundTransparency, s.flash.BackgroundTransparency = 1, 1
			table.clear(s.actors)
			table.clear(s.fx)
			label.Text = "<font color=\"#ff4040\">&#9679;</font> LIVE   " .. CHANNELS[channel].name
		end
		s.director = task.spawn(function()
			while show == s and not s.dead do
				s.reset()
				local ok, err = pcall(CHANNELS[channel].episode)
				if not ok and err ~= "cut" then
					warn("[TV] episode error: " .. tostring(err))
					task.wait(2)
				end
			end
		end)
	end
	-- developer self-test: every plot of a channel back to back at high speed, errors collected.
	-- (in the command bar, while a TV show is on: _G.TVSpeed = 25; print(_G.TVSelfTest("news")))
	_G.TVSelfTest = function(which, from, to)
		if not show then return 0, { "no show on" } end
		if show.director then pcall(task.cancel, show.director) end
		local s = show
		local list = {}
		if which == "heist" then
			for _, hub in ipairs({ "job", "plan", "hideout", "chase", "court", "jail" }) do
				for _, v in ipairs(PLOTS.HEIST[hub]) do table.insert(list, v) end
			end
		else
			list = which == "scooter" and PLOTS.SCOOTER or PLOTS.NEWS
		end
		local errs, n = {}, 0
		for i = from or 1, math.min(to or #list, #list) do
			if show ~= s or s.dead then break end
			s.reset()
			s.cinematic = true
			n += 1
			local item = list[i]
			local ok, err = pcall(function()
				if which == "heist" then
					if not story.gang then story.ctx.newGang() end
					item[2](story.ctx)
				elseif which == "news" then
					story.newsDay = i
					PLOTS.newsDay(item)
				else
					item[2]()
				end
			end)
			if not ok and err ~= "cut" then table.insert(errs, i .. " " .. tostring(item[1]) .. ": " .. tostring(err)) end
		end
		return n, errs
	end
	local lastChannel = 1

	-- full-screen watching: channel buttons + exit, the HUD hides, walking pauses, town music fades
	local exitGui = Instance.new("ScreenGui")
	exitGui.Name = "TVExit"
	exitGui.ResetOnSpawn = false
	exitGui.DisplayOrder = 50
	exitGui.Enabled = false
	exitGui.Parent = plr:WaitForChild("PlayerGui")
	local function button(text, pos, anchor, size, color)
		local b = Instance.new("TextButton")
		b.AnchorPoint = anchor
		b.Position = pos
		b.Size = size
		b.BackgroundColor3 = color
		b.Font = Enum.Font.PermanentMarker
		b.TextSize = 22
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = text
		b.Parent = exitGui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 12)
		c.Parent = b
		return b
	end
	local exitBtn = button("X  EXIT", UDim2.new(1, -16, 0, 16), Vector2.new(1, 0), UDim2.fromOffset(120, 44), Color3.fromRGB(220, 50, 60))
	local prevBtn = button("<  CH", UDim2.new(0.5, -150, 1, -20), Vector2.new(0.5, 1), UDim2.fromOffset(110, 46), Color3.fromRGB(40, 44, 60))
	local nextBtn = button("CH  >", UDim2.new(0.5, 150, 1, -20), Vector2.new(0.5, 1), UDim2.fromOffset(110, 46), Color3.fromRGB(40, 44, 60))
	local function playerControls()
		local ok, controls = pcall(function()
			return require(plr:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
		end)
		return ok and controls or nil
	end
	local function switchChannel(step)
		if not show then return end
		lastChannel = (show.channel - 1 + step) % #CHANNELS + 1
		startShow(show.screen, lastChannel)
		sfx(SFX.blip, 0.5, 0.7)
	end
	prevBtn.Activated:Connect(function() switchChannel(-1) end)
	nextBtn.Activated:Connect(function() switchChannel(1) end)
	local function stopWatching()
		if not watching then return end
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = watching.fov
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
		if watching.prompt.Parent then watching.prompt.Enabled = true end
		for g, was in pairs(watching.hidden) do
			if g.Parent then g.Enabled = was end
		end
		for _, e in ipairs(watching.blur) do
			if e.Parent then e.Enabled = true end
		end
		exitGui.Enabled = false
		setLocalCharacterHidden(false)
		local controls = playerControls()
		if controls then controls:Enable() end
		watching = nil
		plr:SetAttribute("WatchingTV", nil) -- the town music comes back
		if show then show.quality(PPS_IDLE) end
		setMusic()
	end
	exitBtn.Activated:Connect(stopWatching)
	local function hookScreen(screen)
		if screens[screen] then return end
		screens[screen] = true
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Watch"
		prompt.ObjectText = "TV"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = screen
		prompt.Triggered:Connect(function()
			if watching then stopWatching() return end
			local cam = workspace.CurrentCamera
			watching = { screen = screen, prompt = prompt, fov = cam.FieldOfView, hidden = {}, blur = {} }
			-- nothing over the picture: every other panel hides (HUD, quest tracker, ...)
			for _, g in ipairs(plr.PlayerGui:GetChildren()) do
				if g:IsA("ScreenGui") and g ~= exitGui and g.Enabled then
					watching.hidden[g] = true
					g.Enabled = false
				end
			end
			-- and no depth-of-field blur: the screen is right in front of the camera
			for _, e in ipairs(Lighting:GetChildren()) do
				if e:IsA("DepthOfFieldEffect") and e.Enabled then
					e.Enabled = false
					table.insert(watching.blur, e)
				end
			end
			-- close enough that the screen fills the view top to bottom (at a 70 degree FOV)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.FieldOfView = 70
			local dist = (screen.Size.Y / 2) / math.tan(math.rad(35)) * 1.05
			cam.CFrame = CFrame.lookAt(screen.Position + screen.CFrame.LookVector * dist, screen.Position)
			exitGui.Enabled = true
			-- you (and your scooter's handlebar) would be right in front of the camera
			setLocalCharacterHidden(true)
			local controls = playerControls()
			if controls then controls:Disable() end
			prompt.Enabled = false -- (EXIT button gets you out)
			plr:SetAttribute("WatchingTV", true) -- (the town music fades out for this)
			if not show or show.screen ~= screen then startShow(screen, lastChannel) else setMusic() end
			show.quality(PPS_WATCH) -- full resolution while you watch
		end)
	end

	task.spawn(function()
		local town = workspace:WaitForChild("DiscoveryBay", 300)
		if not town then return end
		ReplicatedStorage:WaitForChild("TVCast", 120)
		for _, d in ipairs(town:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "TVScreen" then hookScreen(d) end
		end
		-- rented homes get their insides built later: catch those TVs too
		town.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") and d.Name == "TVScreen" then task.defer(hookScreen, d) end
		end)
		-- once a second: the TV nearest you is the one that's on
		while true do
			local cam = workspace.CurrentCamera
			local best, bestD = nil, TV_RANGE
			if cam and not ldmOn then
				for screen in pairs(screens) do
					if screen.Parent then
						local d = (screen.Position - cam.CFrame.Position).Magnitude
						if d < bestD then best, bestD = screen, d end
					else
						screens[screen] = nil
					end
				end
			end
			if watching then best = watching.screen end
			if best ~= (show and show.screen) then
				if best then startShow(best, lastChannel) else stopShow() end
			end
			task.wait(1)
		end
	end)

	-- speech bubbles follow the heads on screen; the news ticker scrolls
	RunService.RenderStepped:Connect(function(dt)
		if watching and not watching.screen.Parent then stopWatching() end
		if not show then return end
		-- the camera director
		if show.shot then
			local ok, want = pcall(function() return show.shot.fn and show.shot.fn() or show.shot.cf end)
			if ok and want then
				if show.snap then
					show.cam.CFrame = want
					show.snap = false
				else
					show.cam.CFrame = show.cam.CFrame:Lerp(want, 1 - math.exp(-dt * (show.shot.speed or 5)))
				end
			end
		end
		if show.shakeUntil and os.clock() < show.shakeUntil then
			local a = show.shakeAmt or 0.2
			show.cam.CFrame = show.cam.CFrame * CFrame.new(rng:NextNumber(-a, a), rng:NextNumber(-a, a), 0)
		end
		-- bodies: walk / run / idle / talking / gestures, for everyone on screen
		local now = clock()
		for _, actor in ipairs(show.actors) do
			if actor.model.Parent then pcall(poseActor, actor, now, dt) end
		end
		-- effects
		for i = #show.fx, 1, -1 do
			local e = show.fx[i]
			e.age += dt
			if e.age >= e.k.life or not e.p.Parent then
				e.p:Destroy()
				table.remove(show.fx, i)
			else
				e.v -= Vector3.new(0, e.k.gravity * dt, 0)
				e.pos += e.v * dt
				local u = e.age / e.k.life
				if e.k.grow then e.p.Size = e.k.size * (1 + u * e.k.grow) end
				e.p.CFrame = CFrame.new(e.pos) * (e.k.spin and CFrame.Angles(e.spin.X * e.age, e.spin.Y * e.age, e.spin.Z * e.age) or CFrame.new())
				e.p.Transparency = u * u
			end
		end
		-- music ducks under dialogue / big effects
		if show.music then
			local want = (clock() < (show.duckUntil or 0)) and MUSIC_DUCKED or MUSIC_VOL
			show.music.Volume += (want - show.music.Volume) * math.min(1, dt * 6)
		end
		local size = show.gui.AbsoluteSize
		if size.X > 0 then
			local aspect = size.X / size.Y
			local fy = 1 / math.tan(math.rad(show.cam.FieldOfView / 2))
			for _, b in ipairs(show.bubbles) do
				local head = b.actor.model.Parent and b.actor.model:FindFirstChild("Head")
				if head then
					local p = show.cam.CFrame:PointToObjectSpace(head.Position + Vector3.new(0, 1.6, 0))
					if p.Z < 0 then
						b.label.Visible = true
						local bx = 0.5 + (p.X / -p.Z) * fy / aspect * 0.5
						local by = 0.5 - (p.Y / -p.Z) * fy * 0.5
						-- keep the whole bubble on the screen
						local halfW = (b.label.AbsoluteSize.X / 2) / math.max(show.overlay.AbsoluteSize.X, 1)
						b.label.Position = UDim2.fromScale(math.clamp(bx, 0.02 + halfW, 0.98 - halfW), math.clamp(by, 0.2, 0.85))
					end
				else
					b.label.Visible = false
				end
			end
		end
		if show.ticker.Visible then
			local x = show.ticker.Position.X.Scale - 0.0025
			if x < -3 then x = 1 end -- (the ticker is 4 screens wide)
			show.ticker.Position = UDim2.fromScale(x, 1)
		end
	end)
end
