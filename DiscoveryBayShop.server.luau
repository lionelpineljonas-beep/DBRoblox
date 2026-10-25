--==============================================================================================
-- DISCOVERY BAY — runtime systems (Script, ServerScriptService)
--==============================================================================================
-- Runs during Play:
--   * Cash leaderboard ($100 to start) — shown by the HUD (DiscoveryBayClient)
--   * electric scooter, mounted by default, with a Get Off / Ride toggle (G):
--       - deck height comes from a RAYCAST of the avatar's real floor distance
--         (measured after appearance loading), so no avatar sinks into the road
--       - hip raise so the rider stands ON the deck; re-applied if avatar scaling resets it
--       - glide animations (walk/run -> stock idle), forward-lean stance, IK hand grips
--   * tricks (menu / number keys / T): deck tailwhips & kickflips under the rider,
--     Superman/No-Hander body poses, 360 spin; auto-hop when grounded; airborne or not,
--     the chosen trick fires. Mint Cone DOUBLES trick payouts.
--   * shops: Shell mini-mart + Callahan's ice cream. Effects on purchase:
--       Soda +4 scooter speed (cap +20) · Vanilla Cone +6 scooter speed (cap +18)
--       Chocolate Cone +8 walking speed (cap +16) · Mint Cone trick payouts x2
--   * auto-sliding shop doors
--   * NPC traffic (24 cars) on the longest roads; getting hit flings you
--==============================================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")

-- ===== GAME PASS: 2X Scooter Speed [Permanent], 299 Robux =====
-- To activate: publish the game, create a Game Pass named "2X Scooter Speed" priced at
-- 299 Robux (Creator Dashboard > your experience > Monetization > Passes), then paste
-- its numeric ID here AND in DiscoveryBayClient's SPEED_PASS_ID.
local SPEED_PASS_ID = 0

-- day/night cycle: one full day every 10 minutes
local DAY_LENGTH = 600

local START_CASH = 100
local WALK_SPEED = 16
local SCOOTER_SPEED = 30
local VERSION = "v111"

-- ==============================================================================================
-- LIGHTING, DYNAMIC SUNSET & STARRY NIGHT SKY SYSTEM
-- ==============================================================================================
local function lerpColor(a, b, t)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local sky, atmo, bloom, cc, sunRays, dof

local function initializeLighting()
	pcall(function()
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA("Atmosphere") or child:IsA("BloomEffect")
				or child:IsA("ColorCorrectionEffect") or child:IsA("SunRaysEffect")
				or child:IsA("DepthOfFieldEffect") or child:IsA("Sky") then
				child:Destroy()
			end
		end

		Lighting.Technology = Enum.Technology.Future
		Lighting.ShadowSoftness = 0.12
		Lighting.Brightness = 3.2
		Lighting.GlobalShadows = true
		Lighting.Ambient = Color3.fromRGB(35, 38, 52)
		Lighting.OutdoorAmbient = Color3.fromRGB(95, 108, 125)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 215)
		Lighting.GeographicLatitude = 38
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 1

		-- Starry Night Skybox with 5,000 stars and a large glowing Moon
		sky = Instance.new("Sky")
		sky.Name = "DiscoveryBaySky"
		sky.CelestialBodiesShown = true
		sky.StarCount = 5000
		sky.MoonAngularSize = 20
		sky.SunAngularSize = 16
		sky.Parent = Lighting

		-- Dynamic Atmosphere (clears up at night so all 5,000 stars & Moon shine through!)
		atmo = Instance.new("Atmosphere")
		atmo.Name = "DiscoveryBayAtmosphere"
		atmo.Density = 0.16
		atmo.Offset = 0.25
		atmo.Color = Color3.fromRGB(185, 215, 250)
		atmo.Decay = Color3.fromRGB(120, 145, 185)
		atmo.Glare = 0.8
		atmo.Haze = 1.4
		atmo.Parent = Lighting

		-- Bloom (neon signs, streetlights, moon reflection, and shooting stars glow at night)
		bloom = Instance.new("BloomEffect")
		bloom.Name = "DiscoveryBayBloom"
		bloom.Intensity = 1.1
		bloom.Size = 28
		bloom.Threshold = 1.4
		bloom.Parent = Lighting

		-- Color Correction
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "DiscoveryBayColorCorrection"
		cc.Contrast = 0.22
		cc.Saturation = 0.28
		cc.TintColor = Color3.fromRGB(255, 250, 244)
		cc.Parent = Lighting

		-- God Rays
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "DiscoveryBaySunRays"
		sunRays.Intensity = 0.12
		sunRays.Spread = 0.85
		sunRays.Parent = Lighting

		-- Subtle Cinematic Depth of Field
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "DiscoveryBayDOF"
		dof.FocusDistance = 55
		dof.InFocusRadius = 65
		dof.NearIntensity = 0
		dof.FarIntensity = 0.12
		dof.Parent = Lighting
	end)
end

local weatherActive = false

local function updateSkyForClock(ct)
	if not atmo or not atmo.Parent then return end
	-- Compute day (0..1), sunset/sunrise (0..1), and night (0..1) weights
	-- Sunrise ~ 5.5..7.5, Day ~ 7.5..16.5, Sunset ~ 16.5..18.8, Night ~ 18.8..5.5
	local nightW = 0
	local sunsetW = 0
	if ct >= 18.8 or ct <= 5.2 then
		nightW = 1
	elseif ct > 16.5 and ct < 18.8 then
		local u = (ct - 16.5) / (18.8 - 16.5)
		nightW = math.clamp((u - 0.35) / 0.65, 0, 1)
		sunsetW = math.sin(u * math.pi)
	elseif ct > 5.2 and ct < 7.5 then
		local u = (ct - 5.2) / (7.5 - 5.2)
		nightW = math.clamp(1 - u / 0.65, 0, 1)
		sunsetW = math.sin(u * math.pi)
	end

	-- Blend Day -> Sunset -> Starry Night
	local dayAtmoColor = Color3.fromRGB(185, 215, 250)
	local sunsetAtmoColor = Color3.fromRGB(255, 125, 95)
	local nightAtmoColor = Color3.fromRGB(20, 34, 86)

	local dayDecay = Color3.fromRGB(120, 145, 185)
	local sunsetDecay = Color3.fromRGB(135, 55, 165)
	local nightDecay = Color3.fromRGB(10, 16, 48)

	local targetAtmoColor = lerpColor(lerpColor(dayAtmoColor, nightAtmoColor, nightW), sunsetAtmoColor, sunsetW * 0.85)
	local targetDecay = lerpColor(lerpColor(dayDecay, nightDecay, nightW), sunsetDecay, sunsetW * 0.85)

	atmo.Color = targetAtmoColor
	atmo.Decay = targetDecay
	-- Drop Density & Haze at night so all 5,000 stars and the Moon are crystal-clear!
	atmo.Density = 0.16 * (1 - nightW) + 0.045 * nightW + 0.04 * sunsetW
	atmo.Haze = 1.4 * (1 - nightW) + 0.0 * nightW + 1.8 * sunsetW
	atmo.Glare = 0.8 * (1 - nightW) + 0.0 * nightW + 1.6 * sunsetW
	atmo.Offset = 0.25 * (1 - nightW) + 0.05 * nightW

	if not weatherActive then
		local dayOA = Color3.fromRGB(105, 115, 132)
		local sunsetOA = Color3.fromRGB(155, 95, 115)
		local nightOA = Color3.fromRGB(56, 74, 128)
		Lighting.OutdoorAmbient = lerpColor(lerpColor(dayOA, nightOA, nightW), sunsetOA, sunsetW * 0.7)

		local dayAmb = Color3.fromRGB(38, 42, 55)
		local nightAmb = Color3.fromRGB(30, 40, 76)
		Lighting.Ambient = lerpColor(dayAmb, nightAmb, nightW)

		local dayTop = Color3.fromRGB(255, 240, 215)
		local sunsetTop = Color3.fromRGB(255, 160, 110)
		local nightTop = Color3.fromRGB(130, 180, 255)
		Lighting.ColorShift_Top = lerpColor(lerpColor(dayTop, nightTop, nightW), sunsetTop, sunsetW * 0.85)
		Lighting.Brightness = 3.2 * (1 - nightW) + 1.85 * nightW
	end

	if bloom then
		bloom.Intensity = 1.0 * (1 - nightW) + 1.65 * nightW
		bloom.Threshold = 1.45 * (1 - nightW) + 1.05 * nightW
	end
	if cc then
		local dayTint = Color3.fromRGB(255, 250, 244)
		local sunsetTint = Color3.fromRGB(255, 232, 220)
		local nightTint = Color3.fromRGB(222, 234, 255)
		cc.TintColor = lerpColor(lerpColor(dayTint, nightTint, nightW), sunsetTint, sunsetW * 0.6)
		cc.Saturation = 0.28 + 0.06 * nightW + 0.08 * sunsetW
	end
end

initializeLighting()
Lighting.ClockTime = 14
updateSkyForClock(Lighting.ClockTime)

task.spawn(function()
	while task.wait(0.1) do
		-- Smoothly advance sun & moon (~1 hour every 20s) and wrap cleanly at 24:00
		Lighting.ClockTime = (Lighting.ClockTime + 0.005) % 24
		updateSkyForClock(Lighting.ClockTime)
	end
end)

local TRICK_COOLDOWN = 0.65
local TRAFFIC_CARS = 130
local CAR_SPEED = 38
local FLING_RADIUS = 9
local CAR_DAMAGE = 10000

local GLIDE_ANIM = "rbxassetid://507766666"   -- stock Roblox standing idle
local DEFAULT_RUN = "rbxassetid://507767714"  -- stock defaults, restored on dismount
local DEFAULT_WALK = "rbxassetid://507777826"

local rng = Random.new()

-- RemoteEvents ---------------------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("DiscoveryBayRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "DiscoveryBayRemotes"
	remotes.Parent = ReplicatedStorage
end
local function remote(name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local DoTrick = remote("DoTrick")
local TrickResult = remote("TrickResult")
local ToggleScooter = remote("ToggleScooter")
local BuyCustomItem = remote("BuyCustomItem")
local HatchEgg = remote("HatchEgg") -- server -> client: play the on-screen hatch cinematic
local UpdatePity = remote("UpdatePity") -- server -> client: updates pity tracker
local FishGame = remote("FishGame") -- server -> client: FISH ON! start the reel minigame
local FishReel = remote("FishReel") -- client -> server: minigame result (true = landed)
local CompleteQuest = remote("CompleteQuest")
local PianoDrop = remote("PianoDrop")
local DoRebirth = remote("DoRebirth")
local CarFling = remote("CarFling")

-- Resolve real Classic Roblox Face textures from Catalog IDs via InsertService
local CLASSIC_FACE_CATALOG = {
	Smile           = 144075659,
	Chill           = 7074764,
	CheckIt         = 7074786,
	SillyFun        = 7699174,
	Winky           = 7074864,
	GoodIntentioned = 7317793,
	MrChuckles      = 10907541,
	Slickfang       = 7317765,
	Disbelief       = 20337343,
	ItsGoTime       = 7506141,
	HappyWink       = 236399287,
	SureImCool      = 10907549,
	JoyousSurprise  = 28999228,
	Grr             = 19398554,
	Stare           = 8560971,
	Roar            = 406001167,
	Puck            = 20298988,
	Sniffles        = 14516578,
	Vampire         = 7074836,
	Skeptic         = 31117192,
	-- open-mouth faces the client flips to while an NPC is talking
	OpenO           = 7317773,   -- ":-o"
	JoyfulSmile     = 209995366,
	Fang            = 7075142,
	TongueOut       = 14861743,  -- ":P"
}
local classicFacesFolder = remotes:FindFirstChild("ClassicFaces")
if not classicFacesFolder then
	classicFacesFolder = Instance.new("Folder")
	classicFacesFolder.Name = "ClassicFaces"
	classicFacesFolder.Parent = remotes
end
for faceKey, catId in pairs(CLASSIC_FACE_CATALOG) do
	local sv = classicFacesFolder:FindFirstChild(faceKey)
	if not sv then
		sv = Instance.new("StringValue")
		sv.Name = faceKey
		sv.Value = (faceKey == "Chill") and "rbxassetid://7074749" or "rbxasset://textures/face.png"
		sv.Parent = classicFacesFolder
	end
	task.spawn(function()
		pcall(function()
			local m = game:GetService("InsertService"):LoadAsset(catId)
			local d = m:FindFirstChildOfClass("Decal") or m:FindFirstChildWhichIsA("Decal", true)
			if d and d.Texture and d.Texture ~= "" then
				sv.Value = d.Texture
			end
			m:Destroy()
		end)
	end)
end

-- Cash leaderboard ------------------------------------------------------------------------------
local function getCash(plr)
	local stats = plr:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function getRebirths(plr)
	local stats = plr:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Rebirths")
end

local function getMult(plr)
	local r = getRebirths(plr)
	return r and math.pow(1.5, r.Value) or 1
end

local function setupPlayer(plr)
	if not plr:FindFirstChild("leaderstats") then
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = START_CASH
		cash.Parent = stats
		
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Rebirths"
		rebirths.Value = 0
		rebirths.Parent = stats
		
		stats.Parent = plr
	end
end

--==============================================================================================
-- SPEED (mounted vs on foot, with drink/ice-cream boosts)
--==============================================================================================
local function updateSpeed(plr)
	local char = plr.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if plr:GetAttribute("Mounted") then
		local baseSpeed = (SCOOTER_SPEED + (plr:GetAttribute("FastScooter") and 20 or 0)) * getMult(plr)
		local speed = baseSpeed + (plr:GetAttribute("SodaBoost") or 0)
			+ (plr:GetAttribute("VanillaBoost") or 0) + (plr:GetAttribute("EduBoost") or 0)
			+ (plr:GetAttribute("WeatherBoost") or 0)
		if plr:GetAttribute("SpeedPass") then
			speed = speed * 2 -- 2X Scooter Speed gamepass
		end
		humanoid.WalkSpeed = math.max(speed, 8)
	else
		humanoid.WalkSpeed = math.max(WALK_SPEED + (plr:GetAttribute("WalkBoost") or 0)
			+ (plr:GetAttribute("WeatherWalk") or 0), 6)
	end
end

-- grant the 2X speed pass to owners (on join and right after purchase)
local function checkSpeedPass(plr)
	if SPEED_PASS_ID <= 0 then return end
	task.spawn(function()
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService, plr.UserId, SPEED_PASS_ID)
		if ok and owns then
			plr:SetAttribute("SpeedPass", true)
			updateSpeed(plr)
		end
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, purchased)
	if purchased and SPEED_PASS_ID > 0 and passId == SPEED_PASS_ID then
		plr:SetAttribute("SpeedPass", true)
		updateSpeed(plr)
		TrickResult:FireClient(plr, "2X SCOOTER SPEED unlocked - forever!", 0)
	end
end)

--==============================================================================================
-- SCOOTER RIG (mount / dismount)
--==============================================================================================
local charRigs = {}

local function setRideAnimations(char, humanoid, riding)
	local animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 10)
	if animate then
		local function setId(groupName, animName, id)
			local group = animate:FindFirstChild(groupName)
			local anim = group and group:FindFirstChild(animName)
			if anim and anim:IsA("Animation") then
				anim.Parent = nil; anim.AnimationId = id; anim.Parent = group
			end
		end
		setId("run", "RunAnim", riding and GLIDE_ANIM or DEFAULT_RUN)
		setId("walk", "WalkAnim", riding and GLIDE_ANIM or DEFAULT_WALK)
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.1)
		end
	end
end

-- riding stance: lean forward, stagger the feet. Works on BOTH rigs: R15 poses joint
-- pitch directly; R6 swings its Z-axis Torso motors with mirrored signs (and has no
-- waist joint, so waist accents simply skip). Each joint entry carries a pose()
-- closure so the trick code never has to know which rig it's animating.
local function r15Pose(rest, a, yawD, rollD)
	return rest * CFrame.Angles(math.rad(a), math.rad(yawD or 0), math.rad(rollD or 0))
end

local function poseStance(char, rig)
	for _, d in ipairs(char:GetDescendants()) do
		if (d:IsA("Motor6D") or d.Name == "LeftArmGrip" or d.Name == "RightArmGrip") and not d:GetAttribute("WalkOrigC0") then
			d:SetAttribute("WalkOrigC0", d.C0)
		end
	end
	local upperTorso = char:FindFirstChild("UpperTorso")
	local waist = upperTorso and upperTorso:FindFirstChild("Waist")
	if waist and waist:IsA("JointInstance") then
		local orig = waist.C0
		waist.C0 = orig * CFrame.Angles(math.rad(-8), 0, 0)
		rig.waist = { motor = waist, orig = orig, rest = waist.C0 }
	end
	-- whole-body root motor: guaranteed-visible 360 spins on any rig
	local lowerTorso = char:FindFirstChild("LowerTorso")
	local rootMotor = lowerTorso and lowerTorso:FindFirstChild("Root")
	if rootMotor and not rootMotor:IsA("JointInstance") then
		rootMotor = nil
	end
	local rootAxis = "y"
	if not rootMotor then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		rootMotor = hrp and hrp:FindFirstChild("RootJoint")
		if rootMotor and not rootMotor:IsA("JointInstance") then
			rootMotor = nil
		end
		rootAxis = "z"
	end
	if rootMotor then
		rig.root = { motor = rootMotor, rest = rootMotor.C0, axis = rootAxis }
	end
	rig.hips = {}
	local legPose = { Left = 12, Right = -6 }
	for side, deg in pairs(legPose) do
		local upperLeg = char:FindFirstChild(side .. "UpperLeg")
		local hip = upperLeg and upperLeg:FindFirstChild(side .. "Hip")
		if hip and not hip:IsA("JointInstance") then
			hip = nil
		end
		local pose = r15Pose
		if not hip then
			local torso = char:FindFirstChild("Torso")
			hip = torso and torso:FindFirstChild(side .. " Hip")
			if hip and not hip:IsA("JointInstance") then
				hip = nil
			end
			local fw = (side == "Left") and 1 or -1
			pose = function(rest, a)
				return rest * CFrame.Angles(0, 0, math.rad(a * fw))
			end
		end
		if hip then
			local orig = hip.C0
			hip.C0 = pose(orig, deg)
			table.insert(rig.hips, { motor = hip, orig = orig, rest = hip.C0, pose = pose })
		end
	end
	rig.shoulders = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local upperArm = char:FindFirstChild(side .. "UpperArm")
		local shoulder = upperArm and upperArm:FindFirstChild(side .. "Shoulder")
		if shoulder and shoulder:IsA("JointInstance") then
			table.insert(rig.shoulders, { motor = shoulder, rest = shoulder.C0, pose = r15Pose })
		end
	end
	-- Stamp RideBaseC0 on all character joints so client & server trick animators always know the exact resting pose
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") or d.Name == "LeftArmGrip" or d.Name == "RightArmGrip" then
			d:SetAttribute("RideBaseC0", d.C0)
		end
	end
end

-- parked scooters: dismounting leaves the scooter standing in the world where you
-- stepped off; ride it again with its prompt (E) or G when close. One per player.
local parkedScooters = {}

local function clearParked(plr)
	local parked = parkedScooters[plr.UserId]
	if parked and parked.Parent then parked:Destroy() end
	parkedScooters[plr.UserId] = nil
end

local mountScooterBody -- defined below; mountScooter wraps it in pcall
local mounting = {} -- per-player lock: two overlapping mounts would stack the hip raise

local function mountScooter(plr, char)
	local existing = charRigs[plr.UserId]
	if existing and existing.char == char then
		-- already rigged: self-heal the attribute in case it went stale
		plr:SetAttribute("Mounted", true)
		updateSpeed(plr)
		return
	end
	if mounting[plr.UserId] then return end
	mounting[plr.UserId] = true
	local ok, err = pcall(mountScooterBody, plr, char)
	mounting[plr.UserId] = nil
	if not ok then
		-- log only (no player-facing popup); the essential mount registers early, so a
		-- late failure still leaves a rideable scooter
		warn("[DiscoveryBayShop] mount error: " .. tostring(err))
		if not (charRigs[plr.UserId] and charRigs[plr.UserId].char == char) then
			plr:SetAttribute("Mounted", false)
		end
	end
end

