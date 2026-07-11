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
task.spawn(function()
	Lighting.ClockTime = 9 -- start on a sunny morning
	while true do
		task.wait(1)
		Lighting.ClockTime = (Lighting.ClockTime + 24 / DAY_LENGTH) % 24
	end
end)

local START_CASH = 100
local WALK_SPEED = 16
local SCOOTER_SPEED = 30
local VERSION = "v29"
local TRICK_COOLDOWN = 1.2
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
local HatchEgg = remote("HatchEgg") -- server -> client: play the on-screen hatch cinematic

-- Cash leaderboard ------------------------------------------------------------------------------
local function getCash(plr)
	local stats = plr:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function setupPlayer(plr)
	if not plr:FindFirstChild("leaderstats") then
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = START_CASH
		cash.Parent = stats
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
		local speed = SCOOTER_SPEED + (plr:GetAttribute("SodaBoost") or 0)
			+ (plr:GetAttribute("VanillaBoost") or 0) + (plr:GetAttribute("EduBoost") or 0)
		if plr:GetAttribute("SpeedPass") then
			speed = speed * 2 -- 2X Scooter Speed gamepass
		end
		humanoid.WalkSpeed = speed
	else
		humanoid.WalkSpeed = WALK_SPEED + (plr:GetAttribute("WalkBoost") or 0)
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
				anim.AnimationId = id
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

