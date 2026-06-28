local a1 = getfenv().getgc or getgc
local b1 = getfenv().hookfunction or hookfunction
local c1 = getfenv().newcclosure or function(f) return f end
local d1 = getfenv().hookmetamethod or hookmetamethod
local h1 = getfenv().getnamecallmethod or getnamecallmethod

local p = game:GetService("Players").LocalPlayer
local R = {}

local function F(r)
	if R[r] then return true end
	local n = r.Name
	if #n == 36 and string.match(n, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
		R[r] = true
		return true
	end
	return false
end

local o
o = b1(Instance.new("RemoteEvent").FireServer, function(s, ...)
	local a = {...}
	if F(s) then return o(s, ...) end
	for _, v in ipairs(a) do
		if type(v) == "string" and string.find(string.lower(v), "kick") then return end
	end
	return o(s, ...)
end)

local n
n = d1(game, "__namecall", c1(function(s, ...)
	local m = h1()
	if s == p and (m == "Kick" or m == "kick" or m == "Destroy" or m == "destroy") then return end
	return n(s, ...)
end))

local k
k = b1(p.Kick, c1(function(self, ...)
	if not checkcaller() and self == p then return end
	return k(self, ...)
end))

local D
D = b1(p.Destroy, c1(function(self, ...)
	if not checkcaller() and self == p then return end
	return D(self, ...)
end))

pcall(function()
	for _, v in pairs(a1(true)) do
		if type(v) == "table" then
			pcall(function()
				if rawget(v, "Send") and type(rawget(v, "Send")) == "function" and rawget(v, "Get") and rawget(v, "Encrypt") then
					local s
					s = b1(v.Send, c1(function(cmd, ...)
						if type(cmd) == "string" then
							local c = string.lower(cmd)
							if c == "detected" or c == "logerror" then return end
						end
						return s(cmd, ...)
					end))
				end
				if rawget(v, "Kill") and type(rawget(v, "Kill")) == "function" and rawget(v, "Disconnect") then
					b1(v.Kill, c1(function(...) return end))
					b1(v.Disconnect, c1(function(...) return end))
				end
			end)
		end
	end
end)

for k, v in pairs(getgc(true)) do
	if pcall(function()
		return rawget(v, "indexInstance")
	end) and type(rawget(v, "indexInstance")) == "table" and (rawget(v, "indexInstance"))[1] == "kick" then
		setreadonly(v, false)
		v.tvk = {
			"kick",
			function()
				return game.Workspace:WaitForChild("")
			end
		}
	end
end

local IDENTIFIER = "AniPhobiaLiteActive"
local HOOK_FLAG = "AniPhobiaLite_HookInstalled"
local ACTIVE_KEY = "AniPhobiaLite_Active"
local FOLDER_NAME = "OtherWaifus"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

if _G[IDENTIFIER] and _G[IDENTIFIER].Cleanup then
	pcall(_G[IDENTIFIER].Cleanup)
end

local Session = {
	Connections = {},
	Toggled = false,
	Held = false,
	CurrentTarget = nil,
	AimKeybind = nil,
	State = {
		AimEnabled = false,
		Silent = false,
		VisibleCheck = false,
		ToggleMode = false,
		HitPart = "Head",
		FOV = 100,
		InfAmmo = false,
		InfMagAmmo = false,
		KillAura = false,
		AuraRadius = 60,
		Speed = false,
		SpeedValue = 50,
		NoClip = false,
		Fly = false,
		FlySpeed = 50,
		FullBright = false,
		PlayerEsp = false,
	},
}

local events = ReplicatedStorage:WaitForChild("Events", 10)
_G.AniPhobiaLite_gunEvent = events and events:WaitForChild("gunEvent", 10)

local function GetFolder()
	return Workspace:FindFirstChild(FOLDER_NAME)
end

local function IsValidTarget(model)
	if not model:IsA("Model") then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	local hrp = hum.RootPart or model:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end
	return true
end

local function GetAimPart(model)
	local part = model:FindFirstChild(Session.State.HitPart)
	if part and part:IsA("BasePart") then
		return part
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and hum.RootPart then
		return hum.RootPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function IsVisible(part, model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, Camera, LocalPlayer.Character }
	local origin = Camera.CFrame.Position
	local result = Workspace:Raycast(origin, part.Position - origin, params)
	return result == nil
end

local function GetTarget()
	local folder = GetFolder()
	if not folder then
		return nil
	end
	local inset = GuiService:GetGuiInset()
	local mouse = UserInputService:GetMouseLocation() - inset
	local best, bestModel, bestDist = nil, nil, nil
	for _, model in ipairs(folder:GetChildren()) do
		if IsValidTarget(model) then
			local part = GetAimPart(model)
			if part then
				local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local dist = (Vector2.new(screen.X, screen.Y) - mouse).Magnitude
					if dist <= Session.State.FOV and (not bestDist or dist < bestDist) then
						if (not Session.State.VisibleCheck) or IsVisible(part, model) then
							best, bestModel, bestDist = part, model, dist
						end
					end
				end
			end
		end
	end
	return best, bestModel
end

Session.GetTarget = GetTarget

local EspController = {
	Enabled = false,
	Boxes = {},
	RenderConn = nil,
}

local ESP_COLOR = Color3.fromRGB(255, 0, 0)

local function NewSquare()
	if type(Drawing) ~= "table" or not Drawing.new then
		return nil
	end
	local ok, sq = pcall(function()
		local s = Drawing.new("Square")
		s.Thickness = 2
		s.Filled = false
		s.Color = ESP_COLOR
		s.Transparency = 1
		s.Visible = false
		return s
	end)
	if ok then
		return sq
	end
	return nil
end

function EspController.Clear(model)
	local box = EspController.Boxes[model]
	if box then
		if box.square then
			pcall(function() box.square:Remove() end)
		end
		EspController.Boxes[model] = nil
	end
end

