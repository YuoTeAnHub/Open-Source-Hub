if not game:IsLoaded() then game.Loaded:Wait() end

local cloneref      = cloneref      or function(i) return i end
local clonefunction = clonefunction or function(f) return f end
local newcclosure   = newcclosure   or clonefunction

if not (hookfunction and require) then
	return error("[WarTycoon] Missing hookfunction or require")
end

local RS      = cloneref(game:GetService("ReplicatedStorage"))
local Players = cloneref(game:GetService("Players"))
local UIS     = cloneref(game:GetService("UserInputService"))
local RunSvc  = cloneref(game:GetService("RunService"))
local plr     = Players.LocalPlayer
local cam     = workspace.CurrentCamera
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled

local G = getgenv()

local function destroyInstance(inst)
	if type(inst) ~= "table" then return end
	inst.alive = false
	if inst.connections then
		for _, c in ipairs(inst.connections) do pcall(function() c:Disconnect() end) end
	end
	if inst.drawings then
		for _, d in ipairs(inst.drawings) do pcall(function() d:Remove() end) end
	end
	if inst.esp then
		for _, entry in pairs(inst.esp) do
			for _, d in pairs(entry) do pcall(function() d:Remove() end) end
		end
	end
	if inst.vehicleEsp then
		for _, entry in pairs(inst.vehicleEsp) do
			for _, d in pairs(entry) do pcall(function() d:Remove() end) end
		end
	end
	if inst.flyBV then pcall(function() inst.flyBV:Destroy() end) end
	if inst.flyBG then pcall(function() inst.flyBG:Destroy() end) end
	if inst.noclipModified then
		for part in pairs(inst.noclipModified) do
			if part and part.Parent then pcall(function() part.CanCollide = true end) end
		end
	end
	if inst.speedApplied then
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.WalkSpeed = 16 end) end
	end
	if inst.platformStandSet then
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.PlatformStand = false end) end
	end
	if inst.window then
		pcall(function()
			if type(inst.window.Close) == "function" then
				inst.window:Close()
			elseif type(inst.window.Destroy) == "function" then
				inst.window:Destroy()
			elseif inst.window.Frame then
				inst.window.Frame:Destroy()
			end
		end)
	end
end

if G.WT_SA_Instance then
	destroyInstance(G.WT_SA_Instance)
	G.WT_SA_Instance = nil
end

local okAc, ac = pcall(require, RS.BulletFireSystem.FastCastRedux.ActiveCast)
if not okAc then return warn("[WarTycoon] require(ActiveCast) failed: " .. tostring(ac)) end

local gameSystems  = workspace:FindFirstChild("Game Systems")
local localStorage = workspace:FindFirstChild("LocalPartStorage")
if not (gameSystems and localStorage) then
	return warn("[WarTycoon] workspace.Game Systems / LocalPartStorage missing, script needs updating")
end

local okR, ReGui = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Dear-ReGui/refs/heads/main/ReGui.lua"))()
end)
if not okR or type(ReGui) ~= "table" then
	return warn("[WarTycoon] ReGui load failed: " .. tostring(ReGui))
end
local okP, prefabs = pcall(function()
	return game:GetObjects("rbxassetid://" .. ReGui.PrefabsId)[1]
end)
if not okP or not prefabs then
	return warn("[WT-SA] ReGui prefabs load failed")
end
pcall(function() ReGui:Init({ Prefabs = prefabs }) end)

local BIND_FILE = "WarTycoon_KeyBinds.txt"
local hasFileIO = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local function resolveKey(name, fallback)
	if type(name) ~= "string" then return fallback end
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	if ok and typeof(k) == "EnumItem" then return k end
	return fallback
end

local BIND_DEFS = {
	{ key = "AimBind",    field = "aimKey",    nameField = "aimKeyName",    default = Enum.KeyCode.LeftControl },
	{ key = "FlyBind",    field = "flyKey",    nameField = "flyKeyName",    default = Enum.KeyCode.N },
	{ key = "NoClipBind", field = "noclipKey", nameField = "noclipKeyName", default = Enum.KeyCode.V },
	{ key = "SpeedBind",  field = "speedKey",  nameField = "speedKeyName",  default = Enum.KeyCode.B },
}

