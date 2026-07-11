--!strict-ignore
--==============================================================================================
-- DISCOVERY BAY, CALIFORNIA — procedural Roblox build
--==============================================================================================
-- Generates a stylized recreation of the Discovery Bay Golf & Country Club
-- neighborhood (Discovery Bay, CA): Delta waterways, lagoon channels, the four
-- road spines + named cul-de-sac courts, housing rows with private docks and
-- boats, the 18-hole golf core, clubhouse, marina, lighthouse, and the four
-- required businesses (Callahan's Coffee and Cones, Discovery Bay Jiu Jitsu,
-- Shell Gas Station, Convenience Mart).
--
-- HOW TO RUN (pick one):
--   A) Roblox Studio -> open your place -> MODEL tab -> Advanced -> "Run Script"
--      -> select this file. Runs in edit mode; the result persists and can be saved.
--   B) Copy this whole file and paste it into the Command Bar (View -> Command Bar),
--      then press Enter.
-- Re-running is safe: the script deletes its previous output and rebuilds.
--
-- Coordinate system: layout uses a 0..1000 grid (x: 0=west..1000=east,
-- z: 0=south..1000=north). World: X = gx*scale, Z = (1000-gz)*scale, so north
-- is -Z in world space. All sizes in the layout are given in STUDS and stay
-- true-size regardless of worldScale.
--==============================================================================================

----------------------------------------------------------------------------------------------
-- 1. CONFIG
----------------------------------------------------------------------------------------------
local CONFIG = {
	worldScale = 4.0,      -- studs per grid unit. 4.0 => ~4000x4000 stud world (1 stud = 1 ft).
	                       -- Use 2.0 for a half-scale world.
	seed = 94505,          -- deterministic build (94505 = Discovery Bay ZIP). Same seed => same world.
	zonesToBuild = "all",  -- "all", or a list like {1, 3, 4}:
	                       -- 1 Clubhouse & golf core, 2 Fairway housing, 3 Lagoon district,
	                       -- 4 Marina, 5 Perimeter / entry.
	build = {              -- master switches per build stage
		ground    = true,
		roads     = true,
		golf      = true,
		houses    = true,
		docks     = true,
		landmarks = true,
		props     = true,
	},
	density = {
		houseSpacingStuds      = 68,   -- lot pitch along spine roads
		courtHouseSpacingStuds = 62,   -- lot pitch along cul-de-sac courts
		treeCount              = 240,  -- scattered trees (plus golf-edge trees)
		dockBoatChance         = 1.0,  -- chance a private dock also gets a boat (spec: every waterfront lot)
		streetlightStepStuds   = 200,
	},
	groundCellGrid = 5,    -- terrain raster cell size in grid units (5 => 20-stud cells at scale 4).
	                       -- Must stay below ~9 so the 38-stud lagoon channels never fall
	                       -- between row samples and break into dry gaps.
}

local SCALE = CONFIG.worldScale
local rng = Random.new(CONFIG.seed)

-- Elevations (stud heights of TOP surfaces)
local Y_WATER   = 0
local Y_LAND    = 2
local Y_ROAD    = 2.25
local Y_PAD     = 2.1
local Y_BUNKER  = 2.14
local Y_GREEN   = 2.16
local Y_PARKING = 2.18

-- Palette
local COL = {
	delta    = Color3.fromHex("3d6f8c"),
	lagoon   = Color3.fromHex("5aa0c4"),
	land     = Color3.fromHex("d9d0ac"),
	fairway  = Color3.fromHex("82b25c"),
	green    = Color3.fromHex("5fae57"),
	bunker   = Color3.fromHex("e6dcae"),
	road     = Color3.fromHex("3a3a3a"),
	pad      = Color3.fromHex("cfc6a0"),
	parking  = Color3.fromHex("8c8c8c"),
	stripe   = Color3.fromHex("e8e8e8"),
	wood     = Color3.fromHex("7a5230"),
	roofs    = { Color3.fromHex("8c4a2f"), Color3.fromHex("6b6b6b"), Color3.fromHex("7a5230"), Color3.fromHex("334a5c") },
	walls    = { Color3.fromHex("e8e4d8"), Color3.fromHex("d8c9a8"), Color3.fromHex("b8c4a0"), Color3.fromHex("c9c9c9"), Color3.fromHex("a7b6c2") },
}

----------------------------------------------------------------------------------------------
-- 2. LAYOUT DATA (transpiled from discovery-bay-layout.json + trace SVGs)
----------------------------------------------------------------------------------------------
local ZONES = {
	{ id = 1, name = "Clubhouse & golf core", rect = { x = 450, z = 40,  w = 400,  d = 420 } },
	{ id = 2, name = "Fairway housing rows",  rect = { x = 450, z = 40,  w = 420,  d = 560 } },
	{ id = 3, name = "Lagoon district",       rect = { x = 120, z = 300, w = 620,  d = 560 } },
	{ id = 4, name = "Marina",                rect = { x = 780, z = 560, w = 160,  d = 180 } },
	{ id = 5, name = "Perimeter / entry",     rect = { x = 0,   z = 820, w = 1000, d = 180 } },
}

-- Water bodies -------------------------------------------------------------------------------
local WILLOW_LAKE  = { cx = 571, cz = 670, rx = 110, rz = 95 }
local MARINA_BASIN = { x0 = 778, z0 = 596, x1 = 862, z1 = 742 }

local GOLF_PONDS = { -- ellipses, grid units
	{ cx = 620, cz = 160, rx = 28, rz = 16 },
	{ cx = 660, cz = 360, rx = 24, rz = 14 },
	{ cx = 545, cz = 300, rx = 20, rz = 12 },
	{ cx = 726, cz = 92,  rx = 18, rz = 12 },
	{ cx = 575, cz = 80,  rx = 16, rz = 10 },
}

local CHANNEL_WIDTH_STUDS = 38
local CHANNELS = { -- lagoon channel centerlines (grid polylines)
	{ { 145, 810 }, { 260, 800 }, { 360, 806 }, { 412, 796 } },
	{ { 145, 750 }, { 240, 742 }, { 330, 748 }, { 406, 741 } },
	{ { 145, 690 }, { 235, 682 }, { 320, 688 } },
	{ { 145, 630 }, { 240, 622 }, { 330, 628 }, { 400, 621 } },
	{ { 145, 570 }, { 235, 562 }, { 318, 567 } },
	{ { 158, 560 }, { 152, 700 }, { 163, 812 } },              -- west N-S connector
	{ { 299, 558 }, { 294, 652 }, { 304, 747 } },              -- mid N-S connector
	{ { 690, 598 }, { 731, 641 }, { 721, 701 }, { 741, 762 } },-- east of Willow Lake
	{ { 618, 762 }, { 659, 791 }, { 700, 802 }, { 745, 806 } },
	{ { 566, 762 }, { 557, 832 }, { 549, 902 } },              -- lake -> Indian Slough (lighthouse entrance)
	{ { 678, 668 }, { 770, 660 }, { 858, 656 } },              -- lake -> Old River / marina
	{ { 412, 796 }, { 480, 804 }, { 545, 808 } },              -- west maze -> entrance channel
	{ { 150, 500 }, { 240, 492 }, { 330, 498 } },              -- SW lagoon fingers
	{ { 150, 438 }, { 245, 430 }, { 335, 436 } },
	{ { 152, 372 }, { 242, 366 }, { 330, 371 } },
	{ { 158, 368 }, { 152, 438 }, { 156, 502 }, { 152, 560 } },-- SW west connector
}

-- Golf fairways (wide green ribbons, grid polylines) ------------------------------------------
local FAIRWAY_WIDTH_STUDS = 55
local FAIRWAYS = {
	{ { 500, 120 }, { 560, 142 }, { 622, 132 }, { 684, 152 } },
	{ { 516, 182 }, { 588, 192 }, { 658, 182 }, { 722, 202 } },
	{ { 500, 322 }, { 570, 342 }, { 640, 332 }, { 702, 352 } },
	{ { 560, 382 }, { 640, 402 }, { 712, 392 } },
	{ { 608, 62 },  { 678, 82 },  { 742, 72 } },
	{ { 742, 182 }, { 736, 262 }, { 731, 342 }, { 737, 422 } },
	{ { 489, 395 }, { 552, 412 }, { 614, 428 } },
}
local GREENS = { -- putting greens (grid point + radius in studs), each gets a flag
	{ 684, 152, 13 }, { 722, 202, 12 }, { 702, 352, 13 }, { 712, 392, 11 },
	{ 742, 72, 12 },  { 737, 422, 12 }, { 614, 428, 11 },
}
local BUNKERS = { -- sand bunkers (grid point + radius in studs)
	{ 585, 137, 9 }, { 640, 342, 8 }, { 700, 197, 8 }, { 540, 95, 7 },
	{ 744, 302, 7 }, { 600, 412, 7 }, { 660, 72, 7 },
}

