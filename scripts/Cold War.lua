if _G.ColdWar and _G.ColdWar.Destroy then
    pcall(_G.ColdWar.Destroy)
    _G.ColdWar = nil
end

local ColdWar = {}
_G.ColdWar = ColdWar

local function log(...)  print("[Cold War]", ...) end
local function warnf(...) warn("[Cold War]", ...) end
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then warnf(err) end
    end
end

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local LogService        = game:GetService("LogService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

ColdWar.Connections = {}
ColdWar.Drawings    = {}
ColdWar.Instances   = {}

local function track(conn) table.insert(ColdWar.Connections, conn); return conn end
local function trackInst(i)  table.insert(ColdWar.Instances, i);   return i end
local function trackDraw(d)  table.insert(ColdWar.Drawings, d);    return d end

local ok, ReGui = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/YuoTeAnHub/Dear-ReGui/refs/heads/main/ReGui.lua"))()
end)
if not ok or not ReGui then warnf("Failed to load ReGui:", ReGui); return end

local ok2, prefabs = pcall(function()
    return game:GetObjects("rbxassetid://" .. ReGui.PrefabsId)[1]
end)
if not ok2 or not prefabs then warnf("Failed to load prefabs:", prefabs); return end

pcall(function() ReGui:Init({ Prefabs = prefabs }) end)

local Window = ReGui:TabsWindow({
    Title    = "Cold War",
    Size     = UDim2.fromOffset(420, 475),
    NoSelect = true,
}):Center()
ColdWar.Window = Window

local VisualTab   = Window:CreateTab({ Name = "Visuals"  })
local CombatTab   = Window:CreateTab({ Name = "Combat"   })
local GunTab      = Window:CreateTab({ Name = "Gun Mods" })
local MovementTab = Window:CreateTab({ Name = "Movement" })
local OptionsTab  = Window:CreateTab({ Name = "Options"  })

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end))

local ESP = {
    Enabled = false, Box = false, Line = false, Chams = false,
    TeamCheck = false, NoTeamEsp = false,
    Health = false, Name = false, Distance = false,
}

local HighlightHost = (gethui and gethui()) or game:GetService("CoreGui")
local Objects = {}

local function newDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return trackDraw(d)
end

local function buildFor(player)
    if player == LocalPlayer then return end
    if Objects[player] then return end
    local o = {}
    o.BoxOutline = newDrawing("Square", { Thickness = 3, Filled = false, Color = Color3.new(0,0,0), Transparency = 1, Visible = false })
    o.Box        = newDrawing("Square", { Thickness = 1, Filled = false, Color = Color3.new(1,1,1), Transparency = 1, Visible = false })
    o.Line       = newDrawing("Line",   { Thickness = 1, Color = Color3.new(1,1,1), Transparency = 1, Visible = false })
    o.HealthBG   = newDrawing("Line",   { Thickness = 3, Color = Color3.new(0,0,0), Transparency = 1, Visible = false })
    o.Health     = newDrawing("Line",   { Thickness = 1, Color = Color3.fromRGB(0,255,0), Transparency = 1, Visible = false })
    o.Name       = newDrawing("Text",   { Size = 13, Center = true, Outline = true, Font = 2, Color = Color3.new(1,1,1), Visible = false })
    o.Distance   = newDrawing("Text",   { Size = 12, Center = true, Outline = true, Font = 2, Color = Color3.new(1,1,1), Visible = false })
    local hl = Instance.new("Highlight")
    hl.Enabled = false; hl.FillColor = Color3.new(1,1,1); hl.OutlineColor = Color3.new(1,1,1)
    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = HighlightHost
    o.Highlight = trackInst(hl)
    Objects[player] = o
end

local function killFor(player)
    local o = Objects[player]; if not o then return end
    for _, v in pairs(o) do
        if typeof(v) == "Instance" then pcall(function() v:Destroy() end)
        else pcall(function() v:Remove() end) end
    end
    Objects[player] = nil
end

for _, p in ipairs(Players:GetPlayers()) do pcall(buildFor, p) end
track(Players.PlayerAdded:Connect(safe(buildFor)))
track(Players.PlayerRemoving:Connect(safe(killFor)))

local function hideAll(o)
    o.Box.Visible = false; o.BoxOutline.Visible = false
    o.Line.Visible = false; o.Health.Visible = false; o.HealthBG.Visible = false
    o.Name.Visible = false; o.Distance.Visible = false; o.Highlight.Enabled = false
end

