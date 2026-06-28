local ENABLED = true --// Change to false for off bypass

local function start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
	local ChangePosture = RemoteEvents:WaitForChild("ChangePosture")

	local function isBlocked(...)
		local arg1 = (...)
		return type(arg1) == "number" and arg1 >= 6
	end

	local mt = getrawmetatable(game)
	setreadonly(mt, false)

	local oldNamecall = mt.__namecall
	mt.__namecall = newcclosure(function(self, ...)
		if self == ChangePosture then
			local method = getnamecallmethod and getnamecallmethod()
			if (method == "FireServer" or method == "fireServer") and isBlocked(...) then
				return
			end
		end
		return oldNamecall(self, ...)
	end)

	setreadonly(mt, true)

	pcall(function()
		if not hookfunction then return end
		local oldFire
		oldFire = hookfunction(ChangePosture.FireServer, newcclosure(function(self, ...)
			if self == ChangePosture and isBlocked(...) then
				return
			end
			return oldFire(self, ...)
		end))
	end)

	print("[DEADZONE] Anti-Cheat Blocked!")
end

if ENABLED then
	local ok, err = pcall(start)
	if not ok then
		warn("[DEADZONE] Error:", err)
	end
else
	print("[DEADZONE] Off")
end
