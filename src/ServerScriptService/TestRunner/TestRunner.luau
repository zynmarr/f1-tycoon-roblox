local TestRunner = {}
local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)

local function runTests()
	-- Test 1: Verifikasi poin Rebirth 1 s.d 7 (Formula Linier: 340 * (level + 1))
	local rp1 = RebirthManager:calculateRebirthPoints(0) -- Rebirth ke-1
	assert(rp1 == 340, "[TEST FAIL] Rebirth 1 harusnya 340 RP, didapatkan: " .. tostring(rp1))

	local rp2 = RebirthManager:calculateRebirthPoints(1) -- Rebirth ke-2
	assert(rp2 == 680, "[TEST FAIL] Rebirth 2 harusnya 680 RP, didapatkan: " .. tostring(rp2))

	local rp3 = RebirthManager:calculateRebirthPoints(2) -- Rebirth ke-3
	assert(rp3 == 1020, "[TEST FAIL] Rebirth 3 harusnya 1020 RP, didapatkan: " .. tostring(rp3))

	local rp4 = RebirthManager:calculateRebirthPoints(3) -- Rebirth ke-4
	assert(rp4 == 1360, "[TEST FAIL] Rebirth 4 harusnya 1360 RP, didapatkan: " .. tostring(rp4))

	local rp5 = RebirthManager:calculateRebirthPoints(4) -- Rebirth ke-5
	assert(rp5 == 1700, "[TEST FAIL] Rebirth 5 harusnya 1700 RP, didapatkan: " .. tostring(rp5))

	local rp6 = RebirthManager:calculateRebirthPoints(5) -- Rebirth ke-6
	assert(rp6 == 2040, "[TEST FAIL] Rebirth 6 harusnya 2040 RP, didapatkan: " .. tostring(rp6))

	local rp7 = RebirthManager:calculateRebirthPoints(6) -- Rebirth ke-7
	assert(rp7 == 2380, "[TEST FAIL] Rebirth 7 harusnya 2380 RP, didapatkan: " .. tostring(rp7))

	print("[TEST RUNNER] ✅ Semua pengujian perhitungan poin Rebirth (Formula Linier) berhasil lolos!")
end

function TestRunner.Init()
	task.spawn(function()
		task.wait(1) -- Tunggu inisialisasi modul selesai
		print("[TEST RUNNER] Memulai verifikasi fungsionalitas logika Rebirth...")
		local success, err = pcall(runTests)
		if not success then
			warn("[TEST RUNNER] ❌ PENGUJIAN GAGAL: " .. tostring(err))
		end
	end)
end

return TestRunner
