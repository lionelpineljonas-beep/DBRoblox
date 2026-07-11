"""Execute DiscoveryBayShop.luau in a mocked Roblox environment (lupa) and drive the
mount -> trick -> dismount -> remount flow, printing every Lua error with a traceback.
"""

import os
import lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
shop_src = open(os.path.join(ROOT, "DiscoveryBayShop.luau"), encoding="utf-8").read()

lua = lupa.LuaRuntime(unpack_returned_tuples=True)

PRELUDE = r"""
-- ============================ mini Roblox mock ============================
local now = 0
os = { clock = function() return now end }
math.clamp = math.clamp or function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
table.create = table.create or function(n) return {} end

-- scheduler ----------------------------------------------------------------
local scheduled = {}
local function resumeTask(co, ...)
  local ok, dt = coroutine.resume(co, ...)
  if not ok then
    print("!! LUA ERROR in task: " .. tostring(dt))
    print(debug.traceback(co))
  elseif coroutine.status(co) == "suspended" then
    local d = tonumber(dt) or 0.03
    table.insert(scheduled, { co = co, at = now + d, dt = d })
  end
end
task = {
  spawn = function(f, ...)
    if type(f) == "function" then
      resumeTask(coroutine.create(f), ...)
    end
  end,
  wait = function(t) return coroutine.yield(t or 0.03) end,
  delay = function(t, f)
    table.insert(scheduled, { co = coroutine.create(f), at = now + (t or 0) })
  end,
}
function PUMP(seconds)
  local target = now + seconds
  while now < target do
    now = now + 0.05
    local due = {}
    for i = #scheduled, 1, -1 do
      if scheduled[i].at <= now then
        table.insert(due, table.remove(scheduled, i))
      end
    end
    for _, item in ipairs(due) do
      -- task.wait() returns the elapsed time, like real Roblox
      resumeTask(item.co, item.dt or 0.05)
    end
  end
end

-- math types -----------------------------------------------------------------
local V3mt
local function v3(x, y, z)
  return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt)
end
V3mt = {
  __add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
  __sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
  __mul = function(a, b)
    if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
    return v3(a * b.X, a * b.Y, a * b.Z)
  end,
  __div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end,
  __index = function(t, k)
    if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
    if k == "Unit" then
      local m = math.max(math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2), 1e-9)
      return v3(t.X / m, t.Y / m, t.Z / m)
    end
    return nil
  end,
}
Vector3 = { new = v3, zero = v3(0, 0, 0) }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }

local CFmt
local function cf(x, y, z)
  return setmetatable({ Position = v3(x or 0, y or 0, z or 0),
    RightVector = v3(1, 0, 0), LookVector = v3(0, 0, -1) }, CFmt)
end
CFmt = {
  __mul = function(a, b)
    return cf(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
  end,
  __index = function(t, k)
    if k == "Inverse" then
      return function(self) return cf(-self.Position.X, -self.Position.Y, -self.Position.Z) end
    end
    if k == "PointToObjectSpace" then
      return function(self, p)
        return v3(p.X - self.Position.X, p.Y - self.Position.Y, p.Z - self.Position.Z)
      end
    end
    return nil
  end,
}
CFrame = {
  new = function(a, b, c)
    if type(a) == "table" then return cf(a.X, a.Y, a.Z) end
    return cf(a, b, c)
  end,
  Angles = function() return cf(0, 0, 0) end,
  lookAt = function(p, t) return cf(p.X, p.Y, p.Z) end,
  identity = cf(0, 0, 0),
}
Color3 = { new = function() return {} end, fromRGB = function() return {} end,
  fromHSV = function() return {} end, fromHex = function() return {} end }
UDim = { new = function() return {} end }
UDim2 = { new = function() return {} end, fromScale = function() return {} end }
TweenInfo = { new = function() return {} end }
RaycastParams = { new = function() return {} end }
Random = { new = function()
  return {
    NextInteger = function(self, a, b) return a end,
    NextNumber = function(self, a, b) if a then return a end return 0.5 end,
  }
end }

-- Enum: cached auto paths ------------------------------------------------------
local enumCache = {}
Enum = setmetatable({}, { __index = function(t, k)
  enumCache[k] = enumCache[k] or setmetatable({}, { __index = function(t2, k2)
    rawset(t2, k2, { EnumFamily = k, Name = k2 })
    return rawget(t2, k2)
  end })
  return enumCache[k]
end })

-- signals ------------------------------------------------------------------------
local function newSignal()
  local s = { handlers = {} }
  function s:Connect(f)
    table.insert(self.handlers, f)
    local conn = { Connected = true }
    function conn:Disconnect() conn.Connected = false end
    self._conns = self._conns or {}
    self._conns[f] = conn
    return conn
  end
  function s:Fire(...)
    for _, f in ipairs(self.handlers) do
      if not self._conns or self._conns[f] == nil or self._conns[f].Connected then
        task.spawn(f, ...)
      end
    end
  end
  return s
end
NEW_SIGNAL = newSignal

-- instances ----------------------------------------------------------------------
local InstanceMT
local function newInst(class, name)
  local inst = { ClassName = class, _name = name or class, _children = {},
    _props = {}, _attrs = {}, _propSignals = {}, _attrSignals = {}, _destroyed = false }
  return setmetatable(inst, InstanceMT)
end

local methods = {}
function methods.FindFirstChild(self, name, recursive)
  for _, c in ipairs(self._children) do
    if c._name == name then return c end
  end
  if recursive then
    for _, c in ipairs(self._children) do
      local hit = c:FindFirstChild(name, true)
      if hit then return hit end
    end
  end
  return nil
end
function methods.WaitForChild(self, name, timeout)
  return self:FindFirstChild(name)
end
function methods.FindFirstChildOfClass(self, class)
  for _, c in ipairs(self._children) do
    if c.ClassName == class then return c end
  end
  return nil
end
function methods.GetChildren(self)
  local out = {}
  for i, c in ipairs(self._children) do out[i] = c end
  return out
end
function methods.GetDescendants(self)
  local out = {}
  local function walk(node)
    for _, c in ipairs(node._children) do
      table.insert(out, c)
      walk(c)
    end
  end
  walk(self)
  return out
end
function methods.SetAttribute(self, k, v)
  self._attrs[k] = v
  if self._attrSignals[k] then self._attrSignals[k]:Fire() end
end
function methods.GetAttribute(self, k) return self._attrs[k] end
function methods.GetAttributeChangedSignal(self, k)
  self._attrSignals[k] = self._attrSignals[k] or newSignal()
  return self._attrSignals[k]
end
function methods.GetPropertyChangedSignal(self, k)
  self._propSignals[k] = self._propSignals[k] or newSignal()
  return self._propSignals[k]
end
function methods.Destroy(self)
  self.Parent = nil
  self._destroyed = true
end
function methods.Clone(self)
  local c = newInst(self.ClassName, self._name)
  for k, v in pairs(self._props) do c._props[k] = v end
  for k, v in pairs(self._attrs) do c._attrs[k] = v end
  for _, child in ipairs(self._children) do
    local cc = child:Clone()
    cc.Parent = c
  end
  return c
end
function methods.PivotTo(self, cframe) end
function methods.GetPivot(self) return CFrame.new(0, 0, 0) end
function methods.IsA(self, class)
  if class == "BasePart" then
    return self.ClassName == "Part" or self.ClassName == "WedgePart"
      or self.ClassName == "SpawnLocation" or self.ClassName == "Seat"
  end
  return self.ClassName == class
end
function methods.GetPlayingAnimationTracks(self) return {} end
function methods.ChangeState(self, state) end
function methods.TakeDamage(self, amount)
  self.Health = math.max((self.Health or 100) - amount, 0)
end
function methods.FindFirstAncestor(self, name)
  local node = rawget(self, "_parent")
  while node do
    if node._name == name then return node end
    node = rawget(node, "_parent")
  end
  return nil
end
function methods.FireClient(self, plr, a, b)
  print(("  [FireClient] %s <- %s / %s"):format(tostring(plr._name), tostring(a), tostring(b)))
end
function methods.LoadCharacter(self) end

InstanceMT = {
  __index = function(t, k)
    if methods[k] then return methods[k] end
    if k == "Name" then return rawget(t, "_name") end
    if k == "Parent" then return rawget(t, "_parent") end
    local p = rawget(t, "_props")[k]
    if p ~= nil then return p end
    local child = methods.FindFirstChild(t, k)
    if child then return child end
    return nil
  end,
  __newindex = function(t, k, v)
    if k == "Name" then rawset(t, "_name", v) return end
    if k == "Parent" then
      local old = rawget(t, "_parent")
      if old then
        for i, c in ipairs(old._children) do
          if c == t then table.remove(old._children, i) break end
        end
      end
      rawset(t, "_parent", v)
      if v then table.insert(v._children, t) end
      return
    end
    rawget(t, "_props")[k] = v
    local sig = rawget(t, "_propSignals")[k]
    if sig then sig:Fire() end
  end,
}

Instance = { new = function(class)
  local inst = newInst(class)
  if class == "Part" or class == "WedgePart" or class == "SpawnLocation" then
    inst._props.Size = v3(4, 1, 2)
    inst._props.CFrame = cf(0, 0, 0)
    inst._props.Position = v3(0, 0, 0)
    inst._props.Anchored = false
    inst._props.AssemblyLinearVelocity = v3(0, 0, 0)
    inst._props.AssemblyAngularVelocity = v3(0, 0, 0)
    inst._props.Touched = newSignal()
  end
  if class == "RemoteEvent" then
    inst._props.OnServerEvent = newSignal()
  end
  if class == "Motor6D" then
    inst._props.C0 = cf(0, 0, 0)
    inst._props.C1 = cf(0, 0, 0)
  end
  if class == "ProximityPrompt" then
    inst._props.Triggered = newSignal()
  end
  if class == "ClickDetector" then
    inst._props.MouseClick = newSignal()
  end
  if class == "IntValue" then inst._props.Value = 0 end
  return inst
end }
NEW_INST = newInst

-- world ---------------------------------------------------------------------------
workspace = newInst("Workspace", "Workspace")
workspace._props.StreamingEnabled = true
function workspace.Raycast(self, origin, dir, params)
  return { Position = v3(origin.X, origin.Y - 2.35, origin.Z) }
end

local ReplicatedStorage = newInst("ReplicatedStorage", "ReplicatedStorage")
local PlayersService = newInst("Players", "Players")
PlayersService._props.PlayerAdded = newSignal()
PlayersService._props.PlayerRemoving = newSignal()
local playerList = {}
function PlayersService.GetPlayers(self) return playerList end
function PlayersService.GetPlayerFromCharacter(self, ch)
  for _, p in ipairs(playerList) do
    if p.Character == ch then return p end
  end
  return nil
end

local Marketplace = newInst("MarketplaceService", "MarketplaceService")
Marketplace._props.PromptGamePassPurchaseFinished = newSignal()

local TweenService = newInst("TweenService", "TweenService")
function TweenService.Create(self, inst, info, props)
  return { Play = function()
    for k, v in pairs(props) do inst[k] = v end
  end }
end

local services = { Players = PlayersService, ReplicatedStorage = ReplicatedStorage,
  TweenService = TweenService, Workspace = workspace, MarketplaceService = Marketplace }
game = newInst("DataModel", "game")
function game.GetService(self, name)
  if not services[name] then
    services[name] = newInst(name, name) -- singleton, like real Roblox services
  end
  return services[name]
end

-- town with roads (for traffic) + kit with car template
local town = newInst("Model", "DiscoveryBay")
town.Parent = workspace
town._attrs.BuildComplete = true
local roadsFolder = newInst("Folder", "Roads")
roadsFolder.Parent = town
local roadModel = newInst("Model", "Discovery Bay Boulevard")
roadModel.Parent = roadsFolder
for i = 1, 4 do
  local seg = Instance.new("Part")
  seg.Name = "Seg"
  seg._props.Size = v3(26, 0.45, 400)
  seg._props.CFrame = cf(0, 2.025, i * 400)
  seg._props.Position = v3(0, 2.025, i * 400)
  seg.Parent = roadModel
end
-- a rentable house with its sign, and the egg shop
local house = newInst("Model", "House")
house._attrs.DogSpot = v3(300, 2, 300)
house.Parent = town
local houseBody = Instance.new("Part")
houseBody.Name = "Body"
houseBody._props.Size = v3(40, 11, 30)
houseBody._props.CFrame = cf(300, 8, 285)
houseBody._props.Color = { body = true }
houseBody._props.Material = { plastic = true }
houseBody.Parent = house
local houseDoor = Instance.new("Part")
houseDoor.Name = "Door"
houseDoor._props.Position = v3(305, 5, 270)
houseDoor.Parent = house
-- legacy pre-v35 towns: a solid decorative slab over the doorway (must be unblocked on rent)
local houseFrame = Instance.new("Part")
houseFrame.Name = "DoorFrame"
houseFrame._props.CanCollide = true
houseFrame.Parent = house
local rentBoard = Instance.new("Part")
rentBoard.Name = "RentSign"
rentBoard._attrs.RentSign = true
local rentClick = Instance.new("ClickDetector")
rentClick.Parent = rentBoard
rentBoard.Parent = house
RENTBOARD = rentBoard
HOUSE = house
local eggPart = Instance.new("Part")
eggPart.Name = "MysteryEgg"
eggPart._attrs.EggShop = true
local eggPrompt = Instance.new("ProximityPrompt")
eggPrompt.Parent = eggPart
eggPart.Parent = town
EGG = eggPart

-- study button (school classroom)
local studyBtn = Instance.new("Part")
studyBtn.Name = "StudyButton"
studyBtn._attrs.StudyButton = true
local studyPrompt = Instance.new("ProximityPrompt")
studyPrompt.Parent = studyBtn
studyBtn.Parent = town
STUDY = studyBtn

-- jiu jitsu mat
local jjMat = Instance.new("Part")
jjMat.Name = "ChallengeMat"
jjMat._props.Size = v3(20, 0.5, 14)
jjMat._props.CFrame = cf(200, 2.65, 200)
jjMat._props.Position = v3(200, 2.65, 200)
jjMat._attrs.JJMat = true
jjMat.Parent = town
JJMAT = jjMat

local kit = newInst("Folder", "DiscoveryBayKit")
kit.Parent = ReplicatedStorage
local carT = newInst("Model", "car")
local carRoot = Instance.new("Part")
carRoot.Name = "Root"
carRoot.Parent = carT
carT._props.PrimaryPart = carRoot
local carBody = Instance.new("Part")
carBody.Name = "Body"
carBody.Parent = carT
carT.Parent = kit

-- player + R15 character ------------------------------------------------------------
local function makeCharacter()
  local char = newInst("Model", "Rig")
  local hum = newInst("Humanoid", "Humanoid")
  hum._props.RigType = Enum.HumanoidRigType.R15
  hum._props.HipHeight = 1.35
  hum._props.FloorMaterial = Enum.Material.Grass
  hum._props.Health = 100
  hum._props.WalkSpeed = 16
  hum._props.Died = newSignal()
  hum.Parent = char
  local animator = newInst("Animator", "Animator")
  animator.Parent = hum
  local hrp = Instance.new("Part")
  hrp.Name = "HumanoidRootPart"
  hrp._props.Size = v3(2, 2, 1)
  hrp._props.CFrame = cf(0, 4.35, 0)
  hrp._props.Position = v3(0, 4.35, 0)
  hrp.Parent = char
  local animate = newInst("LocalScript", "Animate")
  animate.Parent = char
  for _, g in ipairs({ { "run", "RunAnim" }, { "walk", "WalkAnim" } }) do
    local grp = newInst("StringValue", g[1])
    grp.Parent = animate
    local anim = newInst("Animation", g[2])
    anim._props.AnimationId = "default"
    anim.Parent = grp
  end
  local function wireMotor(motor, p0, p1)
    motor._props.C0 = cf(0, 0, 0)
    motor._props.C1 = cf(0, 0, 0)
    motor._props.Part0 = p0
    motor._props.Part1 = p1
  end
  local ut = Instance.new("Part") ut.Name = "UpperTorso" ut.Parent = char
  local waist = newInst("Motor6D", "Waist") wireMotor(waist, hrp, ut) waist.Parent = ut
  for _, side in ipairs({ "Left", "Right" }) do
    local leg = Instance.new("Part") leg.Name = side .. "UpperLeg" leg.Parent = char
    local hip = newInst("Motor6D", side .. "Hip") wireMotor(hip, ut, leg) hip.Parent = leg
    local arm = Instance.new("Part") arm.Name = side .. "UpperArm" arm.Parent = char
    local sh = newInst("Motor6D", side .. "Shoulder") wireMotor(sh, ut, arm) sh.Parent = arm
    local hand = Instance.new("Part") hand.Name = side .. "Hand" hand.Parent = char
  end
  return char, hum, hrp
end

PLAYER = newInst("Player", "TestPlayer")
PLAYER.Parent = PlayersService -- real players are always parented to Players
PLAYER._props.UserId = 1
PLAYER._props.CharacterAdded = newSignal()
function PLAYER.HasAppearanceLoaded(self) return true end
local backpack = newInst("Backpack", "Backpack")
backpack.Parent = PLAYER
CHAR, HUM, HRP = makeCharacter()
CHAR.Parent = workspace
PLAYER._props.Character = CHAR
table.insert(playerList, PLAYER)
MAKE_CHARACTER = makeCharacter
"""

