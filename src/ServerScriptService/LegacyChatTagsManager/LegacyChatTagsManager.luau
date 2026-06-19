--!strict
local LegacyChatTagsManager = {}
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoleManager = require(ServerScriptService:WaitForChild("RoleManager"):WaitForChild("RoleManager"))
local RoleConfig = require(ReplicatedStorage:WaitForChild("RoleConfig"))

function LegacyChatTagsManager.Init()
	local ChatService = nil
	local success = pcall(function()
		local chatServiceRunner = ServerScriptService:WaitForChild("ChatServiceRunner", 5)
		if chatServiceRunner then
			ChatService = require(chatServiceRunner:WaitForChild("ChatService"))
		end
	end)

	if success and ChatService then
		local function onSpeakerAdded(speakerName: string)
			local speaker = ChatService:GetSpeaker(speakerName)
			local player = speaker:GetPlayer()
			if player then
				local roleName = RoleManager.getPlayerRole(player)
				local roleData = RoleConfig.Roles[roleName]
				if roleData and roleName ~= "Player" then
					local tagText = (roleData.Emoji ~= "" and roleData.Emoji .. " " or "") .. roleData.DisplayName
					speaker:SetExtraData("Tags", {
						{
							TagText = tagText,
							TagColor = roleData.Color,
						},
					})
					speaker:SetExtraData("NameColor", roleData.Color)
				end
			end
		end

		ChatService.SpeakerAdded:Connect(onSpeakerAdded)
		for _, speakerName in ipairs(ChatService:GetSpeakerList()) do
			onSpeakerAdded(speakerName)
		end
	end
end

return LegacyChatTagsManager
