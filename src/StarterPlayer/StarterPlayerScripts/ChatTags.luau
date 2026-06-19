--!strict
local ChatTags = {}

function ChatTags.init()
	local TextChatService = game:GetService("TextChatService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))

	-- Custom chat tags untuk TextChatService (Sistem Chat Baru Roblox)
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")

		if message.TextSource then
			local player = Players:GetPlayerByUserId(message.TextSource.UserId)
			if player then
				local roleName = player:GetAttribute("Role") or "Player"
				local roleData = RoleConfig.Roles[roleName]

				-- Jangan tampilkan tag untuk Player biasa agar chat tetap bersih
				if roleData and roleName ~= "Player" then
					local colorHex = roleData.Color:ToHex()
					local emoji = roleData.Emoji or ""
					local tagText = string.format("<font color='#%s'><b>[%s %s]</b></font> ", colorHex, emoji, string.upper(roleData.DisplayName))
					properties.PrefixText = tagText .. string.format("<font color='#%s'><b>%s</b></font>", colorHex, message.PrefixText)
				end
			end
		end

		return properties
	end
end

return ChatTags