local function espTick()
    for player, o in pairs(Objects) do
        local shown = false
        if ESP.Enabled then
            local char     = player.Character
            local hrp      = char and char:FindFirstChild("HumanoidRootPart")
            local head     = char and char:FindFirstChild("Head")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local teamSkip = ESP.NoTeamEsp and LocalPlayer.Team and player.Team == LocalPlayer.Team
            if char and hrp and head and humanoid and humanoid.Health > 0 and not teamSkip then
                local topWorld = head.Position + Vector3.new(0, 0.6, 0)
                local botWorld = hrp.Position  + Vector3.new(0, -3.0, 0)
                local topS, onScreen = Camera:WorldToViewportPoint(topWorld)
                local botS, _        = Camera:WorldToViewportPoint(botWorld)
                if onScreen and topS.Z > 0 then
                    local h  = math.abs(botS.Y - topS.Y)
                    local w  = h * 0.55
                    local cx = (topS.X + botS.X) * 0.5
                    local x  = cx - w * 0.5
                    local y  = math.min(topS.Y, botS.Y)
                    local color = Color3.new(1,1,1)
                    if ESP.TeamCheck and player.Team then color = player.TeamColor.Color end
                    shown = true
                    if ESP.Box then
                        o.BoxOutline.Position = Vector2.new(x, y); o.BoxOutline.Size = Vector2.new(w, h); o.BoxOutline.Visible = true
                        o.Box.Position = Vector2.new(x, y); o.Box.Size = Vector2.new(w, h); o.Box.Color = color; o.Box.Visible = true
                    else o.Box.Visible = false; o.BoxOutline.Visible = false end
                    if ESP.Line then
                        local vp = Camera.ViewportSize
                        o.Line.From = Vector2.new(vp.X * 0.5, vp.Y); o.Line.To = Vector2.new(cx, y + h); o.Line.Color = color; o.Line.Visible = true
                    else o.Line.Visible = false end
                    if ESP.Chams then
                        o.Highlight.Adornee = char; o.Highlight.FillColor = color; o.Highlight.OutlineColor = color; o.Highlight.Enabled = true
                    else o.Highlight.Enabled = false end
                    if ESP.Health then
                        local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                        local barX = x - 4
                        o.HealthBG.From = Vector2.new(barX, y - 1); o.HealthBG.To = Vector2.new(barX, y + h + 1); o.HealthBG.Visible = true
                        o.Health.From = Vector2.new(barX, y + h); o.Health.To = Vector2.new(barX, y + h - h * frac); o.Health.Visible = true
                    else o.Health.Visible = false; o.HealthBG.Visible = false end
                    if ESP.Name then
                        o.Name.Position = Vector2.new(cx, y - 16); o.Name.Text = player.DisplayName; o.Name.Color = color; o.Name.Visible = true
                    else o.Name.Visible = false end
                    if ESP.Distance then
                        local d = (Camera.CFrame.Position - hrp.Position).Magnitude
                        o.Distance.Position = Vector2.new(cx, y + h + 2); o.Distance.Text = string.format("%d studs", math.floor(d))
                        o.Distance.Color = color; o.Distance.Visible = true
                    else o.Distance.Visible = false end
                end
            end
        end
        if not shown then hideAll(o) end
    end
end

track(RunService.RenderStepped:Connect(function()
    local ok, err = pcall(espTick)
    if not ok then warnf("ESP tick error:", err) end
end))

local FullbrightState = { Active = false, Original = nil }
local function applyFullbright(on)
    if on and not FullbrightState.Active then
        FullbrightState.Original = {
            Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime, FogEnd=Lighting.FogEnd,
            GlobalShadows=Lighting.GlobalShadows, Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
        }
        Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.FogEnd=100000
        Lighting.GlobalShadows=false
        Lighting.Ambient=Color3.fromRGB(178,178,178)
        Lighting.OutdoorAmbient=Color3.fromRGB(178,178,178)
        FullbrightState.Active = true
    elseif (not on) and FullbrightState.Active then
        local o = FullbrightState.Original
        if o then
            Lighting.Brightness=o.Brightness; Lighting.ClockTime=o.ClockTime; Lighting.FogEnd=o.FogEnd
            Lighting.GlobalShadows=o.GlobalShadows; Lighting.Ambient=o.Ambient; Lighting.OutdoorAmbient=o.OutdoorAmbient
        end
        FullbrightState.Active = false
    end
end