-- Roads ---------------------------------------------------------------------------------------
-- kind: "spine" | "minor" | "court". Courts get a cul-de-sac bulb at their last waypoint.
local ROADS = {
	{ name = "Discovery Bay Blvd", kind = "spine", width = 28, houses = true,
		pts = { { 429, 850 }, { 425, 700 }, { 430, 530 }, { 471, 300 }, { 471, 230 } } },
	{ name = "Discovery Bay Blvd (south entry)", kind = "spine", width = 28, houses = false,
		pts = { { 471, 230 }, { 470, 150 }, { 468, 60 } } },
	{ name = "Willow Lake Rd", kind = "spine", width = 26, houses = true,
		pts = { { 336, 530 }, { 450, 545 }, { 571, 548 }, { 714, 530 }, { 771, 470 } } },
	{ name = "Clubhouse Dr", kind = "spine", width = 24, houses = true,
		pts = { { 471, 230 }, { 560, 215 }, { 607, 240 }, { 700, 300 }, { 760, 310 }, { 771, 300 } } },
	{ name = "Cherry Hills Dr", kind = "spine", width = 24, houses = true,
		pts = { { 771, 470 }, { 775, 360 }, { 768, 220 }, { 764, 120 } } },
	{ name = "St Andrews Dr", kind = "minor", width = 20, houses = true,
		pts = { { 468, 80 }, { 500, 88 }, { 514, 148 }, { 542, 200 }, { 560, 215 } } },
	{ name = "Sand Point Rd", kind = "minor", width = 20, houses = true,
		pts = { { 336, 532 }, { 250, 526 }, { 172, 522 } } },
	{ name = "Riverlake Rd", kind = "minor", width = 20, houses = true,
		pts = { { 425, 700 }, { 360, 666 }, { 295, 660 }, { 232, 656 } } },
	{ name = "Marina Rd", kind = "minor", width = 20, houses = false,
		pts = { { 771, 470 }, { 788, 530 }, { 800, 592 } } },

	-- Golf-core courts
	{ name = "Fairway Ct",    kind = "court", width = 16, houses = true, pts = { { 560, 215 }, { 554, 178 }, { 548, 148 } } },
	{ name = "Hampton Ct",    kind = "court", width = 16, houses = true, pts = { { 640, 261 }, { 650, 232 }, { 656, 206 } } },
	{ name = "Augusta Ct",    kind = "court", width = 16, houses = true, pts = { { 700, 300 }, { 707, 264 }, { 713, 236 } } },
	{ name = "Oakmont Ct",    kind = "court", width = 16, houses = true, pts = { { 768, 220 }, { 734, 212 }, { 708, 206 } } },
	{ name = "Gateway Ct",    kind = "court", width = 16, houses = true, pts = { { 690, 294 }, { 695, 312 }, { 698, 330 } } },
	{ name = "Greenfield Way",kind = "court", width = 16, houses = true, pts = { { 775, 360 }, { 741, 368 }, { 713, 376 } } },
	{ name = "Pinehurst Ct",  kind = "court", width = 16, houses = true, pts = { { 521, 222 }, { 528, 258 }, { 534, 286 } } },
	{ name = "Prestwick Dr",  kind = "court", width = 16, houses = true, pts = { { 772, 450 }, { 739, 446 }, { 711, 441 } } },
	{ name = "Wayfarer Ct",   kind = "court", width = 16, houses = true, pts = { { 471, 300 }, { 504, 296 }, { 529, 291 } } },
	{ name = "Azure Ct",      kind = "court", width = 16, houses = true, pts = { { 438, 483 }, { 464, 479 }, { 489, 475 } } },
	{ name = "St Andrews Ct", kind = "court", width = 16, houses = true, pts = { { 514, 148 }, { 488, 140 }, { 468, 132 } } },
	{ name = "Emerald Ct",    kind = "court", width = 16, houses = true, pts = { { 500, 88 }, { 527, 79 }, { 551, 72 } } },

	-- Lagoon-district courts
	{ name = "Starboard Dr",  kind = "court", width = 18, houses = true, pts = { { 336, 530 }, { 331, 585 }, { 336, 642 }, { 351, 700 } } },
	{ name = "Starboard Ct",  kind = "court", width = 16, houses = true, pts = { { 336, 642 }, { 303, 647 }, { 278, 651 } } },
	{ name = "Starfish Ct",   kind = "court", width = 16, houses = true, pts = { { 351, 700 }, { 330, 716 }, { 312, 728 } } },
	{ name = "Salmon Ct",     kind = "court", width = 16, houses = true, pts = { { 331, 585 }, { 297, 580 }, { 272, 576 } } },
	{ name = "Drakes Dr",     kind = "court", width = 18, houses = true, pts = { { 450, 545 }, { 444, 602 }, { 450, 662 }, { 464, 712 } } },
	{ name = "Drakes Ct",     kind = "court", width = 16, houses = true, pts = { { 444, 602 }, { 411, 607 }, { 386, 612 } } },
	{ name = "Marlin Dr",     kind = "court", width = 18, houses = true, pts = { { 714, 530 }, { 721, 586 }, { 716, 636 } } },
	{ name = "Marlin Pl",     kind = "court", width = 16, houses = true, pts = { { 716, 636 }, { 744, 644 }, { 766, 644 } } },
}

-- Landmarks -----------------------------------------------------------------------------------
local CLUBHOUSE_POS   = { 618, 272 } -- campus center, NE of the Clubhouse Dr bend (clear of the road)
local COMMUNITY_CENTER= { 382, 686 } -- north of Riverlake Rd, beside the plaza
local PLAZA           = { -- required-business commercial cluster, Discovery Bay Blvd & Riverlake Rd
	callahans = { 365, 708 },
	jiujitsu  = { 370, 690 },
	shell     = { 388, 715 },
	mart      = { 402, 712 },
	parking   = { 394, 698 },
}
local MARINA_SLIPS    = { 820, 690 }
local YACHT_CLUB      = { 802, 738 }
local BOAT_LAUNCH     = { 845, 740 }
local LIGHTHOUSE      = { 529, 880 }
local ENTRY_MONUMENT  = { 459, 66 }

-- House-placement exclusion regions (grid) ----------------------------------------------------
local EXCLUDE_RECTS = {
	{ x0 = 350, z0 = 668, x1 = 436, z1 = 746 }, -- commercial plaza + community center
	{ x0 = 588, z0 = 256, x1 = 656, z1 = 302 }, -- clubhouse campus: building, parking, pool, tennis
	{ x0 = 775, z0 = 560, x1 = 870, z1 = 760 }, -- marina + yacht club + launch
}
local EXCLUDE_CIRCLES = { -- {gx, gz, radius in grid units}
	{ 529, 880, 14 },  -- lighthouse
	{ 459, 66, 12 },   -- entry monument
}

----------------------------------------------------------------------------------------------
-- 3. CORE HELPERS
----------------------------------------------------------------------------------------------
local function S2G(studs) return studs / SCALE end -- studs -> grid units
local function G2S(grid)  return grid * SCALE end  -- grid units -> studs

local function gridToWorld(gx, gz, y)
	return Vector3.new(gx * SCALE, y, (1000 - gz) * SCALE)
end

-- grid-space direction -> world-space unit vector (z axis flips)
local function dirToWorld(dx, dz)
	local v = Vector3.new(dx, 0, -dz)
	if v.Magnitude < 1e-6 then return Vector3.new(0, 0, -1) end
	return v.Unit
end