function EspController.Render()
	local cam = workspace.CurrentCamera
	local f = GetFolder()
	if not cam or not f then
		for model in pairs(EspController.Boxes) do
			EspController.Clear(model)
		end
		return
	end
	for model in pairs(EspController.Boxes) do
		if (not model.Parent) or model.Parent ~= f or (not IsValidTarget(model)) then
			EspController.Clear(model)
		end
	end
	for _, model in ipairs(f:GetChildren()) do
		if IsValidTarget(model) then
			local ok, cf, size = pcall(function()
				return model:GetBoundingBox()
			end)
			if ok and cf and size then
				local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
				local minX, minY = math.huge, math.huge
				local maxX, maxY = -math.huge, -math.huge
				local onScreen = false
				for sx = -1, 1, 2 do
					for sy = -1, 1, 2 do
						for sz = -1, 1, 2 do
							local world = (cf * CFrame.new(hx * sx, hy * sy, hz * sz)).Position
							local sp = cam:WorldToViewportPoint(world)
							if sp.Z > 0 then
								onScreen = true
								if sp.X < minX then minX = sp.X end
								if sp.Y < minY then minY = sp.Y end
								if sp.X > maxX then maxX = sp.X end
								if sp.Y > maxY then maxY = sp.Y end
							end
						end
					end
				end
				local box = EspController.Boxes[model]
				if onScreen then
					if not box then
						box = { square = NewSquare() }
						EspController.Boxes[model] = box
					end
					if box.square then
						box.square.Size = Vector2.new(maxX - minX, maxY - minY)
						box.square.Position = Vector2.new(minX, minY)
						box.square.Color = ESP_COLOR
						box.square.Visible = true
					end
				else
					if box and box.square then
						box.square.Visible = false
					end
				end
			end
		end
	end
end

function EspController.Enable()
	if EspController.Enabled then
		return
	end
	EspController.Enabled = true
	if type(Drawing) ~= "table" or not Drawing.new then
		print("[AniPhobiaLite] Drawing API not available - box ESP cannot render")
	end
	EspController.RenderConn = RunService.RenderStepped:Connect(function()
		if not EspController.Enabled then
			return
		end
		pcall(EspController.Render)
	end)
end

function EspController.Disable()
	EspController.Enabled = false
	if EspController.RenderConn then
		pcall(function() EspController.RenderConn:Disconnect() end)
		EspController.RenderConn = nil
	end
	for model in pairs(EspController.Boxes) do
		EspController.Clear(model)
	end
	EspController.Boxes = {}
end

Session.EspController = EspController

local FovCircle = {
	Drawing = nil,
	Gui = nil,
	Frame = nil,
}

function FovCircle.Init()
	if type(Drawing) == "table" and Drawing.new then
		local okDraw, obj = pcall(function()
			local c = Drawing.new("Circle")
			c.Thickness = 2
			c.NumSides = 64
			c.Radius = Session.State.FOV
			c.Filled = false
			c.Visible = false
			c.Color = Color3.fromRGB(255, 255, 255)
			return c
		end)
		if okDraw and obj then
			FovCircle.Drawing = obj
			return
		end
	end
	local parent = (gethui and gethui()) or game:GetService("CoreGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "AniPhobiaFov"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	pcall(function() gui.Parent = parent end)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(Session.State.FOV * 2, Session.State.FOV * 2)
	frame.Visible = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = frame
	FovCircle.Gui = gui
	FovCircle.Frame = frame
	FovCircle.Stroke = stroke
end

function FovCircle.Update()
	local visible = Session.State.AimEnabled
	local active = Session.State.Silent
	local color = active and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)
	local m = UserInputService:GetMouseLocation()
	local radius = Session.State.FOV
	if FovCircle.Drawing then
		FovCircle.Drawing.Visible = visible
		FovCircle.Drawing.Color = color
		FovCircle.Drawing.Radius = radius
		FovCircle.Drawing.Position = Vector2.new(m.X, m.Y)
	elseif FovCircle.Frame then
		FovCircle.Frame.Visible = visible
		FovCircle.Frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
		FovCircle.Frame.Position = UDim2.fromOffset(m.X, m.Y)
		if FovCircle.Stroke then
			FovCircle.Stroke.Color = color
		end
	end
end

function FovCircle.Destroy()
	if FovCircle.Drawing then
		pcall(function() FovCircle.Drawing:Remove() end)
		FovCircle.Drawing = nil
	end
	if FovCircle.Gui then
		pcall(function() FovCircle.Gui:Destroy() end)
		FovCircle.Gui = nil
		FovCircle.Frame = nil
	end
end

FovCircle.Init()
Session.FovCircle = FovCircle

table.insert(Session.Connections, RunService.RenderStepped:Connect(function()
	local bindKey = Session.AimKeybind and Session.AimKeybind.Value or nil
	local active = false
	if Session.State.AimEnabled then
		if not bindKey then
			active = true
		elseif Session.State.ToggleMode then
			active = Session.Toggled
		else
			active = Session.Held
		end
	end
	Session.State.Silent = active
	if active then
		local okT, part = pcall(GetTarget)
		Session.CurrentTarget = (okT and part) or nil
	else
		Session.CurrentTarget = nil
	end
	FovCircle.Update()
end))

if not _G[HOOK_FLAG] and hookmetamethod and getnamecallmethod then
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local S = _G[ACTIVE_KEY]
		if S and S.State.Silent then
			local okMethod, method = pcall(getnamecallmethod)
			if okMethod and method == "Fire" and self == _G.AniPhobiaLite_gunEvent then
				local args = table.pack(...)
				pcall(function()
					if args[1] == "VisualizeBullet" and type(args[4]) == "table" then
						local target = S.CurrentTarget
						if target then
							local firePoint = args[5] or args[6]
							local origin = firePoint and firePoint.WorldPosition
							if origin then
								local dir = (target.Position - origin).Unit
								for _, entry in ipairs(args[4]) do
									if type(entry) == "table" then
										entry[1] = dir
									end
								end
								if type(args[7]) == "table" then
									args[7].MousePosition = target.Position
								end
							end
						end
					end
				end)
				return oldNamecall(self, table.unpack(args, 1, args.n))
			end
		end
		return oldNamecall(self, ...)
	end)
	_G[HOOK_FLAG] = true
