--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local TradeSession = require(script.Parent:WaitForChild("TradeSession") :: ModuleScript)

-- 1. REMOTE EVENTS FOR ASYNC CLIENT COMMUNICATIONS
local tradeInvitationEvent = ReplicatedStorage:FindFirstChild("TradeInvitationEvent")
if not tradeInvitationEvent then
	tradeInvitationEvent = Instance.new("RemoteEvent")
	tradeInvitationEvent.Name = "TradeInvitationEvent"
	tradeInvitationEvent.Parent = ReplicatedStorage
end

local tradeStateUpdateEvent = ReplicatedStorage:FindFirstChild("TradeStateUpdateEvent")
if not tradeStateUpdateEvent then
	tradeStateUpdateEvent = Instance.new("RemoteEvent")
	tradeStateUpdateEvent.Name = "TradeStateUpdateEvent"
	tradeStateUpdateEvent.Parent = ReplicatedStorage
end

-- 2. STATE MANAGER & SESSION STORE
local activeSessions: { [Player]: any } = {}
local activeRequests: { [Player]: Player } = {}

local function getRebirthCount(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirthVal = leaderstats and leaderstats:FindFirstChild("Rebirth") :: IntValue?
	return rebirthVal and rebirthVal.Value or 0
end

type ServiceResult = {
	Success: boolean,
	Error: string?,
	Message: string?,
}

-- --- API ENDPOINTS ---
local TradeService = {}

function TradeService:sendTradeRequest(player: Player, targetPlayerName: string): ServiceResult
	if getRebirthCount(player) < 5 then
		return { Success = false, Error = "Anda harus memiliki minimal 5 Rebirth untuk melakukan trading." }
	end

	local targetPlayer = Players:FindFirstChild(targetPlayerName)
	if not targetPlayer then
		return { Success = false, Error = "Pemain tidak ditemukan di server ini." }
	end

	if targetPlayer == player then
		return { Success = false, Error = "Anda tidak dapat melakukan trade dengan diri sendiri." }
	end

	if getRebirthCount(targetPlayer) < 5 then
		return { Success = false, Error = "Target pemain belum mencapai minimal 5 Rebirth." }
	end

	if activeSessions[player] or activeSessions[targetPlayer] then
		return { Success = false, Error = "Salah satu pemain sedang berada dalam sesi trade aktif." }
	end

	-- Record request
	activeRequests[player] = targetPlayer
	tradeInvitationEvent:FireClient(targetPlayer, player.Name)

	return { Success = true, Message = "Undangan trade berhasil dikirim!" }
end

function TradeService:respondToRequest(player: Player, senderPlayerName: string, accepted: boolean): ServiceResult
	local senderPlayer = Players:FindFirstChild(senderPlayerName)
	if not senderPlayer then
		return { Success = false, Error = "Pemain yang mengirim undangan tidak ditemukan." }
	end

	if activeRequests[senderPlayer] ~= player then
		return { Success = false, Error = "Tidak ada undangan trade aktif." }
	end

	-- Clear request
	activeRequests[senderPlayer] = nil

	if accepted then
		if getRebirthCount(player) < 5 or getRebirthCount(senderPlayer) < 5 then
			tradeInvitationEvent:FireClient(senderPlayer, player.Name, "error_rebirth")
			return { Success = false, Error = "Salah satu pemain tidak memenuhi syarat Rebirth." }
		end

		if activeSessions[player] or activeSessions[senderPlayer] then
			tradeInvitationEvent:FireClient(senderPlayer, player.Name, "error_busy")
			return { Success = false, Error = "Salah satu pemain sedang sibuk." }
		end

		-- Create a new OOP session
		local sessionId = HttpService:GenerateGUID(false)
		local session = TradeSession.new(sessionId, senderPlayer, player)
		activeSessions[senderPlayer] = session
		activeSessions[player] = session

		local state = session:GetState()
		tradeStateUpdateEvent:FireClient(senderPlayer, state)
		tradeStateUpdateEvent:FireClient(player, state)

		return { Success = true, Error = nil, Message = nil }
	else
		-- Notify sender that invitation was declined
		tradeInvitationEvent:FireClient(senderPlayer, player.Name, "declined")
		return { Success = true, Error = nil, Message = nil }
	end
end

function TradeService:addCarToOffer(player: Player, carName: string): ServiceResult
	local session = activeSessions[player]
	if not session then
		return { Success = false, Error = "Tidak ada sesi trade aktif." }
	end

	local ok, err = session:AddCar(player, carName)
	if ok then
		local state = session:GetState()
		tradeStateUpdateEvent:FireClient(session.Player1, state)
		tradeStateUpdateEvent:FireClient(session.Player2, state)
		return { Success = true, Error = nil, Message = nil }
	else
		return { Success = false, Error = err, Message = nil }
	end
end

function TradeService:removeCarFromOffer(player: Player, carName: string): ServiceResult
	local session = activeSessions[player]
	if not session then
		return { Success = false, Error = "Tidak ada sesi trade aktif." }
	end

	local ok, err = session:RemoveCar(player, carName)
	if ok then
		local state = session:GetState()
		tradeStateUpdateEvent:FireClient(session.Player1, state)
		tradeStateUpdateEvent:FireClient(session.Player2, state)
		return { Success = true, Error = nil, Message = nil }
	else
		return { Success = false, Error = err, Message = nil }
	end
end

function TradeService:lockOffer(player: Player): ServiceResult
	local session = activeSessions[player]
	if not session then
		return { Success = false, Error = "Tidak ada sesi trade aktif." }
	end

	local ok, err = session:Lock(player)
	if ok then
		local state = session:GetState()
		tradeStateUpdateEvent:FireClient(session.Player1, state)
		tradeStateUpdateEvent:FireClient(session.Player2, state)

		-- Countdown Trigger: if both are locked, run countdown in task scheduler
		if session.IsLocked1 and session.IsLocked2 then
			task.spawn(function()
				for i = 3, 1, -1 do
					if not (session.Active and session.IsLocked1 and session.IsLocked2) then
						return
					end

					local countdownState = session:GetState() :: any
					countdownState.CountdownActive = true
					countdownState.CountdownSeconds = i

					tradeStateUpdateEvent:FireClient(session.Player1, countdownState)
					tradeStateUpdateEvent:FireClient(session.Player2, countdownState)
					task.wait(1)
				end

				-- Lock verified
				if session.Active and session.IsLocked1 and session.IsLocked2 then
					local finalState = session:GetState() :: any
					finalState.CountdownActive = true
					finalState.CountdownSeconds = 0

					tradeStateUpdateEvent:FireClient(session.Player1, finalState)
					tradeStateUpdateEvent:FireClient(session.Player2, finalState)
				end
			end)
		end

		return { Success = true, Error = nil, Message = nil }
	else
		return { Success = false, Error = err, Message = nil }
	end
end

function TradeService:unlockOffer(player: Player): ServiceResult
	local session = activeSessions[player]
	if not session then
		return { Success = false, Error = "Tidak ada sesi trade aktif." }
	end

	local ok, err = session:Unlock(player)
	if ok then
		local state = session:GetState()
		tradeStateUpdateEvent:FireClient(session.Player1, state)
		tradeStateUpdateEvent:FireClient(session.Player2, state)
		return { Success = true, Error = nil, Message = nil }
	else
		return { Success = false, Error = err, Message = nil }
	end
end

function TradeService:confirmTrade(player: Player): ServiceResult
	local session = activeSessions[player]
	if not session then
		return { Success = false, Error = "Tidak ada sesi trade aktif." }
	end

	local ok, err = session:Confirm(player)
	if ok then
		local state = session:GetState()
		tradeStateUpdateEvent:FireClient(session.Player1, state)
		tradeStateUpdateEvent:FireClient(session.Player2, state)

		-- Transaction execution
		if session.IsConfirmed1 and session.IsConfirmed2 then
			local success, execErr = session:Execute()
			if success then
				-- Sesi trade sukses
				tradeStateUpdateEvent:FireClient(session.Player1, { Active = false, Success = true })
				tradeStateUpdateEvent:FireClient(session.Player2, { Active = false, Success = true })
				activeSessions[session.Player1] = nil
				activeSessions[session.Player2] = nil
			else
				-- Gagal transaksi
				tradeStateUpdateEvent:FireClient(session.Player1, { Active = false, Success = false, Error = execErr })
				tradeStateUpdateEvent:FireClient(session.Player2, { Active = false, Success = false, Error = execErr })
				activeSessions[session.Player1] = nil
				activeSessions[session.Player2] = nil
			end
		end

		return { Success = true, Error = nil, Message = nil }
	else
		return { Success = false, Error = err, Message = nil }
	end
end

function TradeService:cancelTrade(player: Player): ServiceResult
	local session = activeSessions[player]
	if session then
		session.Active = false
		tradeStateUpdateEvent:FireClient(session.Player1, { Active = false, Cancelled = true })
		tradeStateUpdateEvent:FireClient(session.Player2, { Active = false, Cancelled = true })
		activeSessions[session.Player1] = nil
		activeSessions[session.Player2] = nil
	end

	-- Clean invitation requests if user cancels
	activeRequests[player] = nil
	return { Success = true, Error = nil, Message = nil }
end

-- 3. CLEANUP ON PLAYER REMOVING
Players.PlayerRemoving:Connect(function(player)
	activeRequests[player] = nil
	for sender, target in pairs(activeRequests) do
		if target == player then
			activeRequests[sender] = nil
		end
	end

	local session = activeSessions[player]
	if session then
		session.Active = false
		local otherPlayer = if session.Player1 == player then session.Player2 else session.Player1
		activeSessions[session.Player1] = nil
		activeSessions[session.Player2] = nil
		if otherPlayer then
			tradeStateUpdateEvent:FireClient(otherPlayer, { Active = false, Cancelled = true })
		end
	end
end)

-- 4. CHARACTER PROXIMITY PROMPT MANAGEMENT FOR TRADING
local function setupCharacterPrompt(player: Player, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end

	-- Clean up existing trade prompts
	local existing = hrp:FindFirstChild("TradePrompt")
	if existing then existing:Destroy() end

	if getRebirthCount(player) >= 5 then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TradePrompt"
		prompt.ActionText = "Trade"
		prompt.ObjectText = player.Name
		prompt.HoldDuration = 1.0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = hrp
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		setupCharacterPrompt(player, character)
	end)
	
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if leaderstats then
			local rebirthVal = leaderstats:WaitForChild("Rebirth", 10)
			if rebirthVal and rebirthVal:IsA("IntValue") then
				rebirthVal.Changed:Connect(function(val)
					if val >= 5 and player.Character then
						setupCharacterPrompt(player, player.Character)
					end
				end)
			end
		end
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setupCharacterPrompt(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		setupCharacterPrompt(player, character)
	end)
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if leaderstats then
			local rebirthVal = leaderstats:WaitForChild("Rebirth", 10)
			if rebirthVal and rebirthVal:IsA("IntValue") then
				rebirthVal.Changed:Connect(function(val)
					if val >= 5 and player.Character then
						setupCharacterPrompt(player, player.Character)
					end
				end)
			end
		end
	end)
end


-- 4. REGISTER SERVICE NETWORKER
Networker.server.new("TradeService", TradeService, {
	TradeService.sendTradeRequest :: any,
	TradeService.respondToRequest :: any,
	TradeService.addCarToOffer :: any,
	TradeService.removeCarFromOffer :: any,
	TradeService.lockOffer :: any,
	TradeService.unlockOffer :: any,
	TradeService.confirmTrade :: any,
	TradeService.cancelTrade :: any,
})