function mountScooterBody(plr, char)
	clearParked(plr) -- riding again consumes the parked scooter
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	local humanoid = char:WaitForChild("Humanoid", 10)
	if not hrp or not humanoid or humanoid.Health <= 0 then return end

	-- wait until the avatar is fully loaded and standing, then measure the REAL
	-- floor distance with a raycast — this is what keeps the deck out of the ground
	local t0 = os.clock()
	while not plr:HasAppearanceLoaded() and os.clock() - t0 < 4 do
		task.wait(0.1)
	end
	while humanoid.FloorMaterial == Enum.Material.Air and os.clock() - t0 < 5 do
		task.wait(0.1)
	end
	if char.Parent == nil or humanoid.Health <= 0 then return end

	local anatDist = (humanoid.RigType == Enum.HumanoidRigType.R15)
		and math.max(humanoid.HipHeight + hrp.Size.Y / 2, 3.0)
		or 3.0
	local floorDist = anatDist
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0), params)
	if hit then
		floorDist = math.max(hrp.Position.Y - hit.Position.Y, anatDist)
	end
	floorDist = math.clamp(floorDist, 2.8, 8)

	local deckY = -floorDist - 0.125 -- deck top right under the feet
	local wheelY = -floorDist - 0.05 -- wheels reach the ground after the hip raise

	pcall(setRideAnimations, char, humanoid, true) -- cosmetic; never blocks the mount
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 55

	local old = char:FindFirstChild("Scooter")
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = "Scooter"

	local function sPart(name, size, cfOffset, color, shape, weldTo)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = hrp.CFrame * cfOffset
		p.Color = color
		p.Material = Enum.Material.Metal
		p.CanCollide = false
		p.Massless = true
		p.Parent = m
		if shape then p.Shape = shape end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = weldTo or hrp
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	local deckRoot = Instance.new("Part")
	deckRoot.Name = "DeckRoot"
	deckRoot.Size = Vector3.new(0.4, 0.4, 0.4)
	deckRoot.Transparency = 1
	deckRoot.CanCollide = false
	deckRoot.Massless = true
	deckRoot.CFrame = hrp.CFrame
	deckRoot.Parent = m
	local deckMount = Instance.new("Motor6D")
	deckMount.Name = "DeckMount"
	deckMount.Part0 = hrp
	deckMount.Part1 = deckRoot
	deckMount.Parent = deckRoot
	
	local hasFast = plr:GetAttribute("FastScooter")
	local deckColor = hasFast and Color3.fromRGB(150, 30, 30) or Color3.fromRGB(40, 40, 45)
	local batColor = hasFast and Color3.fromRGB(250, 200, 30) or Color3.fromRGB(60, 160, 90)

	sPart("Deck", Vector3.new(1.6, 0.25, 4.6), CFrame.new(0, deckY, 0.2), deckColor, nil, deckRoot)
	sPart("Battery", Vector3.new(1.2, 0.35, 1.6), CFrame.new(0, deckY + 0.3, 0.8), batColor, nil, deckRoot)
	sPart("FrontWheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, wheelY, -2.2), Color3.fromRGB(25, 25, 25),
		Enum.PartType.Cylinder, deckRoot)
	local rearWheel = sPart("RearWheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, wheelY, 2.4), Color3.fromRGB(25, 25, 25),
		Enum.PartType.Cylinder, deckRoot)
	local colH = 3.8
	local barRoot = Instance.new("Part")
	barRoot.Name = "BarRoot"
	barRoot.Size = Vector3.new(0.4, 0.4, 0.4)
	barRoot.Transparency = 1
	barRoot.CanCollide = false
	barRoot.Massless = true
	barRoot.CFrame = hrp.CFrame
	barRoot.Parent = m
	local barMount = Instance.new("Motor6D")
	barMount.Name = "BarMount"
	barMount.Part0 = hrp
	barMount.Part1 = barRoot
	barMount.Parent = barRoot
	deckMount:SetAttribute("RideBaseC0", deckMount.C0)
	barMount:SetAttribute("RideBaseC0", barMount.C0)
	m:SetAttribute("DeckY", deckY)

	sPart("Column", Vector3.new(0.25, colH, 0.25), CFrame.new(0, deckY + colH / 2, -2.2) * CFrame.Angles(math.rad(8), 0, 0),
		Color3.fromRGB(200, 200, 205), nil, barRoot)
	local handlebar = sPart("Handlebar", Vector3.new(2.3, 0.22, 0.22), CFrame.new(0, deckY + colH - 0.1, -1.95),
		Color3.fromRGB(40, 40, 45), nil, barRoot)

	-- Add beautiful speed trail to the rear wheel
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TrailAttachment0"
	attachment0.Position = Vector3.new(0.2, 0, 0)
	attachment0.Parent = rearWheel

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "TrailAttachment1"
	attachment1.Position = Vector3.new(-0.2, 0, 0)
	attachment1.Parent = rearWheel

	local trail = Instance.new("Trail")
	trail.Name = "ScooterSpeedTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = 0.4
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 50, 250)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
	})
	trail.LightEmission = 0.8
	trail.LightInfluence = 0
	trail.Enabled = true
	trail.Parent = rearWheel

	-- Add spark emitter for trick effects
	local sparkEmitter = Instance.new("ParticleEmitter")
	sparkEmitter.Name = "SparkEmitter"
	sparkEmitter.Enabled = false
	sparkEmitter.Rate = 0
	sparkEmitter.Lifetime = NumberRange.new(0.15, 0.45)
	sparkEmitter.Speed = NumberRange.new(8, 18)
	sparkEmitter.SpreadAngle = Vector2.new(45, 45)
	sparkEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 180, 50))
	sparkEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparkEmitter.Acceleration = Vector3.new(0, -35, 0)
	sparkEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparkEmitter.Parent = rearWheel

	m.Parent = char

	local rig = { char = char, deckMount = deckMount, deckBase = deckMount.C0, barMount = barMount, barBase = barMount.C0, deckY = deckY, iks = {} }

	-- stand ON the deck: raise the hips by the deck stack height. The character's TRUE
	-- resting hip height is remembered as an attribute on the character itself, so
	-- dismount always restores the exact original no matter what happened in between.
	local origHip = char:GetAttribute("ScooterOrigHip")
	if origHip == nil then
		origHip = humanoid.HipHeight
		char:SetAttribute("ScooterOrigHip", origHip)
	end
	rig.hipBase = origHip
	rig.hipTarget = origHip + 0.6
	humanoid.HipHeight = rig.hipTarget
	-- guard against the avatar-scaling system resetting HipHeight after us
	rig.hipConn = humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
		if charRigs[plr.UserId] == rig and plr:GetAttribute("Mounted")
			and math.abs(humanoid.HipHeight - rig.hipTarget) > 0.05 then
			-- scaling delivered a new true baseline; ride on top of it
			rig.hipBase = humanoid.HipHeight
			rig.hipTarget = rig.hipBase + 0.6
			char:SetAttribute("ScooterOrigHip", rig.hipBase)
			humanoid.HipHeight = rig.hipTarget
		end
	end)

	-- REGISTER THE RIDE NOW: tricks and G work from this point on, no matter what
	-- happens in the cosmetic stages below (hand grips / stance are nice-to-have)
	charRigs[plr.UserId] = rig
	plr:SetAttribute("Mounted", true)
	updateSpeed(plr)

	-- hands on the grips (cosmetic: isolated so a failure can't break the mount)
	local okGrips, gripErr = pcall(function()
		local gripL = Instance.new("Attachment")
		gripL.Position = Vector3.new(-0.95, 0.1, 0)
		gripL.Parent = handlebar
		local gripR = Instance.new("Attachment")
		gripR.Position = Vector3.new(0.95, 0.1, 0)
		gripR.Parent = handlebar
		rig.r6arms = nil
		for _, side in ipairs({ "Left", "Right" }) do
			if humanoid.RigType == Enum.HumanoidRigType.R15 then
				local hand = char:WaitForChild(side .. "Hand", 5)
				local upper = char:WaitForChild(side .. "UpperArm", 5)
				if hand and upper then
					local ik = Instance.new("IKControl")
					ik.Name = side .. "HandGrip"
					ik.Type = Enum.IKControlType.Position
					ik.EndEffector = hand
					ik.ChainRoot = upper
					ik.Target = (side == "Left") and gripL or gripR
					ik.Weight = 1
					ik.SmoothTime = 0.02
					ik.Parent = humanoid
					table.insert(rig.iks, ik)
				end
			else
				local torso = char:FindFirstChild("Torso")
				local motor = torso and torso:FindFirstChild(side .. " Shoulder")
				local arm = char:FindFirstChild(side .. " Arm")
				if torso and motor and arm then
					rig.r6arms = rig.r6arms or {}
					table.insert(rig.r6arms, {
						name = motor.Name, part0 = motor.Part0, part1 = motor.Part1,
						c0 = motor.C0, c1 = motor.C1,
					})
					local sign = (side == "Left") and -1 or 1
					motor:Destroy()
					local weld = Instance.new("Weld")
					weld.Name = side .. "ArmGrip"
					weld.Part0 = torso
					weld.Part1 = arm
					weld.C0 = CFrame.new(sign * 1.4, 0.25, -0.75) * CFrame.Angles(math.rad(62), 0, math.rad(sign * 10))
					weld.Parent = torso
					rig.r6arms[#rig.r6arms].weld = weld
					rig.r6arms[#rig.r6arms].gripC0 = weld.C0 -- trick poses offset from here
				end
			end
		end
	end)
	if not okGrips then
		warn("[DiscoveryBayShop] hand grips skipped: " .. tostring(gripErr))
	end

	local okStance, stanceErr = pcall(poseStance, char, rig)
	if not okStance then
		warn("[DiscoveryBayShop] stance pose skipped: " .. tostring(stanceErr))
	end
end

-- a standalone scooter standing in the world (kickstand lean), owner-only Ride prompt
local function parkScooter(plr, baseCf)
	clearParked(plr)
	local m = Instance.new("Model")
	m.Name = "ParkedScooter"
	local cf = baseCf * CFrame.Angles(0, 0, math.rad(7)) -- kickstand lean
	local function pPart(name, size, off, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * off
		p.Color = color
		p.Material = Enum.Material.Metal
		p.Anchored = true
		p.CanCollide = false
		p.Parent = m
		if shape then p.Shape = shape end
		return p
	end
	local deck = pPart("Deck", Vector3.new(1.6, 0.25, 4.6), CFrame.new(0, 0.75, 0), Color3.fromRGB(40, 40, 45))
	pPart("Battery", Vector3.new(1.2, 0.35, 1.6), CFrame.new(0, 1.05, 0.6), Color3.fromRGB(60, 160, 90))
	pPart("FrontWheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, 0.55, -2.4), Color3.fromRGB(25, 25, 25),
		Enum.PartType.Cylinder)
	pPart("RearWheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, 0.55, 2.2), Color3.fromRGB(25, 25, 25),
		Enum.PartType.Cylinder)
	pPart("Column", Vector3.new(0.25, 3.8, 0.25), CFrame.new(0, 2.65, -2.4) * CFrame.Angles(math.rad(8), 0, 0),
		Color3.fromRGB(200, 200, 205))
	pPart("Handlebar", Vector3.new(2.3, 0.22, 0.22), CFrame.new(0, 4.45, -2.15), Color3.fromRGB(40, 40, 45))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ride"
	prompt.ObjectText = plr.Name .. "'s scooter"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = deck
	prompt.Triggered:Connect(function(who)
		if who ~= plr then return end
		local c = plr.Character
		if c then
			task.spawn(mountScooter, plr, c)
		end
	end)
	m.Parent = workspace:FindFirstChild("DiscoveryBay") or workspace
	parkedScooters[plr.UserId] = m
	return m
end

local function dismountScooter(plr)
	plr:SetAttribute("Mounted", false)
	local rig = charRigs[plr.UserId]
	charRigs[plr.UserId] = nil
	local char = plr.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if rig then
		if rig.hipConn then rig.hipConn:Disconnect() end
		if humanoid then
			-- restore the character's TRUE original hip height (never a stacked value)
			local orig = char and char:GetAttribute("ScooterOrigHip")
			humanoid.HipHeight = orig or rig.hipBase or humanoid.HipHeight
		end
		for _, ik in ipairs(rig.iks or {}) do
			if ik.Parent then ik:Destroy() end
		end
		if rig.waist and rig.waist.motor.Parent then rig.waist.motor.C0 = rig.waist.orig end
		if rig.root and rig.root.motor.Parent then rig.root.motor.C0 = rig.root.rest end
		for _, hh in ipairs(rig.hips or {}) do
			if hh.motor.Parent then hh.motor.C0 = hh.orig end
		end
		if rig.r6arms then
			for _, info in ipairs(rig.r6arms) do
				if info.weld and info.weld.Parent then info.weld:Destroy() end
				if info.part0 and info.part0.Parent and info.part1 and info.part1.Parent then
					local motor = Instance.new("Motor6D")
					motor.Name = info.name
					motor.Part0 = info.part0
					motor.Part1 = info.part1
					motor.C0 = info.c0
					motor.C1 = info.c1
					motor.Parent = info.part0
				end
			end
		end
	end
	if char then
		local scooter = char:FindFirstChild("Scooter")
		if scooter then scooter:Destroy() end
		if humanoid then
			-- teardown that works even without a rig (character is the source of truth)
			for _, ikName in ipairs({ "LeftHandGrip", "RightHandGrip" }) do
				local ik = humanoid:FindFirstChild(ikName)
				if ik then ik:Destroy() end
			end
			local orig = char:GetAttribute("ScooterOrigHip")
			if orig then humanoid.HipHeight = orig end
			setRideAnimations(char, humanoid, false)
		end
		-- leave the scooter standing where you stepped off, just beside you
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local ok, err = pcall(function()
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { char }
				local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0), params)
				local groundY = hit and hit.Position.Y or (hrp.Position.Y - 3)
				local side = hrp.CFrame.RightVector
				local base = Vector3.new(hrp.Position.X, groundY, hrp.Position.Z) + side * 3
				parkScooter(plr, CFrame.lookAt(base, base + hrp.CFrame.LookVector))
			end)
			if not ok then
				warn("[DiscoveryBayShop] parking failed: " .. tostring(err))
			end
		end
	end
	updateSpeed(plr)
end

ToggleScooter.OnServerEvent:Connect(function(plr)
	local now = os.clock()
	if plr:GetAttribute("ToggleLock") and now - plr:GetAttribute("ToggleLock") < 0.5 then return end
	plr:SetAttribute("ToggleLock", now)
	local char = plr.Character
	-- G ALWAYS gets you off: dismount if the attribute says mounted OR a scooter model
	-- is physically on the character (covers any stale/wedged state)
	if plr:GetAttribute("Mounted") or (char and char:FindFirstChild("Scooter")) then
		dismountScooter(plr)
		return
	end
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local parked = parkedScooters[plr.UserId]
	if parked and parked.Parent and hrp then
		local pos = parked:GetPivot().Position
		if (pos - hrp.Position).Magnitude <= 16 then
			task.spawn(mountScooter, plr, char) -- close enough: hop back on
		else
			TrickResult:FireClient(plr, "Your scooter is parked where you left it!", 0)
		end
	else
		-- no parked scooter anywhere (shouldn't happen) — give them a fresh one
		task.spawn(mountScooter, plr, char)
	end
end)

BuyCustomItem.OnServerEvent:Connect(function(plr, itemName)
	local PRICING = { ["Pizza Slice"] = 20, ["Energy Drink"] = 15, ["Burrito"] = 25 }
	local price = PRICING[itemName]
	if not price then return end
	local cash = getCash(plr)
	if cash and cash.Value >= price then
		cash.Value = cash.Value - price
		local kit = ReplicatedStorage:FindFirstChild("DiscoveryBayKit")
		local tools = kit and kit:FindFirstChild("Products")
		local tool = tools and tools:FindFirstChild(itemName)
		if tool then
			tool:Clone().Parent = plr:FindFirstChildOfClass("Backpack") or plr.Character
			TrickResult:FireClient(plr, "Bought " .. itemName .. " for $" .. price .. "!", 0)
		end
	else
		TrickResult:FireClient(plr, "Not enough cash for " .. itemName .. "!", 0)
	end
end)

CompleteQuest.OnServerEvent:Connect(function(plr, questId)
	if questId == "TerrysSoda" then
		if plr:GetAttribute("TerryQuestCompleted") then return end
		plr:SetAttribute("TerryQuestCompleted", true)
		local cash = getCash(plr)
		if cash then
			cash.Value = cash.Value + 200
			TrickResult:FireClient(plr, "Terry's Soda Delivered", 200)
			print("[SERVER]: " .. plr.Name .. " found Terry's Soda and got $200!")
		end
	end
end)

PianoDrop.OnServerEvent:Connect(function(plr, npc)
	if not npc or not npc:IsA("Model") then return end
	if npc:GetAttribute("PianoDropping") then return end
	npc:SetAttribute("PianoDropping", true)
	
	local prompt = npc:FindFirstChild("TalkPrompt", true)
	if prompt then prompt:Destroy() end
	
	task.spawn(function()
		local hum = npc:FindFirstChild("Humanoid")
		if hum then
			-- Disable Humanoid physics so it doesn't fight the slide or fall apart
			hum.PlatformStand = true
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		end
		
		local startCF = npc:GetPivot()
		print("StartCF:", startCF)
		
		local totalTime = 1.8
		local distance = 28
		
		local animConn
		-- Start piano drop halfway
		task.spawn(function()
			task.wait(0.9)
			
			local finalCF = startCF * CFrame.new(0, 0, -distance)
			local piano = Instance.new("Part")
			piano.Name = "Piano"
			piano.Size = Vector3.new(4, 4, 4)
			piano.Position = finalCF.Position + Vector3.new(0, 90, 0)
			piano.Anchored = false
			piano.CanCollide = true
			
			local pmesh = Instance.new("SpecialMesh")
			pmesh.MeshType = Enum.MeshType.FileMesh
			pmesh.MeshId = "rbxassetid://113221356"
			pmesh.TextureId = "rbxassetid://113221332"
			pmesh.Scale = Vector3.new(2, 2, 2)
			pmesh.Parent = piano
			
			piano.Parent = workspace
			
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://9117314405"
			local crashSound = Instance.new("Sound")
			crashSound.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
			crashSound.PlaybackSpeed = 1.15
			crashSound.Volume = 1.8
			crashSound.Parent = piano
			sound.Volume = 2
			sound.Parent = piano
			
			task.wait(0.95) -- wait for impact
			
			sound:Play()
			crashSound:Play()
			
			if npc and npc.Parent then
				-- Smash!
				if animConn then animConn:Disconnect() end
				if hum then hum.Health = 0 end
				for _, part in ipairs(npc:GetDescendants()) do
					if part:IsA("Motor6D") then part:Destroy() end
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = true
					end
				end
				
				-- Spawn a burst of 10 gold coins (Pet Sim X style)
				for i = 1, 10 do
					local coin = Instance.new("Part")
					coin.Name = "MoneyDrop"
					coin.Shape = Enum.PartType.Cylinder
					coin.Size = Vector3.new(0.15, 0.8, 0.8) -- Thin cylinder acts like a coin
					coin.Orientation = Vector3.new(0, 0, 90) -- Lay flat
					coin.Color = Color3.fromRGB(255, 215, 0) -- Gold
					coin.Material = Enum.Material.Metal
					coin.Position = finalCF.Position + Vector3.new(math.random(-2, 2), 4 + (i * 0.2), math.random(-2, 2))
					coin.Velocity = Vector3.new(math.random(-20, 20), math.random(30, 50), math.random(-20, 20))
					coin.Parent = workspace
					
					local pickedUp = false
					local dropConn
					dropConn = game:GetService("RunService").Heartbeat:Connect(function()
						if pickedUp or not coin.Parent then 
							if dropConn then dropConn:Disconnect() end
							return 
						end
						local char = plr.Character
						if char and char.PrimaryPart then
							local dist = (coin.Position - char.PrimaryPart.Position).Magnitude
							if dist < 12 then -- Magnet pull radius
								pickedUp = true
								coin.Anchored = true
								coin.CanCollide = false
								
								local ts = game:GetService("TweenService")
								local tw = ts:Create(coin, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
									Position = char.PrimaryPart.Position,
									Size = Vector3.new(0.05, 0.2, 0.2) -- Shrink while absorbing
								})
								tw:Play()
								tw.Completed:Wait()
								
								local ls = plr:FindFirstChild("leaderstats")
								if ls then
									local cash = ls:FindFirstChild("Cash")
									if cash then cash.Value = cash.Value + math.floor(10 * getMult(plr)) end
								end
								
								-- Soft pop/absorb sound so 10 of them don't deafen the player
								local sfx = Instance.new("Sound")
								sfx.SoundId = "rbxassetid://9061556942" -- Verified public chime / coin pop sound
								sfx.Volume = 0.5
								sfx.Pitch = math.random(90, 110) / 100 -- slightly randomize pitch for satisfying effect
								sfx.Parent = char.PrimaryPart
								sfx:Play()
								game.Debris:AddItem(sfx, 1)
								
								coin:Destroy()
								if dropConn then dropConn:Disconnect() end
							end
						end
					end)
					
					task.delay(30, function()
						if coin and coin.Parent then coin:Destroy() end
					end)
				end
			end
			
			task.delay(5, function()
				if piano then piano:Destroy() end
				if npc then npc:Destroy() end
			end)
		end)
		
		-- Use Motor6Ds so we can animate the limbs mathematically
		local motors = {}
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") and part ~= npc.PrimaryPart then
				local motor = Instance.new("Motor6D")
				motor.Name = part.Name .. "Motor"
				local headPart = npc:FindFirstChild("Head")
				local isHeadAcc = (part ~= headPart) and (part.Name == "Hair" or (part.Parent and part.Parent:IsA("Accessory")))
				local parentPart = (isHeadAcc and headPart) or npc.PrimaryPart
				motor.Part0 = parentPart
				motor.Part1 = part
				motor.C0 = parentPart.CFrame:Inverse() * part.CFrame
				motor.C1 = CFrame.new()
				motor.Parent = npc.PrimaryPart
				
				part.Anchored = false
				part.CanCollide = false
				motors[part.Name] = motor
			end
		end
		
		-- Animate them walking (sliding) smoothly
		if npc.PrimaryPart then
			local ts = game:GetService("TweenService")
			local tween = ts:Create(npc.PrimaryPart, TweenInfo.new(totalTime, Enum.EasingStyle.Linear), {
				CFrame = startCF * CFrame.new(0, 0, -distance)
			})
			-- Driven smoothly by Heartbeat below with step bounce and sway
			
			local elapsed = 0
			animConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
				elapsed = elapsed + dt
				local phase = elapsed * 14
				local angle = math.sin(phase) * 0.75
				local alpha = math.clamp(elapsed / totalTime, 0, 1)
				local bounce = math.abs(math.sin(phase)) * 0.22
				local sway = math.sin(phase) * math.rad(6)
				npc.PrimaryPart.CFrame = startCF * CFrame.new(0, bounce, -distance * alpha) * CFrame.Angles(math.rad(-4), sway, math.cos(phase) * math.rad(2))
				
				local rl = motors["Right Leg"]
				local ll = motors["Left Leg"]
				local ra = motors["Right Arm"]
				local la = motors["Left Arm"]
				
				if rl then rl.C1 = CFrame.new(0, 1, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -1, 0) end
				if ll then ll.C1 = CFrame.new(0, 1, 0) * CFrame.Angles(-angle, 0, 0) * CFrame.new(0, -1, 0) end
				if ra then ra.C1 = CFrame.new(0, 0.5, 0) * CFrame.Angles(-angle, 0, 0) * CFrame.new(0, -0.5, 0) end
				if la then la.C1 = CFrame.new(0, 0.5, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -0.5, 0) end
				local hd = motors["Head"]
				if hd then hd.C1 = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.sin(phase * 2) * 0.08, -sway * 0.6, 0) * CFrame.new(0, 0.5, 0) end
			end)
		end
	end)
end)
-- Ragdoll deaths: keep the body in one piece and convert its joints to ball sockets
-- so it flops and tumbles (the traffic fling velocity carries straight into it).
local function ragdollOnDeath(char, humanoid)
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Connect(function()
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			for _, motor in ipairs(char:GetDescendants()) do
				if motor:IsA("Motor6D") and motor.Part0 and motor.Part1
					and not motor:FindFirstAncestor("Scooter") then
					local a0 = Instance.new("Attachment")
					a0.CFrame = motor.C0
					a0.Parent = motor.Part0
					local a1 = Instance.new("Attachment")
					a1.CFrame = motor.C1
					a1.Parent = motor.Part1
					local socket = Instance.new("BallSocketConstraint")
					socket.Attachment0 = a0
					socket.Attachment1 = a1
					socket.LimitsEnabled = true
					socket.TwistLimitsEnabled = true
					socket.UpperAngle = 45
					socket.TwistLowerAngle = -40
					socket.TwistUpperAngle = 40
					socket.Parent = motor.Part0
					motor:Destroy()
				end
			end
			-- limbs need collision to drape over the ground (the root stays non-solid)
			for _, p in ipairs(char:GetChildren()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
					p.CanCollide = true
				end
			end
		end)
	end)
