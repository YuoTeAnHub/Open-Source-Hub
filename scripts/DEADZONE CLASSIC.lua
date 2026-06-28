loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/Bypasses/DEADZONE%20CLASSIC.lua"))()


local env = (getgenv and getgenv()) or _G

if env.DeadZone and type(env.DeadZone.Unload) == "function" then
	pcall(env.DeadZone.Unload)
end

local DeadZone = {
	Connections = {},
	Esp     = {},
	Tracked = {},
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
		Dot           = false,
		DisableCursor = false,
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
			if data.highlight then pcall(function() data.highlight:Destroy() end) end
			if data.box then pcall(function() data.box:Remove() end) end
			if data.texts then
				for _, t in pairs(data.texts) do pcall(function() t:Remove() end) end
			end
		end
		table.clear(DeadZone.Esp)
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
	Player = Color3.fromRGB(255, 60, 60),
	Zombie = Color3.fromRGB(60, 255, 60),
	Dot    = Color3.fromRGB(255, 0, 0),
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
	if data.highlight then pcall(function() data.highlight:Destroy() end) end
	if data.box then pcall(function() data.box:Remove() end) end
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
	ensureText(data.texts, "health", DeadZone.Flags.Health)
end

local function getBounds(model)
	local hb = model:FindFirstChild("Hitbox")
	if hb then
		if hb:IsA("BasePart") then return hb.CFrame, hb.Size end
		if hb:IsA("Model") then return hb:GetBoundingBox() end
	end
	return model:GetBoundingBox()
end

local function getScreenBounds(model)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local cf, size = getBounds(model)
	local corners = {
		cf * Vector3.new( size.X/2,  size.Y/2,  size.Z/2),
		cf * Vector3.new(-size.X/2,  size.Y/2,  size.Z/2),
		cf * Vector3.new( size.X/2, -size.Y/2,  size.Z/2),
		cf * Vector3.new(-size.X/2, -size.Y/2,  size.Z/2),
		cf * Vector3.new( size.X/2,  size.Y/2, -size.Z/2),
		cf * Vector3.new(-size.X/2,  size.Y/2, -size.Z/2),
		cf * Vector3.new( size.X/2, -size.Y/2, -size.Z/2),
		cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
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

local function updateBox(model, box)
	local minX, minY, maxX, maxY = getScreenBounds(model)
	if not minX then box.Visible = false return end
	box.Size     = Vector2.new(maxX - minX, maxY - minY)
	box.Position = Vector2.new(minX, minY)
	box.Visible  = true
end

local function updateLabels(model, data, t)
	local texts = data.texts
	if not texts then return end
	local minX, minY, maxX, maxY = getScreenBounds(model)
	local onScreen = minX ~= nil
	local cx = onScreen and (minX + maxX) / 2 or 0
	local color = COLORS[data.kind]

	if texts.name then
		if onScreen and DeadZone.Flags.Name then
			texts.name.Text     = model.Name
			texts.name.Color    = color
			texts.name.Position = Vector2.new(cx, minY - 16)
			texts.name.Visible  = true
		else
			texts.name.Visible = false
		end
	end

	local belowY = onScreen and maxY or 0

	if texts.dist then
		if onScreen and DeadZone.Flags.Distance then
			local d = 0
			local root = getSelfRoot()
			local zr = getModelRoot(model)
			if root and zr then d = math.floor((zr.Position - root.Position).Magnitude) end
			texts.dist.Text     = tostring(d) .. "m"
			texts.dist.Color    = Color3.fromRGB(255, 255, 255)
			texts.dist.Position = Vector2.new(cx, belowY + 2)
			texts.dist.Visible  = true
			belowY = belowY + 16
		else
			texts.dist.Visible = false
		end
	end

	if texts.health then
		local hum = t and t.hum
		if onScreen and DeadZone.Flags.Health and hum then
			local hp    = math.floor(hum.Health)
			local maxhp = hum.MaxHealth
			local frac  = (maxhp > 0) and math.clamp(hum.Health / maxhp, 0, 1) or 0
			texts.health.Text     = "HP: " .. tostring(hp)
			texts.health.Color    = Color3.fromRGB(255 - math.floor(195 * frac), 60 + math.floor(195 * frac), 60)
			texts.health.Position = Vector2.new(cx, belowY + 2)
			texts.health.Visible  = true
			belowY = belowY + 16
		else
			texts.health.Visible = false
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

ensureDot()

track(RunService.RenderStepped:Connect(function()
	for model, t in pairs(DeadZone.Tracked) do
		if not model.Parent or isSelf(model) then
			untrack(model)
		else
			local show, kind = classify(model)
			if show then
				ensureEsp(model, kind)
				local data = DeadZone.Esp[model]
				if data then
					if data.box then updateBox(model, data.box) end
					updateLabels(model, data, t)
				end
			else
				removeEsp(model)
			end
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

local Window = ReGui:TabsWindow({
	Title = "Dead Zone",
	Size = UDim2.fromOffset(360, 420),
})
DeadZone.Gui = Window

local VisualsTab = Window:CreateTab({ Name = "Visuals" })

VisualsTab:Checkbox({
	Label = "Enable Player Esp",
	Value = DeadZone.Flags.PlayerEsp,
	Callback = function(_, v) DeadZone.Flags.PlayerEsp = v end,
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

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Open Source Hub",
    Text = "DEADZONE Loaded",
    Duration = 5
})