local function loadBinds()
	local result = {}
	for _, def in ipairs(BIND_DEFS) do
		result[def.key] = def.default
	end
	if hasFileIO then
		if not isfile(BIND_FILE) then
			local lines = {}
			for _, def in ipairs(BIND_DEFS) do
				table.insert(lines, def.key .. "=" .. def.default.Name)
			end
			pcall(writefile, BIND_FILE, table.concat(lines, "\n") .. "\n")
		else
			local okC, content = pcall(readfile, BIND_FILE)
			if okC and type(content) == "string" then
				for line in content:gmatch("[^\r\n]+") do
					local k, v = line:match("^%s*(%w+)%s*=%s*([%w_]+)%s*$")
					if k and v and result[k] then
						result[k] = resolveKey(v, result[k])
					end
				end
			end
		end
	end
	return result
end

local function saveBinds(bindsTable)
	if not hasFileIO then return end
	local lines = {}
	for _, def in ipairs(BIND_DEFS) do
		local k = bindsTable[def.key] or def.default
		local name = typeof(k) == "EnumItem" and k.Name or "LeftControl"
		table.insert(lines, def.key .. "=" .. name)
	end
	pcall(writefile, BIND_FILE, table.concat(lines, "\n") .. "\n")
end

local loaded = loadBinds()

G.WT_SA = G.WT_SA or {}
local C = G.WT_SA
C.silentAim  = C.silentAim  == true
C.gunAim     = C.gunAim     == true
C.vehAim     = C.vehAim     == true
C.wallcheck  = C.wallcheck  == true
C.toggleAim  = C.toggleAim  == true
C.fov        = tonumber(C.fov) or 300
C.aimPart    = C.aimPart or "Head"
C.box        = C.box        == true
C.health     = C.health     == true
C.showName   = C.showName   == true
C.distance   = C.distance   == true
C.vehBox     = C.vehBox     == true
C.vehName    = C.vehName    == true
C.fovHack    = C.fovHack    == true
C.fly        = C.fly        == true
C.flySpeed   = tonumber(C.flySpeed)   or 50
C.noclip     = C.noclip     == true
C.speed      = C.speed      == true
C.speedValue = tonumber(C.speedValue) or 32
C.aimKey       = (typeof(C.aimKey)    == "EnumItem") and C.aimKey    or loaded.AimBind
C.flyKey       = (typeof(C.flyKey)    == "EnumItem") and C.flyKey    or loaded.FlyBind
C.noclipKey    = (typeof(C.noclipKey) == "EnumItem") and C.noclipKey or loaded.NoClipBind
C.speedKey     = (typeof(C.speedKey)  == "EnumItem") and C.speedKey  or loaded.SpeedBind
C.aimKeyName    = C.aimKey.Name
C.flyKeyName    = C.flyKey.Name
C.noclipKeyName = C.noclipKey.Name
C.speedKeyName  = C.speedKey.Name
C.aimToggled = false
C.aimHeld    = false

local function currentBindMap()
	return {
		AimBind    = C.aimKey,
		FlyBind    = C.flyKey,
		NoClipBind = C.noclipKey,
		SpeedBind  = C.speedKey,
	}
end

local instance = {
	connections     = {},
	drawings        = {},
	esp             = {},
	vehicleEsp      = {},
	noclipModified  = {},
	speedApplied    = false,
	platformStandSet = false,
	flyBV           = nil,
	flyBG           = nil,
	window          = nil,
	alive           = true,
}
G.WT_SA_Instance = instance

local function addConn(c) table.insert(instance.connections, c); return c end
local function addDraw(d) table.insert(instance.drawings, d); return d end

local function aimActive()
	if not C.silentAim then return false end
	if C.toggleAim then return C.aimToggled end
	return C.aimHeld
end

local wallRp = RaycastParams.new()
wallRp.FilterType  = Enum.RaycastFilterType.Exclude
wallRp.IgnoreWater = true

local VEHICLE_WS_NAMES = {
	"Vehicle Workspace", "Tank Workspace", "Submarine Workspace", "RC Workspace",
	"Plane Workspace", "Hovercraft Workspace", "Helicopter Workspace",
	"Gunship Workspace", "Drone Workspace", "Boat Workspace",
}