end

local function createNametag(char, displayName)
	local head = char:WaitForChild("Head", 10)
	local humanoid = char:WaitForChild("Humanoid", 10)
	if not head then return end

	-- Hide default Roblox nametag
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	-- Remove existing nametag if any
	local existing = char:FindFirstChild("OverheadNametag")
	if existing then existing:Destroy() end

	local bGui = Instance.new("BillboardGui")
	bGui.Name = "OverheadNametag"
	bGui.Adornee = head
	bGui.Size = UDim2.new(0, 300, 0, 50)
	bGui.StudsOffset = Vector3.new(0, 4.0, 0)
	bGui.AlwaysOnTop = true
	bGui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "PlayerName"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.Text = displayName
	label.ZIndex = 10
	label.Parent = bGui

	bGui.Parent = char
	print("[DiscoveryBayShop] Overhead nametag created for: " .. displayName)
end

local function onCharacter(plr, char)
	charRigs[plr.UserId] = nil -- the previous character's rig is dead with it
	clearParked(plr)          -- respawning brings your scooter back to you
	task.spawn(function()
		local humanoid = char:WaitForChild("Humanoid", 10)
		if humanoid then
			ragdollOnDeath(char, humanoid)
			-- guaranteed respawn: force it 4s after death even if the ragdolled state
			-- confuses the native auto-respawn
			humanoid.Died:Connect(function()
				task.delay(4, function()
					if plr.Parent and plr.Character == char then
						plr:LoadCharacter()
					end
				end)
			end)
		end
	end)
	task.spawn(createNametag, char, plr.DisplayName)
	task.spawn(mountScooter, plr, char)
	-- insurance: if the first mount got disturbed (e.g. a car interrupted the setup),
	-- retry once so respawns ALWAYS come with a scooter
	task.delay(8, function()
		if plr.Parent and plr.Character == char and char.Parent
			and not (charRigs[plr.UserId] and charRigs[plr.UserId].char == char)
			and not char:FindFirstChild("Scooter") then
			mountScooter(plr, char)
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	setupPlayer(plr)
	checkSpeedPass(plr)
	plr.CharacterAdded:Connect(function(char)
		onCharacter(plr, char)
	end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
	setupPlayer(plr)
	checkSpeedPass(plr)
	if plr.Character then onCharacter(plr, plr.Character) end
	plr.CharacterAdded:Connect(function(char)
		onCharacter(plr, char)
	end)
end
Players.PlayerRemoving:Connect(function(plr)
	charRigs[plr.UserId] = nil
	mounting[plr.UserId] = nil
	clearParked(plr)
end)

--==============================================================================================
-- TRICKS
--==============================================================================================
local function spinDeck(rig, axis, dur, kick)
	if not rig or not rig.deckMount or rig.spinning then return end
	rig.spinning = true
	task.spawn(function()
		-- tuck the knees up while the deck whips underneath (real tailwhip form);
		-- on a kickflip one leg snaps out sideways: that's the flick
		local tucked = {}
		if rig.hips and not rig.posing then
			for idx, hh in ipairs(rig.hips) do
				if hh.motor.Parent then
					if kick and idx == 2 then
						hh.motor.C0 = hh.pose(hh.rest, -20, 0, -55)
					else
						hh.motor.C0 = hh.pose(hh.rest, kick and -62 or -55)
					end
					tucked[#tucked + 1] = hh
				end
			end
		end
		-- the arms ride the trick too; IK would fight the pose, so pause it
		local armsOn = false
		if rig.shoulders and #rig.shoulders > 0 and not rig.posing then
			armsOn = true
			for _, ik in ipairs(rig.iks) do
				if ik.Parent then ik.Enabled = false end
			end
		end
		local r6ArmsOn = rig.r6arms and not rig.posing
		local steps = 16
		local dy = rig.deckY or -3.0
		local pivot = axis == "y" and CFrame.new(0, dy, -2.2) or CFrame.new(0, dy, 0.2)
		local waistOK = rig.waist and rig.waist.motor.Parent and not rig.posing
		for i = 1, steps do
			local mount = rig.deckMount
			if not mount or not mount.Parent then break end
			local a = (i / steps) * math.pi * 2
			local rot = axis == "y" and CFrame.Angles(0, a, 0) or CFrame.Angles(0, 0, a)
			local wave = math.sin((i / steps) * math.pi)
			mount.C0 = rig.deckBase * pivot * rot * pivot:Inverse()
			if rig.barMount and rig.barMount.Parent then
				if axis == "z" then
					rig.barMount.C0 = rig.barBase * pivot * rot * pivot:Inverse()
				else
					rig.barMount.C0 = rig.barBase * CFrame.Angles(math.rad(-10 * wave), math.rad(20 * math.sin(a)), math.rad(12 * math.sin(a)))
				end
			end
			if waistOK then
				if axis == "y" then
					rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(math.rad(-24 * wave), 0, 0)
				else
					rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(0, 0, math.rad(26 * wave))
				end
			end
			if armsOn then
				for idx, sh in ipairs(rig.shoulders) do
					if sh.motor.Parent then
						local side = (idx == 1) and 1 or -1
						sh.motor.C0 = sh.pose(sh.rest, -38 * wave, 0, 10 * wave * side)
					end
				end
			end
			if r6ArmsOn then
				for _, ra in ipairs(rig.r6arms) do
					if ra.weld and ra.weld.Parent then
						ra.weld.C0 = ra.gripC0 * CFrame.Angles(math.rad(-22 * wave), 0, 0)
					end
				end
			end
			task.wait(dur / steps)
		end
		if rig.deckMount and rig.deckMount.Parent then
			rig.deckMount.C0 = rig.deckBase
		end
		if rig.barMount and rig.barMount.Parent then
			rig.barMount.C0 = rig.barBase
		end
		if waistOK and rig.waist.motor.Parent then
			rig.waist.motor.C0 = rig.waist.rest
		end
		for _, hh in ipairs(tucked) do
			if hh.motor.Parent then hh.motor.C0 = hh.rest end
		end
		if armsOn then
			for _, sh in ipairs(rig.shoulders) do
				if sh.motor.Parent then sh.motor.C0 = sh.rest end
			end
			for _, ik in ipairs(rig.iks) do
				if ik.Parent then ik.Enabled = true end
			end
		end
		if r6ArmsOn then
			for _, ra in ipairs(rig.r6arms) do
				if ra.weld and ra.weld.Parent then ra.weld.C0 = ra.gripC0 end
			end
		end
		rig.spinning = false
	end)
end

local function legsBack(rig, dur)
	if not rig or not rig.hips or #rig.hips == 0 or rig.posing or rig.spinning then return end
	rig.posing = true
	-- legs kick back at staggered angles with a slight splay: reads as real flight
	for idx, h in ipairs(rig.hips) do
		if h.motor.Parent then
			local pitch = (idx == 1) and -70 or -86
			local yaw = (idx == 1) and 9 or -9
			h.motor.C0 = h.pose(h.rest, pitch, yaw)
		end
	end
	-- arms punch straight ahead (IK paused): the full flying-superman silhouette
	for _, ik in ipairs(rig.iks) do
		if ik.Parent then ik.Enabled = false end
	end
	for idx, s in ipairs(rig.shoulders or {}) do
		if s.motor.Parent then
			s.motor.C0 = s.pose(s.rest, 85, 0, (idx == 1) and 8 or -8)
		end
	end
	if rig.r6arms then
		for _, ra in ipairs(rig.r6arms) do
			if ra.weld and ra.weld.Parent then
				ra.weld.C0 = ra.gripC0 * CFrame.Angles(math.rad(28), 0, 0)
			end
		end
	end
	-- arch the chest up for the full superman silhouette
	if rig.waist and rig.waist.motor.Parent then
		rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(math.rad(20), 0, 0)
	end
	task.delay(dur, function()
		for _, h in ipairs(rig.hips) do
			if h.motor.Parent then h.motor.C0 = h.rest end
		end
		for _, s in ipairs(rig.shoulders or {}) do
			if s.motor.Parent then s.motor.C0 = s.rest end
		end
		if rig.r6arms then
			for _, ra in ipairs(rig.r6arms) do
				if ra.weld and ra.weld.Parent then ra.weld.C0 = ra.gripC0 end
			end
		end
		if rig.waist and rig.waist.motor.Parent then
			rig.waist.motor.C0 = rig.waist.rest
		end
		for _, ik in ipairs(rig.iks) do
			if ik.Parent then ik.Enabled = true end
		end
		rig.posing = false
	end)
end

local function armsBack(rig, dur)
	if not rig or rig.posing or rig.spinning then return end
	local hasArms = (rig.shoulders and #rig.shoulders > 0) or rig.r6arms
	if not hasArms then return end
	rig.posing = true
	task.spawn(function()
		for _, ik in ipairs(rig.iks or {}) do
			if ik.Parent then ik.Enabled = false end
		end
		local steps = 16
		for i = 1, steps do
			local p = i / steps
			local wave = math.sin(p * math.pi)
			for idx, s in ipairs(rig.shoulders or {}) do
				if s.motor.Parent then
					local side = (idx == 1) and -1 or 1
					s.motor.C0 = s.pose(s.rest, 115 * wave, 0, side * 52 * wave)
				end
			end
			if rig.r6arms then
				for idx, ra in ipairs(rig.r6arms) do
					if ra.weld and ra.weld.Parent then
						local side = (idx == 1) and -1 or 1
						ra.weld.C0 = ra.gripC0 * CFrame.Angles(math.rad(85 * wave), 0, math.rad(side * 45 * wave))
					end
				end
			end
			if rig.waist and rig.waist.motor.Parent then
				rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(math.rad(22 * wave), 0, 0)
			end
			if rig.deckMount and rig.deckMount.Parent then
				rig.deckMount.C0 = rig.deckBase * CFrame.Angles(math.rad(18 * wave), 0, 0)
			end
			if rig.barMount and rig.barMount.Parent then
				rig.barMount.C0 = rig.barBase * CFrame.Angles(math.rad(18 * wave), 0, 0)
			end
			task.wait(dur / steps)
		end
		for _, s in ipairs(rig.shoulders or {}) do
			if s.motor.Parent then s.motor.C0 = s.rest end
		end
		if rig.r6arms then
			for _, ra in ipairs(rig.r6arms) do
				if ra.weld and ra.weld.Parent then ra.weld.C0 = ra.gripC0 end
			end
		end
		if rig.waist and rig.waist.motor.Parent then
			rig.waist.motor.C0 = rig.waist.rest
		end
		if rig.deckMount and rig.deckMount.Parent then
			rig.deckMount.C0 = rig.deckBase
		end
		if rig.barMount and rig.barMount.Parent then
			rig.barMount.C0 = rig.barBase
		end
		for _, ik in ipairs(rig.iks or {}) do
			if ik.Parent then ik.Enabled = true end
		end
		rig.posing = false
	end)
end

local function fullFlipOrSpin(rig, mode, dur)
	if not rig or rig.spinning or rig.posing then return end
	rig.spinning = true
	task.spawn(function()
		for _, ik in ipairs(rig.iks or {}) do
			if ik.Parent then ik.Enabled = false end
		end
		local steps = 18
		for i = 1, steps do
			local p = i / steps
			local a = p * math.pi * 2
			local wave = math.sin(p * math.pi)
			local rot
			if mode == "Backflip" then
				rot = CFrame.new(0, 1.1 * wave, 0) * CFrame.Angles(a, 0, 0)
			elseif mode == "Frontflip" then
				rot = CFrame.new(0, 1.1 * wave, 0) * CFrame.Angles(-a, 0, 0)
			else
				rot = CFrame.new(0, 0.7 * wave, 0) * CFrame.Angles(0, a, math.rad(12 * wave))
			end
			if rig.root and rig.root.motor and rig.root.motor.Parent then
				rig.root.motor.C0 = rig.root.rest * rot
			end
			if rig.deckMount and rig.deckMount.Parent then
				rig.deckMount.C0 = rig.deckBase * rot
			end
			if rig.barMount and rig.barMount.Parent then
				local barExtra = (mode == "360 Spin") and CFrame.Angles(0, math.rad(45 * wave), 0) or CFrame.new()
				rig.barMount.C0 = rig.barBase * rot * barExtra
			end
			if rig.hips then
				for _, hh in ipairs(rig.hips) do
					if hh.motor.Parent then
						hh.motor.C0 = hh.pose(hh.rest, -50 * wave)
					end
				end
			end
			task.wait(dur / steps)
		end
		if rig.root and rig.root.motor and rig.root.motor.Parent then
			rig.root.motor.C0 = rig.root.rest
		end
		if rig.deckMount and rig.deckMount.Parent then
			rig.deckMount.C0 = rig.deckBase
		end
		if rig.barMount and rig.barMount.Parent then
			rig.barMount.C0 = rig.barBase
		end
		if rig.hips then
			for _, hh in ipairs(rig.hips) do
				if hh.motor.Parent then hh.motor.C0 = hh.rest end
			end
		end
		for _, ik in ipairs(rig.iks or {}) do
			if ik.Parent then ik.Enabled = true end
		end
		rig.spinning = false
	end)
end

local TRICKS = {
	{ name = "Tailwhip", pay = 4, fn = function(rig, hrp) spinDeck(rig, "y", 0.52) end },
	{ name = "Kickflip", pay = 3, fn = function(rig, hrp) spinDeck(rig, "z", 0.55, true) end },
	{ name = "360 Spin", pay = 6, fn = function(rig, hrp) fullFlipOrSpin(rig, "360 Spin", 0.52) end },
	{ name = "Backflip", pay = 10, fn = function(rig, hrp) fullFlipOrSpin(rig, "Backflip", 0.58) end },
	{ name = "Frontflip", pay = 10, fn = function(rig, hrp) fullFlipOrSpin(rig, "Frontflip", 0.58) end },
	{ name = "No-Hander", pay = 5, fn = function(rig, hrp) armsBack(rig, 0.55) end },
}
local TRICK_BY_NAME = {}
for _, t in ipairs(TRICKS) do
	TRICK_BY_NAME[t.name] = t
end
local lastTrick = {}

DoTrick.OnServerEvent:Connect(function(plr, trickName)
	local char = plr.Character
	local rig = charRigs[plr.UserId]
	-- the rig for the CURRENT character is the source of truth; the attribute only
	-- mirrors it (and self-heals here if it ever goes stale)
	if not (rig and char and rig.char == char) then
		TrickResult:FireClient(plr, "Hop on your scooter first! (G)", 0)
		return
	end
	if not plr:GetAttribute("Mounted") then
		plr:SetAttribute("Mounted", true)
		updateSpeed(plr)
	end
	local now = os.clock()
	if lastTrick[plr.UserId] and now - lastTrick[plr.UserId] < TRICK_COOLDOWN then return end
	lastTrick[plr.UserId] = now
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or humanoid.Health <= 0 then return end

	local trick
	if type(trickName) == "string" then
		trick = TRICK_BY_NAME[trickName]
	end
	if not trick then
		trick = TRICKS[rng:NextInteger(1, #TRICKS)]
	end

	local function perform()
		local cash = getCash(plr)
		if not cash or humanoid.Health <= 0 then return end
		-- Client RenderStepped handles 60fps trick & riding body/scooter animations without server C0/IK replication conflicts
		local pay = trick.pay * (plr:GetAttribute("TrickMult") or 1) * getMult(plr)
		if plr:GetAttribute("CarbLoad") then pay = pay * 1.25 end
		pay = math.floor(pay)
		cash.Value = cash.Value + pay
		TrickResult:FireClient(plr, trick.name, pay)

		-- Spawn a burst of sparks from the back wheel when executing a trick
		local scooter = char:FindFirstChild("Scooter")
		local rearWheel = scooter and scooter:FindFirstChild("RearWheel")
		local emitter = rearWheel and rearWheel:FindFirstChild("SparkEmitter")
		if emitter and pcall(function() return emitter.Emit end) then
			pcall(function() emitter:Emit(40) end)
		end
	end

	if humanoid.FloorMaterial == Enum.Material.Air then
		perform()
	else
		local v = hrp.AssemblyLinearVelocity
		local jumpV = 48
		if plr:GetAttribute("CarbLoad") then jumpV = 35 end
		if plr:GetAttribute("BeanPower") then jumpV = 85 end
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, jumpV, v.Z)
		task.delay(0.05, perform)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastTrick[plr.UserId] = nil
end)

--==============================================================================================
-- SHOP (purchase effects)
--==============================================================================================
local function bumpAttribute(plr, attr, step, cap)
	local v = math.min((plr:GetAttribute(attr) or 0) + step, cap)
	plr:SetAttribute(attr, v)
	return v
end

local EFFECTS = {
	["Bloxy Cola"] = function(plr)
		bumpAttribute(plr, "SodaBoost", 4, 20)
		updateSpeed(plr)
		return "Bloxy Cola rush! Scooter speed +4"
	end,
	["Vanilla Cone"] = function(plr)
		bumpAttribute(plr, "VanillaBoost", 6, 18)
		updateSpeed(plr)
		return "Vanilla! Scooter speed +6"
	end,
	["Chocolate Cone"] = function(plr)
		bumpAttribute(plr, "WalkBoost", 8, 16)
		updateSpeed(plr)
		return "Chocolate! Walking speed +8"
	end,
	["Mint Cone"] = function(plr)
		plr:SetAttribute("TrickMult", 2)
		return "MINT POWER! Trick payouts x2"
	end,
	["Bait Pack"] = function(plr)
		local n = (plr:GetAttribute("Bait") or 0) + 5
		plr:SetAttribute("Bait", n)
		return "Bait +5! You have " .. n .. " bait"
	end,
}

local function hookProduct(part)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	local product = part:GetAttribute("Product")
	local price = part:GetAttribute("Price") or 0
	local normalText = prompt.ObjectText
	prompt.Triggered:Connect(function(plr)
		local cash = getCash(plr)
		if not cash or not product then return end
		if cash.Value < price then
			prompt.ObjectText = "Not enough cash!"
			task.delay(1.5, function()
				prompt.ObjectText = normalText
			end)
			return
		end
		local kit = ReplicatedStorage:FindFirstChild("DiscoveryBayKit")
		local tools = kit and kit:FindFirstChild("Products")
		local tool = tools and tools:FindFirstChild(product)
		if not tool then return end
		cash.Value = cash.Value - price
		local backpack = plr:FindFirstChildOfClass("Backpack")
		if backpack then
			tool:Clone().Parent = backpack
		end
		local effect = EFFECTS[product]
		if effect then
			local msg = effect(plr)
			if msg then
				TrickResult:FireClient(plr, msg, 0)
			end
		end
	end)
end

--==============================================================================================
-- JIU JITSU CHALLENGE (step on the dojo mat)
--==============================================================================================
local JJ_CLICKS = 7      -- buttons to hit
local JJ_WIN = 50        -- prize
local JJ_TIMEOUT = 5     -- seconds per button
local JJ_PENALTY = 5     -- cost of a missed button (can push you into debt)
local jjActive = {}

-- standing on the mat = feet within its footprint (a little margin, sane height range)
local function onMat(mat, hrp)
	local rel = mat.CFrame:PointToObjectSpace(hrp.Position)
	return math.abs(rel.X) <= mat.Size.X / 2 + 3
		and math.abs(rel.Z) <= mat.Size.Z / 2 + 3
		and rel.Y > -4 and rel.Y < 14
end

local function runChallenge(plr, mat)
	local uid = plr.UserId
	local state = { clicks = 0 }
	jjActive[uid] = state
	TrickResult:FireClient(plr, "JIU JITSU CHALLENGE! Click " .. JJ_CLICKS .. " buttons!", 0)
	local town = workspace:FindFirstChild("DiscoveryBay") or workspace
	while state.clicks < JJ_CLICKS do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not plr.Parent or not hrp or not hum or hum.Health <= 0
			or not onMat(mat, hrp) then
			TrickResult:FireClient(plr, "Challenge abandoned - you left the mat!", 0)
			break
		end
		-- glowing button at a random spot above the mat
		local half = mat.Size / 2
		local btn = Instance.new("Part")
		btn.Name = "JJButton"
		btn.Shape = Enum.PartType.Ball
		btn.Size = Vector3.new(2, 2, 2)
		btn.Color = Color3.fromRGB(255, 70, 70)
		btn.Material = Enum.Material.Neon
		btn.Anchored = true
		btn.CanCollide = false
		btn.CFrame = mat.CFrame * CFrame.new(
			rng:NextNumber(-half.X + 2, half.X - 2),
			rng:NextNumber(3, 8),
			rng:NextNumber(-half.Z + 2, half.Z - 2))
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 40
		click.Parent = btn
		btn.Parent = town
		local clicked = false
		click.MouseClick:Connect(function(who)
			if who == plr then clicked = true end
		end)
		-- stepping off the mat mid-button aborts IMMEDIATELY, with no penalty
		local left = false
		local t0 = os.clock()
		while not clicked and os.clock() - t0 < JJ_TIMEOUT do
			task.wait(0.1)
			local ch2 = plr.Character
			local hrp2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
			if not hrp2 or not onMat(mat, hrp2) then
				left = true
				break
			end
		end
		btn:Destroy()
		if left then
			TrickResult:FireClient(plr, "Challenge abandoned - you left the mat!", 0)
			break
		end
		local cash = getCash(plr)
		if not cash then break end
		if clicked then
			state.clicks = state.clicks + 1
			if state.clicks < JJ_CLICKS then
				TrickResult:FireClient(plr, "Hit! " .. state.clicks .. "/" .. JJ_CLICKS, 0)
			end
		else
			cash.Value = cash.Value - JJ_PENALTY -- yes, straight into debt if you're broke
			TrickResult:FireClient(plr, "Too slow! -$" .. JJ_PENALTY, 0)
		end
	end
	if state.clicks >= JJ_CLICKS then
		local cash = getCash(plr)
		if cash then
			cash.Value = cash.Value + JJ_WIN
		end
		TrickResult:FireClient(plr, "JIU JITSU CHAMPION!", JJ_WIN)
	end
	task.wait(2) -- step-off grace before the mat can rearm
	jjActive[uid] = nil
end

local function hookMat(mat)
	mat.Touched:Connect(function(hit)
		local node = hit and hit.Parent
		local plr = node and Players:GetPlayerFromCharacter(node)
		if not plr and node and node.Parent then
			plr = Players:GetPlayerFromCharacter(node.Parent) -- scooter/accessory parts
		end
		if plr and not jjActive[plr.UserId] then
			task.spawn(runChallenge, plr, mat)
		end
	end)
end

-- STUDY BUTTONS (Discovery Bay Elementary classrooms): hold one to finish "studying";
-- when you let go of a completed hold, your scooter is +10 faster for 15 minutes
local EDU_BOOST = 10
local EDU_DURATION = 900
local eduToken = {}

local function hookStudy(part)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(plr)
		plr:SetAttribute("EduBoost", EDU_BOOST)
		updateSpeed(plr)
		TrickResult:FireClient(plr, "BIG BRAIN! Scooter +" .. EDU_BOOST .. " for 15 minutes", 0)
		local token = (eduToken[plr.UserId] or 0) + 1
		eduToken[plr.UserId] = token
		task.delay(EDU_DURATION, function()
			if plr.Parent and eduToken[plr.UserId] == token then
				plr:SetAttribute("EduBoost", 0)
				updateSpeed(plr)
				TrickResult:FireClient(plr, "Study buff wore off - back to class!", 0)
			end
		end)
	end)
end

--==============================================================================================
-- AUTO-SLIDING DOORS (shops, and rented houses' front doors)
--==============================================================================================
local function hookDoor(part)
	local closedCf = part.CFrame
	local dist = part:GetAttribute("SlideDist") or 3.5
	local openCf = closedCf * CFrame.new(dist, 0, 0)
	local isOpen = false
	task.spawn(function()
		while part.Parent do
			local near = false
			for _, plr in ipairs(Players:GetPlayers()) do
				local ch = plr.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - closedCf.Position).Magnitude < 10 then
					near = true
					break
				end
			end
			if near ~= isOpen then
				isOpen = near
				TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out), { CFrame = isOpen and openCf or closedCf }):Play()
			end
			task.wait(0.25)
		end
	end)
end

-- rented houses get a HINGED front door: swings inward on its edge like a normal door
local function hookSwingDoor(part)
	local closedCf = part.CFrame
	local halfW = part.Size.X / 2
	local hinge = closedCf * CFrame.new(-halfW, 0, 0)
	local openCf = hinge * CFrame.Angles(0, math.rad(-105), 0) * CFrame.new(halfW, 0, 0)
	local isOpen = false
	task.spawn(function()
		while part.Parent do
			local near = false
			for _, plr in ipairs(Players:GetPlayers()) do
				local ch = plr.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - closedCf.Position).Magnitude < 9 then
					near = true
					break
				end
			end
			if near ~= isOpen then
				isOpen = near
				TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out), { CFrame = isOpen and openCf or closedCf }):Play()
			end
			task.wait(0.25)
		end
	end)
