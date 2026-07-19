local placeScripts = {
    [6788434697] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/AniPhobia.lua",
    [3221241066] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/DEADZONE%20CLASSIC.lua",
    [139432668432124] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/CLEAR.lua",
    [4639625707] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/WarTycoon.lua",
    [13687899540] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/Cold%20War.lua",
}

local universeScripts = {
    [10123332358] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/CLEAR.lua",
}

local url = placeScripts[game.PlaceId] or universeScripts[game.GameId]

if url then
    loadstring(game:HttpGet(url))()
else
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Open Source Hub",
            Text = "Game Not Supported",
            Duration = 5
        })
    end)
end