end

local InfAmmo = {
	Enabled = false,
	Connections = {},
	CurrentTool = nil,
}

local function FindMagUpvalue(gunClient)
	if type(getgc) ~= "function" then
		return nil
	end
	local isL = islclosure or function() return true end
	for _, fn in ipairs(getgc(true)) do
		if type(fn) == "function" and isL(fn) then
			local okInfo, info = pcall(debug.getinfo, fn)
			if okInfo and info and type(info.source) == "string" and info.source:find(gunClient.Name, 1, true) then
				local okUps, ups = pcall(debug.getupvalues, fn)
				if okUps and type(ups) == "table" then
					for index, val in pairs(ups) do
						if type(val) == "table" and rawget(val, "Mag") then
							return fn, index
						end
					end
				end
			end
		end
	end
	return nil
end

local function HookToolAmmo(tool)
	if not tool:IsA("Tool") then
		return
	end
	InfAmmo.CurrentTool = tool
	local valueFolder = tool:FindFirstChild("ValueFolder")
	if not valueFolder then
		return
	end
	local slot = valueFolder:FindFirstChild("1")
	local magValue = slot and slot:FindFirstChild("Mag")
	if not magValue then
		return
	end
	local gunClient = tool:FindFirstChild("GunClient")
	if not gunClient then
		return
	end
	local fn, index = FindMagUpvalue(gunClient)
	if not fn then
		return
	end
	task.spawn(function()
		while InfAmmo.CurrentTool == tool and InfAmmo.Enabled do
			local okGet, tbl = pcall(debug.getupvalue, fn, index)
			if okGet and tbl and tbl.Mag then
				tbl.Mag = 999
			end
			task.wait(0.05)
		end
	end)
end

function InfAmmo.Bind(char)
	if not char then
		return
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			HookToolAmmo(child)
		end
	end
	table.insert(InfAmmo.Connections, char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and InfAmmo.Enabled then
			task.wait(0.1)
			HookToolAmmo(c)
		end
	end))
	table.insert(InfAmmo.Connections, char.ChildRemoved:Connect(function(c)
		if c == InfAmmo.CurrentTool then
			InfAmmo.CurrentTool = nil
		end
	end))
end

function InfAmmo.Enable()
	if InfAmmo.Enabled then
		return
	end
	InfAmmo.Enabled = true
	InfAmmo.Bind(LocalPlayer.Character)
	table.insert(InfAmmo.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
		if InfAmmo.Enabled then
			InfAmmo.Bind(char)
		end
	end))
end

function InfAmmo.Disable()
	InfAmmo.Enabled = false
	InfAmmo.CurrentTool = nil
	for _, c in ipairs(InfAmmo.Connections) do
		pcall(function() c:Disconnect() end)
	end
	InfAmmo.Connections = {}
end

Session.InfAmmo = InfAmmo

local InfMagAmmo = {
	Enabled = false,
	Connections = {},
}

local function ForceMagViaSwitching(gunClient)
	if not gunClient or type(getgc) ~= "function" or type(getfenv) ~= "function" then
		return
	end
	local magTbl
	for _, v in pairs(getgc(true)) do
		if type(v) == "function" then
			local okFenv, fenv = pcall(getfenv, v)
			if okFenv and type(fenv) == "table" and fenv.script == gunClient then
				local okInfo, info = pcall(debug.getinfo, v)
				if okInfo and info and info.name == "OnSwitching" then
					local okUp, up = pcall(debug.getupvalue, v, 6)
					if okUp and type(up) == "table" and up.Mag ~= nil then
						magTbl = up
						break
					end
				end
			end
		end
	end
	if magTbl then
		task.spawn(function()
			while InfMagAmmo.Enabled do
				task.wait(0.1)
				if InfMagAmmo.Enabled then
					pcall(function() magTbl.Mag = 999 end)
				end
			end
		end)
	end
end

function InfMagAmmo.Bind(char)
	if not char then
		return
	end
	for _, c in ipairs(char:GetChildren()) do
		local gc = c:FindFirstChild("GunClient")
		if gc then
			ForceMagViaSwitching(gc)
		end
	end
	table.insert(InfMagAmmo.Connections, char.ChildAdded:Connect(function(c)
		if InfMagAmmo.Enabled then
			task.wait(0.1)
			local gc = c:FindFirstChild("GunClient")
			if gc then
				ForceMagViaSwitching(gc)
			end
		end
	end))
end

function InfMagAmmo.Enable()
	if InfMagAmmo.Enabled then
		return
	end
	InfMagAmmo.Enabled = true
	InfMagAmmo.Bind(LocalPlayer.Character)
	table.insert(InfMagAmmo.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
		if InfMagAmmo.Enabled then
			InfMagAmmo.Bind(char)
		end
	end))
end

function InfMagAmmo.Disable()
	InfMagAmmo.Enabled = false
	for _, c in ipairs(InfMagAmmo.Connections) do
		pcall(function() c:Disconnect() end)
	end
	InfMagAmmo.Connections = {}
end

Session.InfMagAmmo = InfMagAmmo

local KillAura = {
	Enabled = false,
	InflictTarget = nil,
	CachedTool = nil,
	CachedModuleName = nil,
}

do
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	KillAura.InflictTarget = remotes and remotes:FindFirstChild("InflictTarget")
end

