--==============================================================================================
-- DISCOVERY BAY, CALIFORNIA — OSM-accurate procedural Roblox build (v2)
--==============================================================================================
-- Builds the real Discovery Bay from OpenStreetMap geometry (© OpenStreetMap contributors):
--   * real terrain raster: every lagoon/bay polygon, Old River, golf fairways/greens/
--     tees/bunkers, parks, commercial lots
--   * all ~447 real road ways with their real names (Discovery Bay Blvd, Willow Lake Rd,
--     Cherry Hills Dr, every court), cul-de-sac bulbs, causeways, street signs
--   * 5,595 real building footprints at their true positions/orientations; every
--     waterfront home gets a private dock + boat (2,391 of them)
--   * the full 18-hole golf course with pin flags and cart paths
--   * Discovery Bay Elementary + Timber Point School, the four parks, the clubhouse,
--     the yacht harbor + lighthouse, and the required businesses (Callahan's Coffee and
--     Cones, Discovery Bay Jiu Jitsu, Shell Gas Station, Convenience Mart) at the real
--     Discovery Bay Blvd plaza
--
-- SETUP (two pastes):
--   1. In Explorer: ServerScriptService -> + -> ModuleScript, rename it EXACTLY
--      "DiscoveryBayData", open it, select all, paste the contents of DiscoveryBayData.luau.
--   2. ServerScriptService -> + -> Script, rename it "DiscoveryBayBuild", paste THIS file.
--   3. In the Command Bar run:
--      loadstring(game.ServerScriptService.DiscoveryBayBuild.Source)()
-- Re-running is safe: the previous build is deleted and rebuilt. Same seed = same world.
--==============================================================================================

local CONFIG = {
	worldScale = 1.0,   -- studs per FOOT. 1.0 = true scale (world ~22,000 x 18,700 studs).
	seed = 94505,
	boatChance = 1.0,   -- boat at every private dock (spec: signature Discovery Bay detail)
	treeCount = 1200,
	streetlightSpacingFt = 260,
	yieldEvery = 2000,  -- parts between task.wait() so Studio stays responsive
	build = {
		ground = true, roads = true, buildings = true, docks = true,
		golf = true, landmarks = true, props = true,
	},
	-- Optional sub-region in feet {x0, z0, x1, z1} (x east, z north from the SW corner).
	-- Example, just the original bay neighborhoods + golf: {7000, 2000, 22011, 15500}
	region = nil,
}

local S = CONFIG.worldScale
local rng = Random.new(CONFIG.seed)

local RunService = game:GetService("RunService")
if RunService:IsRunning() and workspace:FindFirstChild("DiscoveryBay") then
	-- Town already exists (built + saved in edit mode): nothing to do during Play.
	return
end
-- Otherwise: build now. In edit mode this is the normal command-bar path; in Play
-- mode it auto-builds so "just press Play" works — that copy vanishes on Stop, so to
-- make it permanent run the command-bar line in edit mode once and save.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DATA = require(ServerScriptService:WaitForChild("DiscoveryBayData"))

local W_FT = DATA.widthFt
local H_FT = DATA.heightFt
local CELL = DATA.cellFt
local COLS = DATA.cols
local ROWS = DATA.rows

--==============================================================================================
-- 1. PALETTE / LOOK
--==============================================================================================
local COL = {
	water    = Color3.fromHex("4a8fb3"),
	land     = Color3.fromHex("7c9e5a"),
	fairway  = Color3.fromHex("8bc34a"),
	green    = Color3.fromHex("68be58"),
	tee      = Color3.fromHex("9acd64"),
	bunker   = Color3.fromHex("e8dcaa"),
	park     = Color3.fromHex("6eaa5f"),
	pavement = Color3.fromHex("a8a298"),
	road     = Color3.fromHex("3a3a3a"),
	cartpath = Color3.fromHex("b8b4a8"),
	wood     = Color3.fromHex("7a5230"),
	stripe   = Color3.fromHex("e8e8e8"),
	roofs = { Color3.fromHex("8c4a2f"), Color3.fromHex("6b6b6b"), Color3.fromHex("7a5230"),
		Color3.fromHex("334a5c"), Color3.fromHex("9c5a3a"), Color3.fromHex("4a4a44") },
	walls = { Color3.fromHex("e8e4d8"), Color3.fromHex("d8c9a8"), Color3.fromHex("b8c4a0"),
		Color3.fromHex("c9c9c9"), Color3.fromHex("a7b6c2"), Color3.fromHex("d9cfc0") },
}

local GROUND_STYLE = {
	w = { top = 0, thick = 8,  color = COL.water,    material = Enum.Material.SmoothPlastic, transparency = 0.12 },
	l = { top = 2, thick = 10, color = COL.land,     material = Enum.Material.Grass },
	f = { top = 2, thick = 10, color = COL.fairway,  material = Enum.Material.Grass },
	g = { top = 2, thick = 10, color = COL.green,    material = Enum.Material.Grass },
	t = { top = 2, thick = 10, color = COL.tee,      material = Enum.Material.Grass },
	b = { top = 2, thick = 10, color = COL.bunker,   material = Enum.Material.Sand },
	p = { top = 2, thick = 10, color = COL.park,     material = Enum.Material.Grass },
	c = { top = 2, thick = 10, color = COL.pavement, material = Enum.Material.Concrete },
}

local Y_LAND = 2 * S
local Y_ROAD = 2.25 * S
local ROAD_THICK = 0.45 * S

--==============================================================================================
-- 2. DATA DECODING (base36 / RLE — verified against the generator by osm/verify_encoding.py)
--==============================================================================================
local function b36(s)
	return tonumber(s, 36)
end

