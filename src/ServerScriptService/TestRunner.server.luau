local RebirthManager = require(game.ServerScriptService.RebirthManager.RebirthManager)

print("[TEST RUNNER] Memulai verifikasi fungsionalitas logika Rebirth...")

local function runTests()
	-- Test 1: Verifikasi poin Rebirth 1 s.d 4
	local rp1 = RebirthManager:calculateRebirthPoints(0) -- Rebirth ke-1
	assert(rp1 == 50, "[TEST FAIL] Rebirth 1 harusnya 50 RP, didapatkan: " .. tostring(rp1))

	local rp2 = RebirthManager:calculateRebirthPoints(1) -- Rebirth ke-2
	assert(rp2 == 100, "[TEST FAIL] Rebirth 2 harusnya 100 RP, didapatkan: " .. tostring(rp2))

	local rp3 = RebirthManager:calculateRebirthPoints(2) -- Rebirth ke-3
	assert(rp3 == 180, "[TEST FAIL] Rebirth 3 harusnya 180 RP, didapatkan: " .. tostring(rp3))

	local rp4 = RebirthManager:calculateRebirthPoints(3) -- Rebirth ke-4 (i=3, 3%3 == 0 -> (180*2)+20 = 380)
	assert(rp4 == 380, "[TEST FAIL] Rebirth 4 harusnya 380 RP, didapatkan: " .. tostring(rp4))

	local rp5 = RebirthManager:calculateRebirthPoints(4) -- Rebirth ke-5 (i=4, 4%3 ~= 0 -> 380+100 = 480)
	assert(rp5 == 480, "[TEST FAIL] Rebirth 5 harusnya 480 RP, didapatkan: " .. tostring(rp5))

	local rp6 = RebirthManager:calculateRebirthPoints(5) -- Rebirth ke-6 (i=5, 5%3 ~= 0 -> 480+100 = 580)
	assert(rp6 == 580, "[TEST FAIL] Rebirth 6 harusnya 580 RP, didapatkan: " .. tostring(rp6))

	local rp7 = RebirthManager:calculateRebirthPoints(6) -- Rebirth ke-7 (i=6, 6%3 == 0 -> (580*2)+20 = 1180)
	assert(rp7 == 1180, "[TEST FAIL] Rebirth 7 harusnya 1180 RP, didapatkan: " .. tostring(rp7))

	print("[TEST RUNNER] ✅ Semua pengujian perhitungan poin Rebirth (Opsi A) berhasil lolos!")
end

task.spawn(function()
	task.wait(1) -- Tunggu inisialisasi modul selesai
	local success, err = pcall(runTests)
	if not success then
		warn("[TEST RUNNER] ❌ PENGUJIAN GAGAL: " .. tostring(err))
	end
end)
