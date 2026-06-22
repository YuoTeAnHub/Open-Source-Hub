local IDENTIFIER = "ClearMenuActive"

if _G[IDENTIFIER] then
	pcall(function()
		_G[IDENTIFIER].Cleanup()
	end)
	_G[IDENTIFIER] = nil
end
_G.ClearMenuHookState = nil

local Session = {
	Connections = {},
	State = {},
	Controllers = {},
	Stopped = false,
	Cleanup = nil,
}
_G[IDENTIFIER] = Session

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local WSFolder = Workspace:WaitForChild("WS_Folder")
local EnemiesFolder = WSFolder:WaitForChild("Enemies")
local HostagesFolder = WSFolder:WaitForChild("Hostages")
local MedkitFolder = WSFolder:WaitForChild("MedkitFolder")

local function CreateEsp(config)
	local controller = {
		Highlights = {},
		Connections = {},
		Enabled = false,
	}
	local function Match(instance)
		if config.Match then
			return config.Match(instance)
		end
		return instance:IsA("Model") or instance:IsA("BasePart")
	end
	local function Apply(instance)
		if controller.Highlights[instance] then return end
		if not Match(instance) then return end
		if instance:FindFirstChildOfClass("Highlight") then return end
		local highlight = Instance.new("Highlight")
		highlight.Adornee = instance
		highlight.Enabled = true
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0
		highlight.OutlineColor = config.Color
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = instance
		controller.Highlights[instance] = highlight
	end
	local function Remove(instance)
		local highlight = controller.Highlights[instance]
		if highlight then
			pcall(function()
				highlight:Destroy()
			end)
			controller.Highlights[instance] = nil
		end
	end
	function controller.Enable()
		if controller.Enabled then return end
		controller.Enabled = true
		local items = config.Recursive and config.Source:GetDescendants() or config.Source:GetChildren()
		for _, item in next, items do
			Apply(item)
		end
		local addedSignal = config.Recursive and config.Source.DescendantAdded or config.Source.ChildAdded
		local removedSignal = config.Recursive and config.Source.DescendantRemoving or config.Source.ChildRemoved
		table.insert(controller.Connections, addedSignal:Connect(Apply))
		table.insert(controller.Connections, removedSignal:Connect(Remove))
	end
	function controller.Disable()
		controller.Enabled = false
		for _, connection in next, controller.Connections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		controller.Connections = {}
		for _, highlight in next, controller.Highlights do
			pcall(function()
				highlight:Destroy()
			end)
		end
		controller.Highlights = {}
	end
	return controller
end

local function GetHumanoid()
	local character = LocalPlayer.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local SpeedController = {
	Enabled = false,
	Speed = 16,
	Connections = {},
}
function SpeedController.Apply()
	if not SpeedController.Enabled then return end
	local humanoid = GetHumanoid()
	if humanoid then
		humanoid.WalkSpeed = SpeedController.Speed
	end
end
function SpeedController.SetSpeed(value)
	SpeedController.Speed = value
	SpeedController.Apply()
end
function SpeedController.Enable()
	if SpeedController.Enabled then return end
	SpeedController.Enabled = true
	SpeedController.Apply()
	table.insert(SpeedController.Connections, RunService.Heartbeat:Connect(SpeedController.Apply))
end
function SpeedController.Disable()
	SpeedController.Enabled = false
	for _, connection in next, SpeedController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	SpeedController.Connections = {}
	local humanoid = GetHumanoid()
	if humanoid then
		pcall(function()
			humanoid.WalkSpeed = 16
		end)
	end
end

local FlyController = {
	Enabled = false,
	Speed = 50,
	Connections = {},
}
function FlyController.SetSpeed(value)
	FlyController.Speed = value
end
function FlyController.Enable()
	if FlyController.Enabled then return end
	FlyController.Enabled = true
	table.insert(FlyController.Connections, RunService.RenderStepped:Connect(function(dt)
		if not FlyController.Enabled then return end
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then return end
		humanoid.PlatformStand = true
		local camera = Workspace.CurrentCamera
		local direction = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction = direction + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direction = direction - Vector3.new(0, 1, 0) end
		root.AssemblyLinearVelocity = Vector3.zero
		if direction.Magnitude > 0 then
			root.CFrame = root.CFrame + direction.Unit * FlyController.Speed * dt
		end
	end))
end
function FlyController.Disable()
	FlyController.Enabled = false
	for _, connection in next, FlyController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	FlyController.Connections = {}
	local humanoid = GetHumanoid()
	if humanoid then
		pcall(function()
			humanoid.PlatformStand = false
		end)
	end
end

local INF = math.huge

