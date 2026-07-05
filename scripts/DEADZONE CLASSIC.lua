loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/Bypasses/DEADZONE%20CLASSIC.lua"))()


local env = (getgenv and getgenv()) or _G

if env.DeadZone and type(env.DeadZone.Unload) == "function" then
	pcall(env.DeadZone.Unload)
end

local DeadZone = {
	Connections = {},
	Esp     = {},
	Tracked = {},
	Cars    = {},
	Dot     = nil,
	Gui     = nil,
	Flags = {
		PlayerEsp     = false,
		ZombieEsp     = false,
		Chams         = false,
		Box           = false,
		Name          = false,
		Distance      = false,
		Health        = false,
		Lines         = false,
		CarEsp        = false,
		Dot           = false,
		DisableCursor = false,
		SilentSpeed   = false,
		SilentSpeedMul = 1,
		Speed         = false,
		SpeedValue    = 16,
		Aim           = false,
		ToggleAim     = false,
		Wallcheck     = false,
		AimFov        = 100,
		AimPart       = "Head",
		AimBindKey    = "LeftControl",
		PlayerCheck   = false,
	},
}
env.DeadZone = DeadZone

local function track(conn)
	table.insert(DeadZone.Connections, conn)
	return conn
end

function DeadZone.Unload()
	for k in pairs(DeadZone.Flags) do DeadZone.Flags[k] = false end
	for _, conn in ipairs(DeadZone.Connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(DeadZone.Connections)
	if DeadZone.Tracked then
		for _, t in pairs(DeadZone.Tracked) do
			for _, c in ipairs(t.conns) do pcall(function() c:Disconnect() end) end
		end
		table.clear(DeadZone.Tracked)
	end
	if DeadZone.Esp then
		for _, data in pairs(DeadZone.Esp) do
			if data.highlight  then pcall(function() data.highlight:Destroy() end) end
			if data.box        then pcall(function() data.box:Remove() end) end
			if data.healthBar  then pcall(function() data.healthBar:Remove() end) end
			if data.healthBg   then pcall(function() data.healthBg:Remove() end) end
			if data.line       then pcall(function() data.line:Remove() end) end
			if data.texts then
				for _, t in pairs(data.texts) do pcall(function() t:Remove() end) end
			end
		end
		table.clear(DeadZone.Esp)
	end
	if DeadZone.Cars then
		for _, t in pairs(DeadZone.Cars) do
			for _, c in ipairs(t.conns or {}) do pcall(function() c:Disconnect() end) end
		end
		table.clear(DeadZone.Cars)
	end
	if DeadZone.Dot and DeadZone.Dot.gui then
		pcall(function() DeadZone.Dot.gui:Destroy() end)
		DeadZone.Dot = nil
	end
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
		local cur = pg and pg:FindFirstChild("Cursor")
		if cur then cur.Enabled = true end
	end)
	if DeadZone.Gui then
		pcall(function() if DeadZone.Gui.Close then DeadZone.Gui:Close() end end)
		pcall(function() if DeadZone.Gui.Destroy then DeadZone.Gui:Destroy() end end)
		DeadZone.Gui = nil
	end
end

local ok, ReGui = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Dear-ReGui/refs/heads/main/ReGui.lua"))()
end)
if not ok then
	warn("[Dead Zone] Can't load ReGui:", ReGui)
	return
end

local prefabs = game:GetObjects("rbxassetid://" .. ReGui.PrefabsId)[1]
ReGui:Init({ Prefabs = prefabs })

local RunService  = game:GetService("RunService")
local Players     = game:GetService("Players")
local UserInput   = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local COLORS = {
	Player = Color3.fromRGB(255, 255, 255),
	Zombie = Color3.fromRGB(60, 255, 60),
	Car    = Color3.fromRGB(255, 255, 0),
	Dot    = Color3.fromRGB(255, 0, 0),
}

-- Fixed axis-aligned world box sizes per entity kind so rotating the model
-- (or the camera) never changes the projected box shape/size.
local BOX_SIZE = {
	Player = Vector3.new(4, 6, 4),
	Zombie = Vector3.new(4, 6, 4),
	Car    = Vector3.new(14, 6, 24),
}

local function getHiddenParent()
	local okh, hui = pcall(function() return gethui() end)
	if okh and hui then return hui end
	local cg = game:GetService("CoreGui")
	if cloneref then cg = cloneref(cg) end
	return cg
end

local function protect(inst)
	pcall(function()
		if syn and syn.protect_gui then syn.protect_gui(inst)
		elseif protect_gui then protect_gui(inst) end
	end)
end

local function isZombie(model)
	local parent = model.Parent
	return (parent ~= nil and parent.Name == "__zombies")
		or model:FindFirstChild("__zombie") ~= nil
		or model.Name == "__zombie"
end

local function isSelf(model)
	if not LocalPlayer then return false end
	if LocalPlayer.Character == model then return true end
	local plr = Players:GetPlayerFromCharacter(model)
	return plr == LocalPlayer
end

local function classify(model)
	if isZombie(model) then
		return DeadZone.Flags.ZombieEsp, "Zombie"
	else
		return DeadZone.Flags.PlayerEsp, "Player"
	end
end

local function getSelfRoot()
	local char = LocalPlayer and LocalPlayer.Character
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart"))
end

