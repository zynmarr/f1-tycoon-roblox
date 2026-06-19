local DeveloperBoostManager = {}
local Players = game:GetService("Players")

local DEVELOPER_USER_IDS = {
	[8361115924] = true,
}

local DEVELOPER_WALK_SPEED = 50

local function onPlayerAdded(player)
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
end

function DeveloperBoostManager.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

return DeveloperBoostManager