local function wallcheckFilter()
	local t = { plr.Character, localStorage }
	for _, name in ipairs(VEHICLE_WS_NAMES) do
		local inst = gameSystems:FindFirstChild(name)
		if inst then table.insert(t, inst) end
	end
	local air = gameSystems:FindFirstChild("Airstrike Workspace")
	if air then table.insert(t, air) end
	local fire = gameSystems:FindFirstChild("FireDamage")
	if fire then table.insert(t, fire) end
	local acs = gameSystems:FindFirstChild("ACS_WorkSpace")
	if acs then table.insert(t, acs) end
	return t
end

local function isVisible(part, origin)
	local char = plr.Character
	if not (char and part) then return false, nil end
	wallRp.FilterDescendantsInstances = wallcheckFilter()
	local dir = part.Position - origin
	local result = workspace:Raycast(origin, dir, wallRp)
	if not result then return true, nil end
	if result.Instance:IsDescendantOf(part.Parent) then return true, result.Instance end
	return false, result.Instance
end

local function classify(behavior)
	if not behavior then return "gun" end
	local params = behavior.RaycastParams
	if not params then return "gun" end
	local list = params.FilterDescendantsInstances
	if type(list) ~= "table" then return "gun" end
	for _, inst in ipairs(list) do
		if typeof(inst) == "Instance" and inst:IsDescendantOf(gameSystems) then
			return "vehicle"
		end
	end
	return "gun"
end