local function getModelRoot(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

-- Per-frame cache: Humanoid -> car it's currently seated in. Rebuilt once at
-- the top of each RenderStepped tick, so ESP for players riding vehicles costs
-- O(1) lookup per model instead of O(cars * parts_per_car) per model per frame
-- (that quadratic scan was the source of the Player-ESP lag).
local frameCarByHum = {}

local function rebuildCarSeatIndex()
	table.clear(frameCarByHum)
	local cars = workspace:FindFirstChild("__cars")
	if not cars then return end
	for _, car in ipairs(cars:GetChildren()) do
		for _, part in ipairs(car:GetDescendants()) do
			if part:IsA("VehicleSeat") or part:IsA("Seat") then
				local occ = part.Occupant
				if occ then frameCarByHum[occ] = car end
			end
		end
	end
end

local function findPlayerCar(model)
	if not model then return nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	return frameCarByHum[hum]
end

-- Resolve the world-space position an ESP box should orbit around, per kind.
-- For characters: prefer the car they're seated in (fixes stale ESP when the
-- player drives away), then HRP, then any part. For cars: PrimaryPart.
local function getEffectivePos(model, kind)
	if kind == "Car" then
		local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		return pp and pp.Position or nil
	end
	local car = findPlayerCar(model)
	if car and car.PrimaryPart then return car.PrimaryPart.Position end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.Position end
	local any = model:FindFirstChildWhichIsA("BasePart")
	return any and any.Position or nil
end

local function getCursorGui()
	local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
	return pg and pg:FindFirstChild("Cursor") or nil
end

local function restoreCursor()
	local cur = getCursorGui()
	if cur and not cur.Enabled then cur.Enabled = true end
end

local function ensureDot()
	if DeadZone.Dot and DeadZone.Dot.gui and DeadZone.Dot.gui.Parent then return end
	local gui = Instance.new("ScreenGui")
	gui.Name           = ""
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn   = false
	gui.DisplayOrder   = 9999
	protect(gui)
	gui.Parent = getHiddenParent()

	local frame = Instance.new("Frame")
	frame.Name             = ""
	frame.AnchorPoint      = Vector2.new(0.5, 0.5)
	frame.Size             = UDim2.fromOffset(4, 4)
	frame.BackgroundColor3 = COLORS.Dot
	frame.BorderSizePixel  = 0
	frame.Active           = false
	frame.Visible          = false
	frame.ZIndex           = 10
	frame.Parent = gui

	DeadZone.Dot = { gui = gui, frame = frame }
end

local function removeEsp(model)
	local data = DeadZone.Esp[model]
	if not data then return end
	if data.highlight  then pcall(function() data.highlight:Destroy() end) end
	if data.box        then pcall(function() data.box:Remove() end) end
	if data.healthBar  then pcall(function() data.healthBar:Remove() end) end
	if data.healthBg   then pcall(function() data.healthBg:Remove() end) end
	if data.line       then pcall(function() data.line:Remove() end) end
	if data.texts then
		for _, t in pairs(data.texts) do pcall(function() t:Remove() end) end
	end
	DeadZone.Esp[model] = nil
end

local function ensureText(texts, key, enabled)
	if enabled then
		if not texts[key] then
			local ok2, d = pcall(function()
				local t = Drawing.new("Text")
				t.Size    = 14
				t.Center  = true
				t.Outline = true
				t.Visible = false
				return t
			end)
			if ok2 then texts[key] = d end
		end
	elseif texts[key] then
		pcall(function() texts[key]:Remove() end)
		texts[key] = nil
	end
end

local function ensureEsp(model, kind)
	local data = DeadZone.Esp[model]
	if not data then
		data = { kind = kind, texts = {} }
		DeadZone.Esp[model] = data
	end
	data.kind = kind
	data.texts = data.texts or {}
	local color = COLORS[kind]

	if DeadZone.Flags.Chams then
		if not data.highlight then
			local hl = Instance.new("Highlight")
			hl.Name                = ""
			hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillColor           = color
			hl.OutlineColor        = color
			hl.FillTransparency    = 0.5
			hl.OutlineTransparency = 0
			hl.Adornee = model
			protect(hl)
			hl.Parent  = getHiddenParent()
			data.highlight = hl
		elseif data.highlight.FillColor ~= color then
			data.highlight.FillColor    = color
			data.highlight.OutlineColor = color
		end
	elseif data.highlight then
		pcall(function() data.highlight:Destroy() end)
		data.highlight = nil
	end

	if DeadZone.Flags.Box then
		if not data.box then
			local ok2, box = pcall(function()
				local b = Drawing.new("Square")
				b.Thickness = 2
				b.Filled    = false
				b.Color     = color
				b.Visible   = false
				return b
			end)
			if ok2 then data.box = box end
		elseif data.box.Color ~= color then
			data.box.Color = color
		end
	elseif data.box then
		pcall(function() data.box:Remove() end)
		data.box = nil
	end

	ensureText(data.texts, "name", DeadZone.Flags.Name)
	ensureText(data.texts, "dist", DeadZone.Flags.Distance)

	-- Health bar (vertical strip on the left edge of the box) replaces the old
	-- "HP: N" text row. Two Squares: a dim background and the filled foreground.
	local wantBar = DeadZone.Flags.Health and (kind == "Player" or kind == "Zombie")
	if wantBar then
		if not data.healthBg then
			local ok2, bg = pcall(function()
				local s = Drawing.new("Square")
				s.Thickness = 1
				s.Filled    = true
				s.Color     = Color3.fromRGB(0, 0, 0)
				s.Transparency = 0.5
				s.Visible   = false
				return s
			end)
			if ok2 then data.healthBg = bg end
		end
		if not data.healthBar then
			local ok2, bar = pcall(function()
				local s = Drawing.new("Square")
				s.Thickness = 1
				s.Filled    = true
				s.Color     = Color3.fromRGB(60, 255, 60)
				s.Visible   = false
				return s
			end)
			if ok2 then data.healthBar = bar end
		end
	else
		if data.healthBg  then pcall(function() data.healthBg:Remove() end);  data.healthBg  = nil end
		if data.healthBar then pcall(function() data.healthBar:Remove() end); data.healthBar = nil end
	end

	-- Tracer line from screen center to entity.
	if DeadZone.Flags.Lines then
		if not data.line then
			local ok2, ln = pcall(function()
				local l = Drawing.new("Line")
				l.Thickness = 1
				l.Color     = color
				l.Visible   = false
				return l
			end)
			if ok2 then data.line = ln end
		elseif data.line.Color ~= color then
			data.line.Color = color
		end
	elseif data.line then
		pcall(function() data.line:Remove() end)
		data.line = nil
	end