local function ResolveModuleName(tool)
	if KillAura.CachedTool == tool and KillAura.CachedModuleName then
		return KillAura.CachedModuleName
	end
	local moduleName = tool.Name
	local gunClient = tool:FindFirstChild("GunClient")
	if gunClient and type(getgc) == "function" then
		for _, fn in ipairs(getgc(true)) do
			if type(fn) == "function" then
				local okInfo, info = pcall(debug.getinfo, fn)
				if okInfo and info and type(info.source) == "string" and info.source:find(gunClient.Name, 1, true) then
					local okUps, ups = pcall(debug.getupvalues, fn)
					if okUps and type(ups) == "table" then
						for _, val in pairs(ups) do
							if type(val) == "table" and type(rawget(val, "ModuleName")) == "string" then
								moduleName = val.ModuleName
								break
							end
						end
					end
				end
			end
			if moduleName ~= tool.Name then
				break
			end
		end
	end
	KillAura.CachedTool = tool
	KillAura.CachedModuleName = moduleName
	return moduleName
end

function KillAura.Enable()
	if KillAura.Enabled then
		return
	end
	KillAura.Enabled = true
	task.spawn(function()
		while KillAura.Enabled do
			pcall(function()
				local inflict = KillAura.InflictTarget
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local tool = char and char:FindFirstChildOfClass("Tool")
				local folder = GetFolder()
				if inflict and hrp and tool and folder then
					local moduleName = ResolveModuleName(tool)
					for _, model in ipairs(folder:GetChildren()) do
						if IsValidTarget(model) then
							local part = GetAimPart(model)
							if part and (part.Position - hrp.Position).Magnitude <= Session.State.AuraRadius then
								pcall(function()
									inflict:FireServer("GunMelee", tool, part, part.Size, moduleName)
								end)
							end
						end
					end
				end
			end)
			task.wait()
		end
	end)
end

function KillAura.Disable()
	KillAura.Enabled = false
	KillAura.CachedTool = nil
	KillAura.CachedModuleName = nil
end

Session.KillAura = KillAura

local function GetHumanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local SpeedController = {
	Enabled = false,
	Conn = nil,
}

function SpeedController.Enable()
	if SpeedController.Enabled then
		return
	end
	SpeedController.Enabled = true
	SpeedController.Conn = RunService.Heartbeat:Connect(function()
		if not SpeedController.Enabled then
			return
		end
		local hum = GetHumanoid()
		if hum then
			pcall(function() hum.WalkSpeed = Session.State.SpeedValue end)
		end
	end)
end

function SpeedController.Disable()
	SpeedController.Enabled = false
	if SpeedController.Conn then
		pcall(function() SpeedController.Conn:Disconnect() end)
		SpeedController.Conn = nil
	end
	local hum = GetHumanoid()
	if hum then
		pcall(function() hum.WalkSpeed = 16 end)
	end
end

Session.SpeedController = SpeedController

local NoClipController = {
	Enabled = false,
	Conn = nil,
}

function NoClipController.Enable()
	if NoClipController.Enabled then
		return
	end
	NoClipController.Enabled = true
	NoClipController.Conn = RunService.Stepped:Connect(function()
		if not NoClipController.Enabled then
			return
		end
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end)
end

function NoClipController.Disable()
	NoClipController.Enabled = false
	if NoClipController.Conn then
		pcall(function() NoClipController.Conn:Disconnect() end)
		NoClipController.Conn = nil
	end
end

Session.NoClipController = NoClipController

local FlyController = {
	Enabled = false,
	Conn = nil,
	BodyVelocity = nil,
}

function FlyController.Enable()
	if FlyController.Enabled then
		return
	end
	FlyController.Enabled = true
	FlyController.Conn = RunService.RenderStepped:Connect(function()
		if not FlyController.Enabled then
			return
		end
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local cam = workspace.CurrentCamera
		if not (hrp and cam) then
			return
		end
		if hum then
			hum.PlatformStand = true
		end
		local bv = FlyController.BodyVelocity
		if not bv or bv.Parent ~= hrp then
			if bv then
				pcall(function() bv:Destroy() end)
			end
			bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bv.P = 1250
			bv.Velocity = Vector3.new(0, 0, 0)
			bv.Parent = hrp
			FlyController.BodyVelocity = bv
		end
		local dir = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			dir = dir + cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			dir = dir - cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			dir = dir - cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			dir = dir + cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			dir = dir + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			dir = dir - Vector3.new(0, 1, 0)
		end
		local speed = Session.State.FlySpeed
		if dir.Magnitude > 0 then
			dir = dir.Unit * speed
		end
		bv.Velocity = dir
	end)
end

function FlyController.Disable()
	FlyController.Enabled = false
	if FlyController.Conn then
		pcall(function() FlyController.Conn:Disconnect() end)
		FlyController.Conn = nil
	end
	if FlyController.BodyVelocity then
		pcall(function() FlyController.BodyVelocity:Destroy() end)
		FlyController.BodyVelocity = nil
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function() hum.PlatformStand = false end)
	end
end

Session.FlyController = FlyController

local FullBrightController = {}