local NoFogState = { Active=false, Original=nil, Atmospheres={}, Conn=nil }
local function captureAtmosphere(atm)
    if NoFogState.Atmospheres[atm] then return end
    NoFogState.Atmospheres[atm] = { Density=atm.Density, Offset=atm.Offset, Glare=atm.Glare, Haze=atm.Haze }
    atm.Density=0; atm.Offset=0; atm.Glare=0; atm.Haze=0
end
local function applyNoFog(on)
    if on and not NoFogState.Active then
        NoFogState.Original = { FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart }
        Lighting.FogEnd=9e9; Lighting.FogStart=9e9
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("Atmosphere") then captureAtmosphere(v) end
        end
        NoFogState.Conn = Lighting.DescendantAdded:Connect(safe(function(v)
            if v:IsA("Atmosphere") then captureAtmosphere(v) end
        end))
        NoFogState.Active = true
    elseif (not on) and NoFogState.Active then
        if NoFogState.Conn then NoFogState.Conn:Disconnect(); NoFogState.Conn = nil end
        local o = NoFogState.Original
        if o then Lighting.FogEnd=o.FogEnd; Lighting.FogStart=o.FogStart end
        for atm, s in pairs(NoFogState.Atmospheres) do
            if atm and atm.Parent then
                atm.Density=s.Density; atm.Offset=s.Offset; atm.Glare=s.Glare; atm.Haze=s.Haze
            end
        end
        NoFogState.Atmospheres = {}
        NoFogState.Active = false
    end
end

local CamState = {
    InfFov=false, Invisicam=false,
    OrigZoom = LocalPlayer.CameraMaxZoomDistance,
    OrigOcclude = LocalPlayer.DevCameraOcclusionMode,
}
local function applyCamera()
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = CamState.InfFov and 9999999 or CamState.OrigZoom
    end)
    pcall(function()
        LocalPlayer.DevCameraOcclusionMode = CamState.Invisicam
            and Enum.DevCameraOcclusionMode.Invisicam or CamState.OrigOcclude
    end)
end

local FovState = {
    Active   = false,
    Value    = Camera.FieldOfView,
    Original = Camera.FieldOfView,
}
track(RunService.RenderStepped:Connect(function()
    if FovState.Active and Camera then
        pcall(function()
            if Camera.FieldOfView ~= FovState.Value then
                Camera.FieldOfView = FovState.Value
            end
        end)
    end
end))

local WeaponMods = {
    NoRecoil = false, NoSpread = false,
    InstantHit = false, WallBang = false,
    Configs  = setmetatable({}, { __mode = "k" }),
}
_G.ColdWarWeaponMods = WeaponMods

local RECOIL_KEYS = {
    "CameraRecoilVertical", "CameraRecoilHorizontal",
    "GunRecoilVertical",    "GunRecoilHorizontal",
    "RecoilKick",
}
local function isWeaponConfig(t)
    if type(t) ~= "table" then return false end
    local ok, r = pcall(function() return t.Recoil end)
    if not ok or type(r) ~= "table" then return false end
    local hits = 0
    pcall(function() if r.CameraRecoilVertical ~= nil then hits = hits + 1 end end)
    pcall(function() if r.GunRecoilVertical    ~= nil then hits = hits + 1 end end)
    pcall(function() if r.RecoilKick           ~= nil then hits = hits + 1 end end)
    return hits >= 2
end
local function applyMods(cfg)
    local entry = WeaponMods.Configs[cfg]
    if not entry then return end
    local rec = cfg.Recoil
    if type(rec) == "table" then
        if WeaponMods.NoRecoil then
            for _, k in ipairs(RECOIL_KEYS) do
                if rec[k] ~= nil then rec[k] = 0 end
            end
        else
            for k, v in pairs(entry.OriginalRecoil) do rec[k] = v end
        end
    end
    if entry.HasSpread then
        cfg.Spread = WeaponMods.NoSpread and 0 or entry.OriginalSpread
    end
end
local function registerConfig(cfg)
    if WeaponMods.Configs[cfg] then applyMods(cfg); return end
    local entry = { OriginalRecoil = {} }
    if type(cfg.Recoil) == "table" then
        for _, k in ipairs(RECOIL_KEYS) do entry.OriginalRecoil[k] = cfg.Recoil[k] end
    end
    if type(cfg.Spread) == "number" then
        entry.HasSpread = true; entry.OriginalSpread = cfg.Spread
    end
    WeaponMods.Configs[cfg] = entry
    applyMods(cfg)