lua.execute(PRELUDE)

# load the shop script
load_shop = lua.eval("function(src) local f, e = load(src, 'DiscoveryBayShop') if not f then error(e) end return f end")
shop_fn = load_shop(shop_src)
ok = lua.eval("function(f) local ok, err = pcall(f) if not ok then print('!! LOAD ERROR: ' .. tostring(err)) end return ok end")(shop_fn)
print("script loaded:", ok)

lua.execute(r"""
print("--- pump 12s (mount should complete) ---")
PUMP(12)
print("Mounted attribute:", tostring(PLAYER:GetAttribute("Mounted")))
print("HipHeight:", HUM.HipHeight)
print("WalkSpeed:", HUM.WalkSpeed)
print("Scooter model present:", tostring(CHAR:FindFirstChild("Scooter") ~= nil))

local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("DiscoveryBayRemotes")
local DoTrick = remotes and remotes:FindFirstChild("DoTrick")
local Toggle = remotes and remotes:FindFirstChild("ToggleScooter")
print("remotes:", tostring(DoTrick ~= nil), tostring(Toggle ~= nil))

print("--- fire DoTrick('Tailwhip') ---")
DoTrick.OnServerEvent:Fire(PLAYER, "Tailwhip")
PUMP(2)
local cash = PLAYER:FindFirstChild("leaderstats") and PLAYER.leaderstats:FindFirstChild("Cash")
print("Cash after trick:", cash and cash.Value or "NO CASH")

print("--- fire DoTrick('Superman') airborne ---")
HUM.FloorMaterial = Enum.Material.Air
DoTrick.OnServerEvent:Fire(PLAYER, "Superman")
PUMP(2)
HUM.FloorMaterial = Enum.Material.Grass
print("Cash after 2nd trick:", cash and cash.Value or "NO CASH")

print("--- toggle off (should PARK the scooter in the world) ---")
Toggle.OnServerEvent:Fire(PLAYER)
PUMP(2)
local parked = workspace:FindFirstChild("ParkedScooter", true)
print("Mounted:", tostring(PLAYER:GetAttribute("Mounted")), "HipHeight:", HUM.HipHeight,
	"riding rig:", tostring(CHAR:FindFirstChild("Scooter") ~= nil),
	"PARKED in world:", tostring(parked ~= nil), "WalkSpeed:", HUM.WalkSpeed)

print("--- remount via the parked scooter's Ride prompt (E) ---")
local deck = parked and parked:FindFirstChild("Deck")
local ridePrompt = deck and deck:FindFirstChildOfClass("ProximityPrompt")
if ridePrompt then ridePrompt.Triggered:Fire(PLAYER) end
PUMP(8)
print("Mounted:", tostring(PLAYER:GetAttribute("Mounted")), "HipHeight:", HUM.HipHeight,
	"riding rig:", tostring(CHAR:FindFirstChild("Scooter") ~= nil),
	"parked gone:", tostring(workspace:FindFirstChild("ParkedScooter", true) == nil))

print("--- park again, walk FAR away, press G (should get a hint, stay on foot) ---")
Toggle.OnServerEvent:Fire(PLAYER)
PUMP(2)
HRP.Position = Vector3.new(500, 4.35, 500)
Toggle.OnServerEvent:Fire(PLAYER)
PUMP(2)
print("Mounted after far G:", tostring(PLAYER:GetAttribute("Mounted")),
	"parked still there:", tostring(workspace:FindFirstChild("ParkedScooter", true) ~= nil))
HRP.Position = Vector3.new(0, 4.35, 0)
Toggle.OnServerEvent:Fire(PLAYER)
PUMP(8)
print("Mounted after near G:", tostring(PLAYER:GetAttribute("Mounted")))

print("--- trick again after remount ---")
DoTrick.OnServerEvent:Fire(PLAYER, "Kickflip")
PUMP(2)
print("Cash after 3rd trick:", cash and cash.Value or "NO CASH")

print("--- RACE TEST: two overlapping mounts must not stack the hip raise ---")
Toggle.OnServerEvent:Fire(PLAYER) -- dismount (parks it)
PUMP(1)
HUM.FloorMaterial = Enum.Material.Air -- forces mount to wait, opening the race window
Toggle.OnServerEvent:Fire(PLAYER)      -- mount attempt #1 (near parked scooter)
PUMP(0.2)
local parked2 = workspace:FindFirstChild("ParkedScooter", true)
local deck2 = parked2 and parked2:FindFirstChild("Deck")
local prompt2 = deck2 and deck2:FindFirstChildOfClass("ProximityPrompt")
if prompt2 then prompt2.Triggered:Fire(PLAYER) end -- mount attempt #2, overlapping
PUMP(0.2)
HUM.FloorMaterial = Enum.Material.Grass -- let the waits finish
PUMP(8)
print("HipHeight after race (must be ~1.95, NOT 2.55):", HUM.HipHeight)
local scooterCount = 0
for _, c in ipairs(CHAR:GetChildren()) do
  if c.Name == "Scooter" then scooterCount = scooterCount + 1 end
end
print("riding rigs on character (must be 1):", scooterCount)
Toggle.OnServerEvent:Fire(PLAYER)
PUMP(2)
print("HipHeight after dismount (must be 1.35):", HUM.HipHeight)

print("--- WEDGED-STATE TEST: Mounted attr stale-false while scooter model exists ---")
Toggle.OnServerEvent:Fire(PLAYER) -- remount (near parked)
PUMP(8)
PLAYER:SetAttribute("Mounted", false) -- simulate a stale/wedged attribute
PUMP(1)
Toggle.OnServerEvent:Fire(PLAYER)     -- G must STILL dismount
PUMP(2)
print("scooter gone after wedged G:", tostring(CHAR:FindFirstChild("Scooter") == nil),
	"HipHeight:", HUM.HipHeight,
	"parked exists:", tostring(workspace:FindFirstChild("ParkedScooter", true) ~= nil))

print("--- TRAFFIC KILL TEST: stand in the road, expect death ---")
HRP.Position = Vector3.new(0, 4.35, 600) -- a route hub the cars keep crossing
PUMP(26)
print("Health after standing in traffic (must be 0):", HUM.Health)

print("--- RESPAWN TEST: new character after death must remount automatically ---")
local newChar, newHum, newHrp = MAKE_CHARACTER()
newChar.Parent = workspace
PLAYER.Character = newChar
PLAYER.CharacterAdded:Fire(newChar)
PUMP(10)
print("Mounted on respawn:", tostring(PLAYER:GetAttribute("Mounted")),
	"scooter on new char:", tostring(newChar:FindFirstChild("Scooter") ~= nil),
	"HipHeight:", newHum.HipHeight)
CHAR, HUM, HRP = newChar, newHum, newHrp

print("--- JIU JITSU TEST: 7 clicks wins $50 ---")
local cash2 = PLAYER.leaderstats.Cash
local before = cash2.Value
HRP.Position = JJMAT.Position
JJMAT.Touched:Fire(HRP)
PUMP(0.3)
for i = 1, 7 do
	local btn = workspace:FindFirstChild("JJButton", true)
	if not btn then PUMP(0.5) btn = workspace:FindFirstChild("JJButton", true) end
	if btn then
		btn:FindFirstChildOfClass("ClickDetector").MouseClick:Fire(PLAYER)
	else
		print("  !! no button found on round " .. i)
	end
	PUMP(0.4)
end
PUMP(3)
print("cash delta after win (must be +50):", cash2.Value - before)

print("--- JIU JITSU TIMEOUT: ignoring a button costs $5 ---")
before = cash2.Value
JJMAT.Touched:Fire(HRP)
PUMP(6.5) -- let one button time out
HRP.Position = Vector3.new(900, 4.35, 900) -- walk away to abandon
PUMP(1)
print("cash delta after timeout (must be -5):", cash2.Value - before)

print("--- STEP-OFF TEST: leaving the mat mid-button must NOT charge you ---")
PUMP(2.5) -- let the previous challenge's rearm cooldown expire
HRP.Position = JJMAT.Position
before = cash2.Value
JJMAT.Touched:Fire(HRP)
PUMP(1.5) -- button is up, don't click
HRP.Position = JJMAT.Position + Vector3.new(30, 0, 0) -- off the mat, still in the dojo
PUMP(7)
print("cash delta after stepping off (must be 0):", cash2.Value - before)

print("--- DEBT TEST: negative cash drains health until repaid ---")
HUM.Health = 100
cash2.Value = -10
PUMP(3.5)
local drained = HUM.Health
cash2.Value = 100
PUMP(2.5)
print("health after 3s in debt (must be < 100):", drained,
	"| stable after repay:", HUM.Health == drained)

print("--- STUDY BUTTON: hold-complete grants +10 scooter speed ---")
STUDY:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(PLAYER)
PUMP(1)
print("WalkSpeed with EduBoost (mounted, must be 40):", HUM.WalkSpeed,
	"| ClockTime advancing:", game:GetService("Lighting").ClockTime)

print("--- RENT + EGG + DOG TEST ---")
local cash3 = PLAYER.leaderstats.Cash
cash3.Value = 100
EGG.ProximityPrompt.Triggered:Fire(PLAYER) -- no house yet: must refuse, no charge
PUMP(0.5)
print("egg without house (cash must stay 100):", cash3.Value)
RENTBOARD.ClickDetector.MouseClick:Fire(PLAYER)
PUMP(0.5)
print("house owner attr (must be 1):", tostring(HOUSE:GetAttribute("OwnerUserId")))
print("hollowed:", tostring(HOUSE:GetAttribute("Hollowed")),
	"| body gone:", tostring(HOUSE:FindFirstChild("Body") == nil),
	"| has floor/back/sofa:", tostring(HOUSE:FindFirstChild("Floor") ~= nil),
	tostring(HOUSE:FindFirstChild("BackWall") ~= nil), tostring(HOUSE:FindFirstChild("Sofa") ~= nil),
	"| door slides:", tostring(HOUSE:FindFirstChild("Door"):GetAttribute("SlideDist") ~= nil),
	"| doorway clear:", tostring(HOUSE:FindFirstChild("DoorFrame").CanCollide == false),
	"| inside dog spot:", tostring(HOUSE:GetAttribute("DogSpotInside") ~= nil))
EGG.ProximityPrompt.Triggered:Fire(PLAYER)
PUMP(0.5)
print("cash after egg (must be 70):", cash3.Value)
PUMP(5) -- let the hatch cinematic (shake + crack + reveal + run home) finish
local dog = nil
for _, c in ipairs(workspace:FindFirstChild("DiscoveryBay"):GetChildren()) do
	if c.Name == "Mary" or c.Name == "Jolene" or c.Name == "Linus" then dog = c end
end
print("dog spawned:", dog and dog.Name or "NONE")
if dog then
	local dogBody = dog:FindFirstChild("Body")
	local dogPrompt = dogBody and dogBody:FindFirstChildOfClass("ProximityPrompt")
	dogPrompt.Triggered:Fire(PLAYER)
	PUMP(0.5)
	print("cash after pet (must be 80 or 170):", cash3.Value)
	dogPrompt.Triggered:Fire(PLAYER) -- cooldown: no double pay
	PUMP(0.5)
	print("cash after immediate re-pet (must be unchanged):", cash3.Value)
end

print("--- RAGDOLL TEST: Died must convert joints to ball sockets ---")
print("BreakJointsOnDeath (must be false):", tostring(HUM.BreakJointsOnDeath))
HUM.Died:Fire()
PUMP(1)
local motors, sockets = 0, 0
for _, d in ipairs(CHAR:GetDescendants()) do
  if d.ClassName == "Motor6D" and d:FindFirstAncestor("Scooter") == nil then motors = motors + 1 end
  if d.ClassName == "BallSocketConstraint" then sockets = sockets + 1 end
end
print("body Motor6Ds left (must be 0):", motors, "| ball sockets (must be >0):", sockets)
""")
print("SIMULATION COMPLETE")