end

-- Build screen-space bounds from a fixed axis-aligned world box centered on the
-- effective position. This is deliberately not tied to model orientation, so
-- turning the character/car does not change the projected box shape.
local function getScreenBounds(model, kind)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local center = getEffectivePos(model, kind)
	if not center then return nil end
	local size = BOX_SIZE[kind] or BOX_SIZE.Player
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local corners = {
		center + Vector3.new( hx,  hy,  hz),
		center + Vector3.new(-hx,  hy,  hz),
		center + Vector3.new( hx, -hy,  hz),
		center + Vector3.new(-hx, -hy,  hz),
		center + Vector3.new( hx,  hy, -hz),
		center + Vector3.new(-hx,  hy, -hz),
		center + Vector3.new( hx, -hy, -hz),
		center + Vector3.new(-hx, -hy, -hz),
	}
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local onScreen = false
	for _, world in ipairs(corners) do
		local sp = cam:WorldToViewportPoint(world)
		if sp.Z > 0 then
			onScreen = true
			minX, minY = math.min(minX, sp.X), math.min(minY, sp.Y)
			maxX, maxY = math.max(maxX, sp.X), math.max(maxY, sp.Y)
		end
	end
	if not onScreen then return nil end
	return minX, minY, maxX, maxY
end

local function updateBox(model, data, kind)
	local minX, minY, maxX, maxY = getScreenBounds(model, kind)
	-- Cache on the data table so updateLabels can reuse the projected bounds
	-- without projecting all 8 world corners a second time this frame.
	data._bMinX, data._bMinY = minX, minY
	data._bMaxX, data._bMaxY = maxX, maxY
	if not minX then
		if data.box       then data.box.Visible = false end
		if data.healthBg  then data.healthBg.Visible = false end
		if data.healthBar then data.healthBar.Visible = false end
		return
	end
	if data.box then
		data.box.Size     = Vector2.new(maxX - minX, maxY - minY)
		data.box.Position = Vector2.new(minX, minY)
		data.box.Visible  = true
	end

	-- Health bar rides on the left edge of the box regardless of Box visibility.
	if data.healthBg and data.healthBar then
		local hum = data._hum
		local frac
		if hum then
			local maxhp = hum.MaxHealth
			frac = (maxhp > 0) and math.clamp(hum.Health / maxhp, 0, 1) or 0
		end
		if frac then
			local boxH = maxY - minY
			local barW = 3
			local gap  = 3
			data.healthBg.Size     = Vector2.new(barW, boxH)
			data.healthBg.Position = Vector2.new(minX - gap - barW, minY)
			data.healthBg.Visible  = true
			local filledH = math.max(1, math.floor(boxH * frac))
			data.healthBar.Size     = Vector2.new(barW, filledH)
			data.healthBar.Position = Vector2.new(minX - gap - barW, minY + (boxH - filledH))
			data.healthBar.Color    = Color3.fromRGB(
				255 - math.floor(195 * frac),
				60  + math.floor(195 * frac),
				60)
			data.healthBar.Visible  = true
		else
			data.healthBg.Visible  = false
			data.healthBar.Visible = false
		end
	end
end

local function updateLabels(model, data, kind)
	local texts = data.texts
	local minX, minY = data._bMinX, data._bMinY
	local maxX, maxY = data._bMaxX, data._bMaxY
	local onScreen = minX ~= nil
	local cx = onScreen and (minX + maxX) / 2 or 0
	local color = COLORS[kind] or COLORS.Player

	if texts and texts.name then
		if onScreen and DeadZone.Flags.Name then
			texts.name.Text     = model.Name
			texts.name.Color    = color
			texts.name.Position = Vector2.new(cx, minY - 16)
			texts.name.Visible  = true
		else
			texts.name.Visible = false
		end
	end

	if texts and texts.dist then
		if onScreen and DeadZone.Flags.Distance then
			local d = 0
			local root = getSelfRoot()
			local target = getEffectivePos(model, kind)
			if root and target then d = math.floor((target - root.Position).Magnitude) end
			texts.dist.Text     = tostring(d) .. "m"
			texts.dist.Color    = Color3.fromRGB(255, 255, 255)
			texts.dist.Position = Vector2.new(cx, (onScreen and maxY or 0) + 2)
			texts.dist.Visible  = true
		else
			texts.dist.Visible = false
		end
	end

	-- Tracer line from viewport center to the bottom-center of the box.
	if data.line then
		if onScreen and DeadZone.Flags.Lines then
			local cam = workspace.CurrentCamera
			local vp  = cam and cam.ViewportSize or Vector2.new(0, 0)
			data.line.From    = Vector2.new(vp.X / 2, vp.Y / 2)
			data.line.To      = Vector2.new(cx, (minY + maxY) / 2)
			data.line.Color   = color
			data.line.Visible = true
		else
			data.line.Visible = false
		end
	end
end