function FullBrightController.Setup()
	if _G.FullBrightExecuted then
		return
	end
	_G.FullBrightEnabled = false
	_G.NormalLightingSettings = {
		Brightness = game:GetService("Lighting").Brightness,
		ClockTime = game:GetService("Lighting").ClockTime,
		FogEnd = game:GetService("Lighting").FogEnd,
		GlobalShadows = game:GetService("Lighting").GlobalShadows,
		Ambient = game:GetService("Lighting").Ambient
	}
	game:GetService("Lighting"):GetPropertyChangedSignal("Brightness"):Connect(function()
		if game:GetService("Lighting").Brightness ~= 1 and game:GetService("Lighting").Brightness ~= _G.NormalLightingSettings.Brightness then
			_G.NormalLightingSettings.Brightness = game:GetService("Lighting").Brightness
			if not _G.FullBrightEnabled then
				repeat
					wait()
				until _G.FullBrightEnabled
			end
			game:GetService("Lighting").Brightness = 1
		end
	end)
	game:GetService("Lighting"):GetPropertyChangedSignal("ClockTime"):Connect(function()
		if game:GetService("Lighting").ClockTime ~= 12 and game:GetService("Lighting").ClockTime ~= _G.NormalLightingSettings.ClockTime then
			_G.NormalLightingSettings.ClockTime = game:GetService("Lighting").ClockTime
			if not _G.FullBrightEnabled then
				repeat
					wait()
				until _G.FullBrightEnabled
			end
			game:GetService("Lighting").ClockTime = 12
		end
	end)
	game:GetService("Lighting"):GetPropertyChangedSignal("FogEnd"):Connect(function()
		if game:GetService("Lighting").FogEnd ~= 786543 and game:GetService("Lighting").FogEnd ~= _G.NormalLightingSettings.FogEnd then
			_G.NormalLightingSettings.FogEnd = game:GetService("Lighting").FogEnd
			if not _G.FullBrightEnabled then
				repeat
					wait()
				until _G.FullBrightEnabled
			end
			game:GetService("Lighting").FogEnd = 786543
		end
	end)
	game:GetService("Lighting"):GetPropertyChangedSignal("GlobalShadows"):Connect(function()
		if game:GetService("Lighting").GlobalShadows ~= false and game:GetService("Lighting").GlobalShadows ~= _G.NormalLightingSettings.GlobalShadows then
			_G.NormalLightingSettings.GlobalShadows = game:GetService("Lighting").GlobalShadows
			if not _G.FullBrightEnabled then
				repeat
					wait()
				until _G.FullBrightEnabled
			end
			game:GetService("Lighting").GlobalShadows = false
		end
	end)
	game:GetService("Lighting"):GetPropertyChangedSignal("Ambient"):Connect(function()
		if game:GetService("Lighting").Ambient ~= Color3.fromRGB(178, 178, 178) and game:GetService("Lighting").Ambient ~= _G.NormalLightingSettings.Ambient then
			_G.NormalLightingSettings.Ambient = game:GetService("Lighting").Ambient
			if not _G.FullBrightEnabled then
				repeat
					wait()
				until _G.FullBrightEnabled
			end
			game:GetService("Lighting").Ambient = Color3.fromRGB(178, 178, 178)
		end
	end)
	game:GetService("Lighting").Brightness = 1
	game:GetService("Lighting").ClockTime = 12
	game:GetService("Lighting").FogEnd = 786543
	game:GetService("Lighting").GlobalShadows = false
	game:GetService("Lighting").Ambient = Color3.fromRGB(178, 178, 178)
	local LatestValue = true
	spawn(function()
		repeat
			wait()
		until _G.FullBrightEnabled
		while wait() do
			if _G.FullBrightEnabled ~= LatestValue then
				if not _G.FullBrightEnabled then
					game:GetService("Lighting").Brightness = _G.NormalLightingSettings.Brightness
					game:GetService("Lighting").ClockTime = _G.NormalLightingSettings.ClockTime
					game:GetService("Lighting").FogEnd = _G.NormalLightingSettings.FogEnd
					game:GetService("Lighting").GlobalShadows = _G.NormalLightingSettings.GlobalShadows
					game:GetService("Lighting").Ambient = _G.NormalLightingSettings.Ambient
				else
					game:GetService("Lighting").Brightness = 1
					game:GetService("Lighting").ClockTime = 12
					game:GetService("Lighting").FogEnd = 786543
					game:GetService("Lighting").GlobalShadows = false
					game:GetService("Lighting").Ambient = Color3.fromRGB(178, 178, 178)
				end
				LatestValue = not LatestValue
			end
		end
	end)
	_G.FullBrightExecuted = true
end

function FullBrightController.Enable()
	FullBrightController.Setup()
	_G.FullBrightEnabled = true
end

function FullBrightController.Disable()
	_G.FullBrightEnabled = false
end

Session.FullBrightController = FullBrightController

local PlayerEspController = {
	Enabled = false,
	Boxes = {},
	RenderConn = nil,
}

local PLAYER_ESP_COLOR = Color3.fromRGB(0, 255, 0)

local function NewPlayerSquare()
	if type(Drawing) ~= "table" or not Drawing.new then
		return nil
	end
	local ok, sq = pcall(function()
		local s = Drawing.new("Square")
		s.Thickness = 2
		s.Filled = false
		s.Color = PLAYER_ESP_COLOR
		s.Transparency = 1
		s.Visible = false
		return s
	end)
	if ok then
		return sq
	end
	return nil
end

function PlayerEspController.Clear(key)
	local box = PlayerEspController.Boxes[key]
	if box then
		if box.square then
			pcall(function() box.square:Remove() end)
		end
		PlayerEspController.Boxes[key] = nil
	end
end

function PlayerEspController.Render()
	local cam = workspace.CurrentCamera
	if not cam then
		for key in pairs(PlayerEspController.Boxes) do
			PlayerEspController.Clear(key)
		end
		return
	end
	for plr in pairs(PlayerEspController.Boxes) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if (not plr.Parent) or (not char) or (not hum) or hum.Health <= 0 then
			PlayerEspController.Clear(plr)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 then
				local ok, cf, size = pcall(function()
					return char:GetBoundingBox()
				end)
				if ok and cf and size then
					local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
					local minX, minY = math.huge, math.huge
					local maxX, maxY = -math.huge, -math.huge
					local onScreen = false
					for sx = -1, 1, 2 do
						for sy = -1, 1, 2 do
							for sz = -1, 1, 2 do
								local world = (cf * CFrame.new(hx * sx, hy * sy, hz * sz)).Position
								local sp = cam:WorldToViewportPoint(world)
								if sp.Z > 0 then
									onScreen = true
									if sp.X < minX then minX = sp.X end
									if sp.Y < minY then minY = sp.Y end
									if sp.X > maxX then maxX = sp.X end
									if sp.Y > maxY then maxY = sp.Y end
								end
							end
						end
					end
					local box = PlayerEspController.Boxes[plr]
					if onScreen then
						if not box then
							box = { square = NewPlayerSquare() }
							PlayerEspController.Boxes[plr] = box
						end
						if box.square then
							box.square.Size = Vector2.new(maxX - minX, maxY - minY)
							box.square.Position = Vector2.new(minX, minY)
							box.square.Color = PLAYER_ESP_COLOR
							box.square.Visible = true
						end
					else
						if box and box.square then
							box.square.Visible = false
						end
					end
				end
			end
		end
	end