local InfAmmoController = {
	Enabled = false,
	Connections = {},
}
function InfAmmoController.Apply()
	if not InfAmmoController.Enabled then return end
	local folder = ReplicatedStorage:FindFirstChild("PlayerGunModels", true)
	if not folder then return end
	for _, descendant in next, folder:GetDescendants() do
		if descendant.Name == "CurrentAmmo" and descendant:IsA("DoubleConstrainedValue") then
			if descendant.MaxValue ~= INF or descendant.Value ~= INF then
				pcall(function()
					descendant.MaxValue = INF
					descendant.Value = INF
				end)
			end
		end
	end
end
function InfAmmoController.Enable()
	if InfAmmoController.Enabled then return end
	InfAmmoController.Enabled = true
	InfAmmoController.Apply()
	table.insert(InfAmmoController.Connections, RunService.Heartbeat:Connect(InfAmmoController.Apply))
end
function InfAmmoController.Disable()
	InfAmmoController.Enabled = false
	for _, connection in next, InfAmmoController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	InfAmmoController.Connections = {}
end

local InfStoredAmmoController = {
	Enabled = false,
	Connections = {},
}
function InfStoredAmmoController.Apply()
	if not InfStoredAmmoController.Enabled then return end
	local stored = LocalPlayer:FindFirstChild("StoredAmmo")
	if not stored then return end
	for _, value in next, stored:GetDescendants() do
		if value:IsA("NumberValue") and value.Value ~= INF then
			pcall(function()
				value.Value = INF
			end)
		end
	end
end
function InfStoredAmmoController.Enable()
	if InfStoredAmmoController.Enabled then return end
	InfStoredAmmoController.Enabled = true
	InfStoredAmmoController.Apply()
	table.insert(InfStoredAmmoController.Connections, RunService.Heartbeat:Connect(InfStoredAmmoController.Apply))
end
function InfStoredAmmoController.Disable()
	InfStoredAmmoController.Enabled = false
	for _, connection in next, InfStoredAmmoController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	InfStoredAmmoController.Connections = {}
end

local function ForEachWeaponSettings(callback)
	local roots = {}
	table.insert(roots, LocalPlayer)
	if LocalPlayer.Character then
		table.insert(roots, LocalPlayer.Character)
	end
	for _, root in next, roots do
		for _, descendant in next, root:GetDescendants() do
			if descendant:IsA("ModuleScript") and descendant.Name == "Settings" then
				local ok, result = pcall(require, descendant)
				if ok and type(result) == "table" then
					callback(result)
				end
			end
		end
	end
end

local NoRecoilController = {
	Enabled = false,
	Connections = {},
	Cache = {},
}
function NoRecoilController.Apply()
	if not NoRecoilController.Enabled then return end
	ForEachWeaponSettings(function(settings)
		if type(settings.recoil) ~= "table" then return end
		if not NoRecoilController.Cache[settings] then
			NoRecoilController.Cache[settings] = {
				Size = settings.recoil.Size,
				shake = settings.recoil.shake,
				Elasticity = settings.recoil.Elasticity,
				FadeInTime = settings.recoil.FadeInTime,
				FadeOutTime = settings.recoil.FadeOutTime,
			}
		end
		settings.recoil.Size = 0
		settings.recoil.shake = 0
		settings.recoil.Elasticity = 0
		settings.recoil.FadeInTime = 0
		settings.recoil.FadeOutTime = 0
	end)
end
function NoRecoilController.Enable()
	if NoRecoilController.Enabled then return end
	NoRecoilController.Enabled = true
	NoRecoilController.Apply()
	table.insert(NoRecoilController.Connections, RunService.Heartbeat:Connect(NoRecoilController.Apply))
end
function NoRecoilController.Disable()
	NoRecoilController.Enabled = false
	for _, connection in next, NoRecoilController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	NoRecoilController.Connections = {}
	for settings, original in next, NoRecoilController.Cache do
		if type(settings.recoil) == "table" then
			settings.recoil.Size = original.Size
			settings.recoil.shake = original.shake
			settings.recoil.Elasticity = original.Elasticity
			settings.recoil.FadeInTime = original.FadeInTime
			settings.recoil.FadeOutTime = original.FadeOutTime
		end
	end
	NoRecoilController.Cache = {}
end

local RapidFireController = {
	Enabled = false,
	Connections = {},
	Cache = {},
	Value = 0.05,
}
function RapidFireController.Apply()
	if not RapidFireController.Enabled then return end
	ForEachWeaponSettings(function(settings)
		if settings.FireRate == nil then return end
		if RapidFireController.Cache[settings] == nil then
			RapidFireController.Cache[settings] = settings.FireRate
		end
		settings.FireRate = RapidFireController.Value
	end)