local function pickPart(char)
	if C.aimPart == "Torso" then
		return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			or char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function getTarget(origin, kind)
	if not aimActive() then return nil end
	if kind == "vehicle" and not C.vehAim then return nil end
	if kind == "gun"     and not C.gunAim then return nil end
	local cPart, cDist = nil, C.fov
	for _, other in Players:GetPlayers() do
		if other == plr then continue end
		local char = other.Character
		if not char then continue end
		if char:FindFirstChildOfClass("ForceField") then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then continue end
		local part = pickPart(char)
		if not part then continue end
		local screen, onScreen = cam:WorldToViewportPoint(part.Position)
		if not onScreen then continue end
		if C.wallcheck then
			local v, np = isVisible(part, origin)
			if not v then
				v, np = isVisible(char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"), origin)
				if not v then continue end
			end
			if np then part = np end
		end
		local mv = isMobile
			and Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
			or UIS:GetMouseLocation()
		local d = (Vector2.new(screen.X, screen.Y) - mv).Magnitude
		if d < cDist then cPart, cDist = part, d end
	end
	return cPart
end

G.WT_SA_GetTarget = getTarget
G.WT_SA_Classify  = classify
G.WT_SA_AimActive = aimActive

if not G.WT_SA_Hooked then
	local acNew = rawget(ac, "new")
	if type(acNew) ~= "function" then
		return warn("[WarTycoon] ActiveCast.new is not a function")
	end
	local old
	old = clonefunction(hookfunction(acNew, newcclosure(function(caster, origin, direction, velocity, behavior, ...)
		local sa = getgenv().WT_SA
		if not sa or not (sa.silentAim and (sa.gunAim or sa.vehAim)) then
			return old(caster, origin, direction, velocity, behavior, ...)
		end
		local active = getgenv().WT_SA_AimActive
		if not (active and active()) then
			return old(caster, origin, direction, velocity, behavior, ...)
		end
		local cf = getgenv().WT_SA_Classify
		local kind = cf and cf(behavior) or "gun"
		if kind == "vehicle" and not sa.vehAim then
			return old(caster, origin, direction, velocity, behavior, ...)
		end
		if kind == "gun" and not sa.gunAim then
			return old(caster, origin, direction, velocity, behavior, ...)
		end
		local gt = getgenv().WT_SA_GetTarget
		local target = gt and gt(origin, kind)
		if target then
			local dir = target.Position - origin
			return old(caster, origin, dir, dir.Unit * 9e9, behavior, ...)
		end
		return old(caster, origin, direction, velocity, behavior, ...)
	end)))
	G.WT_SA_Hooked = true
end

local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"
local circle
if hasDrawing then
	circle = Drawing.new("Circle")
	circle.Thickness    = 2
	circle.NumSides     = 64
	circle.Filled       = false
	circle.Transparency = 1
	circle.Visible      = false
	addDraw(circle)
end

local function mkDraw(kind)
	local d = Drawing.new(kind)
	d.Visible = false
	return d
end

local function makeEspFor(player)
	if not hasDrawing then return nil end
	if instance.esp[player] then return instance.esp[player] end
	local box    = mkDraw("Square"); box.Thickness = 1; box.Filled = false; box.Color = Color3.fromRGB(255,255,255)
	local hpBg   = mkDraw("Square"); hpBg.Thickness = 1; hpBg.Filled = true;  hpBg.Color = Color3.fromRGB(0,0,0); hpBg.Transparency = 0.6
	local hpFill = mkDraw("Square"); hpFill.Thickness = 1; hpFill.Filled = true; hpFill.Color = Color3.fromRGB(0,220,0)
	local nameTx = mkDraw("Text");   nameTx.Size = 14; nameTx.Center = true; nameTx.Outline = true; nameTx.Color = Color3.fromRGB(255,255,255); nameTx.Font = 2
	local distTx = mkDraw("Text");   distTx.Size = 13; distTx.Center = true; distTx.Outline = true; distTx.Color = Color3.fromRGB(255,255,255); distTx.Font = 2
	local entry = { box = box, hpBg = hpBg, hpFill = hpFill, name = nameTx, dist = distTx }
	instance.esp[player] = entry
	return entry
end

local function hideEsp(entry)
	if not entry then return end
	entry.box.Visible    = false
	entry.hpBg.Visible   = false
	entry.hpFill.Visible = false
	entry.name.Visible   = false
	entry.dist.Visible   = false
end

local function destroyEspFor(player)
	local entry = instance.esp[player]
	if not entry then return end
	for _, d in pairs(entry) do pcall(function() d:Remove() end) end
	instance.esp[player] = nil
end

addConn(Players.PlayerRemoving:Connect(destroyEspFor))

local function makeVehicleEspFor(model)
	if not hasDrawing then return nil end
	if instance.vehicleEsp[model] then return instance.vehicleEsp[model] end
	local box    = mkDraw("Square"); box.Thickness = 1; box.Filled = false; box.Color = Color3.fromRGB(255,180,60)
	local nameTx = mkDraw("Text");   nameTx.Size = 14; nameTx.Center = true; nameTx.Outline = true; nameTx.Color = Color3.fromRGB(255,200,120); nameTx.Font = 2
	local entry = { box = box, name = nameTx }
	instance.vehicleEsp[model] = entry
	return entry
end

local function hideVehicleEsp(entry)
	if not entry then return end
	entry.box.Visible  = false
	entry.name.Visible = false
end

local function destroyVehicleEsp(model)
	local entry = instance.vehicleEsp[model]
	if not entry then return end
	for _, d in pairs(entry) do pcall(function() d:Remove() end) end
	instance.vehicleEsp[model] = nil
end

local WORLD_HEIGHT      = 5.5
local WORLD_WIDTH_RATIO = 0.55

local BB_CORNERS = { -1, 1 }

local function projectBoundingBox(model)
	local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
	if not ok or not cf or not size then return nil end
	if size.X == 0 and size.Y == 0 and size.Z == 0 then return nil end
	local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local anyOn = false
	for _, sx in ipairs(BB_CORNERS) do
		for _, sy in ipairs(BB_CORNERS) do
			for _, sz in ipairs(BB_CORNERS) do
				local wp = (cf * CFrame.new(sx * hx, sy * hy, sz * hz)).Position
				local sp, on = cam:WorldToViewportPoint(wp)
				if sp.Z > 0 then
					if on then anyOn = true end
					if sp.X < minX then minX = sp.X end
					if sp.Y < minY then minY = sp.Y end
					if sp.X > maxX then maxX = sp.X end
					if sp.Y > maxY then maxY = sp.Y end
				end
			end
		end
	end
	if not anyOn or minX == math.huge then return nil end
	return minX, minY, maxX, maxY
end

addConn(RunSvc.RenderStepped:Connect(function()
	if circle then
		if not C.silentAim then
			circle.Visible = false
		else
			circle.Visible = true
			circle.Radius  = C.fov
			circle.Color   = aimActive() and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)
			local mp = isMobile
				and Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
				or UIS:GetMouseLocation()
			circle.Position = mp
		end
	end

	if not hasDrawing then return end

	local playerEspOn = C.box or C.health or C.showName or C.distance
	if not playerEspOn then
		for _, e in pairs(instance.esp) do hideEsp(e) end
	else
		local localChar = plr.Character
		local localHrp  = localChar and (localChar:FindFirstChild("HumanoidRootPart") or localChar.PrimaryPart)
		for _, other in ipairs(Players:GetPlayers()) do
			if other == plr then continue end
			local entry = makeEspFor(other)
			if not entry then continue end
			local char = other.Character
			if not char then hideEsp(entry); continue end
			local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then hideEsp(entry); continue end
			local topP, onTop = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0,  WORLD_HEIGHT * 0.5, 0))
			local botP, onBot = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, -WORLD_HEIGHT * 0.5, 0))
			if not (onTop and onBot) then hideEsp(entry); continue end
			local h  = math.abs(topP.Y - botP.Y)
			local w  = h * WORLD_WIDTH_RATIO
			local cx = (topP.X + botP.X) * 0.5
			local ty = math.min(topP.Y, botP.Y)
			local by = math.max(topP.Y, botP.Y)
			local boxX = cx - w * 0.5
			if C.box then
				entry.box.Position = Vector2.new(boxX, ty)
				entry.box.Size     = Vector2.new(w, h)
				entry.box.Visible  = true
			else entry.box.Visible = false end
			if C.health then
				local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
				local barW, barX = 3, boxX - 5
				entry.hpBg.Position = Vector2.new(barX, ty); entry.hpBg.Size = Vector2.new(barW, h); entry.hpBg.Visible = true
				local fillH = h * hp
				entry.hpFill.Position = Vector2.new(barX, ty + (h - fillH))
				entry.hpFill.Size     = Vector2.new(barW, fillH)
				entry.hpFill.Color    = Color3.fromRGB(math.floor(255 * (1 - hp)), math.floor(220 * hp), 0)
				entry.hpFill.Visible  = true
			else
				entry.hpBg.Visible = false; entry.hpFill.Visible = false
			end
			if C.showName then
				entry.name.Text = other.DisplayName ~= "" and other.DisplayName or other.Name
				entry.name.Position = Vector2.new(cx, ty - 16); entry.name.Visible = true
			else entry.name.Visible = false end
			if C.distance then
				local meters = 0
				if localHrp then meters = math.floor((hrp.Position - localHrp.Position).Magnitude * 0.28 + 0.5) end
				entry.dist.Text = string.format("%dm", meters)
				entry.dist.Position = Vector2.new(cx, by + 2); entry.dist.Visible = true
			else entry.dist.Visible = false end
		end
	end

	local vehEspOn = C.vehBox or C.vehName
	for model, entry in pairs(instance.vehicleEsp) do
		if not model.Parent then
			for _, d in pairs(entry) do pcall(function() d:Remove() end) end
			instance.vehicleEsp[model] = nil
		end
	end
	if not vehEspOn then
		for _, entry in pairs(instance.vehicleEsp) do hideVehicleEsp(entry) end
	else
		for _, wsName in ipairs(VEHICLE_WS_NAMES) do
			local ws = gameSystems:FindFirstChild(wsName)
			if ws then
				for _, model in ipairs(ws:GetChildren()) do
					if model:IsA("Model") then
						local entry = makeVehicleEspFor(model)
						if entry then
							local minX, minY, maxX, maxY = projectBoundingBox(model)
							if not minX then hideVehicleEsp(entry) else
								if C.vehBox then
									entry.box.Position = Vector2.new(minX, minY)
									entry.box.Size     = Vector2.new(maxX - minX, maxY - minY)
									entry.box.Visible  = true
								else entry.box.Visible = false end
								if C.vehName then
									entry.name.Text     = model.Name
									entry.name.Position = Vector2.new((minX + maxX) * 0.5, minY - 16)
									entry.name.Visible  = true
								else entry.name.Visible = false end
							end
						end
					end
				end
			end
		end
	end