end
local function scanGC()
    if not getgc then return end
    local ok, list = pcall(getgc, true)
    if not ok or type(list) ~= "table" then return end
    for _, v in ipairs(list) do
        if type(v) == "table" then
            local ok2, is = pcall(isWeaponConfig, v)
            if ok2 and is then pcall(registerConfig, v) end
        end
    end
end
local function scanModule(m)
    if not m or not m:IsA("ModuleScript") then return end
    task.spawn(function()
        local ok, ret = pcall(require, m)
        if ok and isWeaponConfig(ret) then registerConfig(ret) end
    end)
end
local function scanManagers()
    for _, inst in ipairs(game:GetDescendants()) do
        local n = string.lower(inst.Name)
        if (inst:IsA("Folder") or inst:IsA("ModuleScript"))
            and string.find(n, "weapon") and string.find(n, "config") then
            for _, c in ipairs(inst:GetDescendants()) do scanModule(c) end
        end
    end
end
local function anyGunModOn()
    return WeaponMods.NoRecoil or WeaponMods.NoSpread
end
local function rescanAndApplyGuns()
    pcall(scanManagers); pcall(scanGC)
    for cfg in pairs(WeaponMods.Configs) do pcall(applyMods, cfg) end
end
if getloadedmodules then
    local ok, list = pcall(getloadedmodules)
    if ok and type(list) == "table" then
        for _, m in ipairs(list) do scanModule(m) end
    end
end
scanManagers()

if not _G.ColdWarProjectileCasterHooked then
    task.spawn(function()
        local okB, Ballistics = pcall(function()
            return ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("Ballistics", 10)
        end)
        if not okB or not Ballistics then warnf("Ballistics not found"); return end
        local okC, Caster = pcall(function()
            return require(Ballistics:WaitForChild("ProjectileCaster", 10))
        end)
        if not okC or type(Caster) ~= "table" or type(Caster.Fire) ~= "function" then
            warnf("ProjectileCaster.Fire not found"); return
        end
        _G.ColdWarProjectileCasterHooked = true
        local origFire = Caster.Fire
        Caster.Fire = function(args)
            local WM = _G.ColdWarWeaponMods
            if WM and args and type(args) == "table" and type(args.Weapon) == "table"
               and (WM.InstantHit or WM.WallBang) then
                local okC2, cloned = pcall(function() return table.clone(args.Weapon) end)
                if okC2 and cloned then
                    if WM.InstantHit then
                        cloned.MuzzleSpeed = 1e6
                        cloned.K           = 0
                        cloned.Gravity     = 0
                    end
                    if WM.WallBang then
                        cloned.PenetrationPower           = 1000
                        cloned.PierceFloorSpeedMultiplier = 1
                        cloned.PierceMaxDeflectionDeg     = 0
                        cloned.MaxDistance                = math.max(cloned.MaxDistance or 5000, 20000)
                    end
                    args.Weapon = cloned
                end
            end
            return origFire(args)
        end
    end)
end

if not _G.ColdWarInteractionsHooked then
    task.spawn(function()
        local okB, Ballistics = pcall(function()
            return ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("Ballistics", 10)
        end)
        if not okB or not Ballistics then warnf("Ballistics not found (Interactions)"); return end
        local okI, Interactions = pcall(function()
            return require(Ballistics:WaitForChild("Interactions", 10))
        end)
        if not okI or type(Interactions) ~= "table" or type(Interactions.resolve) ~= "function" then
            warnf("Interactions.resolve not found"); return
        end
        _G.ColdWarInteractionsHooked = true
        local origResolve = Interactions.resolve
        Interactions.resolve = function(p1, p2)
            local WM = _G.ColdWarWeaponMods
            if WM and WM.WallBang and p1 and p2 and p2.Result and p2.Result.Instance then
                local Weapon = p1.Weapon
                local v1     = p2.Result.Instance
                local model  = v1:FindFirstAncestorOfClass("Model")
                local isCharacter = (model and model:FindFirstChildOfClass("Humanoid")) and true or false
                local isPhantom   = (v1.Name == "HumanoidRootPart")
                                    or CollectionService:HasTag(v1, "BallisticsPhantom")
                local isExplosive = Weapon and Weapon.Explosive
                local acc = v1:FindFirstAncestorOfClass("Accessory")
                local isArmor = acc and (acc.Name == "CustomHelmet" or acc.Name == "CustomArmor")
                if (not isCharacter) and (not isPhantom) and (not isExplosive) and (not isArmor) then
                    p1.PierceCount       = 0
                    p1.PenetrationBudget = math.max(Weapon and Weapon.PenetrationPower or 1000, 1000)
                    if type(p1.Segments) == "table" and #p1.Segments >= 11 then
                        p1.Segments = {}
                    end
                    return {
                        Outcome      = "Pierce",
                        NewOrigin    = p2.Result.Position,
                        NewDirection = p2.IncomingDir,
                        NewSpeed     = p2.SpeedAtEnd,
                        Thickness    = 0,
                        Ignore       = v1,
                        IsCharacter  = false,
                    }
                end
            end
            return origResolve(p1, p2)
        end
    end)
