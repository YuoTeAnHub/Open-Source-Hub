local allowedPlaces = {
    [6788434697] = "https://raw.githubusercontent.com/YuoTeAnHub/Open-Source-Hub/refs/heads/main/scripts/AniPhobia.lua",
    [idgame] = "link",
}

local url = allowedPlaces[game.PlaceId]
if url then
    loadstring(game:HttpGet(url))()
else
    warn("Open Source Hub: Game Not Supported")
end