end

--==============================================================================================
-- HOUSES FOR RENT + EGG SHOP DOGS
--==============================================================================================
local EGG_PRICE = 30
local PET_COOLDOWN = 1
local DOGS = {
	-- Mary: doberman pinscher, black & brown (49.5%)
	{ name = "Mary", pay = 10, scale = 1,
		color = Color3.fromRGB(38, 32, 30), accent = Color3.fromRGB(150, 95, 50) },
	-- Jolene: great dane, grey & white mix (49.5%) — big girl
	{ name = "Jolene", pay = 10, scale = 1.25,
		color = Color3.fromRGB(168, 170, 175), accent = Color3.fromRGB(245, 245, 245) },
	-- Linus: doberman, brown/tan (1% legendary, still glows)
	{ name = "Linus", pay = 100, scale = 1,
		color = Color3.fromRGB(175, 125, 75), accent = Color3.fromRGB(120, 80, 45) },
}
local ownedHouse = {} -- uid -> { house = Model, board = Part }
local playerDog = {}  -- uid -> Model
local petStamp = {}   -- dog Model -> last pet time

local function setRentSign(board, text, color)
	board.Color = color
	local sgui = board:FindFirstChildOfClass("SurfaceGui")
	local label = sgui and sgui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
		label.BackgroundColor3 = color
	end
end