local function untrack(model)
	local t = DeadZone.Tracked[model]
	if t then
		for _, c in ipairs(t.conns) do pcall(function() c:Disconnect() end) end
	end
	DeadZone.Tracked[model] = nil
	removeEsp(model)
end

local function trackHumanoid(hum)
	if not hum:IsA("Humanoid") then return end
	local model = hum.Parent
	if not (model and model:IsA("Model")) then return end
	if isSelf(model) or DeadZone.Tracked[model] then return end

	local t = { hum = hum, conns = {} }
	DeadZone.Tracked[model] = t
	table.insert(t.conns, hum.AncestryChanged:Connect(function(_, parent)
		if not parent then untrack(model) end
	end))
	table.insert(t.conns, hum.Died:Connect(function()
		untrack(model)
	end))
end

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Humanoid") then trackHumanoid(d) end
end
track(workspace.DescendantAdded:Connect(trackHumanoid))

-- Car tracking: any Model directly under workspace.__cars becomes a car target.
local function untrackCar(car)
	DeadZone.Cars[car] = nil
	removeEsp(car)
end

local function trackCar(car)
	if not (car and car:IsA("Model")) then return end
	if DeadZone.Cars[car] then return end
	local t = { conns = {} }
	DeadZone.Cars[car] = t
	table.insert(t.conns, car.AncestryChanged:Connect(function(_, parent)
		if not parent then untrackCar(car) end
	end))
end

do
	local carsFolder = workspace:FindFirstChild("__cars")
	if carsFolder then
		for _, c in ipairs(carsFolder:GetChildren()) do trackCar(c) end
		track(carsFolder.ChildAdded:Connect(trackCar))
		track(carsFolder.ChildRemoved:Connect(untrackCar))
	else
		track(workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "__cars" then
				for _, c in ipairs(ch:GetChildren()) do trackCar(c) end
				track(ch.ChildAdded:Connect(trackCar))
				track(ch.ChildRemoved:Connect(untrackCar))
			end
		end))
	end
end

ensureDot()

track(RunService.RenderStepped:Connect(function()
	rebuildCarSeatIndex()

	for model, t in pairs(DeadZone.Tracked) do
		if not model.Parent or isSelf(model) then
			untrack(model)
		else
			local show, kind = classify(model)
			if show then
				ensureEsp(model, kind)
				local data = DeadZone.Esp[model]
				if data then
					data._hum = t and t.hum or data._hum
					updateBox(model, data, kind)
					updateLabels(model, data, kind)
				end
			else
				removeEsp(model)
			end
		end
	end

	for car, _ in pairs(DeadZone.Cars) do
		if not car.Parent then
			untrackCar(car)
		elseif DeadZone.Flags.CarEsp then
			ensureEsp(car, "Car")
			local data = DeadZone.Esp[car]
			if data then
				updateBox(car, data, "Car")
				updateLabels(car, data, "Car")
			end
		else
			removeEsp(car)
		end
	end

	if DeadZone.Dot and DeadZone.Dot.frame then
		if DeadZone.Flags.Dot then
			local m = UserInput:GetMouseLocation()
			DeadZone.Dot.frame.Position = UDim2.fromOffset(m.X, m.Y)
			DeadZone.Dot.frame.Visible  = true
		elseif DeadZone.Dot.frame.Visible then
			DeadZone.Dot.frame.Visible = false
		end
	end

	if DeadZone.Flags.DisableCursor then
		local cur = getCursorGui()
		if cur and cur.Enabled then cur.Enabled = false end
	end
end))

-- =========================================================
-- Keybinds persistence: DeadZone_KeyBinds.txt
-- Format per line: <BindName>=<KeyCode.Name or UserInputType.Name>
-- Example:
--   AimBind=LeftControl
--   SpeedBind=J
-- =========================================================
local KEYBINDS_FILE = "DeadZone_KeyBinds.txt"

local function fsRead(path)
	local ok, res = pcall(function()
		return (isfile and isfile(path)) and readfile(path) or nil
	end)
	return ok and res or nil
end
local function fsWrite(path, content)
	pcall(function() if writefile then writefile(path, content) end end)
end

