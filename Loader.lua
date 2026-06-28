local allowedPlaces = {
    [6788434697] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/AniPhobia.lua",
    [139432668432124] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/CLEAR.lua",
    [106741147406362] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/CLEAR.lua",
    [3221241066] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/DEADZONE%20CLASSIC.lua",
}

local url = allowedPlaces[game.PlaceId]
if url then
    loadstring(game:HttpGet(url))()
else
    warn("Open Source Hub: Game Not Supported")
end