end
function RapidFireController.Enable()
	if RapidFireController.Enabled then return end
	RapidFireController.Enabled = true
	RapidFireController.Apply()
	table.insert(RapidFireController.Connections, RunService.Heartbeat:Connect(RapidFireController.Apply))
end
function RapidFireController.Disable()
	RapidFireController.Enabled = false
	for _, connection in next, RapidFireController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	RapidFireController.Connections = {}
	for settings, original in next, RapidFireController.Cache do
		settings.FireRate = original
	end
	RapidFireController.Cache = {}
end

local BulletsModController = {
	Enabled = false,
	Connections = {},
	Cache = {},
	Value = 20,
}
function BulletsModController.Apply()
	if not BulletsModController.Enabled then return end
	ForEachWeaponSettings(function(settings)
		if settings.BulletsFired == nil then return end
		if BulletsModController.Cache[settings] == nil then
			BulletsModController.Cache[settings] = settings.BulletsFired
		end
		settings.BulletsFired = BulletsModController.Value
	end)
end
function BulletsModController.Enable()
	if BulletsModController.Enabled then return end
	BulletsModController.Enabled = true
	BulletsModController.Apply()
	table.insert(BulletsModController.Connections, RunService.Heartbeat:Connect(BulletsModController.Apply))
end
function BulletsModController.Disable()
	BulletsModController.Enabled = false
	for _, connection in next, BulletsModController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	BulletsModController.Connections = {}
	for settings, original in next, BulletsModController.Cache do
		settings.BulletsFired = original
	end
	BulletsModController.Cache = {}
end

local SpreadController = {
	Enabled = false,
	Connections = {},
	Cache = {},
}
function SpreadController.Apply()
	if not SpreadController.Enabled then return end
	local folder = ReplicatedStorage:FindFirstChild("PlayerGunModels", true)
	if not folder then return end
	for _, descendant in next, folder:GetDescendants() do
		if descendant:IsA("NumberValue") and descendant.Name == "Spread" then
			if SpreadController.Cache[descendant] == nil then
				SpreadController.Cache[descendant] = descendant.Value
			end
			if descendant.Value ~= 0 then
				pcall(function()
					descendant.Value = 0
				end)
			end
		end
	end
end
function SpreadController.Enable()
	if SpreadController.Enabled then return end
	SpreadController.Enabled = true
	SpreadController.Apply()
	table.insert(SpreadController.Connections, RunService.Heartbeat:Connect(SpreadController.Apply))
end
function SpreadController.Disable()
	SpreadController.Enabled = false
	for _, connection in next, SpreadController.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	SpreadController.Connections = {}
	for value, original in next, SpreadController.Cache do
		pcall(function()
			value.Value = original
		end)
	end
	SpreadController.Cache = {}
end

local EnemyEsp = CreateEsp({
	Source = EnemiesFolder,
	Color = Color3.fromRGB(255, 0, 0),
})
local HostageEsp = CreateEsp({
	Source = HostagesFolder,
	Color = Color3.fromRGB(0, 255, 0),
})
local MedkitEsp = CreateEsp({
	Source = MedkitFolder,
	Recursive = true,
	Color = Color3.fromRGB(255, 140, 0),
	Match = function(instance)
		return instance:IsA("BasePart") and instance.Name == "Medkit"
	end,
})
local KeycardEsp = CreateEsp({
	Source = Workspace,
	Recursive = true,
	Color = Color3.fromRGB(0, 170, 255),
	Match = function(instance)
		return instance:IsA("BasePart") and instance.Name == "Keycard"
	end,
})

Session.Controllers.EnemyEsp = EnemyEsp
Session.Controllers.HostageEsp = HostageEsp
Session.Controllers.MedkitEsp = MedkitEsp
Session.Controllers.KeycardEsp = KeycardEsp
Session.Controllers.Speed = SpeedController
Session.Controllers.Fly = FlyController
Session.Controllers.InfAmmo = InfAmmoController
Session.Controllers.InfStoredAmmo = InfStoredAmmoController
Session.Controllers.NoRecoil = NoRecoilController
Session.Controllers.RapidFire = RapidFireController
Session.Controllers.BulletsMod = BulletsModController
Session.Controllers.Spread = SpreadController

local function Revert()
	EnemyEsp.Disable()
	HostageEsp.Disable()
	MedkitEsp.Disable()
	KeycardEsp.Disable()
	SpeedController.Disable()
	FlyController.Disable()
	InfAmmoController.Disable()
	InfStoredAmmoController.Disable()
	NoRecoilController.Disable()
	RapidFireController.Disable()
	BulletsModController.Disable()
	SpreadController.Disable()
	Session.State = {}