local function parseKeybindsFile(txt)
	local out = {}
	if not txt then return out end
	for line in string.gmatch(txt, "[^\r\n]+") do
		local k, v = line:match("^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
		if k and v then out[k] = v end
	end
	return out
end
local function serializeKeybinds(tbl)
	local lines = {}
	for k, v in pairs(tbl) do table.insert(lines, tostring(k) .. "=" .. tostring(v)) end
	table.sort(lines)
	return table.concat(lines, "\n") .. "\n"
end

DeadZone.KeyBinds = parseKeybindsFile(fsRead(KEYBINDS_FILE))

local function setKeybind(name, keyName)
	DeadZone.KeyBinds[name] = keyName
	fsWrite(KEYBINDS_FILE, serializeKeybinds(DeadZone.KeyBinds))
end

if DeadZone.KeyBinds.AimBind then
	DeadZone.Flags.AimBindKey = DeadZone.KeyBinds.AimBind
else
	setKeybind("AimBind", DeadZone.Flags.AimBindKey)
end

-- =========================================================
-- Aim runtime
-- =========================================================
local function resolveBindEnum(name)
	if not name then return nil end
	for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
		if item.Name == name then return item end
	end
	for _, item in ipairs(Enum.UserInputType:GetEnumItems()) do
		if item.Name == name then return item end
	end
	return nil
end

local aimEngaged = false   -- true while bind is held (hold-mode)
local aimToggled = false   -- toggled state (toggle-mode)

local function aimBindMatches(input)
	local wanted = DeadZone.Flags.AimBindKey
	if not wanted then return false end
	if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name == wanted then return true end
	if input.UserInputType.Name == wanted then return true end
	return false
end

track(UserInput.InputBegan:Connect(function(input, gameProcessed)
	if not DeadZone.Flags.Aim then return end
	if gameProcessed then return end
	if not aimBindMatches(input) then return end
	if DeadZone.Flags.ToggleAim then
		aimToggled = not aimToggled
	else
		aimEngaged = true
	end
end))

track(UserInput.InputEnded:Connect(function(input)
	if not aimBindMatches(input) then return end
	if not DeadZone.Flags.ToggleAim then
		aimEngaged = false
	end
end))

local function isAimActive()
	if not DeadZone.Flags.Aim then return false end
	if DeadZone.Flags.ToggleAim then return aimToggled end
	return aimEngaged
end

local function getAimPart(model)
	if DeadZone.Flags.AimPart == "Torso" then
		return model:FindFirstChild("UpperTorso")
			or model:FindFirstChild("Torso")
			or model:FindFirstChild("HumanoidRootPart")
	end
	return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
end

-- Wallcheck: raycast from camera to target, excluding self+camera.
local function hasLineOfSight(origin, targetPos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { workspace.CurrentCamera }
	local char = LocalPlayer and LocalPlayer.Character
	if char then table.insert(exclude, char) end
	rp.FilterDescendantsInstances = exclude
	rp.IgnoreWater = true
	local dir = targetPos - origin
	local res = workspace:Raycast(origin, dir, rp)
	if not res then return true end
	return (res.Position - targetPos).Magnitude < 3
end

local function findAimTarget()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local vp = cam.ViewportSize
	local cx, cy = vp.X / 2, vp.Y / 2
	local fov = DeadZone.Flags.AimFov or 100
	local best, bestDist = nil, fov
	for model, t in pairs(DeadZone.Tracked) do
		if model.Parent and not isSelf(model)
			and not (DeadZone.Flags.PlayerCheck and isZombie(model))
		then
			local hum = t.hum
			if hum and hum.Health > 0 then
				local part = getAimPart(model)
				if part then
					local sp = cam:WorldToViewportPoint(part.Position)
					if sp.Z > 0 then
						local dx, dy = sp.X - cx, sp.Y - cy
						local d = math.sqrt(dx * dx + dy * dy)
						if d <= bestDist then
							if (not DeadZone.Flags.Wallcheck)
								or hasLineOfSight(cam.CFrame.Position, part.Position) then
								best = part
								bestDist = d
							end
						end
					end
				end
			end
		end
	end
	return best
end

local fovCircle = Drawing.new("Circle")
fovCircle.NumSides    = 60
fovCircle.Filled      = false
fovCircle.Thickness   = 1
fovCircle.Transparency = 1
fovCircle.Color       = Color3.new(1, 1, 1)
fovCircle.Visible     = false
DeadZone.FovCircle = fovCircle

-- Fake connection so DeadZone.Unload disposes the Drawing on rerun.
table.insert(DeadZone.Connections, {
	Disconnect = function() pcall(function() fovCircle:Remove() end) end,
})

track(RunService.RenderStepped:Connect(function()
	if DeadZone.Flags.Aim then
		local cam = workspace.CurrentCamera
		local vp  = cam and cam.ViewportSize or Vector2.new(0, 0)
		fovCircle.Position = Vector2.new(vp.X / 2, vp.Y / 2)
		fovCircle.Radius   = DeadZone.Flags.AimFov or 100
		fovCircle.Color    = isAimActive()
			and Color3.fromRGB(255, 60, 60)
			or  Color3.new(1, 1, 1)
		fovCircle.Visible  = true
	else
		fovCircle.Visible = false
		aimToggled = false
	end

	if not isAimActive() then return end
	local target = findAimTarget()
	if not target then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	-- Smooth camera interpolation toward target (fixed factor 0.70) so the
	-- visible motion looks humanlike instead of a hard snap.
	local desired = CFrame.lookAt(cam.CFrame.Position, target.Position)
	cam.CFrame = cam.CFrame:Lerp(desired, 0.70)
end))

local Window = ReGui:TabsWindow({
	Title = "Dead Zone",
	Size = UDim2.fromOffset(360, 420),
    NoSelect = true,
})
DeadZone.Gui = Window

--// Combat tab (Aim) — created first so it appears first in the TabsWindow.
local CombatAimTab = Window:CreateTab({ Name = "Combat" })

CombatAimTab:Checkbox({
	Label = "Enable Aim",
	Value = DeadZone.Flags.Aim,
	Callback = function(_, v) DeadZone.Flags.Aim = v end,
})
CombatAimTab:Checkbox({
	Label = "Enable Toggle Aim",
	Value = DeadZone.Flags.ToggleAim,
	Callback = function(_, v)
		DeadZone.Flags.ToggleAim = v
		-- Switching modes resets latched state so behaviour is predictable.
		aimEngaged = false
		aimToggled = false
	end,
})
CombatAimTab:Checkbox({
	Label = "Enable Wallcheck",
	Value = DeadZone.Flags.Wallcheck,
	Callback = function(_, v) DeadZone.Flags.Wallcheck = v end,
})
CombatAimTab:Checkbox({
	Label = "Enable Player Check",
	Value = DeadZone.Flags.PlayerCheck,
	Callback = function(_, v) DeadZone.Flags.PlayerCheck = v end,
})
CombatAimTab:Keybind({
	Label = "Aim Bind",
	Value = resolveBindEnum(DeadZone.Flags.AimBindKey) or Enum.KeyCode.LeftControl,
	IgnoreGameProcessed = false,
	OnKeybindSet = function(_, keyId)
		local name = (keyId and keyId.Name) or "LeftControl"
		DeadZone.Flags.AimBindKey = name
		setKeybind("AimBind", name)
	end,
})
CombatAimTab:Combo({
	Label = "Aim Part",
	Selected = (DeadZone.Flags.AimPart == "Torso") and 2 or 1,
	Items = { "Head", "Torso" },
	Callback = function(_, name) DeadZone.Flags.AimPart = name end,
})
CombatAimTab:SliderInt({
	Label = "Fov",
	Value = DeadZone.Flags.AimFov,
	Minimum = 30,
	Maximum = 600,
	Callback = function(_, v) DeadZone.Flags.AimFov = v end,
})

--// Movement tab (Silent Speed / WalkSpeed) — was 'Combat'
local CombatTab = Window:CreateTab({ Name = "Movement" })

CombatTab:Checkbox({
	Label = "Enable Silent Speed",
	Value = DeadZone.Flags.SilentSpeed,
	Callback = function(_, v) DeadZone.Flags.SilentSpeed = v end,
})
CombatTab:SliderInt({
	Label = "Silent Speed",
	Value = DeadZone.Flags.SilentSpeedMul,
	Minimum = 1,
	Maximum = 50,
	Callback = function(_, v) DeadZone.Flags.SilentSpeedMul = v end,
})

CombatTab:Checkbox({
	Label = "Enable Speed",
	Value = DeadZone.Flags.Speed,
	Callback = function(_, v)
		DeadZone.Flags.Speed = v
		if not v then
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = 16 end
		end
	end,
})
CombatTab:SliderInt({
	Label = "Speed",
	Value = DeadZone.Flags.SpeedValue,
	Minimum = 1,
	Maximum = 1000,
	Callback = function(_, v) DeadZone.Flags.SpeedValue = v end,
})

track(RunService.Heartbeat:Connect(function()
	if not DeadZone.Flags.Speed then return end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.WalkSpeed ~= DeadZone.Flags.SpeedValue then
		hum.WalkSpeed = DeadZone.Flags.SpeedValue
	end
end))

track(RunService.Heartbeat:Connect(function()
	if not DeadZone.Flags.SilentSpeed then return end
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	if hum.MoveDirection.Magnitude > 0 then
		hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (DeadZone.Flags.SilentSpeedMul / 10))
	end
end))

local VisualsTab = Window:CreateTab({ Name = "Visuals" })

VisualsTab:Checkbox({
	Label = "Enable Player Esp",
	Value = DeadZone.Flags.PlayerEsp,
	Callback = function(_, v) DeadZone.Flags.PlayerEsp = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Car Esp",
	Value = DeadZone.Flags.CarEsp,
	Callback = function(_, v) DeadZone.Flags.CarEsp = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Zombie Esp",
	Value = DeadZone.Flags.ZombieEsp,
	Callback = function(_, v) DeadZone.Flags.ZombieEsp = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Chams",
	Value = DeadZone.Flags.Chams,
	Callback = function(_, v) DeadZone.Flags.Chams = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Box",
	Value = DeadZone.Flags.Box,
	Callback = function(_, v) DeadZone.Flags.Box = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Name",
	Value = DeadZone.Flags.Name,
	Callback = function(_, v) DeadZone.Flags.Name = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Distance",
	Value = DeadZone.Flags.Distance,
	Callback = function(_, v) DeadZone.Flags.Distance = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Health",
	Value = DeadZone.Flags.Health,
	Callback = function(_, v) DeadZone.Flags.Health = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Lines",
	Value = DeadZone.Flags.Lines,
	Callback = function(_, v) DeadZone.Flags.Lines = v end,
})
VisualsTab:Checkbox({
	Label = "Enable Dot",
	Value = DeadZone.Flags.Dot,
	Callback = function(_, v) DeadZone.Flags.Dot = v end,
})
VisualsTab:Checkbox({
	Label = "Disable Cursor",
	Value = DeadZone.Flags.DisableCursor,
	Callback = function(_, v)
		DeadZone.Flags.DisableCursor = v
		if not v then restoreCursor() end
	end,
})

local RFn = game:GetService("ReplicatedStorage"):WaitForChild("RemoteFunctions")
local REv = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents")

local DupeTab = Window:CreateTab({ Name = "Dupe" })

local BankCache = {}
local AutoDeposit = false

track(REv:WaitForChild("RefreshBank").OnClientEvent:Connect(function(slot, item)
	BankCache[tostring(slot)] = item
end))

task.spawn(function() pcall(function() RFn.OpenBank:InvokeServer() end) end)

local slotInput = DupeTab:InputText({ Label = "Slot", Value = "1" })
local countSlide = DupeTab:SliderInt({ Label = "Count", Value = 10, Minimum = 1, Maximum = 100 })

DupeTab:Checkbox({
	Label = "Auto Deposit",
	Value = false,
	Callback = function(_, v)
		AutoDeposit = v
		if v then
			task.spawn(function() pcall(function() RFn.OpenBank:InvokeServer() end) end)
		end
	end,
})

local SLOT_TAG = "_dzcSlotNum"
local slotLabelConn
local slotLabelLoop = false

local function findBankFrame()
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	local bgui = pg and pg:FindFirstChild("BackpackGui")
	if not bgui then return nil end
	for _, d in ipairs(bgui:GetDescendants()) do
		if d:IsA("Frame") then
			local hasBankTitle = false
			local n = 0
			for _, ch in ipairs(d:GetChildren()) do
				if ch:IsA("TextLabel") and ch.Text == "Bank" then
					hasBankTitle = true
				end
				if ch:IsA("ImageButton") and tonumber(ch.Name) then
					n = n + 1
				end
			end
			if hasBankTitle and n >= 36 then return d end
		end
	end
	return nil
end

local function applySlotLabel(btn)
	if not (btn and btn:IsA("ImageButton")) then return end
	local n = tonumber(btn.Name)
	if not n then return end
	if btn:FindFirstChild(SLOT_TAG) then return end
	local lbl = Instance.new("TextLabel")
	lbl.Name = SLOT_TAG
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0, 28, 0, 16)
	lbl.Position = UDim2.new(0, 2, 0, 0)
	lbl.Text = tostring(n)
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.TextSize = 14
	lbl.Font = Enum.Font.SourceSansBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.ZIndex = 10
	lbl.Parent = btn
