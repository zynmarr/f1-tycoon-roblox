--!strict
local UpgradeConfig = {}

export type UpgradeItem = {
	ID: string,
	Title: string,
	Value: number,
	BasePrice: number,
}

-- Konfigurasi Upgrade List per Area
-- Tiap area memiliki harga dan nilai upgrade yang disesuaikan dengan tingkat kesulitannya (Tier)
UpgradeConfig.AreaUpgrades = {
	["AtlantisArea"] = {
		-- Speed upgrades
		{ ID = "SpeedExpBox_1", Title = "Upgrade Speed EXP Box 1", Value = 1, BasePrice = 500 },
		{ ID = "SpeedExpBox_2", Title = "Upgrade Speed EXP Box 2", Value = 2, BasePrice = 1500 },
		
		-- EXP amount upgrades
		{ ID = "ExpAmountBox_1", Title = "Upgrade EXP Box 1", Value = 20, BasePrice = 750 },
		{ ID = "ExpAmountBox_2", Title = "Upgrade EXP Box 2", Value = 50, BasePrice = 2000 },
		
		-- General variant upgrades (All variants)
		{ ID = "VariantChance_All_1", Title = "Upgrade All Variants Chance 1", Value = 2, BasePrice = 1000 },
		{ ID = "VariantChance_All_2", Title = "Upgrade All Variants Chance 2", Value = 5, BasePrice = 4000 },

		-- Specific variant upgrades
		{ ID = "VariantChance_Golden_1", Title = "Upgrade Golden Chance 1", Value = 3, BasePrice = 2500 },
		{ ID = "VariantChance_Golden_2", Title = "Upgrade Golden Chance 2", Value = 7, BasePrice = 6000 },
		{ ID = "VariantChance_Galaxy_1", Title = "Upgrade Galaxy Chance 1", Value = 1, BasePrice = 5000 },
		{ ID = "VariantChance_Galaxy_2", Title = "Upgrade Galaxy Chance 2", Value = 3, BasePrice = 12000 },
		
		-- Variant Chance MAX
		{ ID = "VariantChance_All_Max", Title = "All Variants Chance MAX", Value = 20, BasePrice = 1500000 },
	},
	["OlympusArea"] = {
		-- Speed upgrades
		{ ID = "SpeedExpBox_1", Title = "Upgrade Speed EXP Box 1", Value = 1, BasePrice = 5000 },
		{ ID = "SpeedExpBox_2", Title = "Upgrade Speed EXP Box 2", Value = 2, BasePrice = 15000 },
		
		-- EXP amount upgrades
		{ ID = "ExpAmountBox_1", Title = "Upgrade EXP Box 1", Value = 20, BasePrice = 7500 },
		{ ID = "ExpAmountBox_2", Title = "Upgrade EXP Box 2", Value = 50, BasePrice = 20000 },
		
		-- General variant upgrades (All variants)
		{ ID = "VariantChance_All_1", Title = "Upgrade All Variants Chance 1", Value = 2, BasePrice = 10000 },
		{ ID = "VariantChance_All_2", Title = "Upgrade All Variants Chance 2", Value = 5, BasePrice = 40000 },

		-- Specific variant upgrades
		{ ID = "VariantChance_Golden_1", Title = "Upgrade Golden Chance 1", Value = 3, BasePrice = 25000 },
		{ ID = "VariantChance_Golden_2", Title = "Upgrade Golden Chance 2", Value = 7, BasePrice = 60000 },
		{ ID = "VariantChance_Galaxy_1", Title = "Upgrade Galaxy Chance 1", Value = 1, BasePrice = 50000 },
		{ ID = "VariantChance_Galaxy_2", Title = "Upgrade Galaxy Chance 2", Value = 3, BasePrice = 120000 },
		
		-- Variant Chance MAX
		{ ID = "VariantChance_All_Max", Title = "All Variants Chance MAX", Value = 20, BasePrice = 15000000 },
	}
}

local DefaultUpgrades = UpgradeConfig.AreaUpgrades["AtlantisArea"]

-- Fungsi untuk mendapatkan list upgrade berdasarkan nama area
function UpgradeConfig.getUpgradesForArea(areaName: string): {UpgradeItem}
	return UpgradeConfig.AreaUpgrades[areaName] or DefaultUpgrades
end

return UpgradeConfig
