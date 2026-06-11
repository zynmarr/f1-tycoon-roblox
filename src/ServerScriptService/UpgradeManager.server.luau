--local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local buyUpgradeFunction = ReplicatedStorage:WaitForChild("BuyUpgradeFunction")

--buyUpgradeFunction.OnServerInvoke = function(player, upgradeId, price)
--	local leaderstats = player:FindFirstChild("leaderstats")
--	if not leaderstats then return false end

--	local cash = leaderstats:FindFirstChild("Cash")
--	if not cash then return false end

--	-- Cek apakah uangnya cukup
--	if cash.Value >= price then
--		-- Potong uang
--		cash.Value -= price

--		-- Berikan atribut sebagai tanda pemain sudah memiliki upgrade ini
--		player:SetAttribute("Upg_" .. upgradeId, true)

--		print(player.Name .. " successfully bought: " .. upgradeId)
--		return true -- Berhasil
--	else
--		-- Uang tidak cukup
--		return false
--	end
--end