-- terrain raster: row groups "spanChar + (2-char count + 1-char class)*", ';' separated.
-- Row 0 = NORTH edge. Column 0 = WEST edge.
local rasterGroups = {}
local rowToGroup = table.create(ROWS)
do
	local r = 0
	for grp in string.gmatch(DATA.raster, "[^;]+") do
		local span = b36(string.sub(grp, 1, 1))
		local runs = {}
		local col = 0
		for i = 2, #grp - 2, 3 do
			col = col + b36(string.sub(grp, i, i + 1))
			runs[#runs + 1] = { endCol = col, class = string.sub(grp, i + 2, i + 2) }
		end
		rasterGroups[#rasterGroups + 1] = { startRow = r, span = span, runs = runs }
		for k = r + 1, r + span do
			rowToGroup[k] = #rasterGroups
		end
		r = r + span
	end
	assert(r == ROWS, "raster row count mismatch: " .. r .. " vs " .. ROWS)
end

-- The raster's north anchor is ROWS*CELL (it can overhang H_FT by a partial cell);
-- using H_FT here would shift the whole terrain south by that remainder.
local RASTER_NORTH = ROWS * CELL

-- terrain class at a point in FEET (x east from west edge, zn north from south edge)
local function classAt(xFt, znFt)
	if xFt < 0 or xFt >= W_FT or znFt < 0 or znFt >= H_FT then return "l" end
	local col = math.floor(xFt / CELL)
	local row = math.floor((RASTER_NORTH - znFt) / CELL)
	row = math.clamp(row, 0, ROWS - 1)
	col = math.clamp(col, 0, COLS - 1)
	local g = rasterGroups[rowToGroup[row + 1]]
	for _, run in ipairs(g.runs) do
		if col < run.endCol then return run.class end
	end
	return "l"
end

local function isWaterAt(xFt, znFt)
	return classAt(xFt, znFt) == "w"
end

-- roads: "name|classChar|xxx zzz xxx zzz ..." (3+3 base36 chars per point, feet)
local ROAD_WIDTH = { T = 44, P = 40, t = 34, u = 26, r = 26, s = 18, k = 12 }
local roads = {}
for line in string.gmatch(DATA.roads, "[^\n]+") do
	local name, cls, enc = string.match(line, "^([^|]*)|(%a)|(%w+)$")
	if enc then
		local pts = {}
		for i = 1, #enc - 5, 6 do
			pts[#pts + 1] = { b36(string.sub(enc, i, i + 2)), b36(string.sub(enc, i + 3, i + 5)) }
		end
		if #pts >= 2 then
			roads[#roads + 1] = { name = name, cls = cls, width = ROAD_WIDTH[cls] or 24, pts = pts }
		end
	end
end

local cartpaths = {}
for line in string.gmatch(DATA.cartpaths, "[^\n]+") do
	local pts = {}
	for i = 1, #line - 5, 6 do
		pts[#pts + 1] = { b36(string.sub(line, i, i + 2)), b36(string.sub(line, i + 3, i + 5)) }
	end
	if #pts >= 2 then cartpaths[#cartpaths + 1] = pts end
end

-- ROAD GAP FILLER: some OSM streets end a few feet short of the road they actually
-- meet. Bridge every dead endpoint that has another road just ahead of it (forward-
-- facing only, so cul-de-sacs never grow bogus bridges to parallel back streets).
local function segClosest(px, pz, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local l2 = abx * abx + abz * abz
	local t = 0
	if l2 > 1e-9 then
		t = math.clamp(((px - ax) * abx + (pz - az) * abz) / l2, 0, 1)
	end
	local cx, cz = ax + abx * t, az + abz * t
	local dx, dz = px - cx, pz - cz
	return math.sqrt(dx * dx + dz * dz), cx, cz
end

do
	local MAXGAP = 45
	local connectors = {}
	for ri, rd in ipairs(roads) do
		for _, endIdx in ipairs({ 1, #rd.pts }) do
			local p = rd.pts[endIdx]
			local nxt = (endIdx == 1) and rd.pts[2] or rd.pts[#rd.pts - 1]
			local ox, oz = p[1] - nxt[1], p[2] - nxt[2]
			local ol = math.max(math.sqrt(ox * ox + oz * oz), 1e-6)
			ox, oz = ox / ol, oz / ol -- outgoing direction at the dead end
			local bestD, bestX, bestZ = math.huge, nil, nil
			for rj, other in ipairs(roads) do
				if rj ~= ri then
					local opts = other.pts
					for i = 1, #opts - 1 do
						local a, b = opts[i], opts[i + 1]
						if math.min(math.abs(a[1] - p[1]), math.abs(b[1] - p[1])) < MAXGAP + 60
							and math.min(math.abs(a[2] - p[2]), math.abs(b[2] - p[2])) < MAXGAP + 60 then
							local d, cx, cz = segClosest(p[1], p[2], a[1], a[2], b[1], b[2])
							if d < bestD then
								bestD, bestX, bestZ = d, cx, cz
							end
						end
					end
				end
			end
			if bestD > 4 and bestD < MAXGAP then
				local vx, vz = bestX - p[1], bestZ - p[2]
				local vl = math.max(math.sqrt(vx * vx + vz * vz), 1e-6)
				if (vx * ox + vz * oz) / vl > 0.57 then -- continues roughly straight ahead
					connectors[#connectors + 1] = { name = "", cls = rd.cls, width = rd.width,
						pts = { { p[1], p[2] }, { bestX, bestZ } } }
				end
			end
		end
	end
	for _, c in ipairs(connectors) do
		roads[#roads + 1] = c
	end
	print("[DiscoveryBay] road gap filler: " .. #connectors .. " connectors added")
end

-- buildings: fixed 15-char records: x(3) zn(3) w(2) d(2) yaw(2) class(1) dockYaw(2 or '--')
local buildings = {}
do
	local blob = DATA.buildings
	for i = 1, #blob - 14, 15 do
		local dockStr = string.sub(blob, i + 13, i + 14)
		buildings[#buildings + 1] = {
			x = b36(string.sub(blob, i, i + 2)),
			z = b36(string.sub(blob, i + 3, i + 5)),
			w = b36(string.sub(blob, i + 6, i + 7)),
			d = b36(string.sub(blob, i + 8, i + 9)),
			yaw = b36(string.sub(blob, i + 10, i + 11)),
			cls = string.sub(blob, i + 12, i + 12),
			dockYaw = dockStr ~= "--" and b36(dockStr) or nil,
		}
	end
end
print(("[DiscoveryBay] decoded: %d road ways, %d buildings, %d cartpaths"):format(
	#roads, #buildings, #cartpaths))

--==============================================================================================
-- 3. WORLD HELPERS
--==============================================================================================
-- feet -> world studs. x: west->east = +X. zn: south->north; north = -Z, so Z = (H - zn)*S.
local function toWorld(xFt, znFt, yStuds)
	return Vector3.new(xFt * S, yStuds, (H_FT - znFt) * S)
end

-- direction in the feet frame (east, north) -> world unit vector
local function dirToWorld(ex, en)
	local v = Vector3.new(ex, 0, -en)
	if v.Magnitude < 1e-6 then return Vector3.new(0, 0, -1) end
	return v.Unit
end

-- yaw encoded by the pipeline: CFrame.Angles(0, rad(yaw), 0) turns local -Z into the
-- front direction. Recover the (east, north) front vector when needed:
local function yawDir(yawDeg)
	local a = math.rad(yawDeg)
	return -math.sin(a), math.cos(a)
end

local function inRegion(xFt, znFt)
	local r = CONFIG.region
	if not r then return true end
	return xFt >= r[1] and znFt >= r[2] and xFt <= r[3] and znFt <= r[4]
end

--==============================================================================================
-- 4. INSTANCE FACTORY
--==============================================================================================
local partCount = 0
local function tick()
	partCount = partCount + 1
	if partCount % CONFIG.yieldEvery == 0 then
		task.wait()
	end
end

local function newPart(parent, name, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	tick()
	return p
end

local function newWedge(parent, name, size, cframe, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	tick()
	return p
end

local function newDisc(parent, name, diameter, thickness, cframe, color, material)
	local p = newPart(parent, name, Vector3.new(thickness, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function newColumn(parent, name, h, d, cframe, color, material)
	local p = newPart(parent, name, Vector3.new(h, d, d),
		cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function newBall(parent, name, diameter, cframe, color, material)
	local p = newPart(parent, name, Vector3.new(diameter, diameter, diameter), cframe, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- gable roof, ridge along local X. WedgePart's vertical face is on its +Z side.
local function gableRoof(parent, cf, width, depth, height, color)
	local halfD = depth / 2
	newWedge(parent, "RoofA", Vector3.new(width, height, halfD),
		cf * CFrame.new(0, height / 2, -halfD / 2), color)
	newWedge(parent, "RoofB", Vector3.new(width, height, halfD),
		cf * CFrame.new(0, height / 2, halfD / 2) * CFrame.Angles(0, math.pi, 0), color)
end

local function makeSign(part, face, text, bg, fg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or Color3.fromRGB(30, 40, 50)
	label.TextColor3 = fg or Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

local function newModel(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- shopkeeper NPC: a proper classic Robloxian (R6 proportions, bevelled head via the
-- engine's Head mesh, default smiley face, Humanoid name tag) with Roblox's native
-- Dialog "talk" feature. cf = base at floor level, facing local -Z. Absolute studs.
local function buildNPC(parent, npcName, cf, shirt, promptText, choices)
	local n = newModel(parent, npcName)
	local skin = Color3.fromRGB(255, 201, 58)  -- classic Robloxian yellow
	local pants = Color3.fromRGB(45, 90, 160)  -- classic blue jeans
	local function bp(name, size, off, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * off
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = n
		partCount = partCount + 1
		return p
	end
	bp("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), pants)
	bp("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), pants)
	bp("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt)
	bp("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), skin)
	bp("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), skin)
	local head = bp("Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png" -- the classic smiley
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local hum = Instance.new("Humanoid")
	hum.DisplayName = npcName
	hum.MaxHealth = 100
	hum.Health = 100
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = n
	local dlg = Instance.new("Dialog")
	dlg.InitialPrompt = promptText
	dlg.ConversationDistance = 20
	dlg.Tone = Enum.DialogTone.Friendly
	dlg.Parent = head
	for _, c in ipairs(choices or {}) do
		local ch = Instance.new("DialogChoice")
		ch.UserDialog = c[1]
		ch.ResponseDialog = c[2]
		ch.Parent = dlg
	end
	return n
end

--==============================================================================================
-- 5. SCAFFOLD (idempotent)
--==============================================================================================
local old = workspace:FindFirstChild("DiscoveryBay")
if old then old:Destroy() end
local oldKit = ReplicatedStorage:FindFirstChild("DiscoveryBayKit")
if oldKit then oldKit:Destroy() end

local root = Instance.new("Model")
root.Name = "DiscoveryBay"
root.Parent = workspace

local FOLDERS = {}
for _, fname in ipairs({ "Ground", "Water", "Roads", "Buildings", "Golf", "Docks", "Landmarks", "Props" }) do
	local f = Instance.new("Folder")
	f.Name = fname
	f.Parent = root
	FOLDERS[fname] = f
end

local KIT = Instance.new("Folder")
KIT.Name = "DiscoveryBayKit"
KIT.Parent = ReplicatedStorage

pcall(function() workspace.StreamingEnabled = true end)

--==============================================================================================
-- 6. TEMPLATES (boats, trees — cloned many times)
--==============================================================================================
local function addRoot(model, name)
	local rp = Instance.new("Part")
	rp.Name = "Root"
	rp.Size = Vector3.new(1, 0.2, 1) * S
	rp.CFrame = CFrame.new(0, 0.1 * S, 0)
	rp.Anchored = true
	rp.Transparency = 1
	rp.CanCollide = false
	rp.Parent = model
	model.PrimaryPart = rp
	model.Name = name
	return model
end

local function buildRunabout()
	local m = Instance.new("Model")
	newPart(m, "Hull", Vector3.new(4.4, 1.8, 11) * S, CFrame.new(0, 0.9 * S, 0.5 * S),
		Color3.fromRGB(240, 238, 228))
	newWedge(m, "Bow", Vector3.new(4.4, 1.8, 3.6) * S, CFrame.new(0, 0.9 * S, -6.8 * S),
		Color3.fromRGB(240, 238, 228))
	newPart(m, "Windshield", Vector3.new(3.8, 1.1, 0.25) * S,
		CFrame.new(0, 2.3 * S, -2.4 * S) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(160, 210, 230), Enum.Material.Glass)
	newPart(m, "Seats", Vector3.new(3.6, 0.8, 4) * S, CFrame.new(0, 1.9 * S, 2 * S),
		Color3.fromRGB(120, 60, 50), Enum.Material.Fabric)
	newPart(m, "Motor", Vector3.new(1.4, 1.6, 0.9) * S, CFrame.new(0, 1.6 * S, 6.3 * S),
		Color3.fromRGB(40, 40, 45))
	return addRoot(m, "boat_runabout")
end

local function buildSailboat()
	local m = Instance.new("Model")
	newPart(m, "Hull", Vector3.new(3.6, 1.6, 12) * S, CFrame.new(0, 0.8 * S, 0),
		Color3.fromRGB(225, 230, 235))
	newWedge(m, "Bow", Vector3.new(3.6, 1.6, 3) * S, CFrame.new(0, 0.8 * S, -7.5 * S),
		Color3.fromRGB(225, 230, 235))
	newPart(m, "Cabin", Vector3.new(3, 1.2, 4) * S, CFrame.new(0, 2 * S, 1 * S),
		Color3.fromRGB(200, 200, 205))
	newColumn(m, "Mast", 15 * S, 0.35 * S, CFrame.new(0, 9 * S, -1 * S),
		Color3.fromRGB(180, 180, 185), Enum.Material.Metal)
	newPart(m, "Sail", Vector3.new(0.15, 10, 5) * S, CFrame.new(0, 9.5 * S, 1.7 * S),
		Color3.fromRGB(250, 248, 240))
	return addRoot(m, "boat_sailboat")
end

local function buildOak()
	local m = Instance.new("Model")
	newColumn(m, "Trunk", 8 * S, 1.8 * S, CFrame.new(0, 4 * S, 0),
		Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
	newBall(m, "Leaves1", 10 * S, CFrame.new(0, 10.5 * S, 0), Color3.fromRGB(70, 120, 60), Enum.Material.Grass)
	newBall(m, "Leaves2", 7 * S, CFrame.new(2.4 * S, 8.6 * S, 1.4 * S), Color3.fromRGB(85, 135, 70), Enum.Material.Grass)
	return addRoot(m, "tree_oak")
end

local function buildPalm()
	local m = Instance.new("Model")
	newColumn(m, "Trunk", 17 * S, 1.3 * S, CFrame.new(0, 8.5 * S, 0) * CFrame.Angles(0, 0, math.rad(3)),
		Color3.fromRGB(140, 115, 85), Enum.Material.Wood)
	for i = 0, 5 do
		local cf = CFrame.new(0.4 * S, 17 * S, 0) * CFrame.Angles(0, math.rad(i * 60), 0)
			* CFrame.new(0, 0, -3.4 * S) * CFrame.Angles(math.rad(-28), 0, 0)
		newPart(m, "Frond", Vector3.new(1.4, 0.15, 7.5) * S, cf, Color3.fromRGB(75, 140, 70), Enum.Material.Grass)
	end
	return addRoot(m, "tree_palm")
end

local function buildCar()
	local m = Instance.new("Model")
	newPart(m, "Body", Vector3.new(6.2, 2.2, 14.5) * S, CFrame.new(0, 2.1 * S, 0),
		Color3.fromRGB(160, 160, 165))
	newPart(m, "Cabin", Vector3.new(5.6, 1.9, 6.5) * S, CFrame.new(0, 4.1 * S, 0.6 * S),
		Color3.fromRGB(120, 150, 165), Enum.Material.Glass)
	for _, o in ipairs({ { -3, -4.3 }, { 3, -4.3 }, { -3, 4.3 }, { 3, 4.3 } }) do
		local wheel = newPart(m, "Wheel", Vector3.new(0.9, 2.4, 2.4) * S,
			CFrame.new(o[1] * S, 1.2 * S, o[2] * S), Color3.fromRGB(30, 30, 30), Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	return addRoot(m, "car")
end

-- Shop products: sold inside the Shell mini-mart. Display copies get ProximityPrompts;
-- matching Tools live in ReplicatedStorage.DiscoveryBayKit.Products and are cloned into
-- the buyer's Backpack by the DiscoveryBayShop runtime script.
local PRODUCTS = {
	{ name = "Soda",      price = 5, kind = "can",    color = Color3.fromRGB(60, 120, 200) },
	{ name = "Water",     price = 2, kind = "bottle", color = Color3.fromRGB(180, 220, 240) },
	{ name = "Chips",     price = 4, kind = "box",    color = Color3.fromRGB(240, 200, 60) },
	{ name = "Donut",     price = 3, kind = "donut",  color = Color3.fromRGB(245, 170, 190) },
	{ name = "Coffee",    price = 4, kind = "cup",    color = Color3.fromRGB(150, 100, 60) },
	{ name = "Ice Cream", price = 6, kind = "cone",   color = Color3.fromRGB(245, 170, 190) },
	-- Callahan's premium flavors (sold in the ice cream shop; powerful effects, priced to match)
	{ name = "Chocolate Cone", price = 40, kind = "cone", color = Color3.fromRGB(110, 70, 45) },
	{ name = "Vanilla Cone",   price = 45, kind = "cone", color = Color3.fromRGB(245, 235, 210) },
	{ name = "Mint Cone",      price = 60, kind = "cone", color = Color3.fromRGB(150, 220, 180) },
	-- Bloxway groceries (30 aisles of them)
	{ name = "Taco",          price = 6, kind = "taco",    color = Color3.fromRGB(215, 180, 120) },
	{ name = "Cheeseburger",  price = 8, kind = "burger",  color = Color3.fromRGB(200, 150, 80) },
	{ name = "Hot Dog",       price = 5, kind = "hotdog",  color = Color3.fromRGB(205, 120, 80) },
	{ name = "Pizza Slice",   price = 7, kind = "pizza",   color = Color3.fromRGB(230, 180, 90) },
	{ name = "Burrito",       price = 7, kind = "burrito", color = Color3.fromRGB(225, 205, 165) },
	{ name = "Watermelon",    price = 4, kind = "melon",   color = Color3.fromRGB(90, 160, 80) },
	{ name = "Cereal",        price = 4, kind = "box",     color = Color3.fromRGB(235, 120, 60) },
	{ name = "Milk",          price = 3, kind = "box",     color = Color3.fromRGB(245, 245, 245) },
	{ name = "Cookie",        price = 2, kind = "donut",   color = Color3.fromRGB(170, 120, 70) },
	{ name = "Fried Chicken", price = 8, kind = "melon",   color = Color3.fromRGB(190, 140, 70) },
}

-- (addProductDisplay is defined below productPart — Lua locals must be declared
-- before any function that closes over them, or the reference silently goes global)

-- single-part product shape (also used as Tool handles, so exactly one part; sizes are
-- absolute studs, not worldScale-scaled, so they fit a character's hand at any scale)
local function productPart(parent, name, kind, color, cf)
	local p
	if kind == "box" then
		p = newPart(parent, name, Vector3.new(1.2, 1.5, 0.5), cf, color)
	elseif kind == "donut" then
		p = newDisc(parent, name, 1.2, 0.45, cf, color)
	elseif kind == "pizza" then
		p = newDisc(parent, name, 1.7, 0.25, cf, color)
	elseif kind == "cone" then
		p = newBall(parent, name, 1.1, cf, color)
	elseif kind == "melon" then
		p = newBall(parent, name, 1.5, cf, color)
	elseif kind == "taco" then
		p = newWedge(parent, name, Vector3.new(1.4, 1, 1.3), cf, color)
	elseif kind == "burger" then
		p = newColumn(parent, name, 1.0, 1.6, cf, color)
	elseif kind == "hotdog" or kind == "burrito" then
		-- horizontal cylinder (axis already lies along X)
		local len = (kind == "burrito") and 2.0 or 2.2
		local dia = (kind == "burrito") and 0.95 or 0.65
		p = newPart(parent, name, Vector3.new(len, dia, dia), cf, color)
		p.Shape = Enum.PartType.Cylinder
	else -- can / bottle / cup: standing cylinder
		local h = (kind == "bottle" and 1.5) or (kind == "cup" and 1.2) or 1.3
		p = newColumn(parent, name, h, 0.9, cf, color)
	end
	return p
end

-- product display with a Buy prompt (used by the Shell mini-mart and Callahan's)
local function addProductDisplay(parent, pr, cf)
	local disp = productPart(parent, pr.name, pr.kind, pr.color, cf)
	disp:SetAttribute("Product", pr.name)
	disp:SetAttribute("Price", pr.price)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = pr.name .. " - $" .. pr.price
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = disp
	return disp
end

local TPL = {}
local function buildKit()
	TPL.boats = { buildRunabout(), buildSailboat() }
	TPL.trees = { buildOak(), buildPalm() }
	TPL.car = buildCar()
	for _, t in ipairs({ TPL.boats[1], TPL.boats[2], TPL.trees[1], TPL.trees[2], TPL.car }) do
		t.Parent = KIT
	end
	-- purchasable Tools
	local prodFolder = Instance.new("Folder")
	prodFolder.Name = "Products"
	prodFolder.Parent = KIT
	for _, pr in ipairs(PRODUCTS) do
		local tool = Instance.new("Tool")
		tool.Name = pr.name
		tool.ToolTip = pr.name
		local handle = productPart(tool, "Handle", pr.kind, pr.color, CFrame.new())
		handle.Anchored = false
		handle.CanCollide = false
		tool.Parent = prodFolder
	end
end

local function placeClone(template, parent, pos, lookAtWorld)
	local clone = template:Clone()
	local target = Vector3.new(lookAtWorld.X, pos.Y, lookAtWorld.Z)
	if (target - pos).Magnitude < 0.01 then target = pos + Vector3.new(0, 0, -1) end
	clone:PivotTo(CFrame.lookAt(pos, target))
	clone.Parent = parent
	return clone
end

--==============================================================================================
-- 7. GROUND (row-group strips straight from the raster)
--==============================================================================================
local function buildGround()
	local zOff = H_FT - RASTER_NORTH -- align raster rows with the exact-feet frame
	for _, g in ipairs(rasterGroups) do
		local z0 = g.startRow * CELL + zOff   -- feet from NORTH edge
		local z1 = (g.startRow + g.span) * CELL + zOff
		local prevEnd = 0
		for _, run in ipairs(g.runs) do
			local x0, x1 = prevEnd * CELL, run.endCol * CELL
			prevEnd = run.endCol
			local style = GROUND_STYLE[run.class]
			if style then
				-- world Z: row 0 = north = Z 0, so strip spans Z [z0,z1]*S directly
				local size = Vector3.new((x1 - x0) * S, style.thick * S, (z1 - z0) * S)
				local center = Vector3.new((x0 + x1) / 2 * S,
					style.top * S - style.thick * S / 2, (z0 + z1) / 2 * S)
				local parent = run.class == "w" and FOLDERS.Water or FOLDERS.Ground
				local p = newPart(parent, "G_" .. run.class, size, CFrame.new(center),
					style.color, style.material, style.transparency)
				p.CastShadow = false
			end
		end
	end
end

--==============================================================================================
-- 8. ROADS (+ bulbs, causeways, street signs, cartpaths, streetlights)
--==============================================================================================
local function ftDist(a, b)
	local dx, dz = a[1] - b[1], a[2] - b[2]
	return math.sqrt(dx * dx + dz * dz)
end

-- vertex hash for junction detection (feet, 40 ft cells)
local vertexHash = {}
local function vkey(x, z) return math.floor(x / 40) .. ":" .. math.floor(z / 40) end
for _, rd in ipairs(roads) do
	for _, p in ipairs(rd.pts) do
		local k = vkey(p[1], p[2])
		vertexHash[k] = vertexHash[k] or {}
		table.insert(vertexHash[k], { p[1], p[2], rd })
	end
end

local function isJunction(pt, ownRoad)
	for gx = -1, 1 do
		for gz = -1, 1 do
			local cellList = vertexHash[math.floor(pt[1] / 40 + gx) .. ":" .. math.floor(pt[2] / 40 + gz)]
			if cellList then
				for _, v in ipairs(cellList) do
					if v[3] ~= ownRoad and math.abs(v[1] - pt[1]) < 35 and math.abs(v[2] - pt[2]) < 35 then
						return true
					end
				end
			end
		end
	end
	return false
end

-- road-corridor hash: samples every road centerline so props (trees) can cheaply
-- test "am I on or near asphalt?" — roads aren't part of the terrain raster
local roadHash = {}
local ROAD_CELL = 40
do
	for _, rd in ipairs(roads) do
		local pts = rd.pts
		local reach = rd.width / 2 + 8 -- half width + shoulder margin
		for i = 1, #pts - 1 do
			local ax, az = pts[i][1], pts[i][2]
			local bx, bz = pts[i + 1][1], pts[i + 1][2]
			local n = math.max(1, math.ceil(ftDist(pts[i], pts[i + 1]) / 20))
			for k = 0, n do
				local t = k / n
				local px, pz = ax + (bx - ax) * t, az + (bz - az) * t
				local key = math.floor(px / ROAD_CELL) .. ":" .. math.floor(pz / ROAD_CELL)
				local cellList = roadHash[key]
				if not cellList then
					cellList = {}
					roadHash[key] = cellList
				end
				cellList[#cellList + 1] = { px, pz, reach }
			end
		end
	end
end

local function onRoad(x, z)
	for gx = -1, 1 do
		for gz = -1, 1 do
			local cellList = roadHash[math.floor(x / ROAD_CELL + gx) .. ":" .. math.floor(z / ROAD_CELL + gz)]
			if cellList then
				for _, s in ipairs(cellList) do
					local dx, dz = s[1] - x, s[2] - z
					if dx * dx + dz * dz < s[3] * s[3] then return true end
				end
			end
		end
	end
	return false
end

local function buildCauseways(model, width, ax, az, bx, bz)
	local segLen = ftDist({ ax, az }, { bx, bz })
	if segLen < 4 then return end
	local n = math.max(1, math.ceil(segLen / 10))
	local wet = {}
	for k = 0, n do
		local t = k / n
		wet[k + 1] = isWaterAt(ax + (bx - ax) * t, az + (bz - az) * t)
	end
	local k = 1
	while k <= n + 1 do
		if wet[k] then
			local j = k
			while j <= n and wet[j + 1] do j = j + 1 end
			local s0 = (k - 1) / n
			local s1 = (j - 1) / n
			if (s1 - s0) * segLen > 6 then
				local tm = (s0 + s1) / 2
				local mx, mz = ax + (bx - ax) * tm, az + (bz - az) * tm
				local mid = toWorld(mx, mz, (1.85 - 2.2) * S)
				local dir = dirToWorld(bx - ax, bz - az)
				newPart(model, "Causeway",
					Vector3.new((width + 4) * S, 4.4 * S, ((s1 - s0) * segLen + 12) * S),
					CFrame.lookAt(mid, mid + dir), Color3.fromRGB(150, 145, 135), Enum.Material.Concrete)
			end
			k = j + 1
		else
			k = k + 1
		end
	end
end

local signedNames = {}

local function buildRoad(rd, roadIndex)
	if not inRegion(rd.pts[1][1], rd.pts[1][2]) and not inRegion(rd.pts[#rd.pts][1], rd.pts[#rd.pts][2]) then
		return
	end
	local model = newModel(FOLDERS.Roads, rd.name ~= "" and rd.name or "road")
	model:SetAttribute("RoadClass", rd.cls)
	local w = rd.width
	local color, material = COL.road, Enum.Material.Asphalt
	if rd.cls == "k" then -- farm tracks are dirt
		color, material = Color3.fromRGB(150, 130, 100), Enum.Material.Ground
	elseif rd.cls == "s" then
		color, material = Color3.fromRGB(70, 70, 72), Enum.Material.Asphalt
	end
	-- Anti-z-fighting, two layers:
	--   * per-ROAD height band (roadIndex % 5) so crossing roads never share a surface
	--   * per-SEGMENT stagger within a road so bend overlaps never share one either
	local lift = ((roadIndex or 0) % 5) * 0.02 * S
	for i = 1, #rd.pts - 1 do
		local a, b = rd.pts[i], rd.pts[i + 1]
		local lenFt = ftDist(a, b)
		if lenFt > 1 then
			local jitter = (i % 2) * 0.012 * S
			local mid = toWorld((a[1] + b[1]) / 2, (a[2] + b[2]) / 2, Y_ROAD - ROAD_THICK / 2 + lift + jitter)
			local dir = dirToWorld(b[1] - a[1], b[2] - a[2])
			newPart(model, "Seg", Vector3.new(w * S, ROAD_THICK, lenFt * S),
				CFrame.lookAt(mid, mid + dir), color, material)
			buildCauseways(model, w, a[1], a[2], b[1], b[2])
		end
	end
	for i = 1, #rd.pts do
		local p = rd.pts[i]
		local isEnd = (i == 1 or i == #rd.pts)
		local dia = w
		if isEnd and rd.cls == "r" and not isJunction(p, rd) then
			dia = math.max(w * 2.6, 80) -- real cul-de-sac bulb
		end
		newDisc(model, dia > w and "CulDeSac" or "Joint", dia * S, ROAD_THICK * 0.9,
			CFrame.new(toWorld(p[1], p[2], Y_ROAD - ROAD_THICK / 2 + lift - 0.035 * S)),
			color, material)
	end
	-- one street sign per unique road name
	if rd.name ~= "" and not signedNames[rd.name] and (rd.cls == "r" or rd.cls == "t" or rd.cls == "u") then
		signedNames[rd.name] = true
		local a, b = rd.pts[1], rd.pts[2]
		local segLen = math.max(ftDist(a, b), 1)
		local dx, dz = (b[1] - a[1]) / segLen, (b[2] - a[2]) / segLen
		local off = w / 2 + 7
		local gx = a[1] + dx * 18 - dz * off
		local gz = a[2] + dz * 18 + dx * off
		local base = toWorld(gx, gz, Y_LAND)
		newPart(model, "SignPole", Vector3.new(0.4, 8, 0.4) * S,
			CFrame.new(base + Vector3.new(0, 4 * S, 0)), Color3.fromRGB(80, 90, 95), Enum.Material.Metal)
		local dirW = dirToWorld(dx, dz)
		local bcf = CFrame.lookAt(base + Vector3.new(0, 8.4 * S, 0), base + Vector3.new(0, 8.4 * S, 0) + dirW)
		local board = newPart(model, "SignBoard", Vector3.new(0.25, 1.5, 8) * S, bcf,
			Color3.fromRGB(20, 90, 60))
		makeSign(board, Enum.NormalId.Left, rd.name, Color3.fromRGB(20, 90, 60), Color3.new(1, 1, 1))
		makeSign(board, Enum.NormalId.Right, rd.name, Color3.fromRGB(20, 90, 60), Color3.new(1, 1, 1))
	end
end

local function buildStreetlights()
	for _, rd in ipairs(roads) do
		if rd.cls == "t" or rd.cls == "P" or rd.cls == "T" then
			local carry = CONFIG.streetlightSpacingFt / 2 -- spacing carries across vertices
			local side = 1
			for i = 1, #rd.pts - 1 do
				local a, b = rd.pts[i], rd.pts[i + 1]
				local segLen = ftDist(a, b)
				local dx, dz = (b[1] - a[1]) / math.max(segLen, 1), (b[2] - a[2]) / math.max(segLen, 1)
				local s = carry
				while s < segLen do
					local off = rd.width / 2 + 4
					local lx = a[1] + dx * s - dz * off * side
					local lz = a[2] + dz * s + dx * off * side
					if not isWaterAt(lx, lz) and inRegion(lx, lz) then
						local base = toWorld(lx, lz, Y_LAND)
						local m = newModel(FOLDERS.Props, "Streetlight")
						newColumn(m, "Pole", 14 * S, 0.7 * S, CFrame.new(base + Vector3.new(0, 7 * S, 0)),
							Color3.fromRGB(60, 65, 70), Enum.Material.Metal)
						local armDir = dirToWorld(dz * side, -dx * side)
						local armC = base + Vector3.new(0, 13.8 * S, 0) + armDir * 2 * S
						newPart(m, "Arm", Vector3.new(0.5, 0.5, 4.4) * S, CFrame.lookAt(armC, armC + armDir),
							Color3.fromRGB(60, 65, 70), Enum.Material.Metal)
						local bulb = newBall(m, "Bulb", 1.2 * S,
							CFrame.new(base + Vector3.new(0, 13.4 * S, 0) + armDir * 4 * S),
							Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
						local light = Instance.new("PointLight")
						light.Range = 40
						light.Brightness = 1.5
						light.Parent = bulb
					end
					side = -side
					s = s + CONFIG.streetlightSpacingFt
				end
				carry = s - segLen
			end
		end
	end
end

local function buildCartpaths()
	for _, pts in ipairs(cartpaths) do
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local lenFt = ftDist(a, b)
			if lenFt > 1 and inRegion(a[1], a[2]) then
				local mid = toWorld((a[1] + b[1]) / 2, (a[2] + b[2]) / 2, 2.15 * S)
				local dir = dirToWorld(b[1] - a[1], b[2] - a[2])
				newPart(FOLDERS.Golf, "CartPath", Vector3.new(8 * S, 0.3 * S, (lenFt + 4) * S),
					CFrame.lookAt(mid, mid + dir), COL.cartpath, Enum.Material.Concrete)
			end
		end
	end
end

--==============================================================================================
-- 9. BUILDINGS (5,595 real footprints)
--==============================================================================================
local plazaPt = DATA.landmarks.plaza -- suppression zone: the plaza is built as a hero set
local function nearPlaza(x, z)
	if not plazaPt then return false end
	local dx, dz = x - plazaPt.x, z - plazaPt.z
	return dx * dx + dz * dz < 240 * 240
end

-- (Bloxway used to take over the real Safeway site at Hwy 4, but that's a 2-mile ride
-- from spawn — it now hunts for a clear lot right next to the plaza instead, and the
-- real Safeway footprint keeps its generic commercial building.)

-- spatial hash of placed buildings (for tree placement)
local bldgHash = {}
local function bkey(x, z) return math.floor(x / 100) .. ":" .. math.floor(z / 100) end
local function markBuilding(x, z)
	local k = bkey(x, z)
	bldgHash[k] = bldgHash[k] or {}
	table.insert(bldgHash[k], { x, z })
end
local function nearBuilding(x, z, radius)
	local n = math.ceil(radius / 100) -- scan enough 100-ft hash cells to honor the radius
	for gx = -n, n do
		for gz = -n, n do
			local cellList = bldgHash[math.floor(x / 100 + gx) .. ":" .. math.floor(z / 100 + gz)]
			if cellList then
				for _, v in ipairs(cellList) do
					local dx, dz = v[1] - x, v[2] - z
					if dx * dx + dz * dz < radius * radius then return true end
				end
			end
		end
	end
	return false
end

local usedPoi = {}
local function nearestPoiName(x, z)
	local best, bestD = nil, 160 * 160
	for idx, poi in ipairs(DATA.pois) do
		if not usedPoi[idx] and poi.kind ~= "school" then
			local dx, dz = poi.x - x, poi.z - z
			local d = dx * dx + dz * dz
			if d < bestD then best, bestD = idx, d end
		end
	end
	if best then
		usedPoi[best] = true
		return DATA.pois[best].name
	end
	return nil
end

-- Residential builder with real variety: gable ranch / L-shaped / modern flat-roof
-- styles, mixed wall materials, porches, balconies, chimneys, shutters, driveways.
-- All rng draws come from the shared seeded stream, so rebuilds are identical.
local WALL_MATS = { Enum.Material.Brick, Enum.Material.WoodPlanks, Enum.Material.Concrete, Enum.Material.SmoothPlastic }

local function buildResidential(m, cf, b)
	local w, d = b.w, b.d
	local area = w * d
	local wall = COL.walls[rng:NextInteger(1, #COL.walls)]
	local roof = COL.roofs[rng:NextInteger(1, #COL.roofs)]
	local trim = COL.roofs[rng:NextInteger(1, #COL.roofs)]
	local wallMat = WALL_MATS[rng:NextInteger(1, #WALL_MATS)]
	local glass = Color3.fromRGB(150, 200, 220)
	local stories = 1
	if area > 2600 and rng:NextNumber() < 0.7 then stories = 2
	elseif area > 1900 and rng:NextNumber() < 0.35 then stories = 2 end
	local h = stories == 2 and 18 or 10.5

	newPart(m, "Slab", Vector3.new(w + 3, 0.5, d + 3) * S, cf * CFrame.new(0, 0.25 * S, 0),
		Color3.fromRGB(180, 175, 165), Enum.Material.Concrete)

	local style = "gable"
	local roll = rng:NextNumber()
	if roll < 0.12 then
		style = "modern"
	elseif roll < 0.34 and w >= 34 and d >= 24 then
		style = "lshape"
	end

	local frontZ = -d / 2
	local doorX = w * 0.12

	if style == "modern" then
		newPart(m, "Body", Vector3.new(w, h, d) * S, cf * CFrame.new(0, (0.5 + h / 2) * S, 0),
			wall, Enum.Material.Concrete)
		newPart(m, "Parapet", Vector3.new(w + 1, 1.2, d + 1) * S,
			cf * CFrame.new(0, (0.5 + h + 0.6) * S, 0), trim, Enum.Material.Concrete)
		newPart(m, "Accent", Vector3.new(w * 0.3, h, 0.5) * S,
			cf * CFrame.new(w * 0.3 * S, (0.5 + h / 2) * S, (frontZ - 0.15) * S), roof, Enum.Material.WoodPlanks)
		newPart(m, "GlassBand", Vector3.new(w * 0.42, h * 0.55, 0.3) * S,
			cf * CFrame.new(-w * 0.2 * S, (0.5 + h * 0.55) * S, (frontZ - 0.1) * S), glass, Enum.Material.Glass, 0.2)
		newPart(m, "Canopy", Vector3.new(8, 0.4, 4) * S,
			cf * CFrame.new(doorX * S, (0.5 + 7.4) * S, (frontZ - 2) * S), trim, Enum.Material.Concrete)
	elseif style == "lshape" then
		local mainD = d * 0.6
		local wingW = w * 0.42
		local wingX = -w / 2 + wingW / 2
		local mainFront = d / 2 - mainD
		newPart(m, "Body", Vector3.new(w, h, mainD) * S,
			cf * CFrame.new(0, (0.5 + h / 2) * S, (d / 2 - mainD / 2) * S), wall, wallMat)
		gableRoof(m, cf * CFrame.new(0, (0.5 + h) * S, (d / 2 - mainD / 2) * S),
			(w + 1.5) * S, (mainD + 1.5) * S, math.clamp(mainD * 0.3, 3.5, 8) * S, roof)
		newPart(m, "Wing", Vector3.new(wingW, h * 0.85, d * 0.55) * S,
			cf * CFrame.new(wingX * S, (0.5 + h * 0.425) * S, (-d / 2 + d * 0.275) * S), wall, wallMat)
		gableRoof(m, cf * CFrame.new(wingX * S, (0.5 + h * 0.85) * S, (-d / 2 + d * 0.275) * S)
			* CFrame.Angles(0, math.rad(90), 0),
			(d * 0.55 + 1.5) * S, (wingW + 1.5) * S, math.clamp(wingW * 0.3, 3, 7) * S, roof)
		doorX = wingX
		-- windows: one on the wing front, one on the recessed main front
		newPart(m, "Window", Vector3.new(5, 3.4, 0.25) * S,
			cf * CFrame.new((wingX + wingW * 0.3) * S, (0.5 + 5) * S, (frontZ - 0.1) * S), glass, Enum.Material.Glass)
		newPart(m, "WindowMain", Vector3.new(6, 3.4, 0.25) * S,
			cf * CFrame.new(w * 0.22 * S, (0.5 + 5) * S, (mainFront - 0.1) * S), glass, Enum.Material.Glass)
	else -- gable ranch
		newPart(m, "Body", Vector3.new(w, h, d) * S, cf * CFrame.new(0, (0.5 + h / 2) * S, 0), wall, wallMat)
		gableRoof(m, cf * CFrame.new(0, (0.5 + h) * S, 0), (w + 1.5) * S, (d + 1.5) * S,
			math.clamp(d * 0.28, 4, 9) * S, roof)
		if rng:NextNumber() < 0.28 then
			-- front porch
			newPart(m, "PorchRoof", Vector3.new(w * 0.4, 0.4, 4.5) * S,
				cf * CFrame.new(doorX * S, (0.5 + 7.6) * S, (frontZ - 2.2) * S), roof)
			for _, px in ipairs({ doorX - w * 0.14, doorX + w * 0.14 }) do
				newColumn(m, "PorchPost", 7.4 * S, 0.7 * S,
					cf * CFrame.new(px * S, (0.5 + 3.7) * S, (frontZ - 3.8) * S), Color3.fromRGB(235, 232, 225))
			end
		end
		if stories == 2 and rng:NextNumber() < 0.35 then
			newPart(m, "Balcony", Vector3.new(9, 0.4, 3.6) * S,
				cf * CFrame.new(doorX * S, (0.5 + h * 0.55) * S, (frontZ - 1.8) * S), trim, Enum.Material.WoodPlanks)
			newPart(m, "BalconyRail", Vector3.new(9, 2, 0.3) * S,
				cf * CFrame.new(doorX * S, (0.5 + h * 0.55 + 1.2) * S, (frontZ - 3.5) * S),
				trim, Enum.Material.WoodPlanks, 0.35)
		end
	end

	if style ~= "modern" and rng:NextNumber() < 0.3 then
		newPart(m, "Chimney", Vector3.new(2.2, 7, 2.2) * S,
			cf * CFrame.new(w * 0.28 * S, (0.5 + h + 2.4) * S, d * 0.15 * S),
			Color3.fromRGB(150, 90, 70), Enum.Material.Brick)
	end

	newPart(m, "Door", Vector3.new(3.4, 6.6, 0.3) * S,
		cf * CFrame.new(doorX * S, (0.5 + 3.3) * S, (frontZ - 0.12) * S),
		Color3.fromRGB(70, 50, 40), Enum.Material.Wood)
	-- quality details: a proper door frame and an entry step
	newPart(m, "DoorFrame", Vector3.new(4.6, 7.4, 0.18) * S,
		cf * CFrame.new(doorX * S, (0.5 + 3.6) * S, (frontZ - 0.08) * S),
		Color3.fromRGB(245, 242, 235))
	newPart(m, "DoorStep", Vector3.new(5, 0.6, 2.6) * S,
		cf * CFrame.new(doorX * S, 0.55 * S, (frontZ - 1.6) * S),
		Color3.fromRGB(190, 185, 175), Enum.Material.Concrete)

	if style ~= "lshape" then
		for _, off in ipairs({ -0.28, 0.32 }) do
			local wx = w * off
			newPart(m, "Window", Vector3.new(5, 3.4, 0.25) * S,
				cf * CFrame.new(wx * S, (0.5 + 5) * S, (frontZ - 0.1) * S), glass, Enum.Material.Glass)
			newPart(m, "Sill", Vector3.new(5.8, 0.35, 0.8) * S,
				cf * CFrame.new(wx * S, (0.5 + 3.15) * S, (frontZ - 0.35) * S),
				trim, Enum.Material.Concrete)
			if style == "gable" and rng:NextNumber() < 0.4 then
				for _, sxo in ipairs({ -3.1, 3.1 }) do
					newPart(m, "Shutter", Vector3.new(1, 3.4, 0.2) * S,
						cf * CFrame.new((wx + sxo) * S, (0.5 + 5) * S, (frontZ - 0.08) * S), trim)
				end
			end
		end
	end
	if stories == 2 then
		newPart(m, "Window2", Vector3.new(5, 3.2, 0.25) * S,
			cf * CFrame.new(0, 13.5 * S, (frontZ - 0.1) * S), glass, Enum.Material.Glass)
	end
	if w > 34 and style ~= "lshape" then
		newPart(m, "Garage", Vector3.new(9, 6.4, 0.3) * S,
			cf * CFrame.new(-w * 0.3 * S, (0.5 + 3.2) * S, (frontZ - 0.12) * S),
			Color3.fromRGB(220, 215, 205))
		newPart(m, "Driveway", Vector3.new(10, 0.25, 12) * S,
			cf * CFrame.new(-w * 0.3 * S, 0.15 * S, (frontZ - 6.5) * S),
			Color3.fromRGB(165, 160, 152), Enum.Material.Concrete)
	end
	-- RENT sign out front: click it in-game to own this house
	local signCf = cf * CFrame.new((doorX + 7) * S, 0, (frontZ - 5) * S)
	newPart(m, "RentPost", Vector3.new(0.35, 4.2, 0.35) * S, signCf * CFrame.new(0, 2.1 * S, 0),
		Color3.fromRGB(110, 90, 70), Enum.Material.Wood)
	local rentBoard = newPart(m, "RentSign", Vector3.new(4.6, 2.4, 0.25) * S,
		signCf * CFrame.new(0, 4.6 * S, 0), Color3.fromRGB(200, 60, 50))
	rentBoard:SetAttribute("RentSign", true)
	makeSign(rentBoard, Enum.NormalId.Front, "RENT", Color3.fromRGB(200, 60, 50), Color3.new(1, 1, 1))
	local rentClick = Instance.new("ClickDetector")
	rentClick.MaxActivationDistance = 32
	rentClick.Parent = rentBoard
	-- where a hatched dog appears (by the front door)
	m:SetAttribute("DogSpot", (cf * CFrame.new(doorX * S, 1 * S, (frontZ - 10) * S)).Position)
end

local function buildCommercial(m, cf, b)
	local w, d = b.w, b.d
	local h = math.clamp(12 + b.w * 0.05, 13, 20)
	newPart(m, "Body", Vector3.new(w, h, d) * S, cf * CFrame.new(0, h / 2 * S, 0),
		Color3.fromRGB(215, 210, 200), Enum.Material.Brick)
	newPart(m, "Parapet", Vector3.new(w + 1, 1.4, d + 1) * S, cf * CFrame.new(0, (h + 0.7) * S, 0),
		Color3.fromRGB(190, 185, 175), Enum.Material.Concrete)
	newPart(m, "Storefront", Vector3.new(w * 0.7, h * 0.45, 0.3) * S,
		cf * CFrame.new(0, h * 0.28 * S, (-d / 2 - 0.12) * S),
		Color3.fromRGB(140, 195, 215), Enum.Material.Glass, 0.3)
	local name = nearestPoiName(b.x, b.z)
	if name then
		m.Name = name
		local board = newPart(m, "SignBoard", Vector3.new(math.min(w * 0.85, 40), 3, 0.4) * S,
			cf * CFrame.new(0, (h - 2) * S, (-d / 2 - 0.3) * S), Color3.fromRGB(35, 45, 60))
		makeSign(board, Enum.NormalId.Front, name, Color3.fromRGB(35, 45, 60), Color3.new(1, 1, 1))
	end
end

local function buildSchoolBox(m, cf, b)
	local h = 13
	newPart(m, "Body", Vector3.new(b.w, h, b.d) * S, cf * CFrame.new(0, h / 2 * S, 0),
		Color3.fromRGB(200, 205, 215), Enum.Material.Brick)
	newPart(m, "Roof", Vector3.new(b.w + 1, 1, b.d + 1) * S, cf * CFrame.new(0, (h + 0.5) * S, 0),
		Color3.fromRGB(90, 110, 150))
	newPart(m, "Windows", Vector3.new(b.w * 0.8, 3.5, 0.25) * S,
		cf * CFrame.new(0, 6 * S, (-b.d / 2 - 0.1) * S),
		Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
end

local function buildDockAndBoat(b)
	local ex, en = yawDir(b.dockYaw)
	-- march from the building edge to the rendered water edge
	local startD = b.d / 2 + 4
	local edge = nil
	local dd = startD
	while dd <= startD + 160 do
		if isWaterAt(b.x + ex * dd, b.z + en * dd) then
			edge = dd
			break
		end
		dd = dd + 6
	end
	if not edge then return false end
	local px, pz = b.x + ex * (edge + 2), b.z + en * (edge + 2)
	local m = newModel(FOLDERS.Docks, "Dock")
	local pos = toWorld(px, pz, 0)
	local dir = dirToWorld(ex, en)
	local cf = CFrame.lookAt(pos, pos + dir)
	newPart(m, "Deck", Vector3.new(5, 0.8, 22) * S, cf * CFrame.new(0, 1.8 * S, -11 * S),
		COL.wood, Enum.Material.WoodPlanks)
	for _, c in ipairs({ { -2, -2 }, { 2, -2 }, { -2, -20 }, { 2, -20 } }) do
		newPart(m, "Post", Vector3.new(0.8, 5, 0.8) * S, cf * CFrame.new(c[1] * S, -0.4 * S, c[2] * S),
			COL.wood, Enum.Material.Wood)
	end
	if rng:NextNumber() < CONFIG.boatChance then
		local boat = TPL.boats[rng:NextInteger(1, #TPL.boats)]
		local sideDir = Vector3.new(-dir.Z, 0, dir.X)
		local moor = pos + dir * 14 * S + sideDir * 7 * S + Vector3.new(0, 0.4 * S, 0)
		placeClone(boat, m, moor, moor - dir * 10)
	end
	return true
end

-- DB Elementary's generic school boxes are replaced by the big walk-in school
local dbElem = DATA.landmarks.dbElementary
local function nearElementary(x, z)
	if not dbElem then return false end
	local dx, dz = x - dbElem.x, z - dbElem.z
	return dx * dx + dz * dz < 260 * 260
end

local counts = { r = 0, c = 0, s = 0, docks = 0 }
local function buildBuildings()
	for _, b in ipairs(buildings) do
		if inRegion(b.x, b.z) and not nearPlaza(b.x, b.z)
			and not (b.cls == "s" and nearElementary(b.x, b.z)) then
			local pos = toWorld(b.x, b.z, Y_LAND)
			local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(b.yaw), 0)
			local m = newModel(FOLDERS.Buildings, b.cls == "r" and "House" or (b.cls == "c" and "Commercial" or "School"))
			if b.cls == "r" then
				buildResidential(m, cf, b)
				counts.r = counts.r + 1
			elseif b.cls == "c" then
				buildCommercial(m, cf, b)
				counts.c = counts.c + 1
			else
				buildSchoolBox(m, cf, b)
				counts.s = counts.s + 1
			end
			markBuilding(b.x, b.z)
			if b.cls == "r" and b.dockYaw and CONFIG.build.docks then
				if buildDockAndBoat(b) then
					counts.docks = counts.docks + 1
				end
			end
		end
	end
end

--==============================================================================================
-- 10. LANDMARKS
--==============================================================================================
local function nearestRoadPoint(name, x, z)
	local best, bestD = nil, math.huge
	for _, rd in ipairs(roads) do
		if rd.name == name then
			for _, p in ipairs(rd.pts) do
				local dx, dz = p[1] - x, p[2] - z
				local d = dx * dx + dz * dz
				if d < bestD then best, bestD = p, d end
			end
		end
	end
	return best
end

local function buildClubhouse()
	local lm = DATA.landmarks.clubhouse
	if not lm or not inRegion(lm.x, lm.z) then return end
	local m = newModel(FOLDERS.Landmarks, "Clubhouse")
	local pos = toWorld(lm.x, lm.z, Y_LAND)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(lm.yaw), 0)
	local w, d = math.max(lm.w, 60), math.max(lm.d, 40)
	newPart(m, "Main", Vector3.new(w, 22, d) * S, cf * CFrame.new(0, 11 * S, 0),
		Color3.fromRGB(226, 218, 200), Enum.Material.Brick)
	gableRoof(m, cf * CFrame.new(0, 22 * S, 0), (w + 2) * S, (d + 2) * S, 7 * S, COL.roofs[1])
	for _, px in ipairs({ -10, 10 }) do
		newColumn(m, "Column", 12 * S, 1.6 * S, cf * CFrame.new(px * S, 6 * S, (-d / 2 - 4) * S),
			Color3.fromRGB(240, 236, 228))
	end
	newPart(m, "Portico", Vector3.new(26, 1.4, 10) * S, cf * CFrame.new(0, 12.6 * S, (-d / 2 - 4.5) * S),
		COL.roofs[1])
	newPart(m, "Doors", Vector3.new(8, 8, 0.4) * S, cf * CFrame.new(0, 4 * S, (-d / 2 - 0.2) * S),
		Color3.fromRGB(90, 65, 45), Enum.Material.Wood)
	for _, y in ipairs({ 6, 16 }) do
		newPart(m, "Windows", Vector3.new(w * 0.8, 3.6, 0.3) * S,
			cf * CFrame.new(0, y * S, (-d / 2 - 0.1) * S), Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
	end
	local board = newPart(m, "SignBoard", Vector3.new(36, 3.4, 0.5) * S,
		cf * CFrame.new(0, 19.5 * S, (-d / 2 - 0.4) * S), Color3.fromRGB(30, 45, 60))
	makeSign(board, Enum.NormalId.Front, "DISCOVERY BAY GOLF & COUNTRY CLUB",
		Color3.fromRGB(30, 45, 60), Color3.fromRGB(240, 230, 200))
	-- parking apron out front — kept shallow (40 ft) so it stops short of Oakmont Court,
	-- whose centerline runs ~108 ft in front of the building center
	local park = cf * CFrame.new(0, 0, (-d / 2 - 25) * S)
	newPart(m, "Parking", Vector3.new(110, 0.4, 40) * S, park * CFrame.new(0, 0.2 * S, 0),
		Color3.fromRGB(120, 120, 120), Enum.Material.Asphalt)
	for i = 1, 9 do
		newPart(m, "Stripe", Vector3.new(0.6, 0.1, 16) * S,
			park * CFrame.new((-50 + i * 10.5) * S, 0.5 * S, -9 * S), COL.stripe)
	end
	for i = 1, 5 do
		local cpos = (park * CFrame.new((-45 + i * 17) * S, 0.4 * S, -7 * S)).Position
		local tgt = (park * CFrame.new((-45 + i * 17) * S, 0.4 * S, 10 * S)).Position
		placeClone(TPL.car, m, cpos, tgt)
	end
end

local function buildGolfFlags()
	for _, g in ipairs(DATA.greens) do
		if inRegion(g.x, g.z) then
			local base = toWorld(g.x, g.z, Y_LAND)
			newPart(FOLDERS.Golf, "FlagPole", Vector3.new(0.25, 9, 0.25) * S,
				CFrame.new(base + Vector3.new(0, 4.5 * S, 0)), Color3.fromRGB(235, 235, 235), Enum.Material.Metal)
			newPart(FOLDERS.Golf, "Flag", Vector3.new(0.15, 1.5, 2.4) * S,
				CFrame.new(base + Vector3.new(0, 8 * S, 1.25 * S)), Color3.fromRGB(200, 40, 40))
		end
	end
end

local function storefront(parent, name, cf, w, d, h, bg, fg)
	local m = newModel(parent, name)
	newPart(m, "Body", Vector3.new(w, h, d) * S, cf * CFrame.new(0, h / 2 * S, 0),
		Color3.fromRGB(228, 222, 210), Enum.Material.Brick)
	newPart(m, "Parapet", Vector3.new(w + 1, 1.4, d + 1) * S, cf * CFrame.new(0, (h + 0.7) * S, 0),
		Color3.fromRGB(200, 194, 184), Enum.Material.Concrete)
	newPart(m, "Glass", Vector3.new(w * 0.7, h * 0.5, 0.3) * S,
		cf * CFrame.new(0, h * 0.3 * S, (-d / 2 - 0.12) * S), Color3.fromRGB(140, 195, 215),
		Enum.Material.Glass, 0.3)
	newPart(m, "Awning", Vector3.new(w * 0.8, 0.4, 4) * S, cf * CFrame.new(0, h * 0.62 * S, (-d / 2 - 2) * S),
		bg, Enum.Material.Fabric)
	local board = newPart(m, "SignBoard", Vector3.new(w * 0.88, 2.8, 0.4) * S,
		cf * CFrame.new(0, (h - 1.6) * S, (-d / 2 - 0.25) * S), bg)
	makeSign(board, Enum.NormalId.Front, name, bg, fg)
	return m
end

local plazaSpawnPos = nil -- set by buildPlaza: a guaranteed-open spot on the parking lot

local function buildPlaza()
	if not plazaPt or not inRegion(plazaPt.x, plazaPt.z) then return end
	local m = newModel(FOLDERS.Landmarks, "Discovery Bay Blvd Plaza")
	-- face the plaza toward Discovery Bay Boulevard
	local rp = nearestRoadPoint("Discovery Bay Boulevard", plazaPt.x, plazaPt.z)
	local fx, fz = 1, 0
	if rp then
		local dx, dz = rp[1] - plazaPt.x, rp[2] - plazaPt.z
		local dl = math.max(math.sqrt(dx * dx + dz * dz), 1)
		fx, fz = dx / dl, dz / dl
	end
	local pos = toWorld(plazaPt.x, plazaPt.z, Y_LAND)
	local front = dirToWorld(fx, fz)
	local cf = CFrame.lookAt(pos, pos + front)
	local right = cf.RightVector

	-- Shell Gas Station (REQUIRED) at the real fuel-station site
	local shell = newModel(m, "Shell Gas Station")
	newPart(shell, "Forecourt", Vector3.new(46, 0.3, 34) * S, cf * CFrame.new(0, 0.15 * S, -6 * S),
		Color3.fromRGB(120, 120, 120), Enum.Material.Concrete)
	-- kiosk: a hollow, enterable mini-mart with auto-sliding doors and buyable products
	local K = cf * CFrame.new(0, 0, 14 * S) -- kiosk base center at grade; local -Z = storefront
	local wallColor = Color3.fromRGB(235, 232, 225)
	newPart(shell, "KioskFloor", Vector3.new(24, 0.4, 18) * S, K * CFrame.new(0, 0.2 * S, 0),
		Color3.fromRGB(200, 196, 188), Enum.Material.Concrete)
	newPart(shell, "KioskBack", Vector3.new(24, 10, 0.6) * S, K * CFrame.new(0, 5 * S, 8.7 * S),
		wallColor, Enum.Material.Brick)
	for _, sx in ipairs({ -1, 1 }) do
		newPart(shell, "KioskSide", Vector3.new(0.6, 10, 18) * S, K * CFrame.new(sx * 11.7 * S, 5 * S, 0),
			wallColor, Enum.Material.Brick)
		newPart(shell, "KioskFrontWall", Vector3.new(8.5, 10, 0.6) * S,
			K * CFrame.new(sx * 7.75 * S, 5 * S, -8.7 * S), wallColor, Enum.Material.Brick)
		newPart(shell, "KioskWindow", Vector3.new(5.5, 4, 0.3) * S,
			K * CFrame.new(sx * 7.75 * S, 5.5 * S, -8.85 * S),
			Color3.fromRGB(140, 195, 215), Enum.Material.Glass, 0.3)
		local door = newPart(shell, "AutoDoor", Vector3.new(3.5, 7, 0.25) * S,
			K * CFrame.new(sx * 1.75 * S, 3.5 * S, -8.7 * S),
			Color3.fromRGB(160, 205, 225), Enum.Material.Glass, 0.35)
		door:SetAttribute("AutoDoor", true)
		door:SetAttribute("SlideDist", sx * 3.5 * S) -- slides sideways behind the front wall
	end
	newPart(shell, "KioskHeader", Vector3.new(7, 3, 0.6) * S, K * CFrame.new(0, 8.5 * S, -8.7 * S),
		wallColor, Enum.Material.Brick)
	newPart(shell, "KioskRoof", Vector3.new(25.5, 1, 19.5) * S, K * CFrame.new(0, 10.5 * S, 0),
		Color3.fromRGB(180, 40, 35))
	local ks = newPart(shell, "KioskSign", Vector3.new(17, 2.4, 0.4) * S, cf * CFrame.new(0, 8.6 * S, 4.9 * S),
		Color3.fromRGB(250, 205, 30))
	makeSign(ks, Enum.NormalId.Front, "Shell", Color3.fromRGB(250, 205, 30), Color3.fromRGB(200, 30, 30))
	-- interior: light, counter, shelves, products with Buy prompts
	local lightPanel = newPart(shell, "KioskLight", Vector3.new(6, 0.2, 6) * S, K * CFrame.new(0, 9.7 * S, 0),
		Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
	local kioskLight = Instance.new("PointLight")
	kioskLight.Range = 24
	kioskLight.Brightness = 1.2
	kioskLight.Parent = lightPanel
	newPart(shell, "Counter", Vector3.new(8, 3.2, 2.5) * S, K * CFrame.new(-7 * S, 2.05 * S, -5 * S),
		Color3.fromRGB(120, 90, 70), Enum.Material.Wood)
	newPart(shell, "Register", Vector3.new(1.4, 1.4, 1) * S, K * CFrame.new(-7 * S, 4.4 * S, -5 * S),
		Color3.fromRGB(50, 50, 55))
	buildNPC(shell, "Sal", K * CFrame.new(-7 * S, 0.4 * S, -2 * S),
		Color3.fromRGB(250, 205, 30),
		"Fuel for cars, soda for scooters! Every Soda makes that scooter a little quicker - stacks five times.",
		{ { "Anything else?",
			"Snacks, lots of snacks. And don't let Callahan tell you ice cream is fuel. It is delicious though." } })
	for _, sy in ipairs({ 2.2, 4.8 }) do
		newPart(shell, "Shelf", Vector3.new(1.8, 0.3, 12) * S, K * CFrame.new(10.4 * S, sy * S, 0),
			Color3.fromRGB(170, 165, 155), Enum.Material.Metal)
		newPart(shell, "Shelf", Vector3.new(9, 0.3, 1.8) * S, K * CFrame.new(-2 * S, sy * S, 7.6 * S),
			Color3.fromRGB(170, 165, 155), Enum.Material.Metal)
	end
	local productSpots = {
		{ 10.4, 3.05, -4 }, { 10.4, 3.05, 0 }, { 10.4, 3.05, 4 },
		{ 10.4, 5.65, -2 }, { 10.4, 5.65, 2 }, { -2, 3.05, 7.6 },
	}
	for i, pr in ipairs(PRODUCTS) do
		local sp = productSpots[i] -- only the first 6 everyday items; cones live at Callahan's
		if sp then
			addProductDisplay(shell, pr, K * CFrame.new(sp[1] * S, sp[2] * S, sp[3] * S))
		end
	end
	for _, o in ipairs({ { -16, -16 }, { 16, -16 }, { -16, 2 }, { 16, 2 } }) do
		newColumn(shell, "CanopyColumn", 15 * S, 1.4 * S, cf * CFrame.new(o[1] * S, 7.5 * S, o[2] * S),
			Color3.fromRGB(230, 228, 222), Enum.Material.Metal)
	end
	newPart(shell, "Canopy", Vector3.new(44, 1.2, 30) * S, cf * CFrame.new(0, 15.6 * S, -7 * S),
		Color3.fromRGB(250, 205, 30))
	newPart(shell, "CanopyBand", Vector3.new(44.5, 1.6, 30.5) * S, cf * CFrame.new(0, 14.6 * S, -7 * S),
		Color3.fromRGB(200, 30, 30))
	for _, oz in ipairs({ -13, -1 }) do
		newPart(shell, "PumpIsland", Vector3.new(13, 0.6, 4) * S, cf * CFrame.new(0, 0.6 * S, oz * S),
			Color3.fromRGB(200, 200, 200), Enum.Material.Concrete)
		for _, ox in ipairs({ -4, 4 }) do
			newPart(shell, "Pump", Vector3.new(1.8, 4.2, 1.2) * S, cf * CFrame.new(ox * S, 3 * S, oz * S),
				Color3.fromRGB(235, 235, 235))
		end
	end
	local spole = cf * CFrame.new(24 * S, 0, -20 * S)
	newColumn(shell, "RoadSignPole", 22 * S, 1.2 * S, spole * CFrame.new(0, 11 * S, 0),
		Color3.fromRGB(190, 190, 190), Enum.Material.Metal)
	local rs = newPart(shell, "RoadSign", Vector3.new(8, 9, 0.8) * S, spole * CFrame.new(0, 26 * S, 0),
		Color3.fromRGB(250, 205, 30))
	makeSign(rs, Enum.NormalId.Front, "Shell", Color3.fromRGB(250, 205, 30), Color3.fromRGB(200, 30, 30))
	makeSign(rs, Enum.NormalId.Back, "Shell", Color3.fromRGB(250, 205, 30), Color3.fromRGB(200, 30, 30))

	-- storefront row beside the station, set back from the road
	local rowBase = pos - right * 58 * S
	local rowCf = CFrame.lookAt(rowBase, rowBase + front)

	-- Egg Shop (in the old Convenience Mart slot, next to Callahan's): hatch a
	-- mystery egg out front and a dog moves into your rented house
	storefront(m, "Egg Shop", rowCf * CFrame.new(0, 0, 18 * S), 30, 24, 12,
		Color3.fromRGB(235, 200, 90), Color3.fromRGB(80, 60, 30))
	local eggBase = (rowCf * CFrame.new(9 * S, 0, 2 * S)).Position
	newDisc(m, "EggPedestal", 6 * S, 1 * S, CFrame.new(eggBase + Vector3.new(0, 0.5 * S, 0)),
		Color3.fromRGB(200, 195, 185), Enum.Material.Concrete)
	local egg = newBall(m, "MysteryEgg", 4 * S, CFrame.new(eggBase + Vector3.new(0, 3 * S, 0)),
		Color3.fromRGB(250, 245, 228))
	egg:SetAttribute("EggShop", true)
	local eggPrompt = Instance.new("ProximityPrompt")
	eggPrompt.ActionText = "Hatch"
	eggPrompt.ObjectText = "Mystery Egg - $30 (needs a rented house)"
	eggPrompt.HoldDuration = 1
	eggPrompt.MaxActivationDistance = 10
	eggPrompt.RequiresLineOfSight = false
	eggPrompt.Parent = egg
	buildNPC(m, "Eggbert",
		CFrame.lookAt(eggBase + Vector3.new(-8 * S, 0, 3 * S), Vector3.new(eggBase.X, eggBase.Y, eggBase.Z)),
		Color3.fromRGB(235, 200, 90),
		"Psst! Mystery dogs in these eggs. Mostly Mary or Jolene... but one in a HUNDRED hatches Linus. Rent a house first - pups need a home!",
		{ { "Who's Linus?",
			"A golden legend. Pays $100 a pet. I saw him hatch once. Changed my whole life." } })

	-- Callahan's Coffee and Cones (REQUIRED): a walk-in ice cream shop
	do
		local cSh = rowCf * CFrame.new(-36 * S, 0, 18 * S) -- shop base; local -Z = storefront
		local mC = newModel(m, "Callahan's Coffee and Cones")
		local w, d, h = 30, 24, 12
		local wallC = Color3.fromRGB(240, 224, 214)
		newPart(mC, "Floor", Vector3.new(w, 0.4, d) * S, cSh * CFrame.new(0, 0.2 * S, 0),
			Color3.fromRGB(238, 214, 205), Enum.Material.Concrete)
		newPart(mC, "Back", Vector3.new(w, h, 0.6) * S, cSh * CFrame.new(0, h / 2 * S, (d / 2 - 0.3) * S),
			wallC, Enum.Material.Brick)
		for _, sx in ipairs({ -1, 1 }) do
			newPart(mC, "Side", Vector3.new(0.6, h, d) * S, cSh * CFrame.new(sx * (w / 2 - 0.3) * S, h / 2 * S, 0),
				wallC, Enum.Material.Brick)
			-- front wall segments beside a 5-stud door opening
			newPart(mC, "FrontWall", Vector3.new(12.5, h, 0.6) * S,
				cSh * CFrame.new(sx * 8.75 * S, h / 2 * S, (-d / 2 + 0.3) * S), wallC, Enum.Material.Brick)
			newPart(mC, "Window", Vector3.new(7, 4.5, 0.3) * S,
				cSh * CFrame.new(sx * 8.75 * S, 5.6 * S, (-d / 2 + 0.15) * S),
				Color3.fromRGB(140, 195, 215), Enum.Material.Glass, 0.3)
			local doorP = newPart(mC, "AutoDoor", Vector3.new(2.5, 7, 0.25) * S,
				cSh * CFrame.new(sx * 1.25 * S, 3.5 * S, (-d / 2 + 0.3) * S),
				Color3.fromRGB(190, 220, 235), Enum.Material.Glass, 0.35)
			doorP:SetAttribute("AutoDoor", true)
			doorP:SetAttribute("SlideDist", sx * 2.6 * S)
		end
		newPart(mC, "DoorHeader", Vector3.new(5, h - 7, 0.6) * S,
			cSh * CFrame.new(0, (7 + (h - 7) / 2) * S, (-d / 2 + 0.3) * S), wallC, Enum.Material.Brick)
		newPart(mC, "Roof", Vector3.new(w + 1, 1, d + 1) * S, cSh * CFrame.new(0, (h + 0.5) * S, 0),
			Color3.fromRGB(150, 75, 105))
		newPart(mC, "Awning", Vector3.new(w * 0.85, 0.4, 4) * S, cSh * CFrame.new(0, 8 * S, (-d / 2 - 2) * S),
			Color3.fromRGB(150, 75, 105), Enum.Material.Fabric)
		local cSign = newPart(mC, "SignBoard", Vector3.new(w * 0.9, 2.6, 0.4) * S,
			cSh * CFrame.new(0, (h - 1.4) * S, (-d / 2 - 0.35) * S), Color3.fromRGB(150, 75, 105))
		makeSign(cSign, Enum.NormalId.Front, "Callahan's Coffee and Cones",
			Color3.fromRGB(150, 75, 105), Color3.fromRGB(255, 245, 235))
		-- interior: light, counter, menu board, the three premium flavors
		local cLight = newPart(mC, "ShopLight", Vector3.new(5, 0.2, 5) * S, cSh * CFrame.new(0, (h - 0.4) * S, 0),
			Color3.fromRGB(255, 245, 240), Enum.Material.Neon)
		local cPt = Instance.new("PointLight")
		cPt.Range = 22
		cPt.Brightness = 1.2
		cPt.Parent = cLight
		newPart(mC, "Counter", Vector3.new(16, 3.2, 2.4) * S, cSh * CFrame.new(0, 2.05 * S, 4 * S),
			Color3.fromRGB(200, 150, 160), Enum.Material.SmoothPlastic)
		local menu = newPart(mC, "MenuBoard", Vector3.new(14, 4, 0.3) * S,
			cSh * CFrame.new(0, 7.5 * S, (d / 2 - 0.7) * S), Color3.fromRGB(60, 40, 45))
		makeSign(menu, Enum.NormalId.Front, "ICE CREAM — Chocolate $40 · Vanilla $45 · Mint $60",
			Color3.fromRGB(60, 40, 45), Color3.fromRGB(255, 235, 225))
		local flavorX = { ["Chocolate Cone"] = -5, ["Vanilla Cone"] = 0, ["Mint Cone"] = 5 }
		for _, pr in ipairs(PRODUCTS) do
			local fx = flavorX[pr.name]
			if fx then
				addProductDisplay(mC, pr, cSh * CFrame.new(fx * S, 3.6 * S + 0.55, 4 * S))
			end
		end
		buildNPC(mC, "Callahan", cSh * CFrame.new(-4 * S, 0.4 * S, 8 * S),
			Color3.fromRGB(150, 75, 105),
			"Welcome to Callahan's Coffee and Cones! Chocolate makes your legs faster, Vanilla feeds your scooter, and Mint... Mint DOUBLES your trick money!",
			{ { "Which one should I get?",
				"Mint, if you can afford it. I've watched kids earn it back in one lap around Willow Lake." } })
	end

	-- Discovery Bay Jiu Jitsu (REQUIRED): a walk-in dojo with the challenge mat
	do
		local jSh = rowCf * CFrame.new(-70 * S, 0, 18 * S) -- dojo base; local -Z = storefront
		local mJ = newModel(m, "Discovery Bay Jiu Jitsu")
		local w, d, h = 32, 24, 13
		local wallJ = Color3.fromRGB(60, 64, 70)
		newPart(mJ, "Floor", Vector3.new(w, 0.4, d) * S, jSh * CFrame.new(0, 0.2 * S, 0),
			Color3.fromRGB(120, 90, 65), Enum.Material.WoodPlanks)
		newPart(mJ, "Back", Vector3.new(w, h, 0.6) * S, jSh * CFrame.new(0, h / 2 * S, (d / 2 - 0.3) * S),
			wallJ, Enum.Material.Concrete)
		for _, sx in ipairs({ -1, 1 }) do
			newPart(mJ, "Side", Vector3.new(0.6, h, d) * S, jSh * CFrame.new(sx * (w / 2 - 0.3) * S, h / 2 * S, 0),
				wallJ, Enum.Material.Concrete)
			newPart(mJ, "FrontWall", Vector3.new((w - 5) / 2, h, 0.6) * S,
				jSh * CFrame.new(sx * ((w - 5) / 4 + 1.25) * S, h / 2 * S, (-d / 2 + 0.3) * S),
				wallJ, Enum.Material.Concrete)
			newPart(mJ, "Window", Vector3.new(6, 4.5, 0.3) * S,
				jSh * CFrame.new(sx * ((w - 5) / 4 + 1.25) * S, 6 * S, (-d / 2 + 0.15) * S),
				Color3.fromRGB(120, 160, 180), Enum.Material.Glass, 0.35)
			local doorJ = newPart(mJ, "AutoDoor", Vector3.new(2.5, 7, 0.25) * S,
				jSh * CFrame.new(sx * 1.25 * S, 3.5 * S, (-d / 2 + 0.3) * S),
				Color3.fromRGB(170, 200, 215), Enum.Material.Glass, 0.35)
			doorJ:SetAttribute("AutoDoor", true)
			doorJ:SetAttribute("SlideDist", sx * 2.6 * S)
		end
		newPart(mJ, "DoorHeader", Vector3.new(5, h - 7, 0.6) * S,
			jSh * CFrame.new(0, (7 + (h - 7) / 2) * S, (-d / 2 + 0.3) * S), wallJ, Enum.Material.Concrete)
		newPart(mJ, "Roof", Vector3.new(w + 1, 1, d + 1) * S, jSh * CFrame.new(0, (h + 0.5) * S, 0),
			Color3.fromRGB(35, 38, 45))
		local jSign = newPart(mJ, "SignBoard", Vector3.new(w * 0.9, 2.6, 0.4) * S,
			jSh * CFrame.new(0, (h - 1.4) * S, (-d / 2 - 0.35) * S), Color3.fromRGB(25, 30, 40))
		makeSign(jSign, Enum.NormalId.Front, "Discovery Bay Jiu Jitsu",
			Color3.fromRGB(25, 30, 40), Color3.fromRGB(230, 60, 60))
		-- interior: light, THE MAT (steps start the challenge), punching bag, rules poster
		local jLight = newPart(mJ, "DojoLight", Vector3.new(5, 0.2, 5) * S, jSh * CFrame.new(0, (h - 0.4) * S, 0),
			Color3.fromRGB(255, 250, 240), Enum.Material.Neon)
		local jPt = Instance.new("PointLight")
		jPt.Range = 24
		jPt.Brightness = 1.2
		jPt.Parent = jLight
		local mat = newPart(mJ, "ChallengeMat", Vector3.new(20, 0.5, 14) * S,
			jSh * CFrame.new(0, 0.65 * S, 1.5 * S), Color3.fromRGB(128, 130, 134), Enum.Material.Fabric)
		mat:SetAttribute("JJMat", true)
		newPart(mJ, "BagRope", Vector3.new(0.15, 3.5, 0.15) * S, jSh * CFrame.new(-12 * S, (h - 2) * S, 7 * S),
			Color3.fromRGB(60, 50, 40), Enum.Material.Metal)
		newColumn(mJ, "PunchingBag", 4.5 * S, 1.7 * S, jSh * CFrame.new(-12 * S, (h - 6) * S, 7 * S),
			Color3.fromRGB(120, 40, 40), Enum.Material.Fabric)
		local rules = newPart(mJ, "RulesBoard", Vector3.new(16, 4, 0.3) * S,
			jSh * CFrame.new(0, 7.5 * S, (d / 2 - 0.7) * S), Color3.fromRGB(25, 30, 40))
		makeSign(rules, Enum.NormalId.Front, "STEP ON THE MAT · CLICK 7 BUTTONS · WIN $50",
			Color3.fromRGB(25, 30, 40), Color3.fromRGB(255, 235, 200))
		buildNPC(mJ, "Sensei", jSh * CFrame.new(12 * S, 0.4 * S, 8 * S),
			Color3.fromRGB(25, 30, 40),
			"Step on the grey mat to begin your training. Seven buttons. Five seconds each. Miss and you PAY. Win, and you feast: $50.",
			{ { "Any advice?",
				"Never leave the mat mid-fight. And never, EVER, challenge me on a Monday." } })
	end
	-- giant ice-cream prop by Callahan's
	local ic = (rowCf * CFrame.new(-24 * S, 0, 2 * S)).Position
	newColumn(m, "ConePole", 4.5 * S, 1.8 * S, CFrame.new(ic + Vector3.new(0, 2.25 * S, 0)),
		Color3.fromRGB(190, 140, 90), Enum.Material.Wood)
	newBall(m, "Scoop", 3 * S, CFrame.new(ic + Vector3.new(0, 5.6 * S, 0)), Color3.fromRGB(245, 170, 190))
	-- shared parking + cars
	local pk = rowCf * CFrame.new(-30 * S, 0, -16 * S)
	newPart(m, "Parking", Vector3.new(92, 0.35, 34) * S, pk * CFrame.new(0, 0.18 * S, 0),
		Color3.fromRGB(125, 125, 125), Enum.Material.Asphalt)
	for i = 1, 8 do
		newPart(m, "Stripe", Vector3.new(0.5, 0.1, 12) * S, pk * CFrame.new((-42 + i * 10) * S, 0.42 * S, -8 * S),
			COL.stripe)
	end
	for i = 1, 4 do
		local cpos = (pk * CFrame.new((-38 + i * 12) * S, 0.3 * S, -5 * S)).Position
		placeClone(TPL.car, m, cpos, (pk * CFrame.new((-38 + i * 12) * S, 0.3 * S, 10 * S)).Position)
	end
	-- open corner of the parking lot, in the plaza's own frame: always clear pavement
	plazaSpawnPos = (pk * CFrame.new(30 * S, 0.6 * S, 8 * S)).Position
end

-- the big walk-in Discovery Bay Elementary: corridor, four classrooms, and the
-- famous STUDY buttons (hold one, get a long-lasting scooter brain-boost)
local function buildBigSchool(parent, lm)
	-- site: centroid of the real (suppressed) school footprints, so it sits on the parcel
	local sx, sz, n = 0, 0, 0
	for _, b in ipairs(buildings) do
		if b.cls == "s" and nearElementary(b.x, b.z) then
			sx = sx + b.x
			sz = sz + b.z
			n = n + 1
		end
	end
	local cxF, czF
	if n > 0 then
		cxF, czF = sx / n, sz / n
	else
		cxF, czF = lm.x, lm.z + 100
	end
	local m = newModel(parent, "School Building")
	local pos = toWorld(cxF, czF, Y_LAND)
	-- front faces the campus sign at the landmark point
	local cf = CFrame.lookAt(pos, toWorld(lm.x, lm.z, Y_LAND))
	local w, d, h = 170, 100, 15
	local wallS = Color3.fromRGB(222, 214, 196)
	newPart(m, "Floor", Vector3.new(w, 0.4, d) * S, cf * CFrame.new(0, 0.2 * S, 0),
		Color3.fromRGB(196, 190, 180), Enum.Material.Concrete)
	newPart(m, "Back", Vector3.new(w, h, 0.8) * S, cf * CFrame.new(0, h / 2 * S, (d / 2 - 0.4) * S),
		wallS, Enum.Material.Brick)
	for _, sxn in ipairs({ -1, 1 }) do
		newPart(m, "Side", Vector3.new(0.8, h, d) * S, cf * CFrame.new(sxn * (w / 2 - 0.4) * S, h / 2 * S, 0),
			wallS, Enum.Material.Brick)
		newPart(m, "FrontWall", Vector3.new((w - 10) / 2, h, 0.8) * S,
			cf * CFrame.new(sxn * ((w - 10) / 4 + 2.5) * S, h / 2 * S, (-d / 2 + 0.4) * S),
			wallS, Enum.Material.Brick)
		newPart(m, "FrontGlass", Vector3.new((w - 10) / 2 - 12, 4.5, 0.3) * S,
			cf * CFrame.new(sxn * ((w - 10) / 4 + 2.5) * S, 7 * S, (-d / 2 + 0.2) * S),
			Color3.fromRGB(150, 200, 220), Enum.Material.Glass, 0.3)
		local doorS = newPart(m, "AutoDoor", Vector3.new(5, 8.5, 0.3) * S,
			cf * CFrame.new(sxn * 2.5 * S, 4.25 * S, (-d / 2 + 0.4) * S),
			Color3.fromRGB(170, 205, 225), Enum.Material.Glass, 0.35)
		doorS:SetAttribute("AutoDoor", true)
		doorS:SetAttribute("SlideDist", sxn * 5.2 * S)
	end
	newPart(m, "DoorHeader", Vector3.new(10, h - 8.5, 0.8) * S,
		cf * CFrame.new(0, (8.5 + (h - 8.5) / 2) * S, (-d / 2 + 0.4) * S), wallS, Enum.Material.Brick)
	newPart(m, "Roof", Vector3.new(w + 2, 1, d + 2) * S, cf * CFrame.new(0, (h + 0.5) * S, 0),
		Color3.fromRGB(185, 180, 170), Enum.Material.Concrete)
	newPart(m, "Parapet", Vector3.new(w + 3, 2, d + 3) * S, cf * CFrame.new(0, (h + 1.5) * S, 0),
		Color3.fromRGB(45, 80, 150), Enum.Material.SmoothPlastic)
	local schoolSign = newPart(m, "BigSign", Vector3.new(90, 6, 0.5) * S,
		cf * CFrame.new(0, (h - 3.5) * S, (-d / 2 - 0.5) * S), Color3.fromRGB(30, 60, 110))
	makeSign(schoolSign, Enum.NormalId.Front, "DISCOVERY BAY ELEMENTARY",
		Color3.fromRGB(30, 60, 110), Color3.new(1, 1, 1))
	-- paved driveway from the front doors to the nearest road, so you can ride
	-- straight up to school without crossing grass
	do
		local fdx, fdz = lm.x - cxF, lm.z - czF -- front direction (toward the campus sign)
		local fl = math.max(math.sqrt(fdx * fdx + fdz * fdz), 1e-6)
		fdx, fdz = fdx / fl, fdz / fl
		local doorX = cxF + fdx * (d / 2 + 2)
		local doorZ = czF + fdz * (d / 2 + 2)
		local bestD, bestX, bestZ = math.huge, nil, nil
		for _, rd in ipairs(roads) do
			local rpts = rd.pts
			for i = 1, #rpts - 1 do
				local a, b = rpts[i], rpts[i + 1]
				if math.min(math.abs(a[1] - doorX), math.abs(b[1] - doorX)) < 500
					and math.min(math.abs(a[2] - doorZ), math.abs(b[2] - doorZ)) < 500 then
					local dd, cx2, cz2 = segClosest(doorX, doorZ, a[1], a[2], b[1], b[2])
					if dd < bestD then
						bestD, bestX, bestZ = dd, cx2, cz2
					end
				end
			end
		end
		if bestX and bestD > 6 and bestD < 600 then
			local mid = toWorld((doorX + bestX) / 2, (doorZ + bestZ) / 2, 2.2 * S - 0.15 * S)
			local dir = dirToWorld(bestX - doorX, bestZ - doorZ)
			newPart(m, "SchoolDriveway", Vector3.new(14 * S, 0.3 * S, (bestD + 10) * S),
				CFrame.lookAt(mid, mid + dir), Color3.fromRGB(168, 164, 156), Enum.Material.Concrete)
		end
	end
	-- ONE classroom only: HISTORY OF SCOOTERS. The front is an open lobby; a wall
	-- with a central gap leads into the big classroom that fills the rest.
	local lobbyZ = -d / 2 + 26 -- lobby is 26 ft deep
	for _, sxn in ipairs({ -1, 1 }) do
		newPart(m, "LobbyWall", Vector3.new((w - 8) / 2, h - 2, 0.6) * S,
			cf * CFrame.new(sxn * ((w - 8) / 4 + 2) * S, (h - 2) / 2 * S, lobbyZ * S),
			Color3.fromRGB(235, 230, 218), Enum.Material.SmoothPlastic)
	end
	local rs = newPart(m, "RoomSign", Vector3.new(26, 2, 0.25) * S,
		cf * CFrame.new(0, 10.5 * S, (lobbyZ - 0.4) * S), Color3.fromRGB(30, 60, 110))
	makeSign(rs, Enum.NormalId.Front, "Room 103 · HISTORY OF SCOOTERS",
		Color3.fromRGB(30, 60, 110), Color3.new(1, 1, 1))
	-- blackboard across the back wall
	local board = newPart(m, "Blackboard", Vector3.new(50, 7, 0.3) * S,
		cf * CFrame.new(0, 7.5 * S, (d / 2 - 1.2) * S), Color3.fromRGB(30, 70, 45))
	makeSign(board, Enum.NormalId.Front, "HISTORY OF SCOOTERS, VOL. 1",
		Color3.fromRGB(30, 70, 45), Color3.fromRGB(235, 235, 225))
	-- rows of desks
	for row = 0, 2 do
		for col = -2, 2 do
			if not (row == 2 and col == 0) then -- leave an aisle to the teacher desk
				newPart(m, "Desk", Vector3.new(5, 2.6, 3) * S,
					cf * CFrame.new(col * 16 * S, 1.7 * S, (lobbyZ + 14 + row * 12) * S),
					Color3.fromRGB(170, 130, 90), Enum.Material.WoodPlanks)
			end
		end
	end
	-- teacher desk + THE study button
	newPart(m, "TeacherDesk", Vector3.new(9, 3, 3.5) * S,
		cf * CFrame.new(0, 1.9 * S, (d / 2 - 8) * S), Color3.fromRGB(120, 90, 60), Enum.Material.WoodPlanks)
	local button = newDisc(m, "StudyButton", 2.4 * S, 0.8 * S,
		cf * CFrame.new(0, 3.85 * S, (d / 2 - 8) * S), Color3.fromRGB(220, 50, 50), Enum.Material.Neon)
	button:SetAttribute("StudyButton", true)
	local sp = Instance.new("ProximityPrompt")
	sp.ActionText = "Study"
	sp.ObjectText = "Hold to study (scooter +10 for 15 min)"
	sp.HoldDuration = 3
	sp.MaxActivationDistance = 10
	sp.RequiresLineOfSight = false
	sp.Parent = button
	buildNPC(m, "Ms. Wheeler", cf * CFrame.new(8 * S, 0.4 * S, (d / 2 - 6) * S),
		Color3.fromRGB(90, 60, 120),
		"Welcome to Room 103, History of Scooters. Hold the red button to study - smart riders are FAST riders.",
		{ { "Is studying worth it?",
			"Plus ten speed for fifteen whole minutes. Homework has never paid better." } })
	-- lights: lobby + classroom
	for _, lz in ipairs({ lobbyZ - 12, lobbyZ + 24, d / 2 - 16 }) do
		local rl = newPart(m, "RoomLight", Vector3.new(5, 0.2, 5) * S,
			cf * CFrame.new(0, (h - 0.5) * S, lz * S), Color3.fromRGB(255, 250, 240), Enum.Material.Neon)
		local rpt = Instance.new("PointLight")
		rpt.Range = 30
		rpt.Brightness = 1
		rpt.Parent = rl
	end
end

local function buildSchoolCampus(name, lmName)
	local lm = DATA.landmarks[lmName]
	if not lm or not inRegion(lm.x, lm.z) then return end
	local m = newModel(FOLDERS.Landmarks, name)
	if lmName == "dbElementary" then
		buildBigSchool(m, lm)
	end
	local base = toWorld(lm.x, lm.z, Y_LAND)
	local board = newPart(m, "SignBoard", Vector3.new(20, 4, 0.8) * S, CFrame.new(base + Vector3.new(0, 4 * S, 0)),
		Color3.fromRGB(30, 60, 110))
	makeSign(board, Enum.NormalId.Front, name, Color3.fromRGB(30, 60, 110), Color3.new(1, 1, 1))
	makeSign(board, Enum.NormalId.Back, name, Color3.fromRGB(30, 60, 110), Color3.new(1, 1, 1))
	for _, px in ipairs({ -8, 8 }) do
		newPart(m, "SignPost", Vector3.new(0.6, 2, 0.6) * S,
			CFrame.new(base + Vector3.new(px * S, 1 * S, 0)), Color3.fromRGB(120, 110, 100), Enum.Material.Wood)
	end
	newColumn(m, "FlagPole", 24 * S, 0.5 * S, CFrame.new(base + Vector3.new(10 * S, 12 * S, 0)),
		Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	newPart(m, "Flag", Vector3.new(0.15, 2.4, 4) * S, CFrame.new(base + Vector3.new(10 * S, 22 * S, 2 * S)),
		Color3.fromRGB(180, 40, 50))
	-- playground
	local pg = base + Vector3.new(-24 * S, 0, 10 * S)
	newPart(m, "PlayPad", Vector3.new(30, 0.3, 22) * S, CFrame.new(pg + Vector3.new(0, 0.15 * S, 0)),
		Color3.fromRGB(190, 160, 120), Enum.Material.Sand)
	newPart(m, "Slide", Vector3.new(3, 6, 3) * S, CFrame.new(pg + Vector3.new(-8 * S, 3 * S, 0)),
		Color3.fromRGB(220, 80, 60))
	newWedge(m, "SlideRamp", Vector3.new(3, 6, 8) * S,
		CFrame.new(pg + Vector3.new(-8 * S, 3 * S, -5.5 * S)), Color3.fromRGB(240, 200, 80))
	newPart(m, "Monkeybars", Vector3.new(10, 0.4, 3) * S, CFrame.new(pg + Vector3.new(6 * S, 6 * S, 4 * S)),
		Color3.fromRGB(80, 140, 200), Enum.Material.Metal)
end

local function buildParks()
	for _, pk in ipairs(DATA.parks) do
		if inRegion(pk.x, pk.z) then
			local m = newModel(FOLDERS.Landmarks, pk.name)
			local base = toWorld(pk.x, pk.z, Y_LAND)
			local board = newPart(m, "SignBoard", Vector3.new(14, 3, 0.6) * S,
				CFrame.new(base + Vector3.new(0, 3 * S, 0)), Color3.fromRGB(40, 90, 50))
			makeSign(board, Enum.NormalId.Front, pk.name, Color3.fromRGB(40, 90, 50), Color3.new(1, 1, 1))
			makeSign(board, Enum.NormalId.Back, pk.name, Color3.fromRGB(40, 90, 50), Color3.new(1, 1, 1))
			for _, px in ipairs({ -5.5, 5.5 }) do
				newPart(m, "SignPost", Vector3.new(0.5, 1.5, 0.5) * S,
					CFrame.new(base + Vector3.new(px * S, 0.75 * S, 0)), Color3.fromRGB(120, 110, 100), Enum.Material.Wood)
			end
			for i = 1, math.min(8, math.max(4, math.floor(pk.r / 40))) do
				local ang = rng:NextNumber(0, math.pi * 2)
				local rr = rng:NextNumber(20, math.max(30, pk.r * 0.7))
				local tx, tz = pk.x + math.cos(ang) * rr, pk.z + math.sin(ang) * rr
				if not isWaterAt(tx, tz) and not onRoad(tx, tz) then
					local tpos = toWorld(tx, tz, Y_LAND)
					placeClone(TPL.trees[rng:NextInteger(1, 2)], m, tpos, tpos + Vector3.new(1, 0, 1))
				end
			end
		end
	end
end

-- BLOXWAY: the 30-aisle superstore
local BLOXWAY_AISLES = {
	{ "Mexican Food", "Taco" }, { "Tacos & Burritos", "Burrito" }, { "American Classics", "Cheeseburger" },
	{ "Cheeseburgers", "Cheeseburger" }, { "Hot Dogs", "Hot Dog" }, { "BBQ & Grill", "Hot Dog" },
	{ "Pizza", "Pizza Slice" }, { "Pasta & Italian", "Pizza Slice" }, { "Chips & Snacks", "Chips" },
	{ "Candy", "Cookie" }, { "Cookies", "Cookie" }, { "Bakery", "Donut" },
	{ "Donuts", "Donut" }, { "Breakfast Cereal", "Cereal" }, { "Dairy", "Milk" },
	{ "Milk & Eggs", "Milk" }, { "Sodas", "Soda" }, { "Energy Drinks", "Soda" },
	{ "Water & Juice", "Water" }, { "Coffee & Tea", "Coffee" }, { "Ice Cream", "Ice Cream" },
	{ "Frozen Meals", "Burrito" }, { "Fried Chicken", "Fried Chicken" }, { "Rotisserie", "Fried Chicken" },
	{ "Fruits", "Watermelon" }, { "Vegetables", "Watermelon" }, { "Watermelons", "Watermelon" },
	{ "Deli Sandwiches", "Cheeseburger" }, { "Chinese Takeout", "Burrito" }, { "Sushi", "Pizza Slice" },
}
local PRODUCT_BY_NAME = {}
for _, pr in ipairs(PRODUCTS) do
	PRODUCT_BY_NAME[pr.name] = pr
end

-- find a clear lot near the plaza: grass, no roads through it, no buildings on it
local function findBloxwaySite()
	if not plazaPt then return nil end
	for _, r in ipairs({ 380, 460, 540, 640, 760 }) do
		for ang = 0, 345, 15 do
			local cx = plazaPt.x + math.cos(math.rad(ang)) * r
			local cz = plazaPt.z + math.sin(math.rad(ang)) * r
			local ok = true
			for _, off in ipairs({ { 0, 0 }, { 115, 0 }, { -115, 0 }, { 0, 90 }, { 0, -90 },
				{ 85, 70 }, { -85, 70 }, { 85, -70 }, { -85, -70 } }) do
				local px, pz = cx + off[1], cz + off[2]
				local cls = classAt(px, pz)
				if (cls ~= "l" and cls ~= "p") or onRoad(px, pz) or nearBuilding(px, pz, 55) then
					ok = false
					break
				end
			end
			if ok then return cx, cz end
		end
	end
	return nil
end

local function buildBloxway()
	local bx, bz = findBloxwaySite()
	if not bx then
		warn("[DiscoveryBay] no clear lot near the plaza for BLOXWAY; skipped")
		return
	end
	local m = newModel(FOLDERS.Landmarks, "BLOXWAY")
	local pos = toWorld(bx, bz, Y_LAND)
	-- storefront faces the plaza
	local cf = CFrame.lookAt(pos, toWorld(plazaPt.x, plazaPt.z, Y_LAND))
	local w = 190
	local d = 140
	local h = 26
	-- claim the lot so trees keep off it
	markBuilding(bx, bz)
	for _, off in ipairs({ { 80, 0 }, { -80, 0 }, { 0, 60 }, { 0, -60 } }) do
		markBuilding(bx + off[1], bz + off[2])
	end
	local wallB = Color3.fromRGB(228, 224, 216)
	newPart(m, "Floor", Vector3.new(w, 0.4, d) * S, cf * CFrame.new(0, 0.2 * S, 0),
		Color3.fromRGB(205, 202, 196), Enum.Material.Concrete)
	newPart(m, "Back", Vector3.new(w, h, 0.8) * S, cf * CFrame.new(0, h / 2 * S, (d / 2 - 0.4) * S),
		wallB, Enum.Material.Concrete)
	for _, sx in ipairs({ -1, 1 }) do
		newPart(m, "Side", Vector3.new(0.8, h, d) * S, cf * CFrame.new(sx * (w / 2 - 0.4) * S, h / 2 * S, 0),
			wallB, Enum.Material.Concrete)
		newPart(m, "FrontWall", Vector3.new((w - 14) / 2, h, 0.8) * S,
			cf * CFrame.new(sx * ((w - 14) / 4 + 3.5) * S, h / 2 * S, (-d / 2 + 0.4) * S),
			wallB, Enum.Material.Concrete)
		newPart(m, "FrontGlass", Vector3.new((w - 14) / 2 - 8, 6, 0.3) * S,
			cf * CFrame.new(sx * ((w - 14) / 4 + 3.5) * S, 6 * S, (-d / 2 + 0.2) * S),
			Color3.fromRGB(140, 195, 215), Enum.Material.Glass, 0.3)
		local doorB = newPart(m, "AutoDoor", Vector3.new(7, 10, 0.3) * S,
			cf * CFrame.new(sx * 3.5 * S, 5 * S, (-d / 2 + 0.4) * S),
			Color3.fromRGB(170, 205, 225), Enum.Material.Glass, 0.35)
		doorB:SetAttribute("AutoDoor", true)
		doorB:SetAttribute("SlideDist", sx * 7.2 * S)
	end
	newPart(m, "DoorHeader", Vector3.new(14, h - 10, 0.8) * S,
		cf * CFrame.new(0, (10 + (h - 10) / 2) * S, (-d / 2 + 0.4) * S), wallB, Enum.Material.Concrete)
	newPart(m, "Roof", Vector3.new(w + 2, 1.2, d + 2) * S, cf * CFrame.new(0, (h + 0.6) * S, 0),
		Color3.fromRGB(180, 178, 170), Enum.Material.Concrete)
	newPart(m, "Parapet", Vector3.new(w + 3, 2.4, d + 3) * S, cf * CFrame.new(0, (h + 1.8) * S, 0),
		Color3.fromRGB(200, 60, 55), Enum.Material.SmoothPlastic)
	local bSign = newPart(m, "SignBoard", Vector3.new(math.min(w * 0.6, 120), 8, 0.6) * S,
		cf * CFrame.new(0, (h - 5) * S, (-d / 2 - 0.5) * S), Color3.fromRGB(200, 60, 55))
	makeSign(bSign, Enum.NormalId.Front, "BLOXWAY", Color3.fromRGB(200, 60, 55), Color3.new(1, 1, 1))
	-- ceiling lights
	for _, lx in ipairs({ -w / 4, w / 4 }) do
		for _, lz in ipairs({ -d / 4, d / 4 }) do
			local lightB = newPart(m, "StoreLight", Vector3.new(8, 0.2, 8) * S,
				cf * CFrame.new(lx * S, (h - 0.5) * S, lz * S), Color3.fromRGB(255, 250, 240), Enum.Material.Neon)
			local pt = Instance.new("PointLight")
			pt.Range = 50
			pt.Brightness = 1
			pt.Parent = lightB
		end
	end
	-- checkouts by the entrance
	for i = 1, 4 do
		local cx = -21 + i * 8
		newPart(m, "Checkout", Vector3.new(6, 3, 2.2) * S,
			cf * CFrame.new(cx * S, 1.9 * S, (-d / 2 + 14) * S), Color3.fromRGB(90, 110, 130))
		newPart(m, "Register", Vector3.new(1.2, 1.3, 1) * S,
			cf * CFrame.new(cx * S, 4.1 * S, (-d / 2 + 14) * S), Color3.fromRGB(50, 50, 55))
	end
	buildNPC(m, "Manager Bob", cf * CFrame.new(26 * S, 0.4 * S, (-d / 2 + 18) * S),
		Color3.fromRGB(200, 60, 55),
		"Welcome to BLOXWAY! Thirty aisles, and everything is edible. Even aisle 27 - that's watermelons.",
		{ { "Where's the pizza?",
			"Aisle 7, next to Pasta. Tell them Bob sent you. Changes nothing, but it feels nice." } })
	-- 30 aisles in two banks of 15, each with a hanging sign and buyable food
	local perBank = 15
	local spacing = (w - 24) / perBank
	local shelfLen = (d - 60) / 2
	local aisleNum = 0
	for bank = 0, 1 do
		local bz = (bank == 0) and (-shelfLen / 2 - 4) or (shelfLen / 2 + 10)
		for i = 1, perBank do
			aisleNum = aisleNum + 1
			local a = BLOXWAY_AISLES[aisleNum]
			local ax = -w / 2 + 12 + (i - 0.5) * spacing
			local shelf = newPart(m, "Aisle" .. aisleNum, Vector3.new(3.5, 7, shelfLen) * S,
				cf * CFrame.new(ax * S, 3.9 * S, bz * S), Color3.fromRGB(175, 170, 160), Enum.Material.Metal)
			local hang = newPart(m, "AisleSign", Vector3.new(3.2, 1.8, 0.3) * S,
				cf * CFrame.new(ax * S, 11.5 * S, bz * S), Color3.fromRGB(35, 60, 90))
			makeSign(hang, Enum.NormalId.Front, aisleNum .. " · " .. a[1],
				Color3.fromRGB(35, 60, 90), Color3.new(1, 1, 1))
			makeSign(hang, Enum.NormalId.Back, aisleNum .. " · " .. a[1],
				Color3.fromRGB(35, 60, 90), Color3.new(1, 1, 1))
			local pr = PRODUCT_BY_NAME[a[2]]
			if pr then
				for _, oz in ipairs({ -shelfLen * 0.25, shelfLen * 0.25 }) do
					addProductDisplay(m, pr, cf * CFrame.new(ax * S, 7.4 * S + 0.7, (bz + oz) * S))
				end
			end
		end
	end
end

-- Yacht harbor + lighthouse at the real end of Marina Road
local function buildMarina()
	local rd = nil
	for _, r in ipairs(roads) do
		if r.name == "Marina Road" then rd = r break end
	end
	if not rd then return end
	-- endpoint closest to water
	local endpoints = { rd.pts[1], rd.pts[#rd.pts] }
	local anchor, waterDir = nil, nil
	for _, ep in ipairs(endpoints) do
		for ang = 0, 350, 10 do
			local ex, en = math.cos(math.rad(ang)), math.sin(math.rad(ang))
			for dist = 20, 300, 20 do
				if isWaterAt(ep[1] + ex * dist, ep[2] + en * dist) then
					anchor, waterDir = ep, { ex, en }
					break
				end
			end
			if anchor then break end
		end
		if anchor then break end
	end
	if not anchor or not inRegion(anchor[1], anchor[2]) then return end
	local m = newModel(FOLDERS.Landmarks, "Discovery Bay Yacht Harbor")
	-- march to the shoreline
	local dd = 10
	while dd < 400 and not isWaterAt(anchor[1] + waterDir[1] * dd, anchor[2] + waterDir[2] * dd) do
		dd = dd + 10
	end
	local sx, sz = anchor[1] + waterDir[1] * dd, anchor[2] + waterDir[2] * dd
	local shoreW = toWorld(sx, sz, 0)
	local outDir = dirToWorld(waterDir[1], waterDir[2])
	local alongDir = Vector3.new(-outDir.Z, 0, outDir.X)
	-- covered slip rows
	for row = 0, 3 do
		local rc = shoreW + outDir * (40 + 20) * S + alongDir * (row * 30 - 45) * S
		local rowM = newModel(m, "SlipRow" .. (row + 1))
		local cf = CFrame.lookAt(rc, rc + outDir)
		newPart(rowM, "Walkway", Vector3.new(3.5, 0.8, 90) * S, cf * CFrame.new(0, 1.2 * S, 0),
			COL.wood, Enum.Material.WoodPlanks)
		for _, oz in ipairs({ -40, -15, 15, 40 }) do
			newPart(rowM, "Post", Vector3.new(1, 12, 1) * S, cf * CFrame.new(0, 4 * S, oz * S),
				Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
		end
		newPart(rowM, "Roof", Vector3.new(16, 0.8, 92) * S, cf * CFrame.new(0, 10.4 * S, 0),
			Color3.fromRGB(205, 198, 168), Enum.Material.Metal)
		for b = 1, 3 do
			local off = -30 + b * 18
			local bpos = (cf * CFrame.new((b % 2 == 0 and 6 or -6) * S, 0.4 * S, off * S)).Position
			placeClone(TPL.boats[1], m, bpos, bpos + outDir * 10)
		end
	end
	-- yacht club on shore (raised to land grade)
	local yc = shoreW - outDir * 30 * S + Vector3.new(0, Y_LAND, 0)
	local ycCf = CFrame.lookAt(yc, yc + outDir)
	newPart(m, "YachtClub", Vector3.new(34, 12, 22) * S, ycCf * CFrame.new(0, 6 * S, 0),
		Color3.fromRGB(210, 220, 228), Enum.Material.WoodPlanks)
	gableRoof(m, ycCf * CFrame.new(0, 12 * S, 0), 36 * S, 24 * S, 5 * S, COL.roofs[4])
	local ys = newPart(m, "SignBoard", Vector3.new(26, 2.6, 0.4) * S, ycCf * CFrame.new(0, 10 * S, (-11 - 0.3) * S),
		Color3.fromRGB(25, 55, 90))
	makeSign(ys, Enum.NormalId.Front, "DISCOVERY BAY YACHT HARBOR", Color3.fromRGB(25, 55, 90), Color3.new(1, 1, 1))
	-- launch ramp
	local ramp = shoreW + alongDir * 70 * S
	local rampCf = CFrame.lookAt(ramp, ramp + outDir)
	newWedge(m, "LaunchRamp", Vector3.new(24, 3.2, 30) * S, rampCf * CFrame.new(0, 0.4 * S, -6 * S),
		Color3.fromRGB(184, 176, 154), Enum.Material.Concrete)
	-- lighthouse on the point
	local lh = shoreW - alongDir * 80 * S - outDir * 8 * S
	newDisc(m, "LH_Base", 16 * S, 2 * S, CFrame.new(lh + Vector3.new(0, 1 * S, 0)),
		Color3.fromRGB(200, 195, 185), Enum.Material.Concrete)
	local bands = { Color3.new(1, 1, 1), Color3.fromRGB(200, 45, 40), Color3.new(1, 1, 1), Color3.fromRGB(200, 45, 40) }
	for i, color in ipairs(bands) do
		newColumn(m, "LH_Band" .. i, 7 * S, (9.5 - i * 0.9) * S,
			CFrame.new(lh + Vector3.new(0, (2 + 7 * (i - 0.5)) * S, 0)), color)
	end
	local topY = (2 + 28) * S
	newDisc(m, "LH_Gallery", 9 * S, 1 * S, CFrame.new(lh + Vector3.new(0, topY + 0.5 * S, 0)),
		Color3.fromRGB(50, 55, 60), Enum.Material.Metal)
	newColumn(m, "LH_LampRoom", 4.5 * S, 5.4 * S, CFrame.new(lh + Vector3.new(0, topY + 3.2 * S, 0)),
		Color3.fromRGB(180, 220, 235), Enum.Material.Glass)
	local lamp = newBall(m, "LH_Lamp", 2.6 * S, CFrame.new(lh + Vector3.new(0, topY + 3.2 * S, 0)),
		Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 5
	light.Parent = lamp
	newColumn(m, "LH_Cap", 1.4 * S, 6.4 * S, CFrame.new(lh + Vector3.new(0, topY + 6 * S, 0)),
		Color3.fromRGB(200, 45, 40))
end

--==============================================================================================
-- 11. PROPS (trees, bay boats, spawn)
--==============================================================================================
local function buildTrees()
	local placed, attempts = 0, 0
	while placed < CONFIG.treeCount and attempts < CONFIG.treeCount * 15 do
		attempts = attempts + 1
		local x = rng:NextNumber(0, W_FT)
		local z = rng:NextNumber(0, H_FT)
		local cls = classAt(x, z)
		if (cls == "l" or cls == "p") and inRegion(x, z) and not onRoad(x, z)
			and not nearBuilding(x, z, 40) and nearBuilding(x, z, 700) then
			local pos = toWorld(x, z, Y_LAND)
			placeClone(TPL.trees[rng:NextInteger(1, 2)], FOLDERS.Props, pos,
				pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 10)
			placed = placed + 1
		end
	end
end

local function buildBayBoats()
	local placed, attempts = 0, 0
	while placed < 30 and attempts < 600 do
		attempts = attempts + 1
		local x = rng:NextNumber(0, W_FT)
		local z = rng:NextNumber(0, H_FT)
		if inRegion(x, z) and isWaterAt(x, z) and isWaterAt(x + 60, z) and isWaterAt(x - 60, z)
			and isWaterAt(x, z + 60) and isWaterAt(x, z - 60) then
			local pos = toWorld(x, z, 0.4 * S)
			placeClone(TPL.boats[rng:NextInteger(1, 2)], FOLDERS.Props, pos,
				pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 10)
			placed = placed + 1
		end
	end
end

local function buildSpawn()
	if not plazaPt then return end
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12) * S
	-- on the plaza parking lot (computed in the plaza's own frame by buildPlaza), so it
	-- can never land inside a building or on lethal Discovery Bay Blvd
	spawn.Position = plazaSpawnPos or toWorld(plazaPt.x - 70, plazaPt.z + 20, Y_LAND + 0.5 * S)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = Enum.Material.Concrete
	spawn.Color = Color3.fromRGB(180, 180, 175)
	spawn.Parent = root
end

--==============================================================================================
-- 12. BUILD
--==============================================================================================
print(("[DiscoveryBay] building real Discovery Bay: %.0f x %.0f studs (scale %.2f studs/ft), seed %d")
	:format(W_FT * S, H_FT * S, S, CONFIG.seed))
local t0 = os.clock()

buildKit()
if CONFIG.build.ground then buildGround() print("[DiscoveryBay] ground done") end
if CONFIG.build.roads then
	for ri, rd in ipairs(roads) do buildRoad(rd, ri) end
	print("[DiscoveryBay] roads done")
end
if CONFIG.build.golf then
	buildCartpaths()
	buildGolfFlags()
end
if CONFIG.build.buildings then
	buildBuildings()
	print(("[DiscoveryBay] buildings done: %d homes, %d commercial, %d school, %d docks")
		:format(counts.r, counts.c, counts.s, counts.docks))
end
if CONFIG.build.landmarks then
	buildClubhouse()
	buildPlaza()
	buildBloxway()
	buildSchoolCampus("Discovery Bay Elementary School", "dbElementary")
	buildSchoolCampus("Timber Point School", "timberPoint")
	buildParks()
	buildMarina()
end
if CONFIG.build.props then
	buildStreetlights()
	buildTrees()
	buildBayBoats()
	buildSpawn()
end

root:SetAttribute("WorldW", W_FT * S) -- world extents in studs, used by the client map
root:SetAttribute("WorldH", H_FT * S)
root:SetAttribute("BuildComplete", true) -- signals the DiscoveryBayShop runtime script

print(("[DiscoveryBay] DONE in %.1fs — %d parts. Homes %d, docks %d (every waterfront lot)."):format(
	os.clock() - t0, partCount, counts.r, counts.docks))
print("[DiscoveryBay] Businesses at the Discovery Bay Blvd plaza: Callahan's Coffee and Cones, " ..
	"Discovery Bay Jiu Jitsu, Shell Gas Station.")
print("[DiscoveryBay] StreamingEnabled=" .. tostring(workspace.StreamingEnabled) .. ". All parts anchored.")

if RunService:IsRunning() then
	-- Auto-built during Play: respawn everyone at the plaza SpawnLocation.
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		plr:LoadCharacter()
	end
	print("[DiscoveryBay] NOTE: a Play-mode build disappears when you press Stop. " ..
		"To keep the town in the place: in edit mode run " ..
		"loadstring(game.ServerScriptService.DiscoveryBayBuild.Source)() then save (Ctrl+S).")
end