end))

local function applyFovHackOnce()
	if C.fovHack and plr.CameraMode ~= Enum.CameraMode.Classic then
		pcall(function() plr.CameraMode = Enum.CameraMode.Classic end)
	end
end
task.spawn(function()
	while instance.alive do
		applyFovHackOnce()
		task.wait(0.25)
	end
end)
applyFovHackOnce()

local function stopFly()
	if instance.flyBV then pcall(function() instance.flyBV:Destroy() end); instance.flyBV = nil end
	if instance.flyBG then pcall(function() instance.flyBG:Destroy() end); instance.flyBG = nil end
	if instance.platformStandSet then
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.PlatformStand = false end) end
		instance.platformStandSet = false
	end
end

addConn(RunSvc.Stepped:Connect(function()
	local char = plr.Character
	local hrp  = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
	local hum  = char and char:FindFirstChildOfClass("Humanoid")

	if C.fly and char and hrp and hum then
		if not (instance.flyBV and instance.flyBV.Parent) then
			instance.flyBV = Instance.new("BodyVelocity")
			instance.flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			instance.flyBV.Velocity = Vector3.zero
			instance.flyBV.Parent   = hrp
		end
		if not (instance.flyBG and instance.flyBG.Parent) then
			instance.flyBG = Instance.new("BodyGyro")
			instance.flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			instance.flyBG.P         = 20000
			instance.flyBG.CFrame    = hrp.CFrame
			instance.flyBG.Parent    = hrp
		end
		if not hum.PlatformStand then hum.PlatformStand = true; instance.platformStandSet = true end
		local dir = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W)         then dir = dir + cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S)         then dir = dir - cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A)         then dir = dir - cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D)         then dir = dir + cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0, 1, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
		instance.flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * C.flySpeed or Vector3.zero
		instance.flyBG.CFrame   = cam.CFrame
	else
		if instance.flyBV or instance.flyBG or instance.platformStandSet then stopFly() end
	end

	if C.noclip and char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				instance.noclipModified[part] = true
				part.CanCollide = false
			end
		end
	elseif next(instance.noclipModified) then
		for part in pairs(instance.noclipModified) do
			if part and part.Parent then pcall(function() part.CanCollide = true end) end
		end
		instance.noclipModified = {}
	end

	if C.speed and hum then
		if hum.WalkSpeed ~= C.speedValue then pcall(function() hum.WalkSpeed = C.speedValue end) end
		instance.speedApplied = true
	elseif instance.speedApplied then
		if hum then pcall(function() hum.WalkSpeed = 16 end) end
		instance.speedApplied = false
	end