end

local Fly = {
    Enabled = false, Speed = 300, Key = Enum.KeyCode.F,
    Ascend = Enum.KeyCode.Space, Descend = Enum.KeyCode.LeftControl,
    MarkerAnimBase = "110472940702397",
}
local BypassActive = false
local function fakeTrack()
    local p = newproxy(true)
    local mt = getmetatable(p)
    local sig = {
        Connect = function() return { Disconnect = function() end, Disable = function() end } end,
        Wait = function() end,
    }
    mt.__index = function(_, k)
        if k == "IsPlaying" or k == "Looped" then return false end
        if k == "Length" or k == "TimePosition" or k == "Speed"
           or k == "WeightCurrent" or k == "WeightTarget" then return 0 end
        if k == "Stopped" or k == "KeyframeReached"
           or k == "DidLoop" or k == "Ended" then return sig end
        return function() end
    end
    mt.__newindex = function() end
    return p
end
if not _G.ColdWarHooked and hookmetamethod then
    _G.ColdWarHooked = true
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not BypassActive then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if self == LogService and method == "GetLogHistory" then return {} end
        if method == "LoadAnimation" then
            local anim = ...
            if typeof(anim) == "Instance" and anim.AnimationId
               and string.find(anim.AnimationId, Fly.MarkerAnimBase) then
                return fakeTrack()
            end
        end
        if not checkcaller() and method == "FireServer"
           and typeof(self) == "Instance" and self.Name == "Freefall" then
            return
        end
        return oldNamecall(self, ...)
    end))
end

local HardenedConns = {}
local HardenedHum   = nil
local function hardenCharacter(ch)
    if not ch then return end
    if getconnections then
        pcall(function()
            for _, c in ipairs(getconnections(ch.DescendantAdded)) do
                local ok = pcall(function() c:Disable() end)
                if ok then table.insert(HardenedConns, c) end
            end
        end)
    end
    local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall,    false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics,     false)
        end)
        HardenedHum = hum
    end
end
local function unhardenCharacter()
    for _, c in ipairs(HardenedConns) do pcall(function() c:Enable() end) end
    HardenedConns = {}
    if HardenedHum then
        pcall(function()
            HardenedHum:SetStateEnabled(Enum.HumanoidStateType.Freefall,    true)
            HardenedHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            HardenedHum:SetStateEnabled(Enum.HumanoidStateType.Physics,     true)
        end)
        HardenedHum = nil
    end
end

local flyBV, flyAO, flyAtt, flyConn
local savedAutoRotate = true

local function stopFly()
    Fly.Enabled = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV  then flyBV:Destroy();  flyBV  = nil end
    if flyAO  then flyAO:Destroy();  flyAO  = nil end
    if flyAtt then flyAtt:Destroy(); flyAtt = nil end
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then hum.AutoRotate = savedAutoRotate end
    unhardenCharacter()
    BypassActive = false
end

local function startFly()
    local ch = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end
    stopFly()
    BypassActive = true
    hardenCharacter(ch)
    Fly.Enabled = true
    savedAutoRotate = hum.AutoRotate
    hum.AutoRotate = false
    flyAtt = Instance.new("Attachment"); flyAtt.Name = "CBFlyAtt"; flyAtt.Parent = hrp
    flyBV = Instance.new("BodyVelocity"); flyBV.Name = "CBFlyBV"
    flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBV.P = 1250; flyBV.Velocity = Vector3.zero; flyBV.Parent = hrp
    flyAO = Instance.new("AlignOrientation"); flyAO.Name = "CBFlyAO"
    flyAO.Attachment0 = flyAtt
    flyAO.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyAO.RigidityEnabled = true; flyAO.ReactionTorqueEnabled = false
    flyAO.CFrame = hrp.CFrame - hrp.Position; flyAO.Parent = hrp
    flyConn = RunService.RenderStepped:Connect(function()
        if not Fly.Enabled then return end
        local ok, err = pcall(function()
            local ch2 = LocalPlayer.Character
            local hrp2 = ch2 and ch2:FindFirstChild("HumanoidRootPart")
            local hum2 = ch2 and ch2:FindFirstChildOfClass("Humanoid")
            if not (hrp2 and hum2 and flyBV and flyBV.Parent and flyAO and flyAO.Parent) then
                stopFly(); return
            end
            if hum2:GetState() == Enum.HumanoidStateType.Freefall then
                hum2:ChangeState(Enum.HumanoidStateType.Running)
            end
            local cam = Camera.CFrame
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.RightVector end
            if UserInputService:IsKeyDown(Fly.Ascend)     then dir += Vector3.yAxis   end
            if UserInputService:IsKeyDown(Fly.Descend)    then dir -= Vector3.yAxis   end
            flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * Fly.Speed or Vector3.zero
            flyAO.CFrame = cam - cam.Position
        end)
        if not ok then warnf("Fly tick error:", err) end
    end)