end

function PlayerEspController.Enable()
	if PlayerEspController.Enabled then
		return
	end
	PlayerEspController.Enabled = true
	if type(Drawing) ~= "table" or not Drawing.new then
		print("[AniPhobiaLite] Drawing API not available - player ESP cannot render")
	end
	PlayerEspController.RenderConn = RunService.RenderStepped:Connect(function()
		if not PlayerEspController.Enabled then
			return
		end
		pcall(PlayerEspController.Render)
	end)
end

function PlayerEspController.Disable()
	PlayerEspController.Enabled = false
	if PlayerEspController.RenderConn then
		pcall(function() PlayerEspController.RenderConn:Disconnect() end)
		PlayerEspController.RenderConn = nil
	end
	for key in pairs(PlayerEspController.Boxes) do
		PlayerEspController.Clear(key)
	end
	PlayerEspController.Boxes = {}
end

Session.PlayerEspController = PlayerEspController

_G[ACTIVE_KEY] = Session

local ok, ReGui = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Dear-ReGui/refs/heads/main/ReGui.lua"))()
end)
if not ok or not ReGui then
	warn("[AniPhobia] ReGui load failed")
	return
end

local CONFIG_PATH = "AniPhobia_KeyBinds.txt"
local BIND_KEYS = { "AimBind", "EnableSpeed", "EnableFly", "NoClip", "KillAura", "FullBright" }
local DefaultBinds = {
	AimBind = "LeftControl",
	EnableSpeed = "Y",
	EnableFly = "U",
	NoClip = "J",
	KillAura = "K",
	FullBright = "B",
}

local fsRead = (type(readfile) == "function") and readfile or nil
local fsWrite = (type(writefile) == "function") and writefile or nil
local fsIsFile = (type(isfile) == "function") and isfile or nil
local fsIsFolder = (type(isfolder) == "function") and isfolder or nil
local fsMakeFolder = (type(makefolder) == "function") and makefolder or nil

local function KeyNameToCode(name)
	if not name or name == "None" or name == "" then
		return nil
	end
	local ok2, code = pcall(function()
		return Enum.KeyCode[name]
	end)
	if ok2 and code then
		return code
	end
	return nil
end

local function CodeToKeyName(code)
	if not code then
		return "None"
	end
	return code.Name
end

local Binds = {}
for _, k in ipairs(BIND_KEYS) do
	Binds[k] = DefaultBinds[k]
end

local function SerializeBinds()
	local lines = {}
	for _, k in ipairs(BIND_KEYS) do
		table.insert(lines, k .. "=" .. (Binds[k] or "None"))
	end
	return table.concat(lines, "\n")
end

local function SaveBinds()
	if not fsWrite then
		return
	end
	pcall(function()
		fsWrite(CONFIG_PATH, SerializeBinds())
	end)
end

local function LoadBinds()
	if fsIsFile and fsRead and fsIsFile(CONFIG_PATH) then
		local ok2, text = pcall(fsRead, CONFIG_PATH)
		if ok2 and text then
			for line in text:gmatch("[^\r\n]+") do
				local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
				if key and val and DefaultBinds[key] ~= nil then
					Binds[key] = val
				end
			end
			return
		end
	end
	SaveBinds()
end

LoadBinds()
Session.Binds = Binds
Session.SaveBinds = SaveBinds

local function MakeBindSaver(configKey)
	return function(_, key)
		Binds[configKey] = CodeToKeyName(key)
		SaveBinds()
	end
end

local Window = ReGui:TabsWindow({
	Title = "AniPhobia",
	Size = UDim2.fromOffset(264, 348),
})
task.defer(function()
	pcall(function() Window:Center() end)
end)

local EspTab = Window:CreateTab({ Name = "Esp", Focused = true })
local AimTab = Window:CreateTab({ Name = "Aim" })

EspTab:Separator({ Text = "ESP" })

EspTab:Checkbox({
	Label = "Enable Waifus ESP",
	Value = false,
	Callback = function(self, value)
		if value then
			EspController.Enable()
		else
			EspController.Disable()
		end
	end,
})

EspTab:Checkbox({
	Label = "Enable Player ESP",
	Value = false,
	Callback = function(self, value)
		Session.State.PlayerEsp = value
		if value then
			PlayerEspController.Enable()
		else
			PlayerEspController.Disable()
		end
	end,
})

AimTab:Separator({ Text = "Silent Aim" })

AimTab:Checkbox({
	Label = "Enable Silent Aim",
	Value = false,
	Callback = function(self, value)
		Session.State.AimEnabled = value
		if not value then
			Session.Toggled = false
			Session.Held = false
		end
	end,
})

AimTab:Checkbox({
	Label = "Enable Toggle Aim",
	Value = false,
	Callback = function(self, value)
		Session.State.ToggleMode = value
		Session.Toggled = false
		Session.Held = false
	end,
})

AimTab:Checkbox({
	Label = "Enable Wall Check",
	Value = false,
	Callback = function(self, value)
		Session.State.VisibleCheck = value
	end,
})

Session.AimKeybind = AimTab:Keybind({
	Label = "Aim Bind",
	Value = KeyNameToCode(Binds.AimBind),
	Callback = function() end,
	OnKeybindSet = MakeBindSaver("AimBind"),
})

AimTab:Combo({
	Label = "Aim Part",
	Placeholder = Session.State.HitPart,
	Items = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" },
	Selected = Session.State.HitPart,
	Callback = function(self, value)
		Session.State.HitPart = value
	end,
})

AimTab:SliderInt({
	Label = "FOV",
	Value = Session.State.FOV,
	Minimum = 30,
	Maximum = 600,
	Callback = function(self, value)
		Session.State.FOV = math.floor(value + 0.5)
	end,
})