end))

local tabsWin = ReGui:TabsWindow({
	Title    = "War Tycoon",
	Size     = UDim2.fromOffset(370, 440),
	NoSelect = true,
})
instance.window = tabsWin

local combat   = tabsWin:CreateTab({ Name = "Combat" })
local visual   = tabsWin:CreateTab({ Name = "Visual" })
local movement = tabsWin:CreateTab({ Name = "Movement" })
local guns     = tabsWin:CreateTab({ Name = "Guns" })

combat:Checkbox({
	Label = "Enable Silent Aim",
	Value = C.silentAim,
	Callback = function(_, v) C.silentAim = v end,
})

local aimRow = combat:Row()
aimRow:Checkbox({ Label = "Gun Aim",     Value = C.gunAim, Callback = function(_, v) C.gunAim = v end })
aimRow:Checkbox({ Label = "Vehicle Aim", Value = C.vehAim, Callback = function(_, v) C.vehAim = v end })

combat:Checkbox({
	Label = "Enable Wallcheck",
	Value = C.wallcheck,
	Callback = function(_, v) C.wallcheck = v end,
})

combat:Keybind({
	Label = "Aim Bind",
	Value = C.aimKey,
	IgnoreGameProcessed = false,
	KeyBlacklist = { Enum.UserInputType.MouseButton1 },
	OnKeybindSet = function(_, keyId)
		if typeof(keyId) == "EnumItem" and keyId.EnumType == Enum.KeyCode then
			C.aimKey     = keyId
			C.aimKeyName = keyId.Name
			C.aimHeld    = false
			C.aimToggled = false
			saveBinds(currentBindMap())
		end
	end,
	Callback = function() end,
})

combat:Checkbox({
	Label = "Enable Toggle Aim",
	Value = C.toggleAim,
	Callback = function(_, v)
		C.toggleAim  = v
		C.aimToggled = false
		C.aimHeld    = false
	end,
})

combat:Combo({
	Label    = "Aim Part",
	Selected = C.aimPart,
	Items    = { "Head", "Torso" },
	Callback = function(_, name) C.aimPart = name end,
})