end

local FlyCheckbox
local function setFlyEnabled(v)
    if v then startFly() else stopFly() end
    if FlyCheckbox then pcall(function() FlyCheckbox:SetValue(Fly.Enabled) end) end
end

local Noclip = { Enabled = false, Key = Enum.KeyCode.H }
local noclipConn
local function stopNoclip()
    Noclip.Enabled = false
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local ch = LocalPlayer.Character
    if ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                pcall(function() p.CanCollide = true end)
            end
        end
    end
end
local function startNoclip()
    stopNoclip()
    Noclip.Enabled = true
    noclipConn = RunService.Stepped:Connect(function()
        if not Noclip.Enabled then return end
        local ch = LocalPlayer.Character
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                pcall(function() p.CanCollide = false end)
            end
        end
    end)
end
local NoclipCheckbox
local function setNoclipEnabled(v)
    if v then startNoclip() else stopNoclip() end
    if NoclipCheckbox then pcall(function() NoclipCheckbox:SetValue(Noclip.Enabled) end) end
end

local SilentAim = {
    Enabled   = false,
    Key       = Enum.KeyCode.RightShift,
    FOV       = 200,
    TeamCheck = false,
    WallCheck = false,
    HitPart   = "Head",
    LeadTime  = 0,
    ColorOn   = Color3.fromRGB(255, 40, 40),
    ColorOff  = Color3.fromRGB(255, 255, 255),
}

local function pickTarget(SA)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local cursor = UserInputService:GetMouseLocation()
    local best, bestDist, bestPos = nil, SA.FOV, nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local skip = false
            if SA.TeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then
                skip = true
            end
            if not skip then
                local ch = plr.Character
                if ch then
                    local part = ch:FindFirstChild(SA.HitPart)
                                 or ch:FindFirstChild("Head")
                                 or ch:FindFirstChild("HumanoidRootPart")
                    if part then
                        local aimPos = part.Position
                        local screenPos, onScreen = cam:WorldToViewportPoint(aimPos)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - cursor).Magnitude
                            if dist < bestDist then
                                local blocked = false
                                if SA.WallCheck then
                                    local rp = RaycastParams.new()
                                    rp.FilterType = Enum.RaycastFilterType.Exclude
                                    rp.FilterDescendantsInstances = { LocalPlayer.Character, ch, cam }
                                    rp.IgnoreWater = true
                                    local hit = Workspace:Raycast(cam.CFrame.Position, aimPos - cam.CFrame.Position, rp)
                                    if hit and hit.Instance and not hit.Instance:IsDescendantOf(ch) then
                                        blocked = true
                                    end
                                end
                                if not blocked then
                                    best, bestDist, bestPos = part, dist, aimPos
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestPos
end

SilentAim.pickTarget = pickTarget
_G.ColdWarSilentAim = SilentAim

local saCircle
if Drawing then
    saCircle = Drawing.new("Circle")
    saCircle.Thickness    = 1.5
    saCircle.NumSides     = 64
    saCircle.Radius       = SilentAim.FOV
    saCircle.Filled       = false
    saCircle.Color        = SilentAim.ColorOff
    saCircle.Transparency = 1
    saCircle.Visible      = false
    trackDraw(saCircle)
end

track(RunService.RenderStepped:Connect(function()
    if not saCircle then return end
    if SilentAim.Enabled then
        saCircle.Position = UserInputService:GetMouseLocation()
        saCircle.Radius   = SilentAim.FOV
        saCircle.Color    = SilentAim.ColorOn
        saCircle.Visible  = true
    else
        saCircle.Visible = false
    end
end))