local GunTab = Window:CreateTab({ Name = "Gun" })

GunTab:Separator({ Text = "Gun" })

GunTab:Checkbox({
	Label = "Inf Ammo",
	Value = false,
	Callback = function(self, value)
		Session.State.InfAmmo = value
		if value then
			InfAmmo.Enable()
		else
			InfAmmo.Disable()
		end
	end,
})

GunTab:Checkbox({
	Label = "Inf Mag Ammo",
	Value = false,
	Callback = function(self, value)
		Session.State.InfMagAmmo = value
		if value then
			InfMagAmmo.Enable()
		else
			InfMagAmmo.Disable()
		end
	end,
})

GunTab:Separator({ Text = "Kill Aura" })

local killAuraRow = GunTab:Row({})
local killAuraCheckbox = killAuraRow:Checkbox({
	Label = "Kill Aura",
	Value = false,
	Callback = function(self, value)
		Session.State.KillAura = value
		if value then
			KillAura.Enable()
		else
			KillAura.Disable()
		end
	end,
})
killAuraRow:Keybind({
	Label = "",
	Value = KeyNameToCode(Binds.KillAura),
	Callback = function()
		pcall(function() killAuraCheckbox:Toggle() end)
	end,
	OnKeybindSet = MakeBindSaver("KillAura"),
})

GunTab:SliderInt({
	Label = "Aura Radius",
	Value = Session.State.AuraRadius,
	Minimum = 1,
	Maximum = 1000,
	Callback = function(self, value)
		Session.State.AuraRadius = math.floor(value + 0.5)
	end,
})

local MiscTab = Window:CreateTab({ Name = "Misc" })

local speedRow = MiscTab:Row({})
local speedCheckbox = speedRow:Checkbox({
	Label = "Enable Speed",
	Value = false,
	Callback = function(self, value)
		Session.State.Speed = value
		if value then
			SpeedController.Enable()
		else
			SpeedController.Disable()
		end
	end,
})
speedRow:Keybind({
	Label = "",
	Value = KeyNameToCode(Binds.EnableSpeed),
	Callback = function()
		pcall(function() speedCheckbox:Toggle() end)
	end,
	OnKeybindSet = MakeBindSaver("EnableSpeed"),
})

local flyRow = MiscTab:Row({})
local flyCheckbox = flyRow:Checkbox({
	Label = "Enable Fly",
	Value = false,
	Callback = function(self, value)
		Session.State.Fly = value
		if value then
			FlyController.Enable()
		else
			FlyController.Disable()
		end
	end,
})
flyRow:Keybind({
	Label = "",
	Value = KeyNameToCode(Binds.EnableFly),
	Callback = function()
		pcall(function() flyCheckbox:Toggle() end)
	end,
	OnKeybindSet = MakeBindSaver("EnableFly"),
})

MiscTab:SliderInt({
	Label = "Speed",
	Value = Session.State.SpeedValue,
	Minimum = 1,
	Maximum = 500,
	Callback = function(self, value)
		Session.State.SpeedValue = math.floor(value + 0.5)
	end,
})

MiscTab:SliderInt({
	Label = "Fly Speed",
	Value = Session.State.FlySpeed,
	Minimum = 1,
	Maximum = 500,
	Callback = function(self, value)
		Session.State.FlySpeed = math.floor(value + 0.5)
	end,
})

local noclipRow = MiscTab:Row({})
local noclipCheckbox = noclipRow:Checkbox({
	Label = "NoClip",
	Value = false,
	Callback = function(self, value)
		Session.State.NoClip = value
		if value then
			NoClipController.Enable()
		else
			NoClipController.Disable()
		end
	end,
})
noclipRow:Keybind({
	Label = "",
	Value = KeyNameToCode(Binds.NoClip),
	Callback = function()
		pcall(function() noclipCheckbox:Toggle() end)
	end,
	OnKeybindSet = MakeBindSaver("NoClip"),
})

local fullbrightRow = MiscTab:Row({})
local fullbrightCheckbox = fullbrightRow:Checkbox({
	Label = "FullBright",
	Value = false,
	Callback = function(self, value)
		Session.State.FullBright = value
		if value then
			FullBrightController.Enable()
		else
			FullBrightController.Disable()
		end
	end,
})
fullbrightRow:Keybind({
	Label = "",
	Value = KeyNameToCode(Binds.FullBright),
	Callback = function()
		pcall(function() fullbrightCheckbox:Toggle() end)
	end,
	OnKeybindSet = MakeBindSaver("FullBright"),
})

local TAB_NAMES = { Esp = true, Aim = true, Gun = true, Misc = true }

local function tabNameOf(d)
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		local t = d.Text
		if type(t) == "string" then
			local s = t:gsub("%s", "")
			if TAB_NAMES[s] then return s end
		end
	end
	return nil
end

local function tabNameInSubtree(obj)
	local n = tabNameOf(obj)
	if n then return n end
	local ok, des = pcall(function() return obj:GetDescendants() end)
	if ok then
		for _, d in ipairs(des) do
			local nn = tabNameOf(d)
			if nn then return nn end
		end
	end
	return nil
end

local function tabButtonsOf(container)
	local kids = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") and tabNameInSubtree(c) then
			table.insert(kids, c)
		end
	end
	return kids
end

local function distinctTabChildren(container)
	local names = {}
	local cnt = 0
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			local nm = tabNameInSubtree(c)
			if nm and not names[nm] then
				names[nm] = true
				cnt = cnt + 1
			end
		end
	end
	return cnt
end

local function isHorizontalBar(container)
	local lay = container:FindFirstChildOfClass("UIListLayout")
	return lay ~= nil and lay.FillDirection == Enum.FillDirection.Horizontal
end