combat:SliderInt({
	Label    = "FOV",
	Value    = C.fov, Minimum = 30, Maximum = 800,
	Callback = function(_, v) C.fov = v end,
})

visual:Checkbox({ Label = "Enable Box",         Value = C.box,      Callback = function(_, v) C.box = v end })
visual:Checkbox({ Label = "Enable Health",      Value = C.health,   Callback = function(_, v) C.health = v end })
visual:Checkbox({ Label = "Enable Name",        Value = C.showName, Callback = function(_, v) C.showName = v end })
visual:Checkbox({ Label = "Enable Distance",    Value = C.distance, Callback = function(_, v) C.distance = v end })
visual:Checkbox({ Label = "Enable Vehicle Box", Value = C.vehBox,   Callback = function(_, v) C.vehBox = v end })
visual:Checkbox({ Label = "Enable Vehicle Name",Value = C.vehName,  Callback = function(_, v) C.vehName = v end })
visual:Checkbox({
	Label = "FOV Hack",
	Value = C.fovHack,
	Callback = function(_, v)
		C.fovHack = v
		applyFovHackOnce()
	end,
})

local flyCheckbox, noclipCheckbox, speedCheckbox

local flyRow = movement:Row()
flyCheckbox = flyRow:Checkbox({
	Label = "Enable Fly",
	Value = C.fly,
	Callback = function(_, v) C.fly = v end,
})
flyRow:Keybind({
	Value = C.flyKey,
	IgnoreGameProcessed = false,
	KeyBlacklist = { Enum.UserInputType.MouseButton1 },
	OnKeybindSet = function(_, keyId)
		if typeof(keyId) == "EnumItem" and keyId.EnumType == Enum.KeyCode then
			C.flyKey     = keyId
			C.flyKeyName = keyId.Name
			saveBinds(currentBindMap())
		end
	end,
	Callback = function() end,
})

movement:SliderInt({
	Label    = "Fly Speed",
	Value    = C.flySpeed, Minimum = 1, Maximum = 1000,
	Callback = function(_, v) C.flySpeed = v end,
})

local noclipRow = movement:Row()
noclipCheckbox = noclipRow:Checkbox({
	Label = "Enable NoClip",
	Value = C.noclip,
	Callback = function(_, v) C.noclip = v end,
})
noclipRow:Keybind({
	Value = C.noclipKey,
	IgnoreGameProcessed = false,
	KeyBlacklist = { Enum.UserInputType.MouseButton1 },
	OnKeybindSet = function(_, keyId)
		if typeof(keyId) == "EnumItem" and keyId.EnumType == Enum.KeyCode then
			C.noclipKey     = keyId
			C.noclipKeyName = keyId.Name
			saveBinds(currentBindMap())
		end
	end,
	Callback = function() end,
})

local speedRow = movement:Row()
speedCheckbox = speedRow:Checkbox({
	Label = "Enable Speed",
	Value = C.speed,
	Callback = function(_, v) C.speed = v end,
})
speedRow:Keybind({
	Value = C.speedKey,
	IgnoreGameProcessed = false,
	KeyBlacklist = { Enum.UserInputType.MouseButton1 },
	OnKeybindSet = function(_, keyId)
		if typeof(keyId) == "EnumItem" and keyId.EnumType == Enum.KeyCode then
			C.speedKey     = keyId
			C.speedKeyName = keyId.Name
			saveBinds(currentBindMap())
		end
	end,
	Callback = function() end,
})

movement:SliderInt({
	Label    = "Speed",
	Value    = C.speedValue, Minimum = 1, Maximum = 1000,
	Callback = function(_, v) C.speedValue = v end,
})

addConn(UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	local kc = input.KeyCode
	if kc == C.aimKey then
		if C.toggleAim then C.aimToggled = not C.aimToggled else C.aimHeld = true end
	elseif kc == C.flyKey    and flyCheckbox    then flyCheckbox:Toggle()
	elseif kc == C.noclipKey and noclipCheckbox then noclipCheckbox:Toggle()
	elseif kc == C.speedKey  and speedCheckbox  then speedCheckbox:Toggle()
	end
end))
addConn(UIS.InputEnded:Connect(function(input)
	if input.KeyCode == C.aimKey then C.aimHeld = false end
end))

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Open Source Hub",
    Text = "War Tycoon Loaded",
    Duration = 5
})