if not _G.ColdWarShotCodecHooked then
    task.spawn(function()
        local okB, Ballistics = pcall(function()
            return ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("Ballistics", 10)
        end)
        if not okB or not Ballistics then warnf("Ballistics not found"); return end
        local okSC, ShotCodec = pcall(function()
            return require(Ballistics:WaitForChild("ShotCodec", 10))
        end)
        if not okSC or type(ShotCodec) ~= "table" or type(ShotCodec.encodeFire) ~= "function" then
            warnf("ShotCodec.encodeFire not found"); return
        end
        _G.ColdWarShotCodecHooked = true
        local origEncodeFire = ShotCodec.encodeFire
        ShotCodec.encodeFire = function(muzzleId, bulletId, origin, fireTime, pellets)
            local SA = _G.ColdWarSilentAim
            if SA and SA.Enabled and SA.pickTarget
               and typeof(origin) == "Vector3" and type(pellets) == "table" then
                local ok, target, aimPos = pcall(SA.pickTarget, SA)
                if ok and target and aimPos then
                    local delta = aimPos - origin
                    if delta.Magnitude > 0 then
                        local newDir = delta.Unit
                        for i = 1, #pellets do
                            local p = pellets[i]
                            if type(p) == "table" then p.Direction = newDir end
                        end
                    end
                end
            end
            return origEncodeFire(muzzleId, bulletId, origin, fireTime, pellets)
        end
    end)
end

local SilentAimCheckbox
local function setSilentAimEnabled(v)
    SilentAim.Enabled = v
    if SilentAimCheckbox then pcall(function() SilentAimCheckbox:SetValue(SilentAim.Enabled) end) end
end

track(UserInputService.InputBegan:Connect(safe(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Fly.Key then
        setFlyEnabled(not Fly.Enabled)
    elseif input.KeyCode == Noclip.Key then
        setNoclipEnabled(not Noclip.Enabled)
    elseif input.KeyCode == SilentAim.Key then
        setSilentAimEnabled(not SilentAim.Enabled)
    end
end)))

track(LocalPlayer.CharacterAdded:Connect(safe(function(ch)
    task.wait(0.25)
    applyCamera()
    if anyGunModOn() then rescanAndApplyGuns() end
    local wasFly = Fly.Enabled
    stopFly()
    if wasFly then
        task.wait(0.75)
        startFly()
        if FlyCheckbox then pcall(function() FlyCheckbox:SetValue(Fly.Enabled) end) end
    end
end)))

VisualTab:Checkbox({ Label = "Enable Esp",        Value = false, Callback = safe(function(_, v) ESP.Enabled   = v end) })
VisualTab:Checkbox({ Label = "Enable Box",        Value = false, Callback = safe(function(_, v) ESP.Box       = v end) })
VisualTab:Checkbox({ Label = "Enable Line",       Value = false, Callback = safe(function(_, v) ESP.Line      = v end) })
VisualTab:Checkbox({ Label = "Enable Chams",      Value = false, Callback = safe(function(_, v) ESP.Chams     = v end) })
VisualTab:Checkbox({ Label = "Enable Team Check", Value = false, Callback = safe(function(_, v) ESP.TeamCheck = v end) })
VisualTab:Checkbox({ Label = "No Team Esp",       Value = false, Callback = safe(function(_, v) ESP.NoTeamEsp = v end) })
VisualTab:Checkbox({ Label = "Enable Health",     Value = false, Callback = safe(function(_, v) ESP.Health    = v end) })
VisualTab:Checkbox({ Label = "Enable Name",       Value = false, Callback = safe(function(_, v) ESP.Name      = v end) })
VisualTab:Checkbox({ Label = "Enable Distance",   Value = false, Callback = safe(function(_, v) ESP.Distance  = v end) })
VisualTab:Checkbox({ Label = "Fullbright",        Value = false, Callback = safe(function(_, v) applyFullbright(v) end) })
VisualTab:Checkbox({ Label = "No Fog",            Value = false, Callback = safe(function(_, v) applyNoFog(v)     end) })
VisualTab:Checkbox({ Label = "Infinite Fov",      Value = false, Callback = safe(function(_, v) CamState.InfFov    = v; applyCamera() end) })
VisualTab:Checkbox({ Label = "Invisicam Mode",    Value = false, Callback = safe(function(_, v) CamState.Invisicam = v; applyCamera() end) })
VisualTab:SliderInt({
    Label = "FOV", Value = math.floor(FovState.Value + 0.5), Minimum = 1, Maximum = 200,
    Callback = safe(function(_, v)
        FovState.Value = v; FovState.Active = true
        pcall(function() Camera.FieldOfView = v end)
    end),
})

