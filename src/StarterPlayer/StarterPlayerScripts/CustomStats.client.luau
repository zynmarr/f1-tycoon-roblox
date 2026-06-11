local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
-- Sambungkan ke TextLabel
local screenGui = playerGui:WaitForChild("CustomStatsGui") :: ScreenGui
local frame = screenGui:WaitForChild("Frame")
local cashDisplay = frame:WaitForChild("CashDisplay")

-- Tunggu sampai folder leaderstats dimuat
local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")

-- ==========================================
-- FUNGSI SINGKATAN ANGKA (1K, 1M, 1B, dst)
-- ==========================================
local function cashFormat(value: number): string
	local textMoney = tostring(value)
	local word = ""

	if value >= 1e12 then -- 1 Triliun
		textMoney = string.format("%.1f", value / 1e12)
		word = "T"
	elseif value >= 1e9 then -- 1 Miliar (Billion)
		textMoney = string.format("%.1f", value / 1e9)
		word = "B"
	elseif value >= 1e6 then -- 1 Juta (Million)
		textMoney = string.format("%.1f", value / 1e6)
		word = "M"
	elseif value >= 1e3 then -- 1 Ribu
		textMoney = string.format("%.1f", value / 1e3)
		word = "K"
	end

	-- 1. Hapus akhiran ".0" jika pas bulat (Misal 1.0M jadi 1M)
	textMoney = textMoney:gsub("%.0$", "")
	-- 2. Ubah titik (format bule) menjadi koma (format kita), jadi 1.2M -> 1,2M
	textMoney = textMoney:gsub("%.", ",")

	return textMoney .. word
end

-- ==========================================
-- FUNGSI UPDATE LAYAR
-- ==========================================
local function updateUI()
	-- Format uangnya dulu pakai fungsi di atas
	local cashFormatter = cashFormat(cash.Value)

	-- Tempelkan kurs dollar dan angkanya ke TextLabel
	cashDisplay.Text = "$ " .. cashFormatter
end

-- 1. Jalankan pertama kali saat masuk
updateUI()

-- 2. Pantau terus perubahan uang
cash:GetPropertyChangedSignal("Value"):Connect(updateUI)
