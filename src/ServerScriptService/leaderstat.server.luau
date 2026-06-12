-- LeaderstatSetup | ServerScriptService > Script
-- NOTE: Main.server.luau already creates leaderstats via ProfileService
-- This script is DISABLED to prevent duplication
-- Uncomment if you want additional DataStore tracking (separate from Main.server.luau)

--[[
local Players             = game:GetService("Players")
local DataStoreService    = game:GetService("DataStoreService")

local STATS: {{name: string, default: number}} = {
	{ name = "Gold",  default = 0 },
	{ name = "Gems",  default = 0 },
	{ name = "Level", default = 1 },
}

local dataStore = DataStoreService:GetDataStore("PlayerCurrencyData_v1")

local function loadData(player: Player): {[string]: number}?
	local ok, data = pcall(dataStore.GetAsync, dataStore, "Player_" .. player.UserId)
	return (ok and type(data) == "table") and data or nil
end

local function saveData(player: Player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return end

	local data: {[string]: number} = {}
	for _, stat in ipairs(STATS) do
		local obj = ls:FindFirstChild(stat.name)
		if obj then data[stat.name] = obj.Value end
	end

	local ok, err = pcall(dataStore.SetAsync, dataStore, "Player_" .. player.UserId, data)
	if not ok then
		warn("[DATASTORE] Error al guardar " .. player.Name .. ": " .. tostring(err))
	end
end

local function setupLeaderstats(player: Player)
	local saved = loadData(player)

	local ls   = Instance.new("Folder")
	ls.Name    = "leaderstats"
	ls.Parent  = player

	for _, stat in ipairs(STATS) do
		local iv       = Instance.new("IntValue")
		iv.Name        = stat.name
		iv.Value       = (saved and saved[stat.name]) or stat.default
		iv.Parent      = ls
	end
end

Players.PlayerAdded:Connect(setupLeaderstats)
Players.PlayerRemoving:Connect(saveData)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		saveData(plr)
	end
end)
--]]

print("[LeaderstatSetup] Disabled - Main.server.luau handles leaderstats via ProfileService")