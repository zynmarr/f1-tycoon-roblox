local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
-- Sambungkan ke TextLabel
local screenGui = playerGui:WaitForChild("CustomStatsGui") :: ScreenGui
local frame = screenGui:WaitForChild("Frame")
local cashDisplay = frame:WaitForChild("CashDisplay")

-- Tunggu sampai folder leaderstats dimuat
local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")

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