local function LocateTabBar()
	local roots = {}
	pcall(function() if gethui then table.insert(roots, gethui()) end end)
	pcall(function() table.insert(roots, game:GetService("CoreGui")) end)
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
		if pg then table.insert(roots, pg) end
	end)
	local matches = {}
	for _, root in ipairs(roots) do
		local ok, des = pcall(function() return root:GetDescendants() end)
		if ok then
			for _, d in ipairs(des) do
				if tabNameOf(d) then table.insert(matches, d) end
			end
		end
	end
	if #matches < 3 then return nil end
	local candSet = {}
	local cands = {}
	for _, m in ipairs(matches) do
		local node = m.Parent
		local depth = 0
		while node and depth < 10 do
			if node:IsA("GuiObject") and not candSet[node] then
				candSet[node] = true
				table.insert(cands, node)
			end
			node = node.Parent
			depth = depth + 1
		end
	end
	local best, bestScore = nil, -1
	for _, c in ipairs(cands) do
		local distinct = distinctTabChildren(c)
		if distinct >= 3 then
			local score = distinct * 1000
			if c.Name == "TabSelector" then score = score + 5000 end
			if isHorizontalBar(c) then score = score + 500 end
			local y = 0
			pcall(function() y = c.AbsolutePosition.Y end)
			score = score - y * 0.01
			if score > bestScore then
				bestScore = score
				best = c
			end
		end
	end
	return best
end

local function ApplyTabStretch(bar)
	local tabs = tabButtonsOf(bar)
	local n = #tabs
	if n < 3 then return end
	table.sort(tabs, function(a, b) return a.AbsolutePosition.X < b.AbsolutePosition.X end)
	local layout = bar:FindFirstChildOfClass("UIListLayout")
	local pad = 0
	if layout then
		pcall(function() layout.FillDirection = Enum.FillDirection.Horizontal end)
		pcall(function() pad = layout.Padding.Offset end)
		pcall(function() layout.HorizontalFlex = Enum.UIFlexAlignment.None end)
		pcall(function() layout.HorizontalAlignment = Enum.HorizontalAlignment.Left end)
	end
	local barW = bar.AbsoluteSize.X
	if barW <= 0 then return end
	local margin = 6
	local uipad = bar:FindFirstChildOfClass("UIPadding")
	if not uipad then
		pcall(function()
			uipad = Instance.new("UIPadding")
			uipad.Parent = bar
		end)
	end
	if uipad then
		pcall(function()
			local pl = uipad.PaddingLeft.Offset
			if pl and pl > 0 then margin = pl end
		end)
		pcall(function() uipad.PaddingLeft = UDim.new(0, margin) end)
		pcall(function() uipad.PaddingRight = UDim.new(0, margin) end)
	end
	local avail = barW - margin * 2
	if avail <= 0 then avail = barW end
	local each = math.floor((avail - pad * (n - 1)) / n)
	if each < 1 then each = 1 end
	for _, b in ipairs(tabs) do
		pcall(function()
			local as = b.AutomaticSize
			if as == Enum.AutomaticSize.XY then
				b.AutomaticSize = Enum.AutomaticSize.Y
			elseif as == Enum.AutomaticSize.X then
				b.AutomaticSize = Enum.AutomaticSize.None
			end
		end)
		pcall(function()
			local s = b.Size
			b.Size = UDim2.new(0, each, s.Y.Scale, s.Y.Offset)
		end)
		pcall(function()
			local flex = b:FindFirstChildOfClass("UIFlexItem")
			if flex then flex.FlexMode = Enum.UIFlexMode.None end
		end)
		pcall(function()
			for _, ch in ipairs(b:GetDescendants()) do
				if ch:IsA("UIListLayout") then
					pcall(function() ch.HorizontalAlignment = Enum.HorizontalAlignment.Center end)
				elseif ch:IsA("GuiObject") then
					local cas = ch.AutomaticSize
					if cas == Enum.AutomaticSize.XY then
						ch.AutomaticSize = Enum.AutomaticSize.Y
					elseif cas == Enum.AutomaticSize.X then
						ch.AutomaticSize = Enum.AutomaticSize.None
					end
					local cs = ch.Size
					ch.Size = UDim2.new(1, 0, cs.Y.Scale, cs.Y.Offset)
					if ch:IsA("TextLabel") or ch:IsA("TextButton") then
						pcall(function() ch.TextXAlignment = Enum.TextXAlignment.Center end)
					end
				end
			end
		end)
	end
end

task.spawn(function()
	local bar
	while true do
		if Session.Stopped then break end
		if not bar or not bar.Parent then
			bar = LocateTabBar()
		end
		if bar then
			pcall(ApplyTabStretch, bar)
		end
		task.wait(0.25)
	end
end)

table.insert(Session.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
		pcall(function() Window:ToggleVisibility() end)
		return
	end
	local bindKey = Session.AimKeybind and Session.AimKeybind.Value or nil
	if bindKey and input.KeyCode == bindKey then
		if Session.State.ToggleMode then
			Session.Toggled = not Session.Toggled
		else
			Session.Held = true
		end
	end
end))

table.insert(Session.Connections, UserInputService.InputEnded:Connect(function(input)
	local bindKey = Session.AimKeybind and Session.AimKeybind.Value or nil
	if bindKey and input.KeyCode == bindKey then
		Session.Held = false
	end
end))

Session.Cleanup = function()
	Session.Stopped = true
	Session.State.Silent = false
	pcall(function() EspController.Disable() end)
	pcall(function() InfAmmo.Disable() end)
	pcall(function() InfMagAmmo.Disable() end)
	pcall(function() KillAura.Disable() end)
	pcall(function() SpeedController.Disable() end)
	pcall(function() NoClipController.Disable() end)
	pcall(function() FlyController.Disable() end)
	pcall(function() FovCircle.Destroy() end)
	if _G[ACTIVE_KEY] == Session then
		_G[ACTIVE_KEY] = nil
	end
	for _, c in ipairs(Session.Connections) do
		pcall(function() c:Disconnect() end)
	end
	pcall(function() Window:Remove() end)
end

_G[IDENTIFIER] = Session

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Open Source Hub",
    Text = "AniPhobia Loaded",
    Duration = 5
})