local function dist2(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

-- distance (grid units) from point p to segment a-b
local function distToSegment(px, pz, ax, az, bx, bz)
	local abx, abz = bx - ax, bz - az
	local apx, apz = px - ax, pz - az
	local len2 = abx * abx + abz * abz
	local t = 0
	if len2 > 1e-9 then
		t = math.clamp((apx * abx + apz * abz) / len2, 0, 1)
	end
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt(dist2(px, pz, cx, cz))
end

local function distToPolyline(px, pz, pts)
	local best = math.huge
	for i = 1, #pts - 1 do
		local d = distToSegment(px, pz, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
		if d < best then best = d end
	end
	return best
end

local function polylineLength(pts) -- grid units
	local total = 0
	for i = 1, #pts - 1 do
		total = total + math.sqrt(dist2(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]))
	end
	return total
end

-- point at arc-length s (grid units) along polyline; returns gx, gz, dirx, dirz
local function pointAlong(pts, s)
	local acc = 0
	for i = 1, #pts - 1 do
		local ax, az = pts[i][1], pts[i][2]
		local bx, bz = pts[i + 1][1], pts[i + 1][2]
		local seg = math.sqrt(dist2(ax, az, bx, bz))
		if seg > 1e-9 and acc + seg >= s then
			local t = (s - acc) / seg
			return ax + (bx - ax) * t, az + (bz - az) * t, (bx - ax) / seg, (bz - az) / seg
		end
		acc = acc + seg
	end
	local n = #pts
	local ax, az = pts[n - 1][1], pts[n - 1][2]
	local bx, bz = pts[n][1], pts[n][2]
	local seg = math.max(math.sqrt(dist2(ax, az, bx, bz)), 1e-9)
	return bx, bz, (bx - ax) / seg, (bz - az) / seg
end

local function inEllipse(gx, gz, e, scaleFactor)
	local f = scaleFactor or 1
	local dx = (gx - e.cx) / (e.rx * f)
	local dz = (gz - e.cz) / (e.rz * f)
	return dx * dx + dz * dz <= 1
end

-- Instance factories --------------------------------------------------------------------------
local partCount = 0

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
	p.CastShadow = true
	p.Parent = parent
	partCount = partCount + 1
	return p
end

-- flat cylinder (axis rotated vertical): size = (thickness, diameter, diameter)
local function newDisc(parent, name, diameter, thickness, cframe, color, material, transparency)
	local p = newPart(parent, name, Vector3.new(thickness, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, transparency)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- vertical cylinder column: height h, diameter d, cframe at column CENTER
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
	partCount = partCount + 1
	return p
end

-- Gable roof: ridge runs along local X. cf = CFrame of the roof BASE center.
-- WedgePart's vertical face is on its +Z side, so each wedge's tall face meets at the ridge.
local function buildGableRoof(parent, cf, width, depth, height, color)
	local halfD = depth / 2
	newWedge(parent, "RoofA", Vector3.new(width, height, halfD),
		cf * CFrame.new(0, height / 2, -halfD / 2), color)
	newWedge(parent, "RoofB", Vector3.new(width, height, halfD),
		cf * CFrame.new(0, height / 2, halfD / 2) * CFrame.Angles(0, math.pi, 0), color)
end

-- SurfaceGui text sign on a part face
local function makeSign(part, face, text, bgColor, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bgColor or Color3.fromRGB(30, 40, 50)
	label.BackgroundTransparency = bgColor and 0 or 1
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return gui
end

local function newModel(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Zone filter ----------------------------------------------------------------------------------
local function zoneEnabled(gx, gz)
	if CONFIG.zonesToBuild == "all" then return true end
	for _, id in ipairs(CONFIG.zonesToBuild) do
		for _, z in ipairs(ZONES) do
			if z.id == id then
				local r = z.rect
				if gx >= r.x and gx <= r.x + r.w and gz >= r.z and gz <= r.z + r.d then
					return true
				end
			end
		end
	end
	return false
end

----------------------------------------------------------------------------------------------
-- 4. TERRAIN CLASSIFICATION
----------------------------------------------------------------------------------------------
local CHANNEL_HALF_GRID = S2G(CHANNEL_WIDTH_STUDS / 2)
local FAIRWAY_HALF_GRID = S2G(FAIRWAY_WIDTH_STUDS / 2)

-- returns "delta" | "lagoon" | "lake" | "pond" | "fairway" | "land"
local function terrainAt(gx, gz)
	if gz >= 900 then return "delta" end                          -- Indian Slough (north)
	if gx >= 860 and gz >= 120 then return "delta" end            -- Old River (east)
	if gx >= MARINA_BASIN.x0 and gx <= MARINA_BASIN.x1
		and gz >= MARINA_BASIN.z0 and gz <= MARINA_BASIN.z1 then
		return "lagoon"                                           -- marina basin
	end
	if inEllipse(gx, gz, WILLOW_LAKE) then return "lake" end
	for _, e in ipairs(GOLF_PONDS) do
		if inEllipse(gx, gz, e) then return "pond" end
	end
	for _, ch in ipairs(CHANNELS) do
		if distToPolyline(gx, gz, ch) <= CHANNEL_HALF_GRID then return "lagoon" end
	end
	for _, fw in ipairs(FAIRWAYS) do
		if distToPolyline(gx, gz, fw) <= FAIRWAY_HALF_GRID then return "fairway" end
	end
	return "land"
end

local function isWater(t)
	return t == "delta" or t == "lagoon" or t == "lake" or t == "pond"
end

local function inExclusion(gx, gz)
	for _, r in ipairs(EXCLUDE_RECTS) do
		if gx >= r.x0 and gx <= r.x1 and gz >= r.z0 and gz <= r.z1 then return true end
	end
	for _, c in ipairs(EXCLUDE_CIRCLES) do
		if dist2(gx, gz, c[1], c[2]) <= c[3] * c[3] then return true end
	end
	return false
end

----------------------------------------------------------------------------------------------
-- 5. SCAFFOLD (idempotent), FOLDERS, TEMPLATE KIT STORAGE
----------------------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local old = workspace:FindFirstChild("DiscoveryBay")
if old then old:Destroy() end
local oldKit = ReplicatedStorage:FindFirstChild("DiscoveryBayKit")
if oldKit then oldKit:Destroy() end

local root = Instance.new("Model")
root.Name = "DiscoveryBay"
root.Parent = workspace

local FOLDERS = {}
for _, fname in ipairs({ "Ground", "Water", "Roads", "Lots", "Houses", "Golf", "Docks", "Landmarks", "Props" }) do
	local f = Instance.new("Folder")
	f.Name = fname
	f.Parent = root
	FOLDERS[fname] = f
end

local KIT = Instance.new("Folder")
KIT.Name = "DiscoveryBayKit"
KIT.Parent = ReplicatedStorage

pcall(function()
	workspace.StreamingEnabled = true
end)

----------------------------------------------------------------------------------------------
-- 6. GROUND & WATER (rasterized cells, row-merged into strips)
----------------------------------------------------------------------------------------------
local GROUND_STYLE = {
	delta   = { top = Y_WATER, thick = 6, color = COL.delta,   material = Enum.Material.SmoothPlastic, transparency = 0.12 },
	lagoon  = { top = Y_WATER, thick = 6, color = COL.lagoon,  material = Enum.Material.SmoothPlastic, transparency = 0.12 },
	lake    = { top = Y_WATER, thick = 6, color = COL.lagoon,  material = Enum.Material.SmoothPlastic, transparency = 0.12 },
	pond    = { top = Y_WATER, thick = 6, color = COL.lagoon,  material = Enum.Material.SmoothPlastic, transparency = 0.12 },
	fairway = { top = Y_LAND,  thick = 8, color = COL.fairway, material = Enum.Material.Grass,         transparency = 0 },
	land    = { top = Y_LAND,  thick = 8, color = COL.land,    material = Enum.Material.Grass,         transparency = 0 },
}

local function buildGround()
	local step = CONFIG.groundCellGrid
	local waterFolder = FOLDERS.Water
	local groundFolder = FOLDERS.Ground
	for z0 = 0, 1000 - step, step do
		local cz = z0 + step / 2
		local runType = nil
		local runStart = 0
		local function flush(x0, x1)
			if not runType then return end
			local style = GROUND_STYLE[runType]
			local w = G2S(x1 - x0)
			local d = G2S(step)
			local cxWorld = G2S((x0 + x1) / 2)
			local czWorld = G2S(1000 - cz)
			local parent = isWater(runType) and waterFolder or groundFolder
			local p = newPart(parent, "G_" .. runType, Vector3.new(w, style.thick, d),
				CFrame.new(cxWorld, style.top - style.thick / 2, czWorld),
				style.color, style.material, style.transparency)
			p.CastShadow = false
		end
		for x0 = 0, 1000 - step, step do
			local t = terrainAt(x0 + step / 2, cz)
			if t ~= runType then
				flush(runStart, x0)
				runType = t
				runStart = x0
			end
		end
		flush(runStart, 1000)
	end
end

----------------------------------------------------------------------------------------------
-- 7. ROADS (+ cul-de-sac bulbs, street signs, streetlights)
----------------------------------------------------------------------------------------------
local ROAD_THICK = 0.45

-- Where a road segment crosses water, add an embankment part under the asphalt so the
-- crossing reads as a causeway instead of a slab floating 2 studs above the lagoon.
local function buildCauseways(model, road, ax, az, bx, bz)
	local segLen = math.sqrt(dist2(ax, az, bx, bz))
	if segLen < 1e-6 then return end
	local n = math.max(1, math.ceil(segLen / 2)) -- sample every ~2 grid units (8 studs)
	local wet = {}
	for k = 0, n do
		local t = k / n
		wet[k + 1] = isWater(terrainAt(ax + (bx - ax) * t, az + (bz - az) * t))
	end
	local k = 1
	while k <= n + 1 do
		if wet[k] then
			local j = k
			while j <= n and wet[j + 1] do j = j + 1 end
			local s0 = (k - 1) / n * segLen
			local s1 = (j - 1) / n * segLen
			if s1 - s0 > 0.5 then
				local tm = (s0 + s1) / 2 / segLen
				local mx, mz = ax + (bx - ax) * tm, az + (bz - az) * tm
				local mid = gridToWorld(mx, mz, 1.85 - 2.2) -- top 1.85 (just under the road), 4.4 thick
				local dir = dirToWorld(bx - ax, bz - az)
				newPart(model, "Causeway", Vector3.new(road.width + 3, 4.4, G2S(s1 - s0) + 10),
					CFrame.lookAt(mid, mid + dir), Color3.fromRGB(150, 145, 135), Enum.Material.Concrete)
			end
			k = j + 1
		else
			k = k + 1
		end
	end
end

local function buildRoadPolyline(folder, road)
	local model = newModel(folder, road.name)
	local w = road.width
	local pts = road.pts
	for i = 1, #pts - 1 do
		local ax, az = pts[i][1], pts[i][2]
		local bx, bz = pts[i + 1][1], pts[i + 1][2]
		local lenStuds = G2S(math.sqrt(dist2(ax, az, bx, bz)))
		if lenStuds > 0.5 then
			local mid = gridToWorld((ax + bx) / 2, (az + bz) / 2, Y_ROAD - ROAD_THICK / 2)
			local dir = dirToWorld(bx - ax, bz - az)
			local cf = CFrame.lookAt(mid, mid + dir)
			newPart(model, "Seg", Vector3.new(w, ROAD_THICK, lenStuds), cf, COL.road, Enum.Material.Asphalt)
			buildCauseways(model, road, ax, az, bx, bz)
		end
	end
	-- round the joints (and cap the ends)
	for i = 1, #pts do
		local isEnd = (i == #pts)
		local dia = w
		if road.kind == "court" and isEnd then
			dia = math.max(w * 2.4, 44) -- cul-de-sac bulb
		end
		local center = gridToWorld(pts[i][1], pts[i][2], Y_ROAD - ROAD_THICK / 2)
		newDisc(model, isEnd and dia > w and "CulDeSac" or "Joint", dia, ROAD_THICK,
			CFrame.new(center), COL.road, Enum.Material.Asphalt)
	end
	return model
end

local function buildStreetSign(folder, road)
	local pts = road.pts
	local ax, az = pts[1][1], pts[1][2]
	local bx, bz = pts[2][1], pts[2][2]
	local segLen = math.max(math.sqrt(dist2(ax, az, bx, bz)), 1e-6)
	local dx, dz = (bx - ax) / segLen, (bz - az) / segLen
	-- offset: a bit along the road, then to the left side
	local off = S2G(road.width / 2 + 6)
	local along = S2G(14)
	local gx = ax + dx * along + (-dz) * off
	local gz = az + dz * along + (dx) * off
	local base = gridToWorld(gx, gz, Y_LAND)
	local model = newModel(folder, "Sign " .. road.name)
	newPart(model, "Pole", Vector3.new(0.4, 8, 0.4), CFrame.new(base + Vector3.new(0, 4, 0)),
		Color3.fromRGB(80, 90, 95), Enum.Material.Metal)
	local dirW = dirToWorld(dx, dz)
	local boardCf = CFrame.lookAt(base + Vector3.new(0, 8.4, 0), base + Vector3.new(0, 8.4, 0) + dirW)
	local board = newPart(model, "Board", Vector3.new(0.25, 1.6, 7), boardCf,
		Color3.fromRGB(20, 90, 60), Enum.Material.SmoothPlastic)
	makeSign(board, Enum.NormalId.Left, road.name, Color3.fromRGB(20, 90, 60), Color3.new(1, 1, 1))
	makeSign(board, Enum.NormalId.Right, road.name, Color3.fromRGB(20, 90, 60), Color3.new(1, 1, 1))
end

local function buildStreetlight(folder, worldPos, dirW)
	local model = newModel(folder, "Streetlight")
	local poleC = worldPos + Vector3.new(0, 7, 0)
	newColumn(model, "Pole", 14, 0.7, CFrame.new(poleC), Color3.fromRGB(60, 65, 70), Enum.Material.Metal)
	local armDir = dirW
	local armC = worldPos + Vector3.new(0, 13.8, 0) + armDir * 2
	newPart(model, "Arm", Vector3.new(0.5, 0.5, 4.4), CFrame.lookAt(armC, armC + armDir),
		Color3.fromRGB(60, 65, 70), Enum.Material.Metal)
	local bulbPos = worldPos + Vector3.new(0, 13.4, 0) + armDir * 4
	local bulb = newBall(model, "Bulb", 1.2, CFrame.new(bulbPos), Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 235, 190)
	light.Parent = bulb
end

local function buildRoads()
	local folder = FOLDERS.Roads
	for _, road in ipairs(ROADS) do
		if road.kind == "court" and not zoneEnabled(road.pts[1][1], road.pts[1][2]) then
			-- court outside the enabled zones: skip
		else
			buildRoadPolyline(folder, road)
			if road.kind == "court" or road.kind == "minor" then
				buildStreetSign(folder, road)
			end
		end
	end
	-- streetlights along spines
	if CONFIG.build.props then
		local stepG = S2G(CONFIG.density.streetlightStepStuds)
		for _, road in ipairs(ROADS) do
			if road.kind == "spine" then
				local total = polylineLength(road.pts)
				local side = 1
				local s = stepG / 2
				while s < total do
					local gx, gz, dx, dz = pointAlong(road.pts, s)
					local offG = S2G(road.width / 2 + 3)
					local lx = gx + (-dz) * offG * side
					local lz = gz + (dx) * offG * side
					if terrainAt(lx, lz) == "land" or terrainAt(lx, lz) == "fairway" then
						-- the arm hangs back over the road, i.e. opposite the side offset
						buildStreetlight(FOLDERS.Props, gridToWorld(lx, lz, Y_LAND),
							dirToWorld(dz * side, -dx * side))
					end
					side = -side
					s = s + stepG
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------
-- 8. GOLF COURSE OVERLAYS (greens, bunkers, flags) — fairways/ponds are in the ground raster
----------------------------------------------------------------------------------------------
local function buildGolf()
	local folder = FOLDERS.Golf
	for i, g in ipairs(GREENS) do
		if zoneEnabled(g[1], g[2]) then
			local center = gridToWorld(g[1], g[2], Y_GREEN - 0.15)
			newDisc(folder, "Green" .. i, g[3] * 2, 0.3, CFrame.new(center), COL.green, Enum.Material.Grass)
			-- pin flag
			local base = gridToWorld(g[1], g[2], Y_GREEN)
			newPart(folder, "FlagPole", Vector3.new(0.25, 9, 0.25), CFrame.new(base + Vector3.new(0, 4.5, 0)),
				Color3.fromRGB(230, 230, 230), Enum.Material.Metal)
			newPart(folder, "Flag", Vector3.new(0.15, 1.5, 2.4), CFrame.new(base + Vector3.new(0, 8, 1.25)),
				Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic)
		end
	end
	for i, b in ipairs(BUNKERS) do
		if zoneEnabled(b[1], b[2]) then
			local center = gridToWorld(b[1], b[2], Y_BUNKER - 0.15)
			newDisc(folder, "Bunker" .. i, b[3] * 2, 0.3, CFrame.new(center), COL.bunker, Enum.Material.Sand)
		end
	end
end

----------------------------------------------------------------------------------------------
-- 9. TEMPLATE KIT (houses, dock, boats, trees, car) — built once, cloned everywhere
----------------------------------------------------------------------------------------------
-- Every template is built at the origin, front facing -Z, ground contact at Y=0,
-- with an invisible Root part as PrimaryPart so Model:PivotTo() lands it exactly.

local function addRoot(model, name)
	local rootPart = Instance.new("Part")
	rootPart.Name = "Root"
	rootPart.Size = Vector3.new(1, 0.2, 1)
	rootPart.CFrame = CFrame.new(0, 0.1, 0)
	rootPart.Anchored = true
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Parent = model
	model.PrimaryPart = rootPart
	model.Name = name
	return model
end

local function houseCommon(model, w, d, h, wallColor, roofColor)
	-- slab
	newPart(model, "Slab", Vector3.new(w + 4, 0.5, d + 4), CFrame.new(0, 0.25, 0),
		Color3.fromRGB(180, 175, 165), Enum.Material.Concrete)
	-- body
	newPart(model, "Body", Vector3.new(w, h, d), CFrame.new(0, 0.5 + h / 2, 0),
		wallColor, Enum.Material.SmoothPlastic)
	-- gable roof, ridge along X
	buildGableRoof(model, CFrame.new(0, 0.5 + h, 0), w + 1.5, d + 1.5, math.max(4, d * 0.16), roofColor)
	-- door on the front (-Z)
	newPart(model, "Door", Vector3.new(3.4, 6.6, 0.3), CFrame.new(w * 0.12, 0.5 + 3.3, -d / 2 - 0.12),
		Color3.fromRGB(70, 50, 40), Enum.Material.Wood)
end

local function buildHouseTemplate1Story()
	local model = Instance.new("Model")
	local w, d, h = 40, 30, 9
	houseCommon(model, w, d, h, COL.walls[1], COL.roofs[1])
	-- windows
	for _, off in ipairs({ -w * 0.28, w * 0.32 }) do
		newPart(model, "Window", Vector3.new(5, 3.4, 0.25), CFrame.new(off, 0.5 + 5, -d / 2 - 0.1),
			Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
	end
	-- garage door
	newPart(model, "Garage", Vector3.new(9, 6.4, 0.3), CFrame.new(-w * 0.3, 0.5 + 3.2, -d / 2 - 0.12),
		Color3.fromRGB(220, 215, 205), Enum.Material.SmoothPlastic)
	return addRoot(model, "house_1story")
end

local function buildHouseTemplate2Story()
	local model = Instance.new("Model")
	local w, d, h = 44, 32, 17
	houseCommon(model, w, d, h, COL.walls[2], COL.roofs[2])
	for _, y in ipairs({ 5, 12.5 }) do
		for _, off in ipairs({ -w * 0.3, 0, w * 0.3 }) do
			newPart(model, "Window", Vector3.new(4.6, 3.2, 0.25), CFrame.new(off, 0.5 + y, -d / 2 - 0.1),
				Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
		end
	end
	return addRoot(model, "house_2story")
end

local function buildHouseTemplateEstate()
	local model = Instance.new("Model")
	local w, d = 60, 40
	-- main mass (rear)
	newPart(model, "Slab", Vector3.new(w + 4, 0.5, d + 4), CFrame.new(0, 0.25, 0),
		Color3.fromRGB(180, 175, 165), Enum.Material.Concrete)
	local mainH = 16
	newPart(model, "Main", Vector3.new(w, mainH, 24), CFrame.new(0, 0.5 + mainH / 2, 6),
		COL.walls[4], Enum.Material.SmoothPlastic)
	buildGableRoof(model, CFrame.new(0, 0.5 + mainH, 6), w + 1.5, 25.5, 5, COL.roofs[4])
	-- front wing
	local wingH = 10
	newPart(model, "Wing", Vector3.new(26, wingH, 14), CFrame.new(-13, 0.5 + wingH / 2, -11),
		COL.walls[4], Enum.Material.SmoothPlastic)
	buildGableRoof(model, CFrame.new(-13, 0.5 + wingH, -11), 27.5, 15.5, 4, COL.roofs[4])
	-- entry portico
	for _, px in ipairs({ 6, 16 }) do
		newColumn(model, "Column", 9, 1.2, CFrame.new(px, 0.5 + 4.5, -16), Color3.fromRGB(235, 232, 225), Enum.Material.SmoothPlastic)
	end
	newPart(model, "PorchRoof", Vector3.new(14, 1, 8), CFrame.new(11, 10, -16),
		COL.roofs[4], Enum.Material.SmoothPlastic)
	newPart(model, "Door", Vector3.new(4, 7, 0.3), CFrame.new(11, 0.5 + 3.5, -18.2),
		Color3.fromRGB(60, 45, 35), Enum.Material.Wood)
	for _, off in ipairs({ -24, -3, 24 }) do
		newPart(model, "Window", Vector3.new(5.5, 4, 0.25), CFrame.new(off, 0.5 + 9, -6 - 0.1 - (off < 0 and 12 or 0)),
			Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
	end
	return addRoot(model, "house_estate")
end

local function buildDockTemplate()
	local model = Instance.new("Model")
	-- deck extends into -Z (toward water), origin at the shore end.
	-- Deck top sits at ~2.2 world (above the land top at 2) so the shore end never
	-- disappears inside the rasterized land strips.
	newPart(model, "Deck", Vector3.new(6, 0.8, 20), CFrame.new(0, 1.8, -10), COL.wood, Enum.Material.WoodPlanks)
	for _, corner in ipairs({ { -2.5, -1.5 }, { 2.5, -1.5 }, { -2.5, -18.5 }, { 2.5, -18.5 } }) do
		newPart(model, "Post", Vector3.new(0.8, 5, 0.8), CFrame.new(corner[1], -0.4, corner[2]),
			COL.wood, Enum.Material.Wood)
	end
	return addRoot(model, "dock")
end

local function buildBoatTemplateRunabout()
	local model = Instance.new("Model")
	-- floats at water level: hull base ~Y=0 when pivoted at Y_WATER + 0.4
	newPart(model, "Hull", Vector3.new(4.4, 1.8, 11), CFrame.new(0, 0.9, 0.5),
		Color3.fromRGB(240, 238, 228), Enum.Material.SmoothPlastic)
	-- unrotated: the wedge's vertical +Z face butts against the hull, slope descends to the bow tip
	newWedge(model, "Bow", Vector3.new(4.4, 1.8, 3.6), CFrame.new(0, 0.9, -6.8),
		Color3.fromRGB(240, 238, 228), Enum.Material.SmoothPlastic)
	newPart(model, "Windshield", Vector3.new(3.8, 1.1, 0.25), CFrame.new(0, 2.3, -2.4) * CFrame.Angles(math.rad(-20), 0, 0),
		Color3.fromRGB(160, 210, 230), Enum.Material.Glass)
	newPart(model, "Seats", Vector3.new(3.6, 0.8, 4), CFrame.new(0, 1.9, 2),
		Color3.fromRGB(120, 60, 50), Enum.Material.Fabric)
	newPart(model, "Motor", Vector3.new(1.4, 1.6, 0.9), CFrame.new(0, 1.6, 6.3),
		Color3.fromRGB(40, 40, 45), Enum.Material.SmoothPlastic)
	return addRoot(model, "boat_runabout")
end

local function buildBoatTemplateSailboat()
	local model = Instance.new("Model")
	newPart(model, "Hull", Vector3.new(3.6, 1.6, 12), CFrame.new(0, 0.8, 0),
		Color3.fromRGB(225, 230, 235), Enum.Material.SmoothPlastic)
	newWedge(model, "Bow", Vector3.new(3.6, 1.6, 3), CFrame.new(0, 0.8, -7.5),
		Color3.fromRGB(225, 230, 235), Enum.Material.SmoothPlastic)
	newPart(model, "Cabin", Vector3.new(3, 1.2, 4), CFrame.new(0, 2, 1),
		Color3.fromRGB(200, 200, 205), Enum.Material.SmoothPlastic)
	newColumn(model, "Mast", 15, 0.35, CFrame.new(0, 9, -1), Color3.fromRGB(180, 180, 185), Enum.Material.Metal)
	newPart(model, "Sail", Vector3.new(0.15, 10, 5), CFrame.new(0, 9.5, 1.7),
		Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic)
	return addRoot(model, "boat_sailboat")
end

local function buildTreeTemplateOak()
	local model = Instance.new("Model")
	newColumn(model, "Trunk", 8, 1.8, CFrame.new(0, 4, 0), Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
	newBall(model, "Leaves1", 10, CFrame.new(0, 10.5, 0), Color3.fromRGB(70, 120, 60), Enum.Material.Grass)
	newBall(model, "Leaves2", 7, CFrame.new(2.4, 8.6, 1.4), Color3.fromRGB(85, 135, 70), Enum.Material.Grass)
	return addRoot(model, "tree_oak")
end

local function buildTreeTemplatePalm()
	local model = Instance.new("Model")
	newColumn(model, "Trunk", 17, 1.3, CFrame.new(0, 8.5, 0) * CFrame.Angles(0, 0, math.rad(3)),
		Color3.fromRGB(140, 115, 85), Enum.Material.Wood)
	for i = 0, 5 do
		local yaw = math.rad(i * 60)
		local cf = CFrame.new(0.4, 17, 0) * CFrame.Angles(0, yaw, 0)
			* CFrame.new(0, 0, -3.4) * CFrame.Angles(math.rad(-28), 0, 0)
		newPart(model, "Frond", Vector3.new(1.4, 0.15, 7.5), cf, Color3.fromRGB(75, 140, 70), Enum.Material.Grass)
	end
	return addRoot(model, "tree_palm")
end

local function buildCarTemplate()
	local model = Instance.new("Model")
	newPart(model, "Body", Vector3.new(6.2, 2.2, 14.5), CFrame.new(0, 2.1, 0),
		Color3.fromRGB(160, 160, 165), Enum.Material.SmoothPlastic)
	newPart(model, "Cabin", Vector3.new(5.6, 1.9, 6.5), CFrame.new(0, 4.1, 0.6),
		Color3.fromRGB(120, 150, 165), Enum.Material.Glass)
	for _, o in ipairs({ { -3, -4.3 }, { 3, -4.3 }, { -3, 4.3 }, { 3, 4.3 } }) do
		-- cylinder length runs along local X = the axle direction; no rotation needed
		local wheel = newPart(model, "Wheel", Vector3.new(0.9, 2.4, 2.4),
			CFrame.new(o[1], 1.2, o[2]),
			Color3.fromRGB(30, 30, 30), Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	return addRoot(model, "car")
end

local TEMPLATES = {}
local function buildKit()
	TEMPLATES.houses = { buildHouseTemplate1Story(), buildHouseTemplate2Story(), buildHouseTemplateEstate() }
	TEMPLATES.dock = buildDockTemplate()
	TEMPLATES.boats = { buildBoatTemplateRunabout(), buildBoatTemplateSailboat() }
	TEMPLATES.trees = { buildTreeTemplateOak(), buildTreeTemplatePalm() }
	TEMPLATES.car = buildCarTemplate()
	for _, list in ipairs({ TEMPLATES.houses, TEMPLATES.boats, TEMPLATES.trees, { TEMPLATES.dock }, { TEMPLATES.car } }) do
		for _, t in ipairs(list) do
			t.Parent = KIT
		end
	end
end

-- clone a template and pivot it: pos = world position of ground contact, lookAtWorld = face target
local function placeClone(template, parent, pos, lookAtWorld, name)
	local clone = template:Clone()
	if name then clone.Name = name end
	local target = Vector3.new(lookAtWorld.X, pos.Y, lookAtWorld.Z)
	if (target - pos).Magnitude < 0.01 then target = pos + Vector3.new(0, 0, -1) end
	clone:PivotTo(CFrame.lookAt(pos, target))
	clone.Parent = parent
	return clone
end

-- recolor the clone's walls/roof for variety
local function varyHouse(houseModel)
	local wall = COL.walls[rng:NextInteger(1, #COL.walls)]
	local roof = COL.roofs[rng:NextInteger(1, #COL.roofs)]
	for _, part in ipairs(houseModel:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Body" or part.Name == "Main" or part.Name == "Wing" then
				part.Color = wall
			elseif part.Name == "RoofA" or part.Name == "RoofB" or part.Name == "PorchRoof" then
				part.Color = roof
			end
		end
	end
end

----------------------------------------------------------------------------------------------
-- 10. LOTS, HOUSES, DOCKS
----------------------------------------------------------------------------------------------
local placedHouses = {} -- {gx, gz} of every placed house, for min-separation checks

local function houseSiteOk(gx, gz, ownRoadIndex)
	if not zoneEnabled(gx, gz) then return false end
	if inExclusion(gx, gz) then return false end
	-- pad center + two front corners must be dry land
	local t = terrainAt(gx, gz)
	if t ~= "land" then return false end
	local cornerOff = S2G(24)
	if terrainAt(gx - cornerOff, gz) ~= "land" or terrainAt(gx + cornerOff, gz) ~= "land" then
		return false
	end
	-- keep clear of every other road corridor
	for ri, r in ipairs(ROADS) do
		if ri ~= ownRoadIndex then
			if distToPolyline(gx, gz, r.pts) < S2G(r.width / 2 + 30) then return false end
		end
	end
	-- cul-de-sac bulbs
	for _, r in ipairs(ROADS) do
		if r.kind == "court" then
			local e = r.pts[#r.pts]
			if dist2(gx, gz, e[1], e[2]) < S2G(36) * S2G(36) then return false end
		end
	end
	-- min separation from already-placed houses
	local minSep = S2G(46)
	for _, h in ipairs(placedHouses) do
		if dist2(gx, gz, h[1], h[2]) < minSep * minSep then return false end
	end
	return true
end

-- march outward from (gx,gz) along (nx,nz); returns water-edge grid point or nil
local function findWaterEdge(gx, gz, nx, nz, maxGrid)
	local step = 2
	local d = step
	while d <= maxGrid do
		local px, pz = gx + nx * d, gz + nz * d
		if isWater(terrainAt(px, pz)) then
			return gx + nx * (d - step / 2), gz + nz * (d - step / 2)
		end
		d = d + step
	end
	return nil
end

local function buildHousesAlongRoad(roadIndex, road)
	if not road.houses then return end
	local spacingStuds = road.kind == "court" and CONFIG.density.courtHouseSpacingStuds
		or CONFIG.density.houseSpacingStuds
	local spacingG = S2G(spacingStuds)
	local setbackG = S2G(road.width / 2 + 26) -- road edge -> pad center
	local total = polylineLength(road.pts)
	local s = spacingG * 0.6
	while s < total - spacingG * 0.3 do
		local gx, gz, dx, dz = pointAlong(road.pts, s)
		for _, side in ipairs({ 1, -1 }) do
			local nx, nz = -dz * side, dx * side -- outward normal for this side
			local hx, hz = gx + nx * setbackG, gz + nz * setbackG
			if houseSiteOk(hx, hz, roadIndex) then
				table.insert(placedHouses, { hx, hz })
				-- lot pad
				local padCf = CFrame.lookAt(gridToWorld(hx, hz, Y_PAD - 0.2),
					gridToWorld(hx - nx, hz - nz, Y_PAD - 0.2))
				newPart(FOLDERS.Lots, "LotPad", Vector3.new(60, 0.4, 40), padCf, COL.pad, Enum.Material.Grass)
				-- waterfront?
				local wx, wz = findWaterEdge(hx, hz, nx, nz, S2G(130))
				local template = TEMPLATES.houses[rng:NextInteger(1, #TEMPLATES.houses)]
				local jitter = math.rad(rng:NextNumber(-4, 4))
				local facePoint
				if wx then
					facePoint = gridToWorld(wx, wz, Y_LAND) -- waterfront homes face the water
				else
					facePoint = gridToWorld(gx, gz, Y_LAND) -- street homes face the road
				end
				local house = placeClone(template, FOLDERS.Houses, gridToWorld(hx, hz, Y_LAND), facePoint)
				house:PivotTo(house:GetPivot() * CFrame.Angles(0, jitter, 0))
				varyHouse(house)
				-- dock + boat on the water edge (nudged ~6 studs seaward so the shore end
				-- clears the rasterized land strips, which can deviate from the analytic edge)
				if wx and CONFIG.build.docks then
					local dockPos = gridToWorld(wx + nx * S2G(6), wz + nz * S2G(6), Y_WATER)
					local outward = gridToWorld(wx + nx * S2G(26), wz + nz * S2G(26), Y_WATER)
					local dock = placeClone(TEMPLATES.dock, FOLDERS.Docks,
						Vector3.new(dockPos.X, 0, dockPos.Z), outward)
					if rng:NextNumber() < CONFIG.density.dockBoatChance then
						local boat = TEMPLATES.boats[rng:NextInteger(1, #TEMPLATES.boats)]
						-- moor the boat beside the dock, nose to shore
						local sideDir = Vector3.new(-outward.Z + dockPos.Z, 0, outward.X - dockPos.X).Unit
						local moor = Vector3.new(dockPos.X, 0.4, dockPos.Z)
							+ (outward - dockPos).Unit * 14 + sideDir * 6
						placeClone(boat, FOLDERS.Docks, moor, Vector3.new(dockPos.X, 0.4, dockPos.Z))
					end
				end
			end
		end
		s = s + spacingG
	end
end

local function buildHouses()
	for ri, road in ipairs(ROADS) do
		buildHousesAlongRoad(ri, road)
	end
end

----------------------------------------------------------------------------------------------
-- 11. LANDMARKS
----------------------------------------------------------------------------------------------
local function buildParkingLot(parent, centerGrid, wStuds, dStuds, headingGrid, stripes)
	local center = gridToWorld(centerGrid[1], centerGrid[2], Y_PARKING - 0.2)
	local faceTo = gridToWorld(headingGrid[1], headingGrid[2], Y_PARKING - 0.2)
	local cf = CFrame.lookAt(center, faceTo)
	newPart(parent, "Parking", Vector3.new(wStuds, 0.4, dStuds), cf, COL.parking, Enum.Material.Asphalt)
	local n = stripes or 8
	for i = 1, n do
		local x = -wStuds / 2 + i * (wStuds / (n + 1))
		newPart(parent, "Stripe", Vector3.new(0.5, 0.1, dStuds * 0.4),
			cf * CFrame.new(x, 0.26, -dStuds * 0.2), COL.stripe, Enum.Material.SmoothPlastic)
	end
	return cf
end

local function buildClubhouse()
	-- The campus is laid out on world axes NE of the Clubhouse Dr bend: building at
	-- {618,272} facing south toward the road, parking NE, pool W, tennis NW.
	-- Everything stays inside EXCLUDE_RECTS[2] and clear of every road corridor.
	local m = newModel(FOLDERS.Landmarks, "Clubhouse")
	local gx, gz = CLUBHOUSE_POS[1], CLUBHOUSE_POS[2]
	local base = gridToWorld(gx, gz, Y_LAND)
	-- front (local -Z) faces grid-south (toward the road), i.e. world +Z
	local cf = CFrame.new(base) * CFrame.Angles(0, math.pi, 0)
	-- main two-story mass, 70 x 45 studs
	newPart(m, "Main", Vector3.new(70, 22, 45), cf * CFrame.new(0, 11, 0), Color3.fromRGB(226, 218, 200), Enum.Material.Brick)
	buildGableRoof(m, cf * CFrame.new(0, 22, 0), 72, 47, 7, COL.roofs[1])
	-- entrance portico
	for _, px in ipairs({ -10, 10 }) do
		newColumn(m, "Column", 12, 1.6, cf * CFrame.new(px, 6, -26), Color3.fromRGB(240, 236, 228), Enum.Material.SmoothPlastic)
	end
	newPart(m, "Portico", Vector3.new(26, 1.4, 10), cf * CFrame.new(0, 12.6, -26.5), COL.roofs[1], Enum.Material.SmoothPlastic)
	newPart(m, "Doors", Vector3.new(8, 8, 0.4), cf * CFrame.new(0, 4, -22.6), Color3.fromRGB(90, 65, 45), Enum.Material.Wood)
	-- window bands
	for _, y in ipairs({ 6, 16 }) do
		newPart(m, "Windows", Vector3.new(60, 3.6, 0.3), cf * CFrame.new(0, y, -22.4), Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
		newPart(m, "WindowsB", Vector3.new(60, 3.6, 0.3), cf * CFrame.new(0, y, 22.4), Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
	end
	-- sign over the entrance
	local signBoard = newPart(m, "SignBoard", Vector3.new(34, 3.4, 0.5), cf * CFrame.new(0, 19.5, -22.9),
		Color3.fromRGB(30, 45, 60), Enum.Material.SmoothPlastic)
	makeSign(signBoard, Enum.NormalId.Front, "DISCOVERY BAY GOLF & COUNTRY CLUB",
		Color3.fromRGB(30, 45, 60), Color3.fromRGB(240, 230, 200))
	-- parking lot NE of the building (~95 x 60), stripes facing the building
	local parkCf = buildParkingLot(m, { 636, 288 }, 95, 60, { 636, 274 }, 10)
	-- a few parked cars
	for i = 1, 6 do
		local px = -40 + i * 13
		placeClone(TEMPLATES.car, m, (parkCf * CFrame.new(px, 0.2, -8)).Position,
			(parkCf * CFrame.new(px, 0.2, 10)).Position)
	end
	-- pool west of the building (axis-aligned)
	local poolC = gridToWorld(601, 272, Y_LAND)
	newPart(m, "PoolDeck", Vector3.new(34, 0.4, 60), CFrame.new(poolC + Vector3.new(0, 0.1, 0)),
		Color3.fromRGB(210, 205, 190), Enum.Material.Concrete)
	newPart(m, "PoolWater", Vector3.new(24, 0.3, 46), CFrame.new(poolC + Vector3.new(0, 0.25, 0)),
		Color3.fromRGB(80, 180, 220), Enum.Material.Glass, 0.25)
	-- two tennis courts NW of the pool deck (clear of the deck footprint)
	for i = 0, 1 do
		local courtC = gridToWorld(598 + i * 7.5, 289, Y_LAND)
		newPart(m, "TennisCourt", Vector3.new(27, 0.3, 55), CFrame.new(courtC + Vector3.new(0, 0.15, 0)),
			Color3.fromRGB(45, 100, 70), Enum.Material.SmoothPlastic)
		newPart(m, "TennisNet", Vector3.new(24, 2.6, 0.2), CFrame.new(courtC + Vector3.new(0, 1.6, 0)),
			Color3.fromRGB(30, 30, 30), Enum.Material.Fabric, 0.35)
		newPart(m, "TennisLine", Vector3.new(24, 0.1, 0.4), CFrame.new(courtC + Vector3.new(0, 0.32, -24)),
			COL.stripe, Enum.Material.SmoothPlastic)
		newPart(m, "TennisLine2", Vector3.new(24, 0.1, 0.4), CFrame.new(courtC + Vector3.new(0, 0.32, 24)),
			COL.stripe, Enum.Material.SmoothPlastic)
	end
end

local function buildCommunityCenter()
	local m = newModel(FOLDERS.Landmarks, "Community Center")
	local base = gridToWorld(COMMUNITY_CENTER[1], COMMUNITY_CENTER[2], Y_LAND)
	-- front door faces south-east toward Riverlake Rd
	local cf = CFrame.lookAt(base, gridToWorld(COMMUNITY_CENTER[1] + 4, COMMUNITY_CENTER[2] - 10, Y_LAND))
	newPart(m, "Body", Vector3.new(26, 12, 20), cf * CFrame.new(0, 6, 0), Color3.fromRGB(215, 205, 185), Enum.Material.Brick)
	buildGableRoof(m, cf * CFrame.new(0, 12, 0), 27.5, 21.5, 4.5, COL.roofs[2])
	newPart(m, "Doors", Vector3.new(6, 7, 0.4), cf * CFrame.new(0, 3.5, -10.2), Color3.fromRGB(90, 65, 45), Enum.Material.Wood)
	local board = newPart(m, "SignBoard", Vector3.new(18, 2.4, 0.4), cf * CFrame.new(0, 10.4, -10.3),
		Color3.fromRGB(30, 45, 60), Enum.Material.SmoothPlastic)
	makeSign(board, Enum.NormalId.Front, "COMMUNITY CENTER", Color3.fromRGB(30, 45, 60), Color3.new(1, 1, 1))
end

-- generic flat-roof storefront with a sign; returns its CFrame
local function buildStorefront(parent, name, gridPos, wStuds, dStuds, hStuds, wallColor, signBg, signFg, faceGrid)
	local m = newModel(parent, name)
	local base = gridToWorld(gridPos[1], gridPos[2], Y_LAND)
	local cf = CFrame.lookAt(base, gridToWorld(faceGrid[1], faceGrid[2], Y_LAND))
	newPart(m, "Body", Vector3.new(wStuds, hStuds, dStuds), cf * CFrame.new(0, hStuds / 2, 0), wallColor, Enum.Material.Brick)
	newPart(m, "Parapet", Vector3.new(wStuds + 1, 1.4, dStuds + 1), cf * CFrame.new(0, hStuds + 0.7, 0),
		wallColor, Enum.Material.Concrete)
	newPart(m, "Storefront", Vector3.new(wStuds * 0.7, hStuds * 0.5, 0.3),
		cf * CFrame.new(0, hStuds * 0.3, -dStuds / 2 - 0.12), Color3.fromRGB(140, 195, 215), Enum.Material.Glass, 0.3)
	newPart(m, "Awning", Vector3.new(wStuds * 0.8, 0.4, 4), cf * CFrame.new(0, hStuds * 0.62, -dStuds / 2 - 2),
		signBg, Enum.Material.Fabric)
	local board = newPart(m, "SignBoard", Vector3.new(wStuds * 0.86, 2.8, 0.4),
		cf * CFrame.new(0, hStuds - 1.8, -dStuds / 2 - 0.25), signBg, Enum.Material.SmoothPlastic)
	makeSign(board, Enum.NormalId.Front, name, signBg, signFg)
	return m, cf
end

local function buildPlaza()
	local plazaFolder = newModel(FOLDERS.Landmarks, "Commercial Plaza (Discovery Bay Blvd)")

	-- Callahan's Coffee and Cones (REQUIRED)
	local callahans = buildStorefront(plazaFolder, "Callahan's Coffee and Cones",
		PLAZA.callahans, 30, 24, 12, Color3.fromRGB(232, 220, 200),
		Color3.fromRGB(150, 75, 105), Color3.fromRGB(255, 245, 235), { PLAZA.parking[1], PLAZA.parking[2] })
	-- giant ice-cream prop by the door
	local icBase = gridToWorld(PLAZA.callahans[1] + S2G(12), PLAZA.callahans[2] - S2G(10), Y_LAND)
	newColumn(plazaFolder, "ConePole", 4.5, 1.8, CFrame.new(icBase + Vector3.new(0, 2.25, 0)),
		Color3.fromRGB(190, 140, 90), Enum.Material.Wood)
	newBall(plazaFolder, "Scoop", 3, CFrame.new(icBase + Vector3.new(0, 5.6, 0)),
		Color3.fromRGB(245, 170, 190), Enum.Material.SmoothPlastic)

	-- Discovery Bay Jiu Jitsu (REQUIRED)
	buildStorefront(plazaFolder, "Discovery Bay Jiu Jitsu",
		PLAZA.jiujitsu, 34, 26, 14, Color3.fromRGB(200, 200, 205),
		Color3.fromRGB(25, 30, 40), Color3.fromRGB(230, 60, 60), { PLAZA.parking[1], PLAZA.parking[2] })

	-- Shell Gas Station (REQUIRED): kiosk + canopy + pumps + road sign
	local shell = newModel(plazaFolder, "Shell Gas Station")
	local sBase = gridToWorld(PLAZA.shell[1], PLAZA.shell[2], Y_LAND)
	local sCf = CFrame.lookAt(sBase, gridToWorld(425, PLAZA.shell[2], Y_LAND)) -- forecourt faces the Blvd (east)
	-- kiosk
	newPart(shell, "Kiosk", Vector3.new(20, 10, 14), sCf * CFrame.new(0, 5, 12), Color3.fromRGB(235, 232, 225), Enum.Material.Brick)
	newPart(shell, "KioskRoof", Vector3.new(21.5, 1, 15.5), sCf * CFrame.new(0, 10.5, 12), Color3.fromRGB(180, 40, 35), Enum.Material.SmoothPlastic)
	local kioskSign = newPart(shell, "KioskSign", Vector3.new(16, 2.4, 0.4), sCf * CFrame.new(0, 8.6, 4.7),
		Color3.fromRGB(250, 205, 30), Enum.Material.SmoothPlastic)
	makeSign(kioskSign, Enum.NormalId.Front, "Shell", Color3.fromRGB(250, 205, 30), Color3.fromRGB(200, 30, 30))
	-- forecourt + canopy on 4 columns
	newPart(shell, "Forecourt", Vector3.new(40, 0.3, 30), sCf * CFrame.new(0, 0.15, -10), Color3.fromRGB(120, 120, 120), Enum.Material.Concrete)
	for _, o in ipairs({ { -15, -20 }, { 15, -20 }, { -15, 0 }, { 15, 0 } }) do
		newColumn(shell, "CanopyColumn", 15, 1.4, sCf * CFrame.new(o[1], 7.5, o[2]), Color3.fromRGB(230, 228, 222), Enum.Material.Metal)
	end
	local canopy = newPart(shell, "Canopy", Vector3.new(40, 1.2, 28), sCf * CFrame.new(0, 15.6, -10),
		Color3.fromRGB(250, 205, 30), Enum.Material.SmoothPlastic)
	newPart(shell, "CanopyBand", Vector3.new(40.5, 1.6, 28.5), sCf * CFrame.new(0, 14.6, -10),
		Color3.fromRGB(200, 30, 30), Enum.Material.SmoothPlastic)
	-- two pump islands
	for _, oz in ipairs({ -16, -4 }) do
		newPart(shell, "PumpIsland", Vector3.new(12, 0.6, 4), sCf * CFrame.new(0, 0.6, oz), Color3.fromRGB(200, 200, 200), Enum.Material.Concrete)
		for _, ox in ipairs({ -3.5, 3.5 }) do
			newPart(shell, "Pump", Vector3.new(1.8, 4.2, 1.2), sCf * CFrame.new(ox, 3, oz), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		end
	end
	-- tall road sign at the Blvd frontage
	local signBase = gridToWorld(408, 722, Y_LAND)
	newColumn(shell, "RoadSignPole", 20, 1.2, CFrame.new(signBase + Vector3.new(0, 10, 0)), Color3.fromRGB(190, 190, 190), Enum.Material.Metal)
	local roadSign = newPart(shell, "RoadSign", Vector3.new(8, 9, 0.8), CFrame.new(signBase + Vector3.new(0, 24.5, 0)),
		Color3.fromRGB(250, 205, 30), Enum.Material.SmoothPlastic)
	makeSign(roadSign, Enum.NormalId.Front, "Shell", Color3.fromRGB(250, 205, 30), Color3.fromRGB(200, 30, 30))
	makeSign(roadSign, Enum.NormalId.Back, "Shell", Color3.fromRGB(250, 205, 30), Color3.fromRGB(200, 30, 30))

	-- Convenience Mart (REQUIRED) — attached to the Shell kiosk side
	buildStorefront(plazaFolder, "Convenience Mart",
		PLAZA.mart, 34, 26, 12, Color3.fromRGB(228, 224, 214),
		Color3.fromRGB(30, 110, 60), Color3.fromRGB(255, 255, 255), { PLAZA.parking[1], PLAZA.parking[2] - 10 })

	-- shared plaza parking + a few cars
	local parkCf = buildParkingLot(plazaFolder, PLAZA.parking, 80, 40, { PLAZA.parking[1], PLAZA.parking[2] + 10 }, 8)
	for i = 1, 4 do
		placeClone(TEMPLATES.car, plazaFolder, (parkCf * CFrame.new(-30 + i * 12, 0.2, -6)).Position,
			(parkCf * CFrame.new(-30 + i * 12, 0.2, 10)).Position)
	end
end

local function buildMarina()
	local m = newModel(FOLDERS.Landmarks, "Marina")
	-- 5 covered slip rows over the basin. Rows run E-W, which is world X, so plain
	-- axis-aligned CFrames are correct here (no rotation needed).
	local rowLen, rowW = 96, 16
	for i = 0, 4 do
		local gz = MARINA_SLIPS[2] - 14 + i * 7
		local center = gridToWorld(MARINA_SLIPS[1], gz, Y_WATER)
		local row = newModel(m, "SlipRow" .. (i + 1))
		newPart(row, "Walkway", Vector3.new(rowLen, 0.8, 3.5), CFrame.new(center + Vector3.new(0, 1.2, 0)),
			COL.wood, Enum.Material.WoodPlanks)
		for _, ox in ipairs({ -rowLen / 2 + 6, -rowLen / 6, rowLen / 6, rowLen / 2 - 6 }) do
			newPart(row, "Post", Vector3.new(1, 12, 1), CFrame.new(center + Vector3.new(ox, 4, 0)),
				Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
		end
		newPart(row, "Roof", Vector3.new(rowLen, 0.8, rowW), CFrame.new(center + Vector3.new(0, 10.4, 0)),
			Color3.fromRGB(205, 198, 168), Enum.Material.Metal)
		-- moored boats under the roof, nose toward the walkway.
		-- Runabouts only: the sailboat's 15-stud mast would pierce the slip roof.
		for b = 1, 2 do
			local ox = rng:NextNumber(-rowLen / 2 + 12, rowLen / 2 - 12)
			local oz = b == 1 and -6 or 6
			local pos = center + Vector3.new(ox, 0.4, oz)
			placeClone(TEMPLATES.boats[1], row, pos, pos + Vector3.new(0, 0, oz > 0 and -10 or 10))
		end
	end
	-- yacht club building on the north shore
	local yc = newModel(m, "Discovery Bay Yacht Club")
	local ycBase = gridToWorld(YACHT_CLUB[1], YACHT_CLUB[2], Y_LAND)
	local ycCf = CFrame.lookAt(ycBase, gridToWorld(YACHT_CLUB[1], YACHT_CLUB[2] - 12, Y_LAND))
	newPart(yc, "Body", Vector3.new(30, 11, 20), ycCf * CFrame.new(0, 5.5, 0), Color3.fromRGB(210, 220, 228), Enum.Material.WoodPlanks)
	buildGableRoof(yc, ycCf * CFrame.new(0, 11, 0), 31.5, 21.5, 4.5, COL.roofs[4])
	local ycSign = newPart(yc, "SignBoard", Vector3.new(22, 2.4, 0.4), ycCf * CFrame.new(0, 9.2, -10.3),
		Color3.fromRGB(25, 55, 90), Enum.Material.SmoothPlastic)
	makeSign(ycSign, Enum.NormalId.Front, "DISCOVERY BAY YACHT CLUB", Color3.fromRGB(25, 55, 90), Color3.new(1, 1, 1))
	-- boat launch ramp on the north-east shore, sloping down into the basin
	local rampTop = gridToWorld(BOAT_LAUNCH[1], BOAT_LAUNCH[2], 0)
	local rampCf = CFrame.lookAt(rampTop, gridToWorld(BOAT_LAUNCH[1], BOAT_LAUNCH[2] - 14, 0))
	-- unrotated: tall +Z face on the shore side (top flush with land at Y=2), slope descends into the basin
	newWedge(m, "LaunchRamp", Vector3.new(24, 3.2, 30), rampCf * CFrame.new(0, 0.4, -6),
		Color3.fromRGB(184, 176, 154), Enum.Material.Concrete)
	newPart(m, "LaunchDock", Vector3.new(4, 0.8, 26), rampCf * CFrame.new(15, 1.2, -8), COL.wood, Enum.Material.WoodPlanks)
	-- marina parking on the south shore
	buildParkingLot(m, { 800, 580 }, 70, 36, { 800, 570 }, 7)
end

local function buildLighthouse()
	local m = newModel(FOLDERS.Landmarks, "Discovery Bay Lighthouse")
	local base = gridToWorld(LIGHTHOUSE[1], LIGHTHOUSE[2], Y_LAND)
	newDisc(m, "Base", 16, 2, CFrame.new(base + Vector3.new(0, 1, 0)), Color3.fromRGB(200, 195, 185), Enum.Material.Concrete)
	local bands = { Color3.new(1, 1, 1), Color3.fromRGB(200, 45, 40), Color3.new(1, 1, 1), Color3.fromRGB(200, 45, 40) }
	for i, color in ipairs(bands) do
		local dia = 9.5 - i * 0.9
		newColumn(m, "Band" .. i, 7, dia, CFrame.new(base + Vector3.new(0, 2 + 7 * (i - 0.5), 0)), color, Enum.Material.SmoothPlastic)
	end
	local topY = 2 + 28
	newDisc(m, "Gallery", 9, 1, CFrame.new(base + Vector3.new(0, topY + 0.5, 0)), Color3.fromRGB(50, 55, 60), Enum.Material.Metal)
	newColumn(m, "LampRoom", 4.5, 5.4, CFrame.new(base + Vector3.new(0, topY + 3.2, 0)), Color3.fromRGB(180, 220, 235), Enum.Material.Glass)
	local lamp = newBall(m, "Lamp", 2.6, CFrame.new(base + Vector3.new(0, topY + 3.2, 0)), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Range = 60 -- engine maximum; larger values silently clamp
	light.Brightness = 5
	light.Color = Color3.fromRGB(255, 245, 200)
	light.Parent = lamp
	newColumn(m, "Cap", 1.4, 6.4, CFrame.new(base + Vector3.new(0, topY + 6, 0)), Color3.fromRGB(200, 45, 40), Enum.Material.SmoothPlastic)
	newPart(m, "Hut", Vector3.new(10, 7, 8), CFrame.new(base + Vector3.new(11, 3.5, 3)), Color3.new(1, 1, 1), Enum.Material.WoodPlanks)
	buildGableRoof(m, CFrame.new(base + Vector3.new(11, 7, 3)), 11, 9, 3, Color3.fromRGB(200, 45, 40))
end

local function buildEntryMonument()
	local m = newModel(FOLDERS.Landmarks, "Entry Monument")
	local base = gridToWorld(ENTRY_MONUMENT[1], ENTRY_MONUMENT[2], Y_LAND)
	local cf = CFrame.lookAt(base, gridToWorld(ENTRY_MONUMENT[1] + 6, ENTRY_MONUMENT[2] - 10, Y_LAND))
	newPart(m, "Wall", Vector3.new(30, 5, 2.5), cf * CFrame.new(0, 2.5, 0), Color3.fromRGB(190, 178, 155), Enum.Material.Brick)
	newPart(m, "WallCap", Vector3.new(31, 0.8, 3.2), cf * CFrame.new(0, 5.3, 0), Color3.fromRGB(160, 150, 130), Enum.Material.Concrete)
	local board = newPart(m, "SignBoard", Vector3.new(24, 3.4, 0.5), cf * CFrame.new(0, 3.2, -1.6),
		Color3.fromRGB(30, 45, 60), Enum.Material.SmoothPlastic)
	makeSign(board, Enum.NormalId.Front, "DISCOVERY BAY", Color3.fromRGB(30, 45, 60), Color3.fromRGB(240, 230, 200))
	newPart(m, "Bed", Vector3.new(34, 0.5, 8), cf * CFrame.new(0, 0.25, -4), Color3.fromRGB(120, 90, 60), Enum.Material.Ground)
	for _, ox in ipairs({ -14, 14 }) do
		placeClone(TEMPLATES.trees[2], m, (cf * CFrame.new(ox, 0, 1.5)).Position, (cf * CFrame.new(ox, 0, -10)).Position)
	end
end

local function buildLandmarks()
	if zoneEnabled(CLUBHOUSE_POS[1], CLUBHOUSE_POS[2]) then buildClubhouse() end
	if zoneEnabled(COMMUNITY_CENTER[1], COMMUNITY_CENTER[2]) then buildCommunityCenter() end
	if zoneEnabled(PLAZA.shell[1], PLAZA.shell[2]) then buildPlaza() end
	if zoneEnabled(MARINA_SLIPS[1], MARINA_SLIPS[2]) then buildMarina() end
	if zoneEnabled(LIGHTHOUSE[1], LIGHTHOUSE[2]) then buildLighthouse() end
	if zoneEnabled(ENTRY_MONUMENT[1], ENTRY_MONUMENT[2]) then buildEntryMonument() end
end

----------------------------------------------------------------------------------------------
-- 12. PROPS (trees, moored lake boats)
----------------------------------------------------------------------------------------------
local function treeSiteOk(gx, gz)
	if gx < 25 or gx > 975 or gz < 25 or gz > 975 then return false end
	if inExclusion(gx, gz) then return false end
	if terrainAt(gx, gz) ~= "land" then return false end
	for _, r in ipairs(ROADS) do
		if distToPolyline(gx, gz, r.pts) < S2G(r.width / 2 + 10) then return false end
	end
	local minSep = S2G(38)
	for _, h in ipairs(placedHouses) do
		if dist2(gx, gz, h[1], h[2]) < minSep * minSep then return false end
	end
	return true
end

local function buildProps()
	local folder = FOLDERS.Props
	-- scattered neighborhood trees (palms + oaks)
	local placed, attempts = 0, 0
	while placed < CONFIG.density.treeCount and attempts < CONFIG.density.treeCount * 12 do
		attempts = attempts + 1
		local gx = rng:NextNumber(30, 970)
		local gz = rng:NextNumber(30, 970)
		if treeSiteOk(gx, gz) then
			local template = TEMPLATES.trees[rng:NextInteger(1, #TEMPLATES.trees)]
			local pos = gridToWorld(gx, gz, Y_LAND)
			local face = pos + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 10
			placeClone(template, folder, pos, face)
			placed = placed + 1
		end
	end
	-- tree clusters along fairway edges
	for _, fw in ipairs(FAIRWAYS) do
		local total = polylineLength(fw)
		local s = S2G(40)
		while s < total do
			local gx, gz, dx, dz = pointAlong(fw, s)
			for _, side in ipairs({ 1, -1 }) do
				if rng:NextNumber() < 0.5 then
					local off = FAIRWAY_HALF_GRID + S2G(10 + rng:NextNumber(0, 14))
					local tx = gx + (-dz) * off * side
					local tz = gz + (dx) * off * side
					if treeSiteOk(tx, tz) then
						local template = TEMPLATES.trees[rng:NextInteger(1, #TEMPLATES.trees)]
						placeClone(template, folder, gridToWorld(tx, tz, Y_LAND),
							gridToWorld(gx, gz, Y_LAND))
					end
				end
			end
			s = s + S2G(70)
		end
	end
	-- boats moored out on Willow Lake
	for i = 1, 6 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(0.25, 0.8)
		local gx = WILLOW_LAKE.cx + math.cos(ang) * WILLOW_LAKE.rx * rr
		local gz = WILLOW_LAKE.cz + math.sin(ang) * WILLOW_LAKE.rz * rr
		local boat = TEMPLATES.boats[rng:NextInteger(1, #TEMPLATES.boats)]
		local pos = gridToWorld(gx, gz, 0.4)
		placeClone(boat, folder, pos, pos + Vector3.new(math.cos(ang + 1), 0, math.sin(ang + 1)) * 10)
	end
end

----------------------------------------------------------------------------------------------
-- 13. BUILD
----------------------------------------------------------------------------------------------
print("[DiscoveryBay] building… scale=" .. SCALE .. " studs/grid, seed=" .. CONFIG.seed)
local t0 = os.clock()

buildKit()
if CONFIG.build.ground then buildGround() end
if CONFIG.build.roads then buildRoads() end
if CONFIG.build.golf then buildGolf() end
if CONFIG.build.houses then buildHouses() end
if CONFIG.build.landmarks then buildLandmarks() end
if CONFIG.build.props then buildProps() end

local houseCount = #FOLDERS.Houses:GetChildren()
local dockCount = 0
for _, c in ipairs(FOLDERS.Docks:GetChildren()) do
	if c.Name == "dock" then dockCount = dockCount + 1 end
end

print(string.format("[DiscoveryBay] done in %.1fs — %d parts, %d houses, %d docks.",
	os.clock() - t0, partCount, houseCount, dockCount))
print("[DiscoveryBay] required businesses built: Callahan's Coffee and Cones, " ..
	"Discovery Bay Jiu Jitsu, Shell Gas Station, Convenience Mart (Landmarks > Commercial Plaza).")
print("[DiscoveryBay] StreamingEnabled=" .. tostring(workspace.StreamingEnabled) ..
	". Everything is anchored. Re-run any time — the previous build is replaced.")
