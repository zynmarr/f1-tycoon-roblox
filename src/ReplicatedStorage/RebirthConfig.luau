--!strict
-- =============================================================================
-- REBIRTH CONFIG: Konfigurasi terpusat untuk seluruh sistem Rebirth & Upgrade Shop
-- Digunakan oleh: RebirthManager, SpawnerBoxManager, BoxManager,
--                 ParkingAreaManager, SellGuiServer, SellManager, RebirthTab
-- =============================================================================
local RebirthConfig = {}

-- Batas maksimum level Rebirth pemain
RebirthConfig.MAX_REBIRTH = 25

-- =============================================================================
-- TABEL KURVA EFEK NON-FLAT (Tapered / Diminishing Returns)
-- Index = level upgrade (0 = belum beli, 1-10 atau 1-5 = sudah beli)
-- Nilai = efek dalam satuan yang relevan (%, +speed, +slot)
-- =============================================================================
RebirthConfig.UPGRADE_CURVES = {
	-- Level:             0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10
	CashMultiplier =  {  0,  5,  9, 12, 15, 18, 21, 24, 26, 28, 30 }, -- Maks +30% Cash
	LuckMultiplier =  {  0,  8, 15, 21, 27, 32, 37, 41, 45, 48, 50 }, -- Maks +50% Luck

	-- Level:             0,  1,  2,  3,  4,  5
	WalkspeedBoost =     {  0,  5, 10, 14, 17, 20 },  -- Maks +20 speed
	MaxInventorySlots =  {  0,  8, 14, 19, 23, 25 },  -- Maks +25 slot
	DoubleCashChance =   {  0,  6, 11, 16, 21, 25 },  -- Maks 25% chance

	VariantChance_Rainbow =   { 0,  5,  9, 13, 17, 20 }, -- Maks +20% rate
	VariantChance_Frostbite = { 0,  4,  7, 10, 13, 15 }, -- Maks +15% rate
	VariantChance_Galaxy =    { 0,  3,  6,  9, 11, 13 }, -- Maks +13% rate
	VariantChance_Hellfire =  { 0,  3,  5,  7,  9, 10 }, -- Maks +10% rate
	VariantChance_Cosmic =    { 0,  1,  2,  3,  4,  5 }, -- Maks +5% rate
	AllVariantsBoost =        { 0,  5,  9, 13, 17, 20 }, -- Maks +20% rate (global semua varian langka)
}

-- =============================================================================
-- BATAS LEVEL MAKSIMUM PER UPGRADE
-- =============================================================================
RebirthConfig.UPGRADE_CAPS = {
	CashMultiplier =          10,
	LuckMultiplier =          10,
	WalkspeedBoost =          5,
	MaxInventorySlots =       5,
	DoubleCashChance =        5,
	VariantChance_Rainbow =   5,
	VariantChance_Frostbite = 5,
	VariantChance_Galaxy =    5,
	VariantChance_Hellfire =  5,
	VariantChance_Cosmic =    5,
	AllVariantsBoost =        5,
}

-- =============================================================================
-- FORMULA BIAYA UPGRADE (RP)
-- Biaya = BaseCost * (2 ^ currentLevel) [Kecuali DoubleCashChance pakai 2.2]
-- =============================================================================
RebirthConfig.UPGRADE_BASE_COST = {
	CashMultiplier =          15,   -- Easy
	MaxInventorySlots =       20,   -- Easy
	LuckMultiplier =          25,   -- Medium
	WalkspeedBoost =          80,   -- Medium
	VariantChance_Galaxy =    80,   -- Medium
	VariantChance_Rainbow =   60,   -- Medium
	VariantChance_Frostbite = 60,   -- Medium
	AllVariantsBoost =        600,  -- Hard
	VariantChance_Cosmic =    600,  -- Hard
	VariantChance_Hellfire =  500,  -- Hard
	DoubleCashChance =        150,  -- Hard (pakai faktor 2.2)
}

-- Faktor eksponensial khusus per upgrade (default 2.0, DoubleCashChance = 2.2)
RebirthConfig.UPGRADE_COST_FACTOR = {
	DoubleCashChance = 2.2,
}