local function makeSign(part, face, text, bg, fg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg
	label.TextColor3 = fg
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.Parent = sg
end

local WALL_PAINTS = { Color3.fromRGB(226, 208, 180), Color3.fromRGB(188, 212, 226), Color3.fromRGB(206, 222, 190),
	Color3.fromRGB(232, 200, 188), Color3.fromRGB(212, 202, 230) }
local SOFA_COLORS = { Color3.fromRGB(70, 95, 140), Color3.fromRGB(150, 70, 60), Color3.fromRGB(85, 120, 90),
	Color3.fromRGB(125, 115, 105), Color3.fromRGB(200, 150, 60) }
local ACCENTS = { Color3.fromRGB(230, 90, 80), Color3.fromRGB(80, 150, 230), Color3.fromRGB(250, 200, 70),
	Color3.fromRGB(140, 90, 200), Color3.fromRGB(70, 180, 140) }
local WOOD = Color3.fromRGB(160, 115, 72)
local DARK_WOOD = Color3.fromRGB(85, 58, 38)
local WHITE = Color3.fromRGB(240, 238, 232)
local STEEL = Color3.fromRGB(200, 205, 210)
local BLACK = Color3.fromRGB(28, 28, 32)
local LEAF = Color3.fromRGB(70, 150, 70)
local WARM = Color3.fromRGB(255, 214, 160)

local function mk(parent, name, sz, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = sz
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- A wall along the frame's local X (centre of the wall), local +Z pointing into the room, with
-- rectangular holes { x0, x1, y0, y1 } (y measured up from the wall's bottom) left open.
local function holedWall(parent, name, frame, L, H, T, zOff, holes, color, material)
	local xs = { -L / 2, L / 2 }
	for _, ho in ipairs(holes) do
		if ho.x1 > -L / 2 and ho.x0 < L / 2 then
			table.insert(xs, math.clamp(ho.x0, -L / 2, L / 2))
			table.insert(xs, math.clamp(ho.x1, -L / 2, L / 2))
		end
	end
	table.sort(xs)
	for i = 1, #xs - 1 do
		local a, b = xs[i], xs[i + 1]
		if b - a > 0.05 then
			local mid = (a + b) / 2
			local covering = {}
			for _, ho in ipairs(holes) do
				if ho.x0 < mid and ho.x1 > mid then table.insert(covering, ho) end
			end
			table.sort(covering, function(p, q) return p.y0 < q.y0 end)
			local function seg(y0, y1)
				if y1 - y0 > 0.05 then
					mk(parent, name, Vector3.new(b - a, y1 - y0, T),
						frame * CFrame.new(mid, -H / 2 + (y0 + y1) / 2, zOff), color, material)
				end
			end
			local y = 0
			for _, ho in ipairs(covering) do
				seg(y, ho.y0)
				y = math.max(y, ho.y1)
			end
			seg(y, H)
		end
	end
end

-- Renting a house makes it REAL: the solid body is swapped for two-layer walls (outside finish +
-- painted inside) with see-through windows and a walk-through front door, plus a furnished
-- open-plan home: living room, kitchen, dining, bed corner and a dog corner with the Auto-Petter.
-- Runs once per house (when a player first walks near it, or rents it).
local function hollowHouse(house)
	if house:GetAttribute("Hollowed") then return end
	house:SetAttribute("Hollowed", true)
	local body = house:FindFirstChild("Body")
	if not body then return end
	local cfB, size = body.CFrame, body.Size
	local col, mat = body.Color, body.Material
	local w, h, d = size.X, size.Y, size.Z
	body:Destroy()

	local rnd = Random.new(math.floor(cfB.X * 7 + cfB.Z * 13))
	local function pick(t) return t[rnd:NextInteger(1, #t)] end
	local paint = pick(WALL_PAINTS)
	local sofaCol = pick(SOFA_COLORS)
	local accent = pick(ACCENTS)

	local interior = Instance.new("Model")
	interior.Name = "Interior"
	interior.Parent = house

	local function addHole(list, xc, wdt, y0, y1)
		table.insert(list, { x0 = xc - wdt / 2, x1 = xc + wdt / 2, y0 = y0, y1 = y1 })
	end
	local function buildWall(name, frame, L, H, holes, paintL)
		holedWall(house, name, frame, L, H, 0.5, -0.15, holes, col, mat)
		holedWall(interior, name .. "Paint", frame, paintL or (L - 1.6), H, 0.3, 0.25, holes, paint)
	end
	-- glass already on the outside of a wall becomes a real window: cut a hole behind it
	local glassParts = {}
	for _, c in ipairs(house:GetChildren()) do
		if c:IsA("BasePart") and (c.Name == "Window" or c.Name == "WindowMain" or c.Name == "Window2" or c.Name == "GlassBand") then
			table.insert(glassParts, c)
		end
	end
	local function glassHolesOn(list, frontZ, centerX, centerY, H)
		for _, g in ipairs(glassParts) do
			local rel = cfB:ToObjectSpace(g.CFrame)
			if math.abs(rel.Z - frontZ) < 0.8 then
				addHole(list, rel.X - centerX, g.Size.X - 0.3,
					rel.Y - centerY + H / 2 - g.Size.Y / 2 + 0.15, rel.Y - centerY + H / 2 + g.Size.Y / 2 - 0.15)
				g.Transparency = 0.55
			end
		end
	end
	local function newWindowPane(frame, xLocal, y0, y1, wdt, H)
		mk(interior, "WindowPane", Vector3.new(wdt + 0.2, y1 - y0 + 0.2, 0.15),
			frame * CFrame.new(xLocal, -H / 2 + (y0 + y1) / 2, -0.15), Color3.fromRGB(170, 215, 235), Enum.Material.Glass).Transparency = 0.6
		mk(interior, "WindowSill", Vector3.new(wdt + 0.8, 0.25, 0.9),
			frame * CFrame.new(xLocal, -H / 2 + y0 - 0.1, 0.35), WHITE)
	end

	-- door: on the main front wall, or on the front of an L-shaped house's wing
	local door = house:FindFirstChild("Door")
	local doorRel = door and cfB:PointToObjectSpace(door.Position)
	if door then
		-- a REAL front door: swings open on its hinges when you walk up
		door:SetAttribute("SwingDoor", true)
		hookSwingDoor(door)
	end
	-- towns saved before v35 have a solid decorative slab over the doorway; unblock it
	local oldFrame = house:FindFirstChild("DoorFrame")
	if oldFrame then
		oldFrame.CanCollide = false
	end
	local DOOR_W, DOOR_H = 5.5, 7.6

	local frontHoles, backHoles, leftHoles, rightHoles = {}, {}, {}, {}
	local doorX = 0
	local doorOnBody = doorRel ~= nil and math.abs(doorRel.Z + d / 2) < 1.2
	if doorOnBody then
		doorX = math.clamp(doorRel.X, -w / 2 + 4, w / 2 - 4)
		addHole(frontHoles, doorX, DOOR_W, 0, DOOR_H)
	end
	glassHolesOn(frontHoles, -d / 2, 0, 0, h)

	-- L-shaped houses: the wing becomes an entry hall that opens into the main room
	local wing = house:FindFirstChild("Wing")
	local wingInfo = nil
	if wing then
		local wrel = cfB:ToObjectSpace(wing.CFrame)
		local ws = wing.Size
		local wf, bf = wrel.Z - ws.Z / 2, -d / 2
		if wf < bf - 3 then
			wing:Destroy()
			local wx, wy, wh = wrel.X, wrel.Y, ws.Y
			-- the wing's roof ran back into the main body; trim it at the main front wall so it
			-- doesn't poke down into the main room (its ridge runs along body Z, i.e. its local X)
			for _, r in ipairs(house:GetChildren()) do
				if r:IsA("WedgePart") then
					local rr = cfB:ToObjectSpace(r.CFrame)
					if math.abs(rr.X - wx) < ws.X / 2 + 1 and rr.Y - r.Size.Y / 2 < h / 2 - 0.5 then
						local z0 = rr.Z - r.Size.X / 2
						local z1 = math.min(rr.Z + r.Size.X / 2, bf + 0.4)
						if z1 - z0 > 1 then
							r.Size = Vector3.new(z1 - z0, r.Size.Y, r.Size.Z)
							r.CFrame = cfB * CFrame.new(rr.X, rr.Y, (z0 + z1) / 2) * rr.Rotation
						end
					end
				end
			end
			local len = bf - wf
			wingInfo = { x = wx, front = wf, len = len, wdt = ws.X, h = wh, floorY = wy - wh / 2 + 0.4 }
			mk(house, "Floor", Vector3.new(ws.X, 0.4, len), cfB * CFrame.new(wx, wy - wh / 2 + 0.2, wf + len / 2),
				Color3.fromRGB(160, 125, 85), Enum.Material.WoodPlanks)
			mk(house, "Ceiling", Vector3.new(ws.X, 0.4, len), cfB * CFrame.new(wx, wy + wh / 2 - 0.2, wf + len / 2),
				Color3.fromRGB(238, 234, 224))
			local wHoles = {}
			if doorRel and not doorOnBody then
				addHole(wHoles, doorRel.X - wx, DOOR_W, 0, DOOR_H)
				doorX = wx
			end
			glassHolesOn(wHoles, wf, wx, wy, wh)
			buildWall("WingFront", cfB * CFrame.new(wx, wy, wf + 0.4), ws.X, wh, wHoles)
			local sideLen = len - 0.8
			local zc = wf + 0.8 + sideLen / 2
			buildWall("WingSideL", cfB * CFrame.new(wx - ws.X / 2 + 0.4, wy, zc) * CFrame.Angles(0, math.pi / 2, 0), sideLen, wh, {}, sideLen)
			buildWall("WingSideR", cfB * CFrame.new(wx + ws.X / 2 - 0.4, wy, zc) * CFrame.Angles(0, -math.pi / 2, 0), sideLen, wh, {}, sideLen)
			-- wide opening from the wing into the main room
			addHole(frontHoles, wx, ws.X - 1.6, 0, math.min(wh, h) - 1.2)
		end
	end

	local iw, idp = w - 1.6, d - 1.6
	local zMin, zMax = -idp / 2, idp / 2
	local y0 = -h / 2 + 0.4
	local sD = doorX >= 0 and 1 or -1 -- door side
	local sA = -sD                    -- living side
	local function F(x, z, yaw)
		return cfB * CFrame.new(x, y0, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	-- yaw that turns a piece's front (local -Z) to face +X / -X / +Z
	local FACE_PX, FACE_NX, FACE_PZ = -math.pi / 2, math.pi / 2, math.pi

	local hasKitchen = iw >= 22 and idp >= 12
	local hasDining = iw >= 30 and idp >= 22
	local hasBed = iw >= 22 and idp >= 22
	local sofaDist = math.clamp(idp * 0.45, 7, 12)
	local runLen = math.clamp(iw * 0.32, 10.5, 15)
	local SINK_DIST = 4.9                                  -- from the door-side wall
	local stoveDist = math.max(runLen - 1.6, SINK_DIST + 3.7) -- clear of the sink window
	local sinkX = sD * (iw / 2 - SINK_DIST)
	local diningZ = zMax - 9

	-- extra windows: over the kitchen sink and beside the dining table
	if hasKitchen and h >= 9 then
		addHole(backHoles, -sinkX, 4.4, 4.4, 7.4)
	end
	if hasDining and h >= 9 then
		addHole(sD > 0 and rightHoles or leftHoles, sD > 0 and diningZ or -diningZ, 5, 3.4, 7.2)
	end

	mk(house, "Floor", Vector3.new(w, 0.4, d), cfB * CFrame.new(0, -h / 2 + 0.2, 0),
		Color3.fromRGB(160, 125, 85), Enum.Material.WoodPlanks)
	mk(house, "Ceiling", Vector3.new(w, 0.4, d), cfB * CFrame.new(0, h / 2 - 0.2, 0), Color3.fromRGB(238, 234, 224))
	buildWall("FrontWall", cfB * CFrame.new(0, 0, -d / 2 + 0.4), w, h, frontHoles)
	buildWall("BackWall", cfB * CFrame.new(0, 0, d / 2 - 0.4) * CFrame.Angles(0, math.pi, 0), w, h, backHoles)
	buildWall("SideL", cfB * CFrame.new(-w / 2 + 0.4, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), d - 1.6, h, leftHoles, d - 1.6)
	buildWall("SideR", cfB * CFrame.new(w / 2 - 0.4, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), d - 1.6, h, rightHoles, d - 1.6)
	for _, ho in ipairs(backHoles) do
		newWindowPane(cfB * CFrame.new(0, 0, d / 2 - 0.4) * CFrame.Angles(0, math.pi, 0), (ho.x0 + ho.x1) / 2, ho.y0, ho.y1, ho.x1 - ho.x0, h)
	end
	for _, ho in ipairs(leftHoles) do
		newWindowPane(cfB * CFrame.new(-w / 2 + 0.4, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), (ho.x0 + ho.x1) / 2, ho.y0, ho.y1, ho.x1 - ho.x0, h)
	end
	for _, ho in ipairs(rightHoles) do
		newWindowPane(cfB * CFrame.new(w / 2 - 0.4, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), (ho.x0 + ho.x1) / 2, ho.y0, ho.y1, ho.x1 - ho.x0, h)
	end
	-- baseboards (no front one so the doorway stays flat)
	mk(interior, "Baseboard", Vector3.new(iw, 0.6, 0.15), F(0, zMax - 0.05) * CFrame.new(0, 0.3, 0), WHITE)
	mk(interior, "Baseboard", Vector3.new(0.15, 0.6, idp), F(-iw / 2 + 0.05, 0) * CFrame.new(0, 0.3, 0), WHITE)
	mk(interior, "Baseboard", Vector3.new(0.15, 0.6, idp), F(iw / 2 - 0.05, 0) * CFrame.new(0, 0.3, 0), WHITE)

	local function ceilingLight(x, z, withLight, ceilH)
		local yTop = (ceilH or h) - 0.8
		local hang = math.max(yTop - 9.2, 0)
		if hang > 0.5 then
			mk(interior, "LightCord", Vector3.new(0.12, hang, 0.12), F(x, z) * CFrame.new(0, yTop - hang / 2, 0), BLACK)
		end
		local fixture = mk(interior, "CeilingLight", Vector3.new(0.5, 2.6, 2.6),
			F(x, z) * CFrame.new(0, yTop - hang - 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), WARM, Enum.Material.Neon, Enum.PartType.Cylinder)
		if withLight then
			local l = Instance.new("PointLight")
			l.Range = 22
			l.Brightness = 0.6
			l.Color = WARM
			l.Parent = fixture
		end
	end
	local function plant(x, z)
		mk(interior, "PlantPot", Vector3.new(1.6, 1.8, 1.8), F(x, z) * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(190, 105, 70), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		mk(interior, "PlantLeaves", Vector3.new(2.6, 2.6, 2.6), F(x, z) * CFrame.new(0, 2.6, 0), LEAF, Enum.Material.Grass, Enum.PartType.Ball)
		mk(interior, "PlantLeaves", Vector3.new(1.8, 1.8, 1.8), F(x, z) * CFrame.new(0.3, 3.7, -0.2),
			Color3.fromRGB(95, 175, 85), Enum.Material.Grass, Enum.PartType.Ball)
	end

	-- LIVING ROOM (living side, back): TV console against the back wall, sofa facing it, rug + coffee table
	if iw >= 14 and idp >= 10 then
		local lx = sA * math.min(iw * 0.25, iw / 2 - 5)
		local tv = F(lx, zMax - 0.9)
		mk(interior, "TVConsole", Vector3.new(7, 1.8, 1.6), tv * CFrame.new(0, 0.9, 0), DARK_WOOD, Enum.Material.WoodPlanks)
		mk(interior, "TV", Vector3.new(6, 3.4, 0.3), tv * CFrame.new(0, 3.85, 0.3), BLACK)
		mk(interior, "TVScreen", Vector3.new(5.6, 3, 0.1), tv * CFrame.new(0, 3.85, 0.12), Color3.fromRGB(60, 120, 200), Enum.Material.Neon)
		mk(interior, "Soundbar", Vector3.new(3.6, 0.4, 0.6), tv * CFrame.new(0, 2, -0.3), BLACK)
		mk(interior, "GameConsole", Vector3.new(1.2, 0.3, 0.9), tv * CFrame.new(2.4, 1.95, -0.1), WHITE)

		local sofa = F(lx, zMax - sofaDist, FACE_PZ)
		mk(interior, "Sofa", Vector3.new(7, 1.4, 3), sofa * CFrame.new(0, 0.7, 0), sofaCol, Enum.Material.Fabric)
		for _, sx in ipairs({ -1.7, 1.7 }) do
			mk(interior, "SofaCushion", Vector3.new(3.3, 0.6, 2.5), sofa * CFrame.new(sx, 1.7, -0.15), sofaCol:Lerp(WHITE, 0.15), Enum.Material.Fabric)
		end
		mk(interior, "SofaBack", Vector3.new(7, 2.4, 0.8), sofa * CFrame.new(0, 2.6, 1.1), sofaCol, Enum.Material.Fabric)
		for _, sx in ipairs({ -3.9, 3.9 }) do
			mk(interior, "SofaArm", Vector3.new(0.8, 2.3, 3), sofa * CFrame.new(sx, 1.15, 0), sofaCol:Lerp(BLACK, 0.12), Enum.Material.Fabric)
		end
		mk(interior, "ThrowPillow", Vector3.new(1.4, 1.3, 0.5), sofa * CFrame.new(-2.6, 2.4, 0.5) * CFrame.Angles(0, 0, math.rad(12)), accent, Enum.Material.Fabric)

		local midZ = zMax - 0.9 - (sofaDist - 0.9) * 0.5
		mk(interior, "Rug", Vector3.new(9.5, 0.1, math.max(sofaDist - 2.2, 4)), F(lx, midZ) * CFrame.new(0, 0.05, 0), accent:Lerp(WHITE, 0.35), Enum.Material.Fabric)
		mk(interior, "RugBorder", Vector3.new(10.3, 0.08, math.max(sofaDist - 1.4, 4.8)), F(lx, midZ) * CFrame.new(0, 0.04, 0), accent:Lerp(BLACK, 0.3), Enum.Material.Fabric)
		local ct = F(lx, midZ)
		mk(interior, "CoffeeTable", Vector3.new(4.2, 0.3, 2.2), ct * CFrame.new(0, 1.55, 0), WOOD, Enum.Material.WoodPlanks)
		for _, sx in ipairs({ -1.8, 1.8 }) do
			mk(interior, "CoffeeTableLeg", Vector3.new(0.3, 1.4, 2), ct * CFrame.new(sx, 0.7, 0), DARK_WOOD, Enum.Material.WoodPlanks)
		end
		mk(interior, "Mug", Vector3.new(0.5, 0.45, 0.45), ct * CFrame.new(0.9, 1.92, 0.2) * CFrame.Angles(0, 0, math.pi / 2), accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		mk(interior, "Magazine", Vector3.new(1.2, 0.08, 0.9), ct * CFrame.new(-0.8, 1.74, 0) * CFrame.Angles(0, 0.3, 0), WHITE)
		if iw >= 34 then
			-- armchair on the room side of the coffee table, turned toward it
			local arm = F(lx - sA * 5.4, midZ, sA > 0 and FACE_PX or FACE_NX)
			local armCol = accent:Lerp(BLACK, 0.25)
			mk(interior, "Armchair", Vector3.new(3.2, 1.4, 3), arm * CFrame.new(0, 0.7, 0), armCol, Enum.Material.Fabric)
			mk(interior, "ArmchairCushion", Vector3.new(2.4, 0.5, 2.4), arm * CFrame.new(0, 1.65, -0.15), armCol:Lerp(WHITE, 0.15), Enum.Material.Fabric)
			mk(interior, "ArmchairBack", Vector3.new(3.2, 2.4, 0.7), arm * CFrame.new(0, 2.6, 1.15), armCol, Enum.Material.Fabric)
			for _, ax in ipairs({ -1.45, 1.45 }) do
				mk(interior, "ArmchairArm", Vector3.new(0.5, 2.1, 3), arm * CFrame.new(ax, 1.05, 0), armCol, Enum.Material.Fabric)
			end
		end

		-- floor lamp at the outer end of the sofa
		local lampX = lx + sA * 5.3
		if math.abs(lampX) < iw / 2 - 0.8 then
			local lamp = F(lampX, zMax - sofaDist + 0.4)
			mk(interior, "LampBase", Vector3.new(0.2, 1.4, 1.4), lamp * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			mk(interior, "LampPole", Vector3.new(0.2, 4.6, 0.2), lamp * CFrame.new(0, 2.4, 0), BLACK)
			local shade = mk(interior, "LampShade", Vector3.new(1.3, 1.6, 1.6), lamp * CFrame.new(0, 5.1, 0) * CFrame.Angles(0, 0, math.pi / 2), WARM, Enum.Material.Neon, Enum.PartType.Cylinder)
			local l = Instance.new("PointLight")
			l.Range = 14
			l.Brightness = 0.6
			l.Color = WARM
			l.Parent = shade
			plant(lampX, zMax - 1.4)
		end
		ceilingLight(lx, midZ, true)
	end

	-- KITCHEN (door side, back): fridge in the corner, counter run with sink + stove, cabinets above
	if hasKitchen then
		local fx = sD * (iw / 2 - 1.6)
		local fridge = F(fx, zMax - 1.4)
		mk(interior, "Fridge", Vector3.new(3, 6.6, 2.6), fridge * CFrame.new(0, 3.3, 0), STEEL, Enum.Material.Metal)
		mk(interior, "FridgeSeam", Vector3.new(2.9, 0.08, 0.05), fridge * CFrame.new(0, 4.4, -1.31), Color3.fromRGB(120, 125, 130))
		mk(interior, "FridgeHandle", Vector3.new(0.18, 1.6, 0.25), fridge * CFrame.new(-sD * 1.1, 5.4, -1.42), BLACK)
		mk(interior, "FridgeHandle", Vector3.new(0.18, 1.6, 0.25), fridge * CFrame.new(-sD * 1.1, 3.2, -1.42), BLACK)
		local fridgeMagnet = mk(interior, "FridgeDrawing", Vector3.new(1, 1.2, 0.05), fridge * CFrame.new(sD * 0.4, 5, -1.32), WHITE)
		fridgeMagnet.CanCollide = false

		local xa, xb = sD * (iw / 2 - 3.3), sD * (iw / 2 - runLen)
		local xc, len = (xa + xb) / 2, math.abs(xa - xb)
		local run = F(xc, zMax - 1.25)
		mk(interior, "Cabinets", Vector3.new(len, 2.8, 2.3), run * CFrame.new(0, 1.4, 0), WHITE)
		mk(interior, "Countertop", Vector3.new(len + 0.2, 0.25, 2.5), run * CFrame.new(0, 2.92, -0.05), Color3.fromRGB(60, 62, 68), Enum.Material.Marble)
		mk(interior, "CabinetToeKick", Vector3.new(len, 0.35, 0.1), run * CFrame.new(0, 0.18, -1.12), BLACK)
		-- cabinet door lines
		for i = 1, math.floor(len / 2.4) - 1 do
			mk(interior, "CabinetLine", Vector3.new(0.06, 2.1, 0.05), run * CFrame.new(-len / 2 + i * 2.4, 1.55, -1.17), Color3.fromRGB(190, 188, 182))
		end
		-- sink + faucet under the back window
		local sink = F(sinkX, zMax - 1.25)
		mk(interior, "Sink", Vector3.new(2.4, 0.1, 1.5), sink * CFrame.new(0, 3.06, -0.1), STEEL, Enum.Material.Metal)
		mk(interior, "Faucet", Vector3.new(0.2, 1.1, 0.2), sink * CFrame.new(0, 3.55, 0.8), STEEL, Enum.Material.Metal)
		mk(interior, "FaucetSpout", Vector3.new(0.2, 0.2, 0.8), sink * CFrame.new(0, 4.05, 0.45), STEEL, Enum.Material.Metal)
		-- stove near the inner end of the counter
		local sx = sD * (iw / 2 - stoveDist)
		local stove = F(sx, zMax - 1.25)
		mk(interior, "Cooktop", Vector3.new(2.6, 0.06, 2.1), stove * CFrame.new(0, 3.08, -0.05), BLACK)
		for _, b in ipairs({ { -0.6, -0.5 }, { 0.6, -0.5 }, { -0.6, 0.45 }, { 0.6, 0.45 } }) do
			mk(interior, "Burner", Vector3.new(0.05, 0.8, 0.8), stove * CFrame.new(b[1], 3.12, b[2]) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(70, 70, 75), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		mk(interior, "OvenDoor", Vector3.new(2.4, 1.7, 0.08), stove * CFrame.new(0, 1.45, -1.18), Color3.fromRGB(40, 40, 46), Enum.Material.Glass)
		mk(interior, "OvenHandle", Vector3.new(2, 0.15, 0.2), stove * CFrame.new(0, 2.45, -1.28), STEEL, Enum.Material.Metal)
		mk(interior, "Pot", Vector3.new(0.9, 1.1, 1.1), stove * CFrame.new(-0.6, 3.6, -0.5) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(190, 60, 50), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		if h >= 9 then
			mk(interior, "RangeHood", Vector3.new(2.8, 0.9, 1.8), stove * CFrame.new(0, 6.9, 0.2), STEEL, Enum.Material.Metal)
			-- upper cabinets between the sink window and the range hood
			local da, db = SINK_DIST + 2.4, stoveDist - 1.5
			if db - da > 1.5 then
				mk(interior, "UpperCabinets", Vector3.new(db - da, 2.4, 1.3), F(sD * (iw / 2 - (da + db) / 2), zMax - 0.65) * CFrame.new(0, 6.6, 0), WHITE)
			end
		end
		mk(interior, "KitchenTiles", Vector3.new(runLen + 0.6, 0.06, 6.2), F(sD * (iw / 2 - runLen / 2 - 0.1), zMax - 3.1) * CFrame.new(0, 0.03, 0),
			Color3.fromRGB(210, 214, 218), Enum.Material.Slate)
		ceilingLight(sinkX, zMax - 3.5, true)
	end

	-- DINING (door side, middle): round table, four chairs, flower vase
	if hasDining then
		local dx = sD * math.min(iw * 0.24, iw / 2 - 5)
		local tbl = F(dx, diningZ)
		mk(interior, "DiningTable", Vector3.new(0.3, 4.4, 4.4), tbl * CFrame.new(0, 2.7, 0) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
		mk(interior, "TablePedestal", Vector3.new(0.6, 2.5, 0.6), tbl * CFrame.new(0, 1.35, 0), DARK_WOOD, Enum.Material.WoodPlanks)
		mk(interior, "TableFoot", Vector3.new(0.2, 2, 2), tbl * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), DARK_WOOD, Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
		mk(interior, "Vase", Vector3.new(0.6, 1, 0.6), tbl * CFrame.new(0, 3.35, 0), WHITE, Enum.Material.Glass)
		mk(interior, "Flowers", Vector3.new(1.1, 1.1, 1.1), tbl * CFrame.new(0, 4.1, 0), accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		for i = 0, 3 do
			local a = i * math.pi / 2
			local chair = tbl * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 3.1)
			mk(interior, "ChairSeat", Vector3.new(1.8, 0.3, 1.8), chair * CFrame.new(0, 1.7, 0), WOOD, Enum.Material.WoodPlanks)
			mk(interior, "ChairBack", Vector3.new(1.8, 2, 0.25), chair * CFrame.new(0, 2.85, 0.8), WOOD, Enum.Material.WoodPlanks)
			mk(interior, "ChairLegs", Vector3.new(1.3, 1.55, 1.3), chair * CFrame.new(0, 0.78, 0), DARK_WOOD, Enum.Material.WoodPlanks)
		end
		ceilingLight(dx, diningZ, false)
	end

	-- BED CORNER (living side, front): bed with headboard against the side wall, nightstand, art above
	if hasBed then
		local bx = sA * (iw / 2 - 4.4)
		local bz = zMin + 4.2
		local bed = F(bx, bz, sA * math.pi / 2) -- head (local +Z) against the side wall
		mk(interior, "BedFrame", Vector3.new(5.6, 1.2, 8), bed * CFrame.new(0, 0.6, 0), WOOD, Enum.Material.WoodPlanks)
		mk(interior, "Mattress", Vector3.new(5.2, 0.8, 7.6), bed * CFrame.new(0, 1.6, 0), WHITE, Enum.Material.Fabric)
		mk(interior, "Blanket", Vector3.new(5.4, 0.35, 5), bed * CFrame.new(0, 2.05, -1.35), accent, Enum.Material.Fabric)
		for _, px in ipairs({ -1.3, 1.3 }) do
			mk(interior, "Pillow", Vector3.new(2.1, 0.55, 1.4), bed * CFrame.new(px, 2.25, 2.85), WHITE, Enum.Material.Fabric)
		end
		mk(interior, "Headboard", Vector3.new(6, 4.2, 0.5), bed * CFrame.new(0, 2.1, 4.15), DARK_WOOD, Enum.Material.WoodPlanks)
		-- nightstand with a little glowing lamp, toward the back of the bed
		local ns = F(sA * (iw / 2 - 1.1), bz + 4.1)
		mk(interior, "Nightstand", Vector3.new(1.8, 2, 1.8), ns * CFrame.new(0, 1, 0), WOOD, Enum.Material.WoodPlanks)
		mk(interior, "NightstandDrawer", Vector3.new(0.05, 0.6, 1.3), ns * CFrame.new(-sA * 0.92, 1.3, 0), DARK_WOOD)
		mk(interior, "BedsideLamp", Vector3.new(0.9, 0.9, 0.9), ns * CFrame.new(0, 2.6, 0), WARM, Enum.Material.Neon, Enum.PartType.Ball)
		if h >= 9 then
			-- painting above the headboard: frame, sky, sun and a hill
			local art = cfB * CFrame.new(sA * (iw / 2 - 0.05), y0 + 6.4, bz) * CFrame.Angles(0, sA * math.pi / 2, 0)
			mk(interior, "PaintingFrame", Vector3.new(4.6, 3.2, 0.15), art, DARK_WOOD)
			mk(interior, "PaintingSky", Vector3.new(4.1, 2.7, 0.06), art * CFrame.new(0, 0, -0.09), Color3.fromRGB(140, 195, 235))
			mk(interior, "PaintingHill", Vector3.new(4.1, 1, 0.06), art * CFrame.new(0, -0.85, -0.11), Color3.fromRGB(90, 160, 80))
			mk(interior, "PaintingSun", Vector3.new(0.05, 0.9, 0.9), art * CFrame.new(1.2, 0.6, -0.12) * CFrame.Angles(0, math.pi / 2, 0),
				Color3.fromRGB(255, 210, 80), Enum.Material.Neon, Enum.PartType.Cylinder)
		end
		ceilingLight(bx, bz, false)
		local roomEndZ = bz + 6
		if iw >= 34 and h >= 9 then
			local px, pz = sA * (iw / 2 - 11), zMin + 10.5
			-- side partition runs back from the front wall, doorway beside the foot of the bed
			local sideLen = pz - zMin
			local sideZc = zMin + sideLen / 2
			local doorLocal = -((zMin + 6.5) - sideZc) * sA
			holedWall(interior, "BedroomWall", cfB * CFrame.new(px, 0, sideZc) * CFrame.Angles(0, sA * math.pi / 2, 0),
				sideLen, h, 0.4, 0, { { x0 = doorLocal - 2.3, x1 = doorLocal + 2.3, y0 = 0, y1 = DOOR_H } }, paint)
			holedWall(interior, "BedroomWall", cfB * CFrame.new(sA * (iw / 2 - 5.5), 0, pz), 11, h, 0.4, 0, {}, paint)
			mk(interior, "BedroomDoorTrim", Vector3.new(0.6, 0.4, 5.2), cfB * CFrame.new(px, y0 + DOOR_H + 0.2, zMin + 6.5), WHITE)
			roomEndZ = pz + 1
		end

		-- bookshelf against the living-side wall, between the bed(room) and the sofa
		local shelfZ = (roomEndZ + zMax - sofaDist - 1.5) / 2
		if (zMax - sofaDist - 1.5) - roomEndZ > 5.5 then
			local sh = F(sA * (iw / 2 - 0.75), shelfZ, sA * math.pi / 2)
			mk(interior, "ShelfBack", Vector3.new(5, 7, 0.25), sh * CFrame.new(0, 3.5, 0.6), DARK_WOOD, Enum.Material.WoodPlanks)
			for _, sxo in ipairs({ -2.4, 2.4 }) do
				mk(interior, "ShelfSide", Vector3.new(0.25, 7, 1.4), sh * CFrame.new(sxo, 3.5, 0), DARK_WOOD, Enum.Material.WoodPlanks)
			end
			for i, yy in ipairs({ 0.15, 2.4, 4.6, 6.85 }) do
				mk(interior, "Shelf", Vector3.new(4.6, 0.25, 1.3), sh * CFrame.new(0, yy, 0), DARK_WOOD, Enum.Material.WoodPlanks)
				if i <= 3 then
					-- two rows of book spines per shelf, a different color each
					mk(interior, "Books", Vector3.new(2, 1.6, 1), sh * CFrame.new(-1.1, yy + 0.95, 0.05), pick(ACCENTS))
					mk(interior, "Books", Vector3.new(1.4, 1.3, 1), sh * CFrame.new(1.2, yy + 0.8, 0.05) * CFrame.Angles(0, 0, math.rad(-8)), pick(ACCENTS))
				end
			end
		end
	end

	-- GAME AREA in the middle of big houses: an area rug and a pool table (shifted away from the door path)
	if iw >= 40 and idp >= 30 then
		local gx = -sD * 3
		local gz = (zMin + 12 + zMax - sofaDist - 2) / 2
		mk(interior, "AreaRug", Vector3.new(0.1, 13, 13), F(gx, gz) * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
			accent:Lerp(WHITE, 0.55), Enum.Material.Fabric, Enum.PartType.Cylinder)
		local pt = F(gx, gz)
		mk(interior, "PoolTable", Vector3.new(7, 2.3, 4), pt * CFrame.new(0, 1.15, 0), DARK_WOOD, Enum.Material.WoodPlanks)
		mk(interior, "PoolTableFelt", Vector3.new(6.2, 0.12, 3.2), pt * CFrame.new(0, 2.36, 0), Color3.fromRGB(40, 130, 70), Enum.Material.Fabric)
		mk(interior, "PoolBall", Vector3.new(0.45, 0.45, 0.45), pt * CFrame.new(1.6, 2.65, 0.3), WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		mk(interior, "PoolBall", Vector3.new(0.45, 0.45, 0.45), pt * CFrame.new(-1.4, 2.65, -0.4), Color3.fromRGB(230, 60, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		mk(interior, "PoolBall", Vector3.new(0.45, 0.45, 0.45), pt * CFrame.new(-1.9, 2.65, 0.2), Color3.fromRGB(250, 200, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		mk(interior, "PoolCue", Vector3.new(4.8, 0.12, 0.12), pt * CFrame.new(0.4, 2.5, 1.3) * CFrame.Angles(0, 0.15, 0), Color3.fromRGB(210, 170, 110))
		ceilingLight(gx, gz, false)
	end

	-- DOG CORNER: in an L-house's entry wing, otherwise the front corner on the door side
	local dogX, dogZ, dogY, dogFace
	if wingInfo then
		dogX = wingInfo.x - sD * (wingInfo.wdt / 2 - 2.8)
		dogZ = wingInfo.front + 3.2
		dogY = wingInfo.floorY
		dogFace = sD > 0 and FACE_PX or FACE_NX
	else
		dogX = sD * (iw / 2 - 2.6)
		dogZ = zMin + 2.8
		if math.abs(dogX - doorX) < 6 then dogZ = zMin + 8.5 end
		dogY = y0
		dogFace = sD > 0 and FACE_NX or FACE_PX
	end
	local function G(x, z, yaw) return cfB * CFrame.new(x, dogY, z) * CFrame.Angles(0, yaw or 0, 0) end
	mk(interior, "DogBed", Vector3.new(0.7, 4, 4), G(dogX, dogZ) * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(120, 85, 60), Enum.Material.Fabric, Enum.PartType.Cylinder)
	mk(interior, "DogBedCushion", Vector3.new(0.5, 3.1, 3.1), G(dogX, dogZ) * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(235, 220, 190), Enum.Material.Fabric, Enum.PartType.Cylinder)
	local bowlX = dogX - (dogFace == FACE_PX and -1 or 1) * 3.2
	mk(interior, "DogBowl", Vector3.new(0.5, 1.4, 1.4), G(bowlX, dogZ - 0.6) * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(200, 60, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	mk(interior, "Kibble", Vector3.new(0.1, 1.1, 1.1), G(bowlX, dogZ - 0.6) * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(150, 95, 50), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	mk(interior, "ChewBone", Vector3.new(1.2, 0.3, 0.3), G(dogX + 0.8, dogZ - 2.5) * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0.6, 0), WHITE)

	-- Auto-Petter 3000 beside the dog bed
	local apSpot = G(dogX, dogZ + 4.2, dogFace) * CFrame.new(0, 2, 0)
	local ap = mk(interior, "AutoPetter", Vector3.new(3, 4, 2.6), apSpot, Color3.fromRGB(70, 75, 85), Enum.Material.Metal)
	mk(interior, "AutoPetterStripe", Vector3.new(3.05, 0.35, 2.65), apSpot * CFrame.new(0, -1.2, 0), Color3.fromRGB(80, 220, 120), Enum.Material.Neon)
	mk(interior, "AutoPetterArm", Vector3.new(0.35, 0.35, 2.4), apSpot * CFrame.new(0, 1.6, -2.3), STEEL, Enum.Material.Metal)
	mk(interior, "AutoPetterHand", Vector3.new(1, 1, 1), apSpot * CFrame.new(0, 1.4, -3.5), Color3.fromRGB(255, 200, 160), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local apScreen = mk(interior, "AutoPetterScreen", Vector3.new(2.6, 1.4, 0.15), apSpot * CFrame.new(0, 0.6, -1.36), BLACK)
	makeSign(apScreen, Enum.NormalId.Front, "AUTO-PETTER", BLACK, Color3.fromRGB(80, 220, 120))
	ap:SetAttribute("AutoPetter", true)

	-- welcome mat inside the front door
	if wingInfo then
		mk(interior, "Doormat", Vector3.new(3.8, 0.1, 2.2), cfB * CFrame.new(wingInfo.x, wingInfo.floorY + 0.05, wingInfo.front + 2), Color3.fromRGB(140, 100, 60), Enum.Material.Fabric)
		ceilingLight(wingInfo.x, wingInfo.front + wingInfo.len / 2, true, wingInfo.h)
	else
		mk(interior, "Doormat", Vector3.new(3.8, 0.1, 2.2), F(doorX, zMin + 1.6) * CFrame.new(0, 0.05, 0), Color3.fromRGB(140, 100, 60), Enum.Material.Fabric)
		ceilingLight(doorX, zMin + 4, true)
	end
	if iw >= 20 and not wingInfo and not hasDining then
		plant(sD * (iw / 2 - 1.4), zMax - (hasKitchen and 4.4 or 1.4))
	end

	task.spawn(function()
		while house.Parent do
			local currOwnerId = house:GetAttribute("OwnerUserId")
			if currOwnerId then
				local ownerPlr = game.Players:GetPlayerByUserId(currOwnerId)
				if ownerPlr then
					local mdl = playerDog[currOwnerId]
					if mdl then
						local pay = mdl:GetAttribute("Pay")
						local dogName = mdl:GetAttribute("DogName")
						local oCash = getCash(ownerPlr)
						if pay and dogName and oCash and pay > 0 then
							oCash.Value = oCash.Value + pay
							TrickResult:FireClient(ownerPlr, dogName .. " loves the Auto-Petter 3000!", pay)
						end
					end
				end
			end
			task.wait(4)
		end
	end)

	-- where a hatched dog waits: on the dog bed, inside
	house:SetAttribute("DogSpotInside", (G(dogX, dogZ) * CFrame.new(0, 0.6, 0)).Position)
end

-- Houses are hollowed + furnished on demand, when a player first comes near (5000+ houses would
-- otherwise mean ~150k interior parts nobody ever sees).
local HOLLOW_GRID = 100
local HOLLOW_RADIUS = 80
local unhollowedByCell = {}
local function queueHouseForHollowing(house)
	local body = house:FindFirstChild("Body")
	if not body or house:GetAttribute("Hollowed") then return end
	local p = body.Position
	local key = math.floor(p.X / HOLLOW_GRID) .. ":" .. math.floor(p.Z / HOLLOW_GRID)
	local list = unhollowedByCell[key]
	if not list then
		list = {}
		unhollowedByCell[key] = list
	end
	table.insert(list, house)
end
task.spawn(function()
	while true do
		for _, plr in ipairs(Players:GetPlayers()) do
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = root.Position
				local gx, gz = math.floor(p.X / HOLLOW_GRID), math.floor(p.Z / HOLLOW_GRID)
				for dx = -1, 1 do
					for dz = -1, 1 do
						local list = unhollowedByCell[(gx + dx) .. ":" .. (gz + dz)]
						if list then
							for i = #list, 1, -1 do
								local house = list[i]
								local body = house.Parent and house:FindFirstChild("Body")
								if not body or house:GetAttribute("Hollowed") then
									table.remove(list, i)
								elseif (body.Position - p).Magnitude < HOLLOW_RADIUS + math.max(body.Size.X, body.Size.Z) / 2 then
									table.remove(list, i)
									local ok, err = pcall(hollowHouse, house)
									if not ok then warn("[DiscoveryBayShop] hollowing failed: " .. tostring(err)) end
									task.wait()
								end
							end
						end
					end
				end
			end
		end
		task.wait(0.4)
	end
end)

local function hookRent(board)
	local click = board:FindFirstChildOfClass("ClickDetector")
	if not click then return end
	click.MouseClick:Connect(function(plr)
		local house = board.Parent
		if not house then return end
		local owner = house:GetAttribute("OwnerUserId")
		if owner == plr.UserId then
			TrickResult:FireClient(plr, "That's already YOUR house!", 0)
			return
		elseif owner ~= nil then
			TrickResult:FireClient(plr, "Someone already owns this one!", 0)
			return
		end
		local prev = ownedHouse[plr.UserId] -- one home per player: release the old one
		if prev and prev.house.Parent then
			prev.house:SetAttribute("OwnerUserId", nil)
			setRentSign(prev.board, "RENT", Color3.fromRGB(200, 60, 50))
		end
		house:SetAttribute("OwnerUserId", plr.UserId)
		ownedHouse[plr.UserId] = { house = house, board = board }
		setRentSign(board, plr.Name .. "'s house", Color3.fromRGB(60, 160, 80))
		local ok, err = pcall(hollowHouse, house)
		if not ok then
			warn("[DiscoveryBayShop] hollowing failed: " .. tostring(err))
		end
		TrickResult:FireClient(plr, "Welcome home! Walk in through your front door.", 0)
	end)
end

local function spawnDog(plr, dogDef, spot)
	local old = playerDog[plr.UserId]
	if old and old.Parent then old:Destroy() end
	local town = workspace:FindFirstChild("DiscoveryBay") or workspace
	local mdl = Instance.new("Model")
	mdl.Name = dogDef.name
	local base = Vector3.new(spot.X, spot.Y, spot.Z)
	local k = dogDef.scale or 1
	
	local c = dogDef.color
	local a = dogDef.accent or c
	
	-- Root part
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.2, 1.8, 3.6) * k
	body.CFrame = CFrame.new(base + Vector3.new(0, 2.1, 0) * k)
	body.Color = c
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true -- Only root is anchored for Tweening
	body.CanCollide = true
	body.Parent = mdl
	mdl.PrimaryPart = body
	
	local function dpWeld(name, size, off, color, shape, parentPart)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * k
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		if shape then p.Shape = shape end
		
		-- off is relative to the base floor spot, not the body!
		p.CFrame = CFrame.new(base + off * k)
		p.Parent = mdl
		
		local weld = Instance.new("Weld")
		weld.Part0 = parentPart or body
		weld.Part1 = p
		-- C0 is the offset from the parent part
		weld.C0 = weld.Part0.CFrame:Inverse() * weld.Part1.CFrame
		weld.Parent = weld.Part0
		return p, weld
	end

	dpWeld("Chest", Vector3.new(1.6, 1.2, 0.6), Vector3.new(0, 1.9, -1.7), a)
	local head = dpWeld("Head", Vector3.new(1.7, 1.7, 1.7), Vector3.new(0, 3.4, -1.9), c, Enum.PartType.Ball)
	dpWeld("Snout", Vector3.new(0.8, 0.6, 0.9), Vector3.new(0, 3.1, -2.8), a)
	dpWeld("EarL", Vector3.new(0.4, 0.9, 0.4), Vector3.new(-0.6, 4.3, -1.9), c)
	dpWeld("EarR", Vector3.new(0.4, 0.9, 0.4), Vector3.new(0.6, 4.3, -1.9), c)
	
	-- EYES
	dpWeld("EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.4, 3.5, -2.7), Color3.new(0,0,0), Enum.PartType.Ball, head)
	dpWeld("EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.4, 3.5, -2.7), Color3.new(0,0,0), Enum.PartType.Ball, head)
	
	dpWeld("Tail", Vector3.new(0.4, 0.4, 1.5), Vector3.new(0, 2.9, 2.2), c)
	
	local legWelds = {}
	for _, lx in ipairs({ -0.7, 0.7 }) do
		for _, lz in ipairs({ -1.2, 1.2 }) do
			local leg, lw = dpWeld("Leg", Vector3.new(0.6, 1.4, 0.6), Vector3.new(lx, 0.7, lz), lz < 0 and a or c)
			-- adjust C0 so they pivot at the top of the leg
			lw.C0 = lw.C0 * CFrame.new(0, 0.7*k, 0)
			lw.C1 = CFrame.new(0, 0.7*k, 0)
			legWelds[#legWelds + 1] = lw
		end
	end

	if dogDef.pay >= 100 then
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 220, 120)
		glow.Range = 18
		glow.Brightness = 2
		glow.Parent = body
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pet"
	prompt.ObjectText = dogDef.name .. " - pet for $" .. dogDef.pay
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(who)
		if who ~= plr then
			TrickResult:FireClient(who, "That's " .. plr.Name .. "'s dog!", 0)
			return
		end
		local now = os.clock()
		if petStamp[mdl] and now - petStamp[mdl] < PET_COOLDOWN then
			TrickResult:FireClient(who, dogDef.name .. " needs a rest! Come back soon.", 0)
			return
		end
		petStamp[mdl] = now
		local cash = getCash(who)
		if cash then
			cash.Value = cash.Value + dogDef.pay
			TrickResult:FireClient(who, dogDef.name .. " loves you!", dogDef.pay)
		end
	end)
	playerDog[plr.UserId] = mdl
	mdl:SetAttribute("Pay", dogDef.pay)
	mdl:SetAttribute("DogName", dogDef.name)
	
	-- AI Wandering Loop
	task.spawn(function()
		local trng = Random.new()
		local t = 0
		local ts = game:GetService("TweenService")
		local initialC0s = {}
		for i, lw in ipairs(legWelds) do initialC0s[i] = lw.C0 end
		
		while body and body.Parent do
			task.wait(trng:NextNumber(2, 6))
			if not body or not body.Parent then break end
			
			-- pick a random spot near the original spawn spot (the dog bed)
			local targetSpot = spot + Vector3.new(trng:NextNumber(-9, 9), 0, trng:NextNumber(-9, 9))
			local targetPos = targetSpot + Vector3.new(0, 2.1 * k, 0)
			local dist = (body.Position - targetPos).Magnitude
			local walkTime = dist / 5 -- walk speed: 5 studs per sec
			
			local lookAtCFrame = CFrame.lookAt(body.Position, Vector3.new(targetPos.X, body.Position.Y, targetPos.Z))
			
			-- Pivot to face the target immediately (or use a quick tween)
			local turnTween = ts:Create(body, TweenInfo.new(0.3), {CFrame = lookAtCFrame})
			turnTween:Play()
			task.wait(0.3)
			
			if not body or not body.Parent then break end
			local walkTween = ts:Create(body, TweenInfo.new(walkTime, Enum.EasingStyle.Linear), {CFrame = lookAtCFrame + (targetPos - lookAtCFrame.Position)})
			walkTween:Play()
			
			-- Walk animation loop
			local walkConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
				t = t + dt * 15
				for i, lw in ipairs(legWelds) do
					-- alternate diagonal legs
					local swing = math.sin(t + ((i == 1 or i == 4) and 0 or math.pi)) * 0.45
					lw.C0 = initialC0s[i] * CFrame.Angles(swing, 0, 0)
				end
			end)
			
			task.wait(walkTime)
			walkConn:Disconnect()
			for i, lw in ipairs(legWelds) do lw.C0 = initialC0s[i] end -- reset stance
		end
	end)
	mdl.Parent = town
end

local playerRolls = {}

local function hookEgg(egg)
	local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(plr)
		local home = ownedHouse[plr.UserId]
		if not home or not home.house.Parent then
			TrickResult:FireClient(plr, "Rent a house first (click a RENT sign) so your dog has a home!", 0)
			return
		end
		local cash = getCash(plr)
		if not cash or cash.Value < EGG_PRICE then
			TrickResult:FireClient(plr, "Not enough cash! Eggs are $" .. EGG_PRICE, 0)
			return
		end
		cash.Value = cash.Value - EGG_PRICE
		
		local rolls = (playerRolls[plr.UserId] or 0) + 1
		local roll = rng:NextInteger(1, 200)
		local dogDef
		
		-- PITY SYSTEM
		if roll <= 2 then
			dogDef = DOGS[3] -- Linus 1% chance randomly! (Resets pity)
			playerRolls[plr.UserId] = 0
		elseif roll <= 101 then
			dogDef = DOGS[1] -- Mary
			playerRolls[plr.UserId] = math.min(rolls, 90)
		else
			dogDef = DOGS[2] -- Jolene
			playerRolls[plr.UserId] = math.min(rolls, 90)
		end
		
		-- Update client on their pity status
		local currentRolls = playerRolls[plr.UserId] or 0
		UpdatePity:FireClient(plr, 90 - currentRolls)
		
		local homeSpot = home.house:GetAttribute("DogSpotInside")
			or home.house:GetAttribute("DogSpot") or home.house:GetPivot().Position
		-- Pet-Sim-X-style hatch: the cinematic plays ON THE PLAYER'S SCREEN (client),
		-- while the pet spawns at home ready for petting afterwards
		HatchEgg:FireClient(plr, dogDef.name)
		spawnDog(plr, dogDef, Vector3.new(homeSpot.X, homeSpot.Y, homeSpot.Z))
	end)
end

-- Pity Claim Button Logic
local ClaimPity = remote("ClaimPity")
ClaimPity.OnServerEvent:Connect(function(plr)
	local home = ownedHouse[plr.UserId]
	if not home or not home.house.Parent then
		TrickResult:FireClient(plr, "Rent a house first so your dog has a home!", 0)
		return
	end
	local rolls = playerRolls[plr.UserId] or 0
	if rolls >= 90 then
		playerRolls[plr.UserId] = rolls - 90
		UpdatePity:FireClient(plr, 90 - (playerRolls[plr.UserId] or 0))
		local homeSpot = home.house:GetAttribute("DogSpotInside")
			or home.house:GetAttribute("DogSpot") or home.house:GetPivot().Position
		HatchEgg:FireClient(plr, DOGS[3].name)
		spawnDog(plr, DOGS[3], Vector3.new(homeSpot.X, homeSpot.Y, homeSpot.Z))
	end
end)

DoRebirth.OnServerEvent:Connect(function(plr)
	local cash = getCash(plr)
	local rebirths = getRebirths(plr)
	if not cash or not rebirths then return end
	local cost = 1000 * math.pow(5, rebirths.Value)
	if cash.Value < cost then return end
	
	-- Increment rebirths and reset money
	rebirths.Value = rebirths.Value + 1
	cash.Value = 100
	
	-- Lose house
	local home = ownedHouse[plr.UserId]
	if home and home.house.Parent then
		home.house:SetAttribute("OwnerUserId", nil)
		setRentSign(home.board, "RENT", Color3.fromRGB(200, 60, 50))
	end
	ownedHouse[plr.UserId] = nil
	
	-- Lose pet
	local dog = playerDog[plr.UserId]
	if dog and dog.Parent then dog:Destroy() end
	playerDog[plr.UserId] = nil
	
	-- Force speed update so scooter updates immediately
	updateSpeed(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	local home = ownedHouse[plr.UserId]
	if home and home.house.Parent then
		home.house:SetAttribute("OwnerUserId", nil)
		setRentSign(home.board, "RENT", Color3.fromRGB(200, 60, 50))
	end
	ownedHouse[plr.UserId] = nil
	local dog = playerDog[plr.UserId]
	if dog and dog.Parent then dog:Destroy() end
	playerDog[plr.UserId] = nil
end)

-- DEBT: negative cash drains health every second, anywhere, until you're back to $0+
task.spawn(function()
	while true do
		task.wait(1)
		for _, plr in ipairs(Players:GetPlayers()) do
			local cash = getCash(plr)
			if cash and cash.Value < 0 then
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum:TakeDamage(5)
				end
			end
		end
	end
end)

-- AUTO-PETTER LOOP: automatically triggers dog payouts for homeowners
task.spawn(function()
	while true do
		task.wait(4)
		for _, plr in ipairs(Players:GetPlayers()) do
			local home = ownedHouse[plr.UserId]
			local dog = playerDog[plr.UserId]
			if home and dog and dog.Parent then
				-- If they own a home, it has an auto-petter inside!
				local cash = getCash(plr)
				local pay = dog:GetAttribute("Pay") or 0
				local dogName = dog:GetAttribute("DogName") or "Your pet"
				if cash and pay > 0 then
					cash.Value = cash.Value + pay
					TrickResult:FireClient(plr, "Auto-Petter 3000 loved on " .. dogName .. "!", pay)
				end
			end
		end
	end
end)

--==============================================================================================
-- FISHING (Fish N Bait): rod + bait -> cast into water -> reel minigame -> sell the catch
--==============================================================================================
local FISH = {
	{ name = "Bluegill",      pay = 6,   weight = 40, color = Color3.fromRGB(90, 140, 160) },
	{ name = "Bass",          pay = 14,  weight = 28, color = Color3.fromRGB(90, 130, 70) },
	{ name = "Rainbow Trout", pay = 22,  weight = 16, color = Color3.fromRGB(200, 140, 150) },
	{ name = "Catfish",       pay = 35,  weight = 10, color = Color3.fromRGB(110, 100, 85) },
	{ name = "Golden Salmon", pay = 120, weight = 5,  color = Color3.fromRGB(235, 180, 60) },
	{ name = "THE LIONEL",    pay = 500, weight = 1,  color = Color3.fromRGB(255, 200, 40) },
}
local FISH_BY_NAME = {}
for _, f in ipairs(FISH) do
	FISH_BY_NAME[f.name] = f
end

local castState = {} -- uid -> { stage = "wait"|"bite", bobber = Part }

-- caught fish go into the INVENTORY as Tools; sell them at the Fish N Bait counter
local function giveFishTool(plr, f)
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = Instance.new("Tool")
	tool.Name = f.name
	tool.ToolTip = "Sells for $" .. f.pay .. " at Fish N Bait"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2, 0.7, 0.45)
	handle.Color = f.color
	if f.name == "THE LIONEL" then
		handle.Material = Enum.Material.Neon
	end
	handle.CanCollide = false
	handle.Parent = tool
	tool.Parent = backpack
end

local function collectFishTools(plr)
	local found = {}
	local function scan(container)
		if not container then return end
		for _, t in ipairs(container:GetChildren()) do
			if FISH_BY_NAME[t.Name] then
				found[#found + 1] = t
			end
		end
	end
	scan(plr:FindFirstChildOfClass("Backpack"))
	scan(plr.Character)
	return found
end

local function rollFish()
	local total = 0
	for _, f in ipairs(FISH) do
		total = total + f.weight
	end
	local pick = rng:NextNumber() * total
	local acc = 0
	for _, f in ipairs(FISH) do
		acc = acc + f.weight
		if pick <= acc then return f end
	end
	return FISH[1]
end

local function clearCast(uid)
	local st = castState[uid]
	if st then
		if st.bobber and st.bobber.Parent then
			st.bobber:Destroy()
		end
		if st.a0 and st.a0.Parent then
			st.a0:Destroy()
		end
	end
	castState[uid] = nil
end

local function findWaterAhead(hrp)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { hrp.Parent }
	local look = hrp.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	for _, dist in ipairs({ 8, 14, 22 }) do
		local origin = hrp.Position + flat * dist + Vector3.new(0, 12, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, -60, 0), params)
		if hit and hit.Instance and hit.Instance:GetAttribute("Water") then
			return hit.Position
		end
	end
	return nil
end

local function hookRod(plr, tool)
	tool.Activated:Connect(function()
		local uid = plr.UserId
		if castState[uid] then return end -- line's already in the water
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then return end
		local waterPos = findWaterAhead(hrp)
		if not waterPos then
			TrickResult:FireClient(plr, "Face some water to cast! The bay is full of it.", 0)
			return
		end
		local bait = plr:GetAttribute("Bait") or 0
		if bait <= 0 then
			TrickResult:FireClient(plr, "Out of bait! Grab a Bait Pack at Fish N Bait.", 0)
			return
		end
		plr:SetAttribute("Bait", bait - 1)
		local bobber = Instance.new("Part")
		bobber.Name = "Bobber"
		bobber.Shape = Enum.PartType.Ball
		bobber.Size = Vector3.new(1, 1, 1)
		bobber.Color = Color3.fromRGB(230, 60, 50)
		bobber.Anchored = true
		bobber.CanCollide = false
		bobber.CFrame = CFrame.new(waterPos + Vector3.new(0, 0.3, 0))
		bobber.Parent = workspace
		
		-- Add the fishing string (Beam)
		local handle = tool:FindFirstChild("Handle")
		local a0, a1, beam
		if handle then
			a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(2.8, 0, 0) -- tip of the 6-stud rod
			a0.Parent = handle
			a1 = Instance.new("Attachment")
			a1.Parent = bobber
			
			beam = Instance.new("Beam")
			beam.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
			beam.Width0 = 0.04
			beam.Width1 = 0.04
			beam.FaceCamera = true
			beam.CurveSize0 = 1.5 -- slight droop
			beam.CurveSize1 = 1.5
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Parent = bobber
		end
		
		castState[uid] = { stage = "wait", bobber = bobber, a0 = a0 }
		TrickResult:FireClient(plr, "Cast! Watch the bobber... (" .. (bait - 1) .. " bait left)", 0)
		task.delay(rng:NextNumber(2, 6), function()
			local st = castState[uid]
			if not st or st.stage ~= "wait" then return end
			if not tool.Parent then
				clearCast(uid)
				return
			end
			st.stage = "bite"
			if st.bobber and st.bobber.Parent then
				st.bobber.Material = Enum.Material.Neon -- the bobber lights up: FISH ON
			end
			FishGame:FireClient(plr)
			task.delay(9, function()
				local st2 = castState[uid]
				if st2 and st2.stage == "bite" then
					clearCast(uid)
					TrickResult:FireClient(plr, "Too slow... it got away.", 0)
				end
			end)
		end)
	end)
end

FishReel.OnServerEvent:Connect(function(plr, success)
	local uid = plr.UserId
	local st = castState[uid]
	if not st or st.stage ~= "bite" then return end
	clearCast(uid)
	if success ~= true then
		TrickResult:FireClient(plr, "It wriggled off the hook!", 0)
		return
	end
	local f = rollFish()
	giveFishTool(plr, f)
	if f.name == "THE LIONEL" then
		TrickResult:FireClient(plr, "THE LIONEL!!! The 1-in-100 legend is in your inventory - worth $500!", 0)
	else
		TrickResult:FireClient(plr, "Caught a " .. f.name .. "! It's in your inventory - sell it at Fish N Bait.", 0)
	end
end)

local function hookFishSell(part)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(plr)
		local tools = collectFishTools(plr)
		local total = 0
		for _, t in ipairs(tools) do
			total = total + FISH_BY_NAME[t.Name].pay
		end
		if #tools == 0 then
			TrickResult:FireClient(plr, "No fish in your inventory! Cast a line anywhere in the bay.", 0)
			return
		end
		for _, t in ipairs(tools) do
			t:Destroy()
		end
		local cash = getCash(plr)
		if cash then
			cash.Value = cash.Value + total
		end
		TrickResult:FireClient(plr, "Sold " .. #tools .. " fish for $" .. total .. "!", 0)
	end)
end

local CONSUME_EFFECTS = {
	["Pizza Slice"] = function(plr)
		plr:SetAttribute("CarbLoad", true)
		task.delay(30, function() plr:SetAttribute("CarbLoad", nil) end)
		return "CARB LOAD! +25% Trick Money and Heavy Mass for 30s!"
	end,
	["Energy Drink"] = function(plr)
		plr:SetAttribute("SugarRush", true)
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = hum.WalkSpeed + 40 end
		task.delay(10, function() 
			plr:SetAttribute("SugarRush", nil) 
			local h2 = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if h2 then h2.WalkSpeed = h2.WalkSpeed - 40 end
		end)
		return "SUGAR RUSH! Insane sprint speed for 10s!"
	end,
	["Burrito"] = function(plr)
		plr:SetAttribute("BeanPower", true)
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.JumpPower = 100 hum.UseJumpPower = true end
		task.delay(20, function()
			plr:SetAttribute("BeanPower", nil)
			local h2 = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if h2 then h2.JumpPower = 50 end
		end)
		return "BEAN POWER! Massive jump height for 20s!"
	end,
	["Mint Cone"] = function(plr)
		plr:SetAttribute("TrickMult", 2)
		task.delay(60, function() plr:SetAttribute("TrickMult", 1) end)
		return "MINTY FRESH! 2x Trick Payouts for 60s!"
	end,
	["Vanilla Cone"] = function(plr)
		bumpAttribute(plr, "VanillaBoost", 10, 30)
		updateSpeed(plr)
		return "Vanilla! Permanent +10 Scooter Speed"
	end,
	["Chocolate Cone"] = function(plr)
		bumpAttribute(plr, "WalkBoost", 5, 20)
		updateSpeed(plr)
		return "Chocolate! Permanent +5 Walk Speed"
	end
}

local function watchTools(char, plr)
	local ev = char.ChildAdded
	if not ev then return end -- (mock sim characters have no ChildAdded)
	ev:Connect(function(child)
		if child:IsA("Tool") and not child:GetAttribute("Hooked") then
			child:SetAttribute("Hooked", true)
			if child.Name == "Fishing Rod" then
				hookRod(plr, child)
			elseif CONSUME_EFFECTS[child.Name] then
				child.Activated:Connect(function()
					local msg = CONSUME_EFFECTS[child.Name](plr)
					if msg then TrickResult:FireClient(plr, msg, 0) end
					child:Destroy()
				end)
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		watchTools(char, plr)
	end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
	plr.CharacterAdded:Connect(function(char)
		watchTools(char, plr)
	end)
	if plr.Character then
		watchTools(plr.Character, plr)
	end
end
Players.PlayerRemoving:Connect(function(plr)
	clearCast(plr.UserId)
end)

--==============================================================================================
-- WEATHER: every 2 in-game days a random one of 50 weathers rolls in for 2 minutes.
-- Disasters hurt (shelter indoors!), boosts speed you up, some just pay or look wild.
--==============================================================================================
local WEATHER_EVERY = 2 * DAY_LENGTH
local WEATHER_TIME = 120

-- fields: scooter/walk = speed delta while active · dmg = hp/s outdoors · cash = $/s
-- fog/oa/clock = atmosphere · grav = gravity multiplier · jump = JumpPower
-- hazard = meteor | lightning | tornado | quake | wind
local WEATHERS = {
	-- DISASTERS ------------------------------------------------------------------------------
	{ name = "Meteor Shower", desc = "Flaming rocks incoming - RUN!", hazard = "meteor", fog = 1500, oa = Color3.fromRGB(255, 180, 120) },
	{ name = "Lightning Storm", desc = "Bolts from above. Stay sharp!", hazard = "lightning", fog = 900, clock = 19 },
	{ name = "Tornado Warning", desc = "A twister is roaming the bay!", hazard = "tornado", fog = 1100 },
	{ name = "Earthquake", desc = "The ground won't sit still!", hazard = "quake" },
	{ name = "Acid Rain", desc = "This rain STINGS. Get inside!", dmg = 4, fog = 600, oa = Color3.fromRGB(120, 160, 90) },
	{ name = "Hailstorm", desc = "Ice chunks! Ouch! Take cover!", dmg = 3, walk = -4, fog = 800 },
	{ name = "Blizzard", desc = "Freezing! Everything is slower.", scooter = -8, walk = -6, fog = 300, oa = Color3.fromRGB(200, 215, 235) },
	{ name = "Sandstorm", desc = "Grit in your eyes and gears.", dmg = 1, walk = -4, fog = 200, oa = Color3.fromRGB(210, 180, 120) },
	{ name = "Heatwave", desc = "Too hot to hustle on foot.", walk = -5, clock = 12, oa = Color3.fromRGB(255, 200, 150) },
	{ name = "Firestorm", desc = "The sky is BURNING. Hide!", dmg = 6, fog = 500, clock = 18, oa = Color3.fromRGB(255, 120, 60) },
	{ name = "Hurricane", desc = "Howling wind drags you around!", hazard = "wind", dmg = 2, fog = 700 },
	{ name = "Thundersnow", desc = "Snow AND lightning?! Wild.", hazard = "lightning", walk = -5, fog = 400, oa = Color3.fromRGB(230, 235, 245) },
	{ name = "Killer Fog", desc = "This fog... bites?", dmg = 2, fog = 90 },
	{ name = "Frog Rain", desc = "Ribbits from above! Mildly painful.", dmg = 1, oa = Color3.fromRGB(170, 220, 140) },
	-- SCOOTER BOOSTS -------------------------------------------------------------------------
	{ name = "Tailwind", desc = "The wind is on your side! Scooter +10.", scooter = 10 },
	{ name = "Jetstream", desc = "Surf the sky river! Scooter +14.", scooter = 14 },
	{ name = "Perfect Sunshine", desc = "Ideal riding weather. Scooter +6.", scooter = 6, clock = 12 },
	{ name = "Cool Breeze", desc = "Crisp and quick. Scooter +5.", scooter = 5 },
	{ name = "Adrenaline Front", desc = "You feel UNSTOPPABLE. Scooter +12.", scooter = 12, walk = 4 },
	{ name = "Golden Hour", desc = "Sunset cruising. Scooter +8.", scooter = 8, clock = 17, oa = Color3.fromRGB(255, 205, 140) },
	{ name = "Static Charge", desc = "Hair up, speed up! Scooter +9.", scooter = 9 },
	{ name = "Spring Bloom", desc = "Fresh air, fresh legs. Scooter +6.", scooter = 6, walk = 2, oa = Color3.fromRGB(220, 255, 210) },
	{ name = "Crisp Autumn Air", desc = "Leaves crunch, wheels fly. Scooter +7.", scooter = 7, oa = Color3.fromRGB(255, 225, 180) },
	{ name = "Morning Dew", desc = "Early bird gets the speed. Scooter +5.", scooter = 5, clock = 7 },
	{ name = "Nitro Clouds", desc = "The air itself is FAST. Scooter +15!", scooter = 15 },
	{ name = "Lucky Rainbow", desc = "Speed AND pocket money!", scooter = 8, cash = 1 },
	-- FUN & STRANGE --------------------------------------------------------------------------
	{ name = "Money Rain", desc = "IT'S RAINING CASH! +$2 every second!", cash = 2 },
	{ name = "Cash Drizzle", desc = "A light sprinkle of dollars.", cash = 1 },
	{ name = "Low Gravity", desc = "Everything floats. Jump around!", grav = 0.4 },
	{ name = "Moon Gravity", desc = "One small step for Discovery Bay...", grav = 0.17 },
	{ name = "Super Jump Storm", desc = "Your legs are springs now!", jump = 120 },
	{ name = "Bouncy Clouds", desc = "Boing. Boing. BOING.", jump = 90, grav = 0.6 },
	{ name = "Blood Moon", desc = "The moon is watching...", clock = 0, oa = Color3.fromRGB(200, 60, 60), fog = 800 },
	{ name = "Aurora Borealis", desc = "Ribbons of light over the bay.", clock = 1, oa = Color3.fromRGB(90, 220, 190) },
	{ name = "Neon Night", desc = "The town glows purple tonight.", clock = 2, oa = Color3.fromRGB(190, 90, 255) },
	{ name = "Pink Sky", desc = "Cotton candy heavens.", oa = Color3.fromRGB(255, 170, 210) },
	{ name = "Candy Clouds", desc = "Sweet skies pay sweet money.", oa = Color3.fromRGB(255, 190, 220), cash = 1 },
	{ name = "Glitter Storm", desc = "Everything sparkles!", oa = Color3.fromRGB(255, 235, 150), fog = 1200 },
	{ name = "Starfall", desc = "Wishes falling everywhere. +$1/s!", clock = 0, cash = 1 },
	{ name = "Misty Morning", desc = "Soft fog rolls off the water.", fog = 350, clock = 7 },
	{ name = "Sun Shower", desc = "Rain AND sun. Scooter +4.", scooter = 4, fog = 1500 },
	{ name = "Double Rainbow", desc = "All the way! Speed and cash!", scooter = 6, cash = 1 },
	{ name = "Petal Storm", desc = "Flower petals everywhere.", oa = Color3.fromRGB(255, 200, 220), walk = 3 },
	{ name = "Snow Flurries", desc = "Gentle snow. Cozy town.", fog = 900, oa = Color3.fromRGB(225, 235, 250) },
	{ name = "Pumpkin Sky", desc = "Spooky orange evening.", clock = 18, oa = Color3.fromRGB(255, 150, 60) },
	{ name = "Silver Lining", desc = "Shiny clouds drop shiny coins.", cash = 1, oa = Color3.fromRGB(220, 220, 230) },
	{ name = "Firefly Night", desc = "Tiny lights over the water.", clock = 22, oa = Color3.fromRGB(255, 235, 170) },
	{ name = "Disco Sky", desc = "The sky wants to DANCE.", oa = Color3.fromRGB(255, 90, 200), jump = 70 },
	{ name = "Dog Days", desc = "Dogs love it. Walkers +5.", walk = 5 },
	{ name = "Windy Kites", desc = "Gusty but great for riding.", hazard = "wind", scooter = 3 },
}

local function weatherAnnounce(text)
	for _, p in ipairs(Players:GetPlayers()) do
		TrickResult:FireClient(p, "WX|" .. text, 0)
	end
end

-- roof over your head = safe from ambient weather damage
local function isSheltered(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return true end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	return workspace:Raycast(hrp.Position, Vector3.new(0, 180, 0), params) ~= nil
end

local function spawnMeteor()
	local ps = Players:GetPlayers()
	if #ps == 0 then return end
	local target = ps[rng:NextInteger(1, #ps)]
	local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local meteor = Instance.new("Part")
	meteor.Name = "Meteor"
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(4, 4, 4)
	meteor.Color = Color3.fromRGB(255, 120, 30)
	meteor.Material = Enum.Material.Neon
	meteor.CFrame = CFrame.new(hrp.Position
		+ Vector3.new(rng:NextNumber(-70, 70), 150, rng:NextNumber(-70, 70)))
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Parent = meteor
	meteor.Touched:Connect(function(hit)
		local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if hum then hum:TakeDamage(45) end
	end)
	meteor.Parent = workspace
	task.delay(8, function()
		if meteor.Parent then meteor:Destroy() end
	end)
end

local function strikeLightning()
	local ps = Players:GetPlayers()
	if #ps == 0 then return end
	local target = ps[rng:NextInteger(1, #ps)]
	local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local pos = hrp.Position + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
	local bolt = Instance.new("Part")
	bolt.Name = "Lightning"
	bolt.Size = Vector3.new(1.2, 90, 1.2)
	bolt.CFrame = CFrame.new(pos + Vector3.new(0, 45, 0))
	bolt.Color = Color3.fromRGB(200, 230, 255)
	bolt.Material = Enum.Material.Neon
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.Parent = workspace
	task.delay(0.25, function()
		if bolt.Parent then bolt:Destroy() end
	end)
	for _, p in ipairs(ps) do
		local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if h and hum then
			local d = h.Position - pos
			if math.sqrt(d.X * d.X + d.Z * d.Z) < 10 then
				hum:TakeDamage(35)
			end
		end
	end
end

local function makeFunnel()
	local ps = Players:GetPlayers()
	local anchor = Vector3.new(11000, 0, 9300)
	local first = ps[1] and ps[1].Character and ps[1].Character:FindFirstChild("HumanoidRootPart")
	if first then
		anchor = first.Position + Vector3.new(rng:NextNumber(-120, 120), 0, rng:NextNumber(-120, 120))
	end
	local funnel = Instance.new("Model")
	funnel.Name = "Tornado"
	for i = 1, 5 do
		local disc = Instance.new("Part")
		disc.Name = "Funnel" .. i
		disc.Shape = Enum.PartType.Cylinder
		local dia = 6 + i * 5
		disc.Size = Vector3.new(9, dia, dia)
		disc.CFrame = CFrame.new(anchor + Vector3.new(0, i * 9 - 4, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		disc.Color = Color3.fromRGB(120, 120, 130)
		disc.Material = Enum.Material.SmoothPlastic
		disc.Transparency = 0.35
		disc.Anchored = true
		disc.CanCollide = false
		disc.Parent = funnel
	end
	funnel.Parent = workspace
	return funnel
end

local function tickFunnel(funnel)
	if not funnel.Parent then return end
	-- spin on the spot and wander; fling anyone who gets close
	funnel:PivotTo(funnel:GetPivot() * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, -8))
	local center = funnel:GetPivot().Position
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = hrp.Position - center
			if math.sqrt(d.X * d.X + d.Z * d.Z) < 20 and math.abs(d.Y) < 45 then
				hrp.AssemblyLinearVelocity = Vector3.new(
					rng:NextNumber(-30, 30), 80, rng:NextNumber(-30, 30))
			end
		end
	end
end

local function runWeather(w)
	weatherActive = true
	weatherAnnounce("WEATHER: " .. w.name .. "! " .. w.desc)
	if w.fog then Lighting.FogEnd = w.fog end
	if w.oa then Lighting.OutdoorAmbient = w.oa end
	if w.clock then Lighting.ClockTime = w.clock end
	workspace.Gravity = 196.2 * (w.grav or 1)
	local funnel = w.hazard == "tornado" and makeFunnel() or nil
	local windAngle = rng:NextNumber(0, 2 * math.pi)
	local windDir = Vector3.new(math.cos(windAngle), 0, math.sin(windAngle))
	for _ = 1, WEATHER_TIME do
		for _, p in ipairs(Players:GetPlayers()) do
			p:SetAttribute("WeatherBoost", w.scooter or 0)
			p:SetAttribute("WeatherWalk", w.walk or 0)
			updateSpeed(p)
			local char = p.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				if w.jump then
					hum.UseJumpPower = true
					hum.JumpPower = w.jump
				end
				if w.dmg and not isSheltered(char) then
					hum:TakeDamage(w.dmg)
				end
				if w.cash then
					local cash = getCash(p)
					if cash then cash.Value = cash.Value + w.cash end
				end
				if w.hazard == "quake" then
					hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity
						+ Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(2, 6), rng:NextNumber(-14, 14))
				elseif w.hazard == "wind" then
					hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + windDir * 10
				end
			end
		end
		if w.hazard == "meteor" then spawnMeteor() end
		if w.hazard == "lightning" and rng:NextNumber() < 0.45 then strikeLightning() end
		if funnel then tickFunnel(funnel) end
		task.wait(1)
	end
	if funnel then funnel:Destroy() end
	weatherActive = false
	Lighting.FogEnd = 100000
	updateSkyForClock(Lighting.ClockTime)
	workspace.Gravity = 196.2
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("WeatherBoost", 0)
		p:SetAttribute("WeatherWalk", 0)
		updateSpeed(p)
		if w.jump then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.UseJumpPower = false
				hum.JumpPower = 50
			end
		end
	end
	weatherAnnounce("The " .. w.name .. " has passed. Clear skies over Discovery Bay!")
end

task.spawn(function()
	local sinceWeather = 0
	while true do
		task.wait(1)
		sinceWeather = sinceWeather + 1
		if sinceWeather >= WEATHER_EVERY then
			sinceWeather = 0
			local ok, err = pcall(runWeather, WEATHERS[rng:NextInteger(1, #WEATHERS)])
			if not ok then
				warn("[DiscoveryBayShop] weather error: " .. tostring(err))
			end
		end
	end
end)

local ForceWeather = remote("ForceWeather")
ForceWeather.OnServerEvent:Connect(function(plr)
	-- only for testing!
	task.spawn(function()
		local ok, err = pcall(runWeather, WEATHERS[rng:NextInteger(1, #WEATHERS)])
		if not ok then
			warn("[DiscoveryBayShop] debug weather error: " .. tostring(err))
		end
	end)
end)

local InfiniteMoney = remote("InfiniteMoney")
InfiniteMoney.OnServerEvent:Connect(function(plr)
	-- only for testing!
	local cash = getCash(plr)
	if cash then
		cash.Value = 999999999
	end
end)

--==============================================================================================
-- NPC TRAFFIC
--==============================================================================================
-- spawn grace: a fresh spawn (or someone still on the PLAY screen) can't be mowed down
-- while standing on the pad; cars ignore them for the first 10 seconds
local function markSpawnGrace(char)
	char:SetAttribute("SpawnGrace", true)
	task.delay(10, function()
		if char.Parent then
			char:SetAttribute("SpawnGrace", nil)
		end
	end)
end
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(markSpawnGrace)
end)
for _, plr in ipairs(Players:GetPlayers()) do
	plr.CharacterAdded:Connect(markSpawnGrace)
	if plr.Character then
		markSpawnGrace(plr.Character)
	end
end

local flingCooldown = {}

local function tryFling(carPos, carDir)
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		local humanoid = ch and ch:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 and not ch:GetAttribute("SpawnGrace") then
			local now = os.clock()
			if not flingCooldown[plr.UserId] or now - flingCooldown[plr.UserId] > 3 then
				local off = hrp.Position - carPos
				local flat = Vector3.new(off.X, 0, off.Z)
				-- flat (ground) distance so the rider's height can never make a car miss
				if flat.Magnitude < FLING_RADIUS and math.abs(off.Y) < 12 then
					flingCooldown[plr.UserId] = now
					local away = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
					pcall(function() setMounted(plr, false) end)
					local flingVel = away * 95 + carDir * 85 + Vector3.new(0, 108, 0)
					local angVel = Vector3.new(rng:NextNumber(-28, 28), rng:NextNumber(-28, 28), rng:NextNumber(-28, 28))
					humanoid.PlatformStand = true
					humanoid.Sit = true
					local hitSnd = Instance.new("Sound")
					hitSnd.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
					hitSnd.PlaybackSpeed = 1.15
					hitSnd.Volume = 2.5
					hitSnd.Parent = hrp
					hitSnd:Play()
					game:GetService("Debris"):AddItem(hitSnd, 2)
					local bv = Instance.new("BodyVelocity")
					bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
					bv.Velocity = flingVel
					bv.Parent = hrp
					game:GetService("Debris"):AddItem(bv, 0.35)
					local bav = Instance.new("BodyAngularVelocity")
					bav.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
					bav.AngularVelocity = angVel
					bav.Parent = hrp
					game:GetService("Debris"):AddItem(bav, 0.35)
					hrp.AssemblyLinearVelocity = flingVel
					hrp.AssemblyAngularVelocity = angVel
					CarFling:FireClient(plr, flingVel, angVel)
					task.delay(0.45, function()
						if not ch or not ch.Parent then return end
						local ff = ch:FindFirstChildOfClass("ForceField")
						if ff then ff:Destroy() end
						for _, part in ipairs(ch:GetDescendants()) do
							if part:IsA("BasePart") then
								part.AssemblyLinearVelocity = flingVel * 0.75
							end
						end
						if humanoid and humanoid.Parent then
							humanoid:TakeDamage(CAR_DAMAGE)
							humanoid.Health = 0
						end
					end)
				end
			end
		end
	end
end

local carObstacleParams = OverlapParams.new()
carObstacleParams.FilterType = Enum.RaycastFilterType.Include

local function isRoadBoxBlocked(cf, size)
	local hits = workspace:GetPartBoundsInBox(cf, size, carObstacleParams)
	for _, h in ipairs(hits) do
		if h.Size.Y > 1.5 and h.Name ~= "Parking" and h.Name ~= "Forecourt" and h.Name ~= "Floor" and h.Name ~= "KioskFloor" then
			return true
		end
	end
	return false
end

local function routeFromRoadModel(model)
	local pts = {}
	local roadTop = nil
	for _, seg in ipairs(model:GetChildren()) do
		if seg.Name == "Seg" and seg:IsA("BasePart") then
			local half = seg.Size.Z / 2
			local a = (seg.CFrame * CFrame.new(0, 0, half)).Position
			local b = (seg.CFrame * CFrame.new(0, 0, -half)).Position
			if #pts == 0 then
				pts[1] = Vector3.new(a.X, 0, a.Z)
			end
			pts[#pts + 1] = Vector3.new(b.X, 0, b.Z)
			roadTop = seg.Position.Y + seg.Size.Y / 2
			if isRoadBoxBlocked(seg.CFrame * CFrame.new(0, 4.5, 0), Vector3.new(seg.Size.X + 10, 6, seg.Size.Z + 14)) then
				if #pts >= 3 then break end
				pts = {}
			end
		end
	end
	if #pts < 3 or not roadTop then return nil end
	local total = 0
	for i = 1, #pts - 1 do
		total = total + (pts[i + 1] - pts[i]).Magnitude
	end
	return { pts = pts, y = roadTop, length = total }
end

-- position on a route at a fraction of its arc length; returns point + next waypoint index
local function routeStart(route, frac)
	local pts = route.pts
	local wanted = route.length * math.clamp(frac, 0, 0.99)
	local acc = 0
	for i = 1, #pts - 1 do
		local seg = (pts[i + 1] - pts[i]).Magnitude
		if acc + seg >= wanted then
			local t = (wanted - acc) / math.max(seg, 1e-6)
			return pts[i] + (pts[i + 1] - pts[i]) * t, i + 1
		end
		acc = acc + seg
	end
	return pts[1], 2
end

local function driveCar(template, route, startFrac, reverse)
	local car = template:Clone()
	car.Name = "TrafficCar"
	local body = car:FindFirstChild("Body")
	if body then
		body.Color = Color3.fromHSV(rng:NextNumber(), 0.5, rng:NextNumber(0.4, 0.9))
	end
	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
	local torso = Instance.new("Part")
	torso.Size = Vector3.new(1.6, 1.7, 0.9)
	torso.Color = Color3.fromHSV(rng:NextNumber(), 0.6, 0.7)
	torso.CanCollide = false
	torso.Anchored = true
	torso.Parent = car
	local head = Instance.new("Part")
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.1, 1.1, 1.1)
	head.Color = Color3.fromRGB(255, 204, 153)
	head.CanCollide = false
	head.Anchored = true
	head.Parent = car
	local driverFace = Instance.new("Decal")
	driverFace.Name = "face"
	driverFace.Texture = "rbxasset://textures/face.png"
	driverFace.Face = Enum.NormalId.Front
	driverFace.Parent = head
	local root = car.PrimaryPart
	torso.CFrame = root.CFrame * CFrame.new(0, 3.6, 1.2)
	head.CFrame = root.CFrame * CFrame.new(0, 4.9, 1.2)
	car.Parent = workspace:FindFirstChild("DiscoveryBay") or workspace

	task.spawn(function()
		local pts = route.pts
		local cur, target = routeStart(route, startFrac or 0)
		local dirSign = 1
		if reverse then
			dirSign = -1
			target = math.max(target - 1, 1)
		end
		while car.Parent do
			local dt = task.wait()
			local delta = pts[target] - cur
			local d = delta.Magnitude
			local step = CAR_SPEED * (dt or 0.03)
			if d <= step then
				cur = pts[target]
				target = target + dirSign
				if target > #pts then
					dirSign = -1
					target = #pts - 1
				elseif target < 1 then
					dirSign = 1
					target = 2
				end
			else
				local dir = delta / d
				local nextCur = cur + dir * step
				local nextPos = Vector3.new(nextCur.X, route.y + 0.05, nextCur.Z)
				local checkCF = CFrame.lookAt(nextPos + Vector3.new(0, 4, 0), nextPos + Vector3.new(0, 4, 0) + dir)
				if isRoadBoxBlocked(checkCF * CFrame.new(0, 0, -4), Vector3.new(8, 5, 18)) then
					dirSign = -dirSign
					target = math.clamp(target + dirSign, 1, #pts)
				else
					cur = nextCur
				end
				local pos = Vector3.new(cur.X, route.y + 0.05, cur.Z)
				car:PivotTo(CFrame.lookAt(pos, pos + dir))
				tryFling(pos, dir)
			end
		end
	end)
end

local function startTraffic(town)
	local kit = ReplicatedStorage:FindFirstChild("DiscoveryBayKit")
	local carTemplate = kit and kit:FindFirstChild("car")
	local roadsFolder = town:FindFirstChild("Roads")
	if not carTemplate or not roadsFolder then return end
	local filterList = {}
	if town:FindFirstChild("Buildings") then table.insert(filterList, town.Buildings) end
	if town:FindFirstChild("Landmarks") then table.insert(filterList, town.Landmarks) end
	carObstacleParams.FilterDescendantsInstances = filterList
	local routes = {}
	for _, model in ipairs(roadsFolder:GetChildren()) do
		local cls = model:GetAttribute("RoadClass")
		-- no cars on parking aisles / service lanes / farm tracks
		if cls ~= "s" and cls ~= "k" then
			local route = routeFromRoadModel(model)
			if route and route.length > 600 then
				routes[#routes + 1] = route
			end
		end
	end
	table.sort(routes, function(x, y) return x.length > y.length end)
	if #routes == 0 then return end
	local count = math.min(TRAFFIC_CARS, #routes * 4)
	for i = 1, count do
		local route = routes[((i - 1) % #routes) + 1]
		-- scatter cars along each route and alternate directions so streets feel alive
		driveCar(carTemplate, route, rng:NextNumber(), i % 2 == 0)
	end
	print("[DiscoveryBayShop] traffic: " .. count .. " NPC cars on the road. Watch out!")
end

local function hookScooterShop(deck)
	local prompt = deck:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(plr)
		if plr:GetAttribute("FastScooter") then
			TrickResult:FireClient(plr, "You already own the Fast Scooter!", 0)
			return
		end
		local cash = getCash(plr)
		if not cash or cash.Value < 1000 then
			TrickResult:FireClient(plr, "Not enough cash! The Fast Scooter costs $1000.", 0)
			return
		end
		cash.Value = cash.Value - 1000
		plr:SetAttribute("FastScooter", true)
		TrickResult:FireClient(plr, "Fast Scooter unlocked! Press G to ride in style.", 0)
		-- if already mounted, update their speed & color by respawning the scooter
		if plr:GetAttribute("Mounted") then
			updateSpeed(plr)
			spawnScooter(plr)
		end
	end)
end

--==============================================================================================
-- WIRE UP (waits for the build's BuildComplete attribute)
--==============================================================================================
task.spawn(function()
	local town = workspace:WaitForChild("DiscoveryBay", 300)
	if not town then
		warn("[DiscoveryBayShop] no DiscoveryBay model appeared; shop/traffic inactive")
		return
	end
	while not town:GetAttribute("BuildComplete") do
		task.wait(0.5)
	end
	local hooked = 0
	for _, d in ipairs(town:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "Register" then
				d:Destroy()
			elseif d:GetAttribute("Product") then
				hookProduct(d)
				hooked = hooked + 1
			elseif d:GetAttribute("AutoDoor") then
				hookDoor(d)
			elseif d:GetAttribute("JJMat") then
				hookMat(d)
			elseif d:GetAttribute("StudyButton") then
				hookStudy(d)
			elseif d:GetAttribute("RentSign") then
				if d.Parent then
					queueHouseForHollowing(d.Parent)
				end
				hookRent(d)
			elseif d:GetAttribute("EggShop") then
				hookEgg(d)
			elseif d:GetAttribute("FishSell") then
				hookFishSell(d)
			elseif d:GetAttribute("ScooterShop") then
				hookScooterShop(d)
			end
		end
	end
	local terry = town:FindFirstChild("Thirsty Terry", true)
	if terry and terry:IsA("Model") then
		local tTorso = terry:FindFirstChild("Torso")
		local kioskBack = terry.Parent and terry.Parent:FindFirstChild("KioskBack")
		if tTorso and kioskBack then
			local toWall = (kioskBack.Position - tTorso.Position).Unit
			if tTorso.CFrame.LookVector:Dot(toWall) > 0.2 then
				terry:PivotTo(terry:GetPivot() * CFrame.Angles(0, math.pi, 0))
			end
		end
	end
	startTraffic(town)
	print("[DiscoveryBayShop] " .. VERSION .. " ready — " .. hooked ..
		" products for sale (ShellBlox mini-mart + Callahan's + Bloxway).")
end)