local SaRow = CombatTab:Row()
SilentAimCheckbox = SaRow:Checkbox({
    Label = "Enable Silent Aim", Value = false,
    Callback = safe(function(_, v) setSilentAimEnabled(v) end),
})
SaRow:Keybind({
    Value = SilentAim.Key,
    Callback = safe(function(_, key)
        if typeof(key) == "EnumItem" then SilentAim.Key = key end
    end),
})
CombatTab:Checkbox({
    Label = "Enable Team Check", Value = SilentAim.TeamCheck,
    Callback = safe(function(_, v) SilentAim.TeamCheck = v end),
})
CombatTab:Checkbox({
    Label = "Enable Wall Check", Value = SilentAim.WallCheck,
    Callback = safe(function(_, v) SilentAim.WallCheck = v end),
})
CombatTab:SliderInt({
    Label = "FOV", Value = SilentAim.FOV, Minimum = 1, Maximum = 500,
    Callback = safe(function(_, v) SilentAim.FOV = v end),
})

GunTab:Checkbox({ Label = "No Recoil",   Value = false, Callback = safe(function(_, v)
    WeaponMods.NoRecoil = v; rescanAndApplyGuns()
end)})
GunTab:Checkbox({ Label = "No Spread",   Value = false, Callback = safe(function(_, v)
    WeaponMods.NoSpread = v; rescanAndApplyGuns()
end)})
GunTab:Checkbox({ Label = "Instant Hit", Value = false, Callback = safe(function(_, v)
    WeaponMods.InstantHit = v
end)})
GunTab:Checkbox({ Label = "WallBang",    Value = false, Callback = safe(function(_, v)
    WeaponMods.WallBang = v
end)})

local FlyRow = MovementTab:Row()
FlyCheckbox = FlyRow:Checkbox({
    Label = "Enable Fly", Value = false,
    Callback = safe(function(_, v) setFlyEnabled(v) end),
})
FlyRow:Keybind({
    Value = Fly.Key,
    Callback = safe(function(_, key)
        if typeof(key) == "EnumItem" then Fly.Key = key end
    end),
})
MovementTab:SliderInt({
    Label = "Fly Speed", Value = Fly.Speed, Minimum = 1, Maximum = 1500,
    Callback = safe(function(_, v) Fly.Speed = v end),
})

local NoclipRow = MovementTab:Row()
NoclipCheckbox = NoclipRow:Checkbox({
    Label = "Noclip", Value = false,
    Callback = safe(function(_, v) setNoclipEnabled(v) end),
})
NoclipRow:Keybind({
    Value = Noclip.Key,
    Callback = safe(function(_, key)
        if typeof(key) == "EnumItem" then Noclip.Key = key end
    end),
})

ColdWar.Destroy = function()
    pcall(stopFly)
    pcall(stopNoclip)
    SilentAim.Enabled = false
    pcall(function() applyFullbright(false) end)
    pcall(function() applyNoFog(false)      end)
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance  = CamState.OrigZoom
        LocalPlayer.DevCameraOcclusionMode = CamState.OrigOcclude
    end)
    pcall(function()
        if FovState.Active and Camera then Camera.FieldOfView = FovState.Original end
    end)
    FovState.Active = false

    WeaponMods.NoRecoil = false; WeaponMods.NoSpread = false
    WeaponMods.InstantHit = false; WeaponMods.WallBang = false
    for cfg in pairs(WeaponMods.Configs) do pcall(applyMods, cfg) end
    WeaponMods.Configs = setmetatable({}, { __mode = "k" })

    for _, c in ipairs(ColdWar.Connections) do pcall(function() c:Disconnect() end) end
    ColdWar.Connections = {}
    for player, _ in pairs(Objects) do killFor(player) end
    Objects = {}
    for _, d in ipairs(ColdWar.Drawings)  do pcall(function() d:Remove()  end) end
    for _, i in ipairs(ColdWar.Instances) do pcall(function() i:Destroy() end) end
    ColdWar.Drawings = {}; ColdWar.Instances = {}
    if ColdWar.Window then pcall(function() ColdWar.Window:Close() end) end
    ColdWar.Window = nil
    _G.ColdWar = nil
    log("Unloaded")
end

log("Loaded")