end

local function clearAllSlotLabels()
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, d in ipairs(pg:GetDescendants()) do
		if d.Name == SLOT_TAG then d:Destroy() end
	end
end

DupeTab:Checkbox({
	Label = "Show Bank Slots",
	Value = false,
	Callback = function(_, v)
		if v then
			slotLabelLoop = true
			task.spawn(function()
				while slotLabelLoop do
					local f = findBankFrame()
					if f then
						for _, ch in ipairs(f:GetChildren()) do applySlotLabel(ch) end
						if not slotLabelConn then
							slotLabelConn = f.ChildAdded:Connect(function(ch)
								task.defer(function()
									if slotLabelLoop then applySlotLabel(ch) end
								end)
							end)
						end
					end
					task.wait(0.5)
				end
			end)
		else
			slotLabelLoop = false
			if slotLabelConn then pcall(function() slotLabelConn:Disconnect() end); slotLabelConn = nil end
			clearAllSlotLabels()
		end
	end,
})

local function readWidget(w, fallback)
	if w == nil then return fallback end
	for _, f in ipairs({"Value","Text","CurrentValue","Number"}) do
		local v = w[f]
		if type(v) ~= "function" and v ~= nil then return v end
	end
	return fallback
end

local function genNonce()
	return math.random(54, 75) * 53 * 78 * 33 * 96 * 18 * 22 * 35 * 91
