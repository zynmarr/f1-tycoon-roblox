--!strict
local ChatAnnounceHandler = {}

function ChatAnnounceHandler.init()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TextChatService = game:GetService("TextChatService")
	local StarterGui = game:GetService("StarterGui")

	local chatAnnounceEventNullable = ReplicatedStorage:WaitForChild("ChatAnnounceEvent", 15) :: RemoteEvent?
	if not chatAnnounceEventNullable then
		warn("[ChatAnnounceHandler] ChatAnnounceEvent tidak ditemukan!")
		return
	end
	local chatAnnounceEvent = chatAnnounceEventNullable :: RemoteEvent

	chatAnnounceEvent.OnClientEvent:Connect(function(richText: string, chatColor: Color3)
		-- 1. Siarkan ke TextChatService (Modern Chat UI) jika tersedia
		local textChannels = TextChatService:FindFirstChild("TextChannels")
		local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral") :: any
		
		if generalChannel then
			pcall(function()
				generalChannel:DisplaySystemMessage(richText)
			end)
		else
			-- Cari TextChannel lain jika RBXGeneral belum di-load
			for _, channel in ipairs(TextChatService:GetDescendants()) do
				if channel:IsA("TextChannel") then
					pcall(function()
						(channel :: any):DisplaySystemMessage(richText)
					end)
				end
			end
		end

		-- 2. Siarkan ke Legacy ChatService (Lama) sebagai cadangan
		pcall(function()
			local plainText = string.gsub(richText, "<[^>]+>", "")
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = plainText,
				Color = chatColor or Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.GothamBold,
				FontSize = Enum.FontSize.Size14,
			})
		end)
	end)
end

return ChatAnnounceHandler
