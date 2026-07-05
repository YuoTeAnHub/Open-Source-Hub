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
		SilentSpeed   = false,
		SilentSpeedMul = 1,
		Speed         = false,
		SpeedValue    = 16,
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
    NoSelect = true,
})
DeadZone.Gui = Window

--// Combat tab (Silent Speed)
local CombatTab = Window:CreateTab({ Name = "Combat" })

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