end

local function snapshotInventoryBySlot()
	local bySlot = {}
	local ok, struct, items = pcall(function()
		return RFn.FetchInventory:InvokeServer()
	end)
	if not ok then return bySlot end
	local function harvest(tbl)
		if type(tbl) ~= "table" then return end
		for k, it in pairs(tbl) do
			if type(it) == "table" and it.special then
				bySlot[tostring(k)] = it
			end
		end
	end
	harvest(items)
	if next(bySlot) == nil and type(struct) == "table" then
		harvest(struct)
		harvest(struct.items)
	end
	return bySlot
end

local function findNewInventoryEntry(before, after)
	for slot, it in pairs(after) do
		local b = before and before[slot]
		if not b or b.special ~= it.special then
			return slot, it
		end
	end
	return nil, nil
end

local function performDupe(slot, count)
	slot = tostring(slot)
	count = math.max(1, math.floor((tonumber(count) or 1) + 0.5))
	local targetBankSlot = tonumber(slot)

	local before = AutoDeposit and snapshotInventoryBySlot() or nil

	for i = 1, count do
		task.spawn(function()
			pcall(function() RFn.Withdraw:InvokeServer(slot, false) end)
		end)
	end

	if AutoDeposit and targetBankSlot then
		task.spawn(function()
			local newInvSlot, newItem
			local tries = 0
			while not newInvSlot and tries < 10 do
				task.wait(0.15)
				tries = tries + 1
				local after = snapshotInventoryBySlot()
				newInvSlot, newItem = findNewInventoryEntry(before, after)
			end
			if not newInvSlot then
				return
			end

			local invSlotNum = tonumber(newInvSlot)
			local sp = newItem.special

			local bankBefore = {}
			for k, v in pairs(BankCache) do
				if type(v) == "table" then bankBefore[tostring(k)] = v end
			end

			local nonce = genNonce()
			pcall(function()
				return RFn.Deposit:InvokeServer(sp, invSlotNum, false, nonce, false)
			end)

			local landedBankSlot
			local waited = 0
			while not landedBankSlot and waited < 1.5 do
				task.wait(0.1)
				waited = waited + 0.1
				for k, v in pairs(BankCache) do
					if type(v) == "table" and not bankBefore[tostring(k)] then
						landedBankSlot = tostring(k)
						break
					end
				end
			end

			if landedBankSlot and tonumber(landedBankSlot) ~= targetBankSlot then
				local src = tostring(landedBankSlot)
				local dst = tostring(targetBankSlot)
				local movedItem = BankCache[src]
				local resS
				pcall(function() resS = RFn.MoveItem:InvokeServer(src, dst, true) end)
				if not resS then
					pcall(function() RFn.MoveItem:InvokeServer(tonumber(src), tonumber(dst), true) end)
				end

				BankCache[src] = nil
				BankCache[dst] = movedItem

				local RS = game:GetService("ReplicatedStorage")
				local BEs = RS:FindFirstChild("BindableEvents")
				local bankBE = BEs and BEs:FindFirstChild("Bank")
				if bankBE then
					pcall(function() bankBE:Fire() end)
					task.wait(0.05)
					pcall(function() bankBE:Fire() end)
				end
			end
		end)
	end
end

local DUPE_BTN_TAG = "_dzcSlotDupeBtn"
local dupeBtnConn
local dupeBtnLoop = false