-- riding stance (R15): lean forward, stagger the feet. Stores both the original C0
-- (restored on dismount) and the stance C0 (what tricks return to).
local function poseStance(char, rig)
	local upperTorso = char:FindFirstChild("UpperTorso")
	local waist = upperTorso and upperTorso:FindFirstChild("Waist")
	if waist then
		local orig = waist.C0
		waist.C0 = orig * CFrame.Angles(math.rad(-8), 0, 0)
		rig.waist = { motor = waist, orig = orig, rest = waist.C0 }
	end
	rig.hips = {}
	local legPose = { Left = 12, Right = -6 }
	for side, deg in pairs(legPose) do
		local upperLeg = char:FindFirstChild(side .. "UpperLeg")
		local hip = upperLeg and upperLeg:FindFirstChild(side .. "Hip")
		if hip then
			local orig = hip.C0
			hip.C0 = orig * CFrame.Angles(math.rad(deg), 0, 0)
			table.insert(rig.hips, { motor = hip, orig = orig, rest = hip.C0 })
		end
	end
	rig.shoulders = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local upperArm = char:FindFirstChild(side .. "UpperArm")
		local shoulder = upperArm and upperArm:FindFirstChild(side .. "Shoulder")
		if shoulder then
			table.insert(rig.shoulders, { motor = shoulder, rest = shoulder.C0 })
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

	local floorDist
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -30, 0), params)
	if hit then
		floorDist = hrp.Position.Y - hit.Position.Y
	elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
		floorDist = humanoid.HipHeight + hrp.Size.Y / 2
	else
		floorDist = 3.0
	end
	floorDist = math.clamp(floorDist, 1.5, 8)

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

	sPart("Deck", Vector3.new(1.6, 0.25, 4.6), CFrame.new(0, deckY, 0.2), Color3.fromRGB(40, 40, 45), nil, deckRoot)
	sPart("Battery", Vector3.new(1.2, 0.35, 1.6), CFrame.new(0, deckY + 0.3, 0.8), Color3.fromRGB(60, 160, 90), nil, deckRoot)
	sPart("FrontWheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, wheelY, -2.2), Color3.fromRGB(25, 25, 25),
		Enum.PartType.Cylinder, deckRoot)
	sPart("RearWheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(0, wheelY, 2.4), Color3.fromRGB(25, 25, 25),
		Enum.PartType.Cylinder, deckRoot)
	local colH = 3.8
	sPart("Column", Vector3.new(0.25, colH, 0.25), CFrame.new(0, deckY + colH / 2, -2.2) * CFrame.Angles(math.rad(8), 0, 0),
		Color3.fromRGB(200, 200, 205))
	local handlebar = sPart("Handlebar", Vector3.new(2.3, 0.22, 0.22), CFrame.new(0, deckY + colH - 0.1, -1.95),
		Color3.fromRGB(40, 40, 45))
	m.Parent = char

	local rig = { char = char, deckMount = deckMount, deckBase = deckMount.C0, deckY = deckY, iks = {} }

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
					ik.SmoothTime = 0.06
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
				end
			end
		end
	end)
	if not okGrips then
		warn("[DiscoveryBayShop] hand grips skipped: " .. tostring(gripErr))
	end

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local okStance, stanceErr = pcall(poseStance, char, rig)
		if not okStance then
			warn("[DiscoveryBayShop] stance pose skipped: " .. tostring(stanceErr))
		end
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
local function spinDeck(rig, axis, dur)
	if not rig or not rig.deckMount or rig.spinning then return end
	rig.spinning = true
	task.spawn(function()
		-- tuck the knees up while the deck whips underneath (real tailwhip form)
		local tucked = {}
		if rig.hips and not rig.posing then
			for _, hh in ipairs(rig.hips) do
				if hh.motor.Parent then
					hh.motor.C0 = hh.rest * CFrame.Angles(math.rad(-55), 0, 0)
					tucked[#tucked + 1] = hh
				end
			end
		end
		local steps = 16
		local dy = rig.deckY or -3.0
		local pivot = axis == "y" and CFrame.new(0, dy, -2.2) or CFrame.new(0, dy, 0.2)
		local waistOK = rig.waist and rig.waist.motor.Parent and not rig.posing
		for i = 1, steps do
			local mount = rig.deckMount
			if not mount or not mount.Parent then break end
			local a = (i / steps) * math.pi * 2
			local rot = axis == "y" and CFrame.Angles(0, a, 0) or CFrame.Angles(0, 0, a)
			mount.C0 = rig.deckBase * pivot * rot * pivot:Inverse()
			-- the RIDER moves too: dip into the tailwhip, lean through the kickflip
			if waistOK then
				local wave = math.sin((i / steps) * math.pi)
				if axis == "y" then
					rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(math.rad(-24 * wave), 0, 0)
				else
					rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(0, 0, math.rad(26 * wave))
				end
			end
			task.wait(dur / steps)
		end
		if rig.deckMount and rig.deckMount.Parent then
			rig.deckMount.C0 = rig.deckBase
		end
		if waistOK and rig.waist.motor.Parent then
			rig.waist.motor.C0 = rig.waist.rest
		end
		for _, hh in ipairs(tucked) do
			if hh.motor.Parent then hh.motor.C0 = hh.rest end
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
			h.motor.C0 = h.rest * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
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
		if rig.waist and rig.waist.motor.Parent then
			rig.waist.motor.C0 = rig.waist.rest
		end
		rig.posing = false
	end)
end

local function armsBack(rig, dur)
	if not rig or not rig.shoulders or #rig.shoulders == 0 or rig.posing or rig.spinning then return end
	rig.posing = true
	for _, ik in ipairs(rig.iks) do
		if ik.Parent then ik.Enabled = false end
	end
	for _, s in ipairs(rig.shoulders) do
		if s.motor.Parent then
			s.motor.C0 = s.rest * CFrame.Angles(math.rad(-130), 0, 0)
		end
	end
	-- lean back with the arms flung: full no-hander commitment
	if rig.waist and rig.waist.motor.Parent then
		rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(math.rad(-16), 0, 0)
	end
	task.delay(dur, function()
		for _, s in ipairs(rig.shoulders) do
			if s.motor.Parent then s.motor.C0 = s.rest end
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

local TRICKS = {
	{ name = "Tailwhip", pay = 4, fn = function(rig, hrp) spinDeck(rig, "y", 0.45) end },
	{ name = "Kickflip", pay = 3, fn = function(rig, hrp) spinDeck(rig, "z", 0.5) end },
	{ name = "360 Spin", pay = 6, fn = function(rig, hrp)
		local dirSign = (rng:NextInteger(0, 1) == 0 and 1 or -1)
		-- wind the shoulders up, then whip the whole rider around
		task.spawn(function()
			if rig and rig.waist and rig.waist.motor.Parent and not rig.posing and not rig.spinning then
				rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(0, math.rad(-30 * dirSign), 0)
				task.wait(0.12)
				rig.waist.motor.C0 = rig.waist.rest * CFrame.Angles(0, math.rad(14 * dirSign), 0)
				task.wait(0.35)
				if rig.waist.motor.Parent then
					rig.waist.motor.C0 = rig.waist.rest
				end
			end
		end)
		hrp.AssemblyAngularVelocity = Vector3.new(0, dirSign * 22, 0)
	end },
	{ name = "Superman", pay = 8, fn = function(rig, hrp) legsBack(rig, 0.55) end },
	{ name = "No-Hander", pay = 5, fn = function(rig, hrp) armsBack(rig, 0.5) end },
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
		trick.fn(rig, hrp)
		local pay = trick.pay * (plr:GetAttribute("TrickMult") or 1)
		cash.Value = cash.Value + pay
		TrickResult:FireClient(plr, trick.name, pay)
	end

	if humanoid.FloorMaterial == Enum.Material.Air then
		perform()
	else
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, 36, v.Z)
		task.delay(0.32, perform)
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
	["Soda"] = function(plr)
		bumpAttribute(plr, "SodaBoost", 4, 20)
		updateSpeed(plr)
		return "Soda rush! Scooter speed +4"
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
-- HOUSES FOR RENT + EGG SHOP DOGS
--==============================================================================================
local EGG_PRICE = 30
local PET_COOLDOWN = 2
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

-- Renting a house makes it REAL: the solid body is swapped for walls with a
-- walk-through front door, plus a furnished living room. Runs once per house.
local function hollowHouse(house)
	if house:GetAttribute("Hollowed") then return end
	house:SetAttribute("Hollowed", true)
	local body = house:FindFirstChild("Body")
	if not body then return end
	local cfB, size = body.CFrame, body.Size
	local col, mat = body.Color, body.Material
	local w, h, d = size.X, size.Y, size.Z
	body:Destroy()
	local function wall(name, sz, off, wcol, wmat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.CFrame = cfB * off
		p.Color = wcol or col
		p.Material = wmat or mat
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = house
		return p
	end
	wall("Floor", Vector3.new(w, 0.4, d), CFrame.new(0, -h / 2 + 0.2, 0),
		Color3.fromRGB(160, 125, 85), Enum.Material.WoodPlanks)
	wall("Ceiling", Vector3.new(w, 0.4, d), CFrame.new(0, h / 2 - 0.2, 0),
		Color3.fromRGB(238, 234, 224), Enum.Material.SmoothPlastic)
	wall("BackWall", Vector3.new(w, h, 0.8), CFrame.new(0, 0, d / 2 - 0.4))
	wall("SideL", Vector3.new(0.8, h, d), CFrame.new(-w / 2 + 0.4, 0, 0))
	wall("SideR", Vector3.new(0.8, h, d), CFrame.new(w / 2 - 0.4, 0, 0))
	-- front wall with a doorway where the door visual stands
	local doorX = 0
	local door = house:FindFirstChild("Door")
	if door then
		local rel = cfB:PointToObjectSpace(door.Position)
		doorX = math.clamp(rel.X, -w / 2 + 5, w / 2 - 5)
		door.CanCollide = false -- walk right through your own front door
	end
	local gapW = 5.5
	local leftW = (doorX - gapW / 2) - (-w / 2)
	if leftW > 0.6 then
		wall("FrontL", Vector3.new(leftW, h, 0.8), CFrame.new(-w / 2 + leftW / 2, 0, -d / 2 + 0.4))
	end
	local rightW = (w / 2) - (doorX + gapW / 2)
	if rightW > 0.6 then
		wall("FrontR", Vector3.new(rightW, h, 0.8), CFrame.new(w / 2 - rightW / 2, 0, -d / 2 + 0.4))
	end
	if h > 8.4 then
		wall("DoorHeader", Vector3.new(gapW, h - 7.6, 0.8),
			CFrame.new(doorX, h / 2 - (h - 7.6) / 2, -d / 2 + 0.4))
	end
	-- cozy furnishing
	wall("Rug", Vector3.new(math.min(w * 0.4, 12), 0.15, math.min(d * 0.35, 9)),
		CFrame.new(0, -h / 2 + 0.5, 0), Color3.fromRGB(170, 60, 60), Enum.Material.Fabric)
	wall("Sofa", Vector3.new(8, 2.4, 3), CFrame.new(-w * 0.22, -h / 2 + 1.6, d * 0.22),
		Color3.fromRGB(90, 110, 150), Enum.Material.Fabric)
	wall("SofaBack", Vector3.new(8, 2, 0.8), CFrame.new(-w * 0.22, -h / 2 + 3.6, d * 0.22 + 1.1),
		Color3.fromRGB(90, 110, 150), Enum.Material.Fabric)
	wall("Table", Vector3.new(4.5, 2.2, 3), CFrame.new(0, -h / 2 + 1.5, -d * 0.05),
		Color3.fromRGB(140, 105, 70), Enum.Material.WoodPlanks)
	wall("Bed", Vector3.new(6.5, 1.8, 4), CFrame.new(w * 0.26, -h / 2 + 1.3, d * 0.28),
		Color3.fromRGB(230, 230, 240), Enum.Material.Fabric)
	wall("DogBed", Vector3.new(3.5, 0.6, 3.5), CFrame.new(w * 0.28, -h / 2 + 0.7, -d * 0.22),
		Color3.fromRGB(120, 85, 60), Enum.Material.Fabric)
	local lampPart = wall("Lamp", Vector3.new(1, 4.5, 1), CFrame.new(w * 0.4 - 1.5, -h / 2 + 2.6, -d * 0.4 + 1.5),
		Color3.fromRGB(240, 230, 200), Enum.Material.Neon)
	local lampLight = Instance.new("PointLight")
	lampLight.Range = 22
	lampLight.Brightness = 1.2
	lampLight.Parent = lampPart
	-- where a hatched dog waits: on the dog bed, inside
	house:SetAttribute("DogSpotInside", (cfB * CFrame.new(w * 0.28, -h / 2 + 1, -d * 0.22)).Position)
end

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
	local function dp(name, size, off, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * k
		p.CFrame = CFrame.new(base + off * k)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.Parent = mdl
		if shape then p.Shape = shape end
		return p
	end
	local c = dogDef.color
	local a = dogDef.accent or c
	local body = dp("Body", Vector3.new(2.2, 1.8, 3.6), Vector3.new(0, 2.1, 0), c)
	dp("Chest", Vector3.new(1.6, 1.2, 0.6), Vector3.new(0, 1.9, -1.7), a) -- breed marking
	dp("Head", Vector3.new(1.7, 1.7, 1.7), Vector3.new(0, 3.4, -1.9), c, Enum.PartType.Ball)
	dp("Snout", Vector3.new(0.8, 0.6, 0.9), Vector3.new(0, 3.1, -2.8), a)
	dp("EarL", Vector3.new(0.4, 0.9, 0.4), Vector3.new(-0.6, 4.3, -1.9), c)
	dp("EarR", Vector3.new(0.4, 0.9, 0.4), Vector3.new(0.6, 4.3, -1.9), c)
	dp("Tail", Vector3.new(0.4, 0.4, 1.5), Vector3.new(0, 2.9, 2.2), c)
	for _, lx in ipairs({ -0.7, 0.7 }) do
		for _, lz in ipairs({ -1.2, 1.2 }) do
			-- front legs carry the accent ("boots"), back legs stay the base coat
			dp("Leg", Vector3.new(0.6, 1.4, 0.6), Vector3.new(lx, 0.7, lz),
				lz < 0 and a or c)
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
	mdl.Parent = town
	playerDog[plr.UserId] = mdl
end

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
		local roll = rng:NextInteger(1, 200)
		local dogDef
		if roll <= 2 then
			dogDef = DOGS[3] -- Linus, 1%
		elseif roll <= 101 then
			dogDef = DOGS[1] -- Mary
		else
			dogDef = DOGS[2] -- Jolene
		end
		local homeSpot = home.house:GetAttribute("DogSpotInside")
			or home.house:GetAttribute("DogSpot") or home.house:GetPivot().Position
		-- Pet-Sim-X-style hatch: the cinematic plays ON THE PLAYER'S SCREEN (client),
		-- while the pet spawns at home ready for petting afterwards
		HatchEgg:FireClient(plr, dogDef.name)
		spawnDog(plr, dogDef, Vector3.new(homeSpot.X, homeSpot.Y, homeSpot.Z))
	end)
end

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

--==============================================================================================
-- AUTO-SLIDING DOORS
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

--==============================================================================================
-- NPC TRAFFIC
--==============================================================================================
local flingCooldown = {}

local function tryFling(carPos, carDir)
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		local humanoid = ch and ch:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 then
			local now = os.clock()
			if not flingCooldown[plr.UserId] or now - flingCooldown[plr.UserId] > 3 then
				local off = hrp.Position - carPos
				local flat = Vector3.new(off.X, 0, off.Z)
				-- flat (ground) distance so the rider's height can never make a car miss
				if flat.Magnitude < FLING_RADIUS and math.abs(off.Y) < 12 then
					flingCooldown[plr.UserId] = now
					local away = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(1, 0, 0)
					humanoid.Sit = true
					hrp.AssemblyLinearVelocity = away * 55 + carDir * 30 + Vector3.new(0, 70, 0)
					hrp.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), 0)
					-- traffic is lethal, no exceptions: shred any forcefield, deal massive
					-- damage AND hard-zero the health
					local ff = ch:FindFirstChildOfClass("ForceField")
					if ff then ff:Destroy() end
					humanoid:TakeDamage(CAR_DAMAGE)
					humanoid.Health = 0
				end
			end
		end
	end
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
				cur = cur + dir * step
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
			if d:GetAttribute("Product") then
				hookProduct(d)
				hooked = hooked + 1
			elseif d:GetAttribute("AutoDoor") then
				hookDoor(d)
			elseif d:GetAttribute("JJMat") then
				hookMat(d)
			elseif d:GetAttribute("StudyButton") then
				hookStudy(d)
			elseif d:GetAttribute("RentSign") then
				hookRent(d)
			elseif d:GetAttribute("EggShop") then
				hookEgg(d)
			end
		end
	end
	startTraffic(town)
	print("[DiscoveryBayShop] " .. VERSION .. " ready — " .. hooked ..
		" products for sale (Shell mini-mart + Callahan's).")
end)