end

local ok, ReGui = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Dear-ReGui/refs/heads/main/ReGui.lua"))()
end)
if not ok or not ReGui then
	warn("[ClearMenu] ReGui load failed")
	return
end

local Window = ReGui:TabsWindow({
	Title = "Clear Menu",
	Size = UDim2.fromOffset(264, 348),
})
task.defer(function()
	pcall(function() Window:Center() end)
end)

local EspTab = Window:CreateTab({ Name = "ESP", Focused = true })
local GunTab = Window:CreateTab({ Name = "Gun" })
local SpeedTab = Window:CreateTab({ Name = "Speed" })
local FlyTab = Window:CreateTab({ Name = "Fly" })

EspTab:Separator({ Text = "ESP" })

local espRow1 = EspTab:Row({})
espRow1:Checkbox({
	Label = "Enemy Esp",
	Value = false,
	Callback = function(self, value)
		Session.State.EnemyEsp = value
		if value then
			EnemyEsp.Enable()
		else
			EnemyEsp.Disable()
		end
	end,
})
espRow1:Checkbox({
	Label = "Medkit Esp",
	Value = false,
	Callback = function(self, value)
		Session.State.MedkitEsp = value
		if value then
			MedkitEsp.Enable()
		else
			MedkitEsp.Disable()
		end
	end,
})

local espRow2 = EspTab:Row({})
espRow2:Checkbox({
	Label = "Hostage Esp",
	Value = false,
	Callback = function(self, value)
		Session.State.HostageEsp = value
		if value then
			HostageEsp.Enable()
		else
			HostageEsp.Disable()
		end
	end,
})
espRow2:Checkbox({
	Label = "Keycard Esp",
	Value = false,
	Callback = function(self, value)
		Session.State.KeycardEsp = value
		if value then
			KeycardEsp.Enable()
		else
			KeycardEsp.Disable()
		end
	end,
})

GunTab:Separator({ Text = "Weapons" })

GunTab:Checkbox({
	Label = "Inf Ammo",
	Value = false,
	Callback = function(self, value)
		Session.State.InfAmmo = value
		if value then
			InfAmmoController.Enable()
		else
			InfAmmoController.Disable()
		end
	end,
})
GunTab:Checkbox({
	Label = "Inf Stored Ammo",
	Value = false,
	Callback = function(self, value)
		Session.State.InfStoredAmmo = value
		if value then
			InfStoredAmmoController.Enable()
		else
			InfStoredAmmoController.Disable()
		end
	end,
})
GunTab:Checkbox({
	Label = "No Recoil",
	Value = false,
	Callback = function(self, value)
		Session.State.NoRecoil = value
		if value then
			NoRecoilController.Enable()
		else
			NoRecoilController.Disable()
		end
	end,
})
GunTab:Checkbox({
	Label = "Rapid Fire",
	Value = false,
	Callback = function(self, value)
		Session.State.RapidFire = value
		if value then
			RapidFireController.Enable()
		else
			RapidFireController.Disable()
		end
	end,
})
GunTab:Checkbox({
	Label = "20 Bullets Mod",
	Value = false,
	Callback = function(self, value)
		Session.State.BulletsMod = value
		if value then
			BulletsModController.Enable()
		else
			BulletsModController.Disable()
		end
	end,
})
GunTab:Checkbox({
	Label = "No Spread",
	Value = false,
	Callback = function(self, value)
		Session.State.NoSpread = value
		if value then
			SpreadController.Enable()
		else
			SpreadController.Disable()
		end
	end,
})

SpeedTab:Checkbox({
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
SpeedTab:SliderInt({
	Label = "Speed",
	Value = 16,
	Minimum = 1,
	Maximum = 200,
	Callback = function(self, value)
		SpeedController.SetSpeed(math.floor(value + 0.5))
	end,
})

FlyTab:Checkbox({
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
FlyTab:SliderInt({
	Label = "Fly Speed",
	Value = 50,
	Minimum = 1,
	Maximum = 200,
	Callback = function(self, value)
		FlyController.SetSpeed(math.floor(value + 0.5))
	end,
})

local TAB_NAMES = { ESP = true, Gun = true, Speed = true, Fly = true }

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
	end
end))

function Session.Cleanup()
	Session.Stopped = true
	Revert()
	for _, connection in next, Session.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	Session.Connections = {}
	if _G[IDENTIFIER] == Session then
		_G[IDENTIFIER] = nil
	end
	pcall(function()
		Window:Remove()
	end)
end

_G[IDENTIFIER] = Session
warn("Open Source Hub: CLEAR loaded")
