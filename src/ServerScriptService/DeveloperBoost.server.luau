-- ===============================================
-- DEVELOPER BOOST SYSTEM (Whitelist-Based)
-- ===============================================
-- Ubah DEVELOPER_USER_IDS ke Roblox User ID bukan username (lebih aman & unique)
local DEVELOPER_USER_IDS = {
	[8361115924] = true, -- Replace dengan User ID Anda (bukan username)
	-- Contoh: [123456789] = true,
}

local DEVELOPER_WALK_SPEED = 50 -- Kecepatan Developer (default: 16)

game.Players.PlayerAdded:Connect(function(player)
	-- Cek apakah user ID termasuk dalam whitelist developer
	if not DEVELOPER_USER_IDS[player.UserId] then
		return
	end

	player.CharacterAdded:Connect(function(char)
		local humanoid = char:WaitForChild("Humanoid")
		humanoid.WalkSpeed = DEVELOPER_WALK_SPEED
		print(
			"[DeveloperBoost] Developer "
				.. player.Name
				.. " ("
				.. player.UserId
				.. ") joined. Speed boosted to "
				.. DEVELOPER_WALK_SPEED
		)
	end)
end)