local function applyDupeButton(btn)
	if not (btn and btn:IsA("ImageButton")) then return end
	local n = tonumber(btn.Name)
	if not n then return end
	if btn:FindFirstChild(DUPE_BTN_TAG) then return end
	local b = Instance.new("TextButton")
	b.Name = DUPE_BTN_TAG
	b.AnchorPoint = Vector2.new(0, 1)
	b.Size = UDim2.new(0, 16, 0, 16)
	b.Position = UDim2.new(0, 2, 1, -2)
	b.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	b.BackgroundTransparency = 0.4
	b.BorderSizePixel = 0
	b.Text = ""
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0
	b.TextStrokeColor3 = Color3.new(0, 0, 0)
	b.TextSize = 14
	b.Font = Enum.Font.SourceSansBold
	b.AutoButtonColor = true
	b.ZIndex = 20
	b.Active = true
	b.Parent = btn
	track(b.MouseButton1Click:Connect(function()
		local countRaw = tonumber(readWidget(countSlide, 10)) or 10
		performDupe(tostring(n), countRaw)
	end))
end

local function clearAllDupeButtons()
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, d in ipairs(pg:GetDescendants()) do
		if d.Name == DUPE_BTN_TAG then d:Destroy() end
	end
end

DupeTab:Checkbox({
	Label = "Show Bank Dupe",
	Value = false,
	Callback = function(_, v)
		if v then
			dupeBtnLoop = true
			task.spawn(function()
				while dupeBtnLoop do
					local f = findBankFrame()
					if f then
						for _, ch in ipairs(f:GetChildren()) do applyDupeButton(ch) end
						if not dupeBtnConn then
							dupeBtnConn = f.ChildAdded:Connect(function(ch)
								task.defer(function()
									if dupeBtnLoop then applyDupeButton(ch) end
								end)
							end)
						end
					end
					task.wait(0.5)
				end
			end)
		else
			dupeBtnLoop = false
			if dupeBtnConn then pcall(function() dupeBtnConn:Disconnect() end); dupeBtnConn = nil end
			clearAllDupeButtons()
		end
	end,
})

local DupeRow = DupeTab:Row()
DupeRow:Button({
	Text = "Dupe",
	Callback = function()
		local slotRaw = tostring(readWidget(slotInput, "1"))
		local slot = slotRaw:match("(%d+)") or "1"
		local countRaw = tonumber(readWidget(countSlide, 10)) or 10
		performDupe(slot, countRaw)
	end,
})
DupeRow:Button({
	Text = "Drop All",
	Callback = function()
		task.spawn(function()
			-- Iterate rather than trust snapshot quantity: for non-stackable items
			-- (e.g. fuel canisters where .quantity is liters, not stack count) the
			-- server drops the whole slot on a single FireServer, so we drop each
			-- slot once, re-fetch, and repeat until the inventory reports empty.
			for iter = 1, 200 do
				local ok, inv, items = pcall(function() return RFn.FetchInventory:InvokeServer() end)
				if not ok then return end
				local itemsBySlot = items
				if type(itemsBySlot) ~= "table" and type(inv) == "table" and type(inv.items) == "table" then
					itemsBySlot = inv.items
				end
				if type(itemsBySlot) ~= "table" then return end
				local specials = {}
				for _, it in pairs(itemsBySlot) do
					if type(it) == "table" and it.special then
						table.insert(specials, it.special)
					end
				end
				if #specials == 0 then return end
				for _, sp in ipairs(specials) do
					pcall(function() REv.DropItem:FireServer(sp, true, true) end)
					task.wait(0.05)
				end
				task.wait(0.15)
			end
		end)
	end,
})

--// Misc tab
local MiscTab = Window:CreateTab({ Name = "Misc" })

local DEFAULT_MAX_ZOOM = 10
pcall(function() LocalPlayer.CameraMaxZoomDistance = DEFAULT_MAX_ZOOM end)

MiscTab:SliderInt({
	Label = "Camera Fov",
	Value = DEFAULT_MAX_ZOOM,
	Minimum = 1,
	Maximum = 1000,
	Callback = function(_, v)
		pcall(function() LocalPlayer.CameraMaxZoomDistance = v end)
	end,
})

local function initFullbright()
	if _G.FullBrightExecuted then return end

	local Lighting = game:GetService("Lighting")

	_G.FullBrightEnabled = false
	_G.NormalLightingSettings = {
		Brightness    = Lighting.Brightness,
		ClockTime     = Lighting.ClockTime,
		FogEnd        = Lighting.FogEnd,
		GlobalShadows = Lighting.GlobalShadows,
		Ambient       = Lighting.Ambient,
	}

	local FORCED = {
		Brightness    = 1,
		ClockTime     = 12,
		FogEnd        = 786543,
		GlobalShadows = false,
		Ambient       = Color3.fromRGB(178, 178, 178),
	}

	local function guard(prop)
		Lighting:GetPropertyChangedSignal(prop):Connect(function()
			local cur = Lighting[prop]
			if cur ~= FORCED[prop] and cur ~= _G.NormalLightingSettings[prop] then
				_G.NormalLightingSettings[prop] = cur
				if _G.FullBrightEnabled then
					Lighting[prop] = FORCED[prop]
				end
			end
		end)
	end
	for prop in pairs(FORCED) do guard(prop) end

	local latest = false
	task.spawn(function()
		while true do
			task.wait()
			if _G.FullBrightEnabled ~= latest then
				latest = _G.FullBrightEnabled
				local src = latest and FORCED or _G.NormalLightingSettings
				for prop, val in pairs(src) do
					Lighting[prop] = val
				end
			end
		end
	end)

	_G.FullBrightExecuted = true
end

MiscTab:Checkbox({
	Label = "Enable Fullbright",
	Value = false,
	Callback = function(_, v)
		initFullbright()
		_G.FullBrightEnabled = v
	end,
})

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Open Source Hub",
    Text = "DEADZONE Loaded",
    Duration = 5
})