-- Helper: Hitung biaya RP untuk membeli level berikutnya
function RebirthConfig.getUpgradeCost(upgradeName: string, currentLevel: number): number
	local base = RebirthConfig.UPGRADE_BASE_COST[upgradeName] or 50
	local factor = RebirthConfig.UPGRADE_COST_FACTOR[upgradeName] or 2.0
	return math.floor(base * (factor ^ currentLevel))
end

-- Helper: Ambil efek upgrade pada level tertentu
function RebirthConfig.getUpgradeEffect(upgradeName: string, level: number): number
	local curve = RebirthConfig.UPGRADE_CURVES[upgradeName]
	if not curve then return 0 end
	local idx = math.clamp(level, 0, #curve - 1)
	return curve[idx + 1] or 0
end

-- =============================================================================
-- METADATA UPGRADE UNTUK UI (RebirthTab)
-- =============================================================================
RebirthConfig.UPGRADE_META = {
	CashMultiplier = {
		Name = "Cash Multiplier",
		Desc = "Tambahan % Cash dari semua sumber (Maks +30%)",
		Icon = "💰",
		Category = "Easy",
		Unit = "%",
	},
	MaxInventorySlots = {
		Name = "Inventory Slots",
		Desc = "Tambah kapasitas slot tas mobil (Maks +25 slot)",
		Icon = "🎒",
		Category = "Easy",
		Unit = " slot",
	},
	LuckMultiplier = {
		Name = "Luck Multiplier",
		Desc = "Tambahan % Luck gacha box secara global (Maks +50%)",
		Icon = "🍀",
		Category = "Medium",
		Unit = "%",
	},
	WalkspeedBoost = {
		Name = "Walkspeed Boost",
		Desc = "Tambahan kecepatan lari permanen (Maks +20 speed)",
		Icon = "👟",
		Category = "Medium",
		Unit = " speed",
	},
	VariantChance_Galaxy = {
		Name = "Galaxy Chance",
		Desc = "Tambahan % rate gacha varian Galaxy (Maks +13%)",
		Icon = "🌌",
		Category = "Medium",
		Unit = "%",
	},
	VariantChance_Rainbow = {
		Name = "Rainbow Chance",
		Desc = "Tambahan % rate gacha varian Rainbow (Maks +20%)",
		Icon = "🌈",
		Category = "Medium",
		Unit = "%",
	},
	VariantChance_Frostbite = {
		Name = "Frostbite Chance",
		Desc = "Tambahan % rate gacha varian Frostbite (Maks +15%)",
		Icon = "❄️",
		Category = "Medium",
		Unit = "%",
	},
	AllVariantsBoost = {
		Name = "All Variants Boost",
		Desc = "Tambahan % rate global seluruh varian langka (Maks +20%)",
		Icon = "✨",
		Category = "Hard",
		Unit = "%",
	},
	VariantChance_Cosmic = {
		Name = "Cosmic Chance",
		Desc = "Tambahan % rate gacha varian Cosmic (Maks +5%)",
		Icon = "🌀",
		Category = "Hard",
		Unit = "%",
	},
	VariantChance_Hellfire = {
		Name = "Hellfire Chance",
		Desc = "Tambahan % rate gacha varian Hellfire (Maks +10%)",
		Icon = "🔥",
		Category = "Hard",
		Unit = "%",
	},
	DoubleCashChance = {
		Name = "Double Cash Chance",
		Desc = "% peluang mendapatkan Cash 2x lipat (Maks 25%)",
		Icon = "⚡",
		Category = "Hard",
		Unit = "%",
	},
}

-- Urutan tampilan upgrade di UI per kategori
RebirthConfig.UPGRADE_ORDER = {
	Easy   = { "CashMultiplier", "MaxInventorySlots" },
	Medium = { "LuckMultiplier", "WalkspeedBoost", "VariantChance_Rainbow", "VariantChance_Frostbite", "VariantChance_Galaxy" },
	Hard   = { "AllVariantsBoost", "VariantChance_Cosmic", "VariantChance_Hellfire", "DoubleCashChance" },
}

return RebirthConfig
