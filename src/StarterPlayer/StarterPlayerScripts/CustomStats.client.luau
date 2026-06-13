local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("CustomStatsGui", math.huge) :: ScreenGui
local frame = screenGui:WaitForChild("Frame", math.huge)
local cashDisplay = frame:WaitForChild("CashDisplay", math.huge)

-- Tunggu sampai folder leaderstats dimuat
local leaderstats = player:WaitForChild("leaderstats", math.huge)
local cash = leaderstats:WaitForChild("Cash", math.huge)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))


-- ==========================================
-- FUNGSI UPDATE LAYAR
-- ==========================================
local function updateUI()
	-- Format uangnya dulu pakai fungsi di atas
	local cashFormatter = GameUtils.formatCompact(cash.Value)

	-- Tempelkan kurs dollar dan angkanya ke TextLabel
	cashDisplay.Text = "$ " .. cashFormatter
end

-- 1. Jalankan pertama kali saat masuk
updateUI()

-- 2. Pantau terus perubahan uang
cash:GetPropertyChangedSignal("Value"):Connect(updateUI)
