local ShopConfig = {}

-- Daftar Box yang dijual di Toko
-- Dapat dibeli menggunakan RPM Tokens (mata uang keaktifan) atau Robux (Developer Products)
ShopConfig.Items = {
	{
		Level = 1,
		Name = "Starter Wooden Crate",
		Cost = 5,
		CostRobux = 15,
		ProductID = 1819445101, -- Ganti dengan ID Product asli Anda nanti
		Description = "Kotak kayu dasar untuk pemula.",
	},
	{
		Level = 3,
		Name = "Reinforced Steel Case",
		Cost = 15,
		CostRobux = 35,
		ProductID = 1819445102,
		Description = "Kotak baja kokoh dengan rate gacha lebih baik.",
	},
	{
		Level = 5,
		Name = "Bronze Tier Container",
		Cost = 30,
		CostRobux = 75,
		ProductID = 1819445103,
		Description = "Kontainer perunggu berisi mobil kelas menengah.",
	},
	{
		Level = 8,
		Name = "Platinum F1 Box",
		Cost = 75,
		CostRobux = 150,
		ProductID = 1819445104,
		Description = "Kotak platinum dengan peluang besar mendapat mobil legendaris.",
	},
	{
		Level = 10,
		Name = "Emerald Paddock Case",
		Cost = 150,
		CostRobux = 299,
		ProductID = 1819445105,
		Description = "Casing eksklusif dengan peluang mobil mitos F1.",
	},
}

-- Daftar Gamepass yang dipajang di Toko (pembelian via Robux Gamepass)
ShopConfig.Gamepasses = {
	{
		ID = 1819444791,
		Name = "F1 Pass / VIP",
		CostRobux = 400,
		Description = "Dapatkan cash 1.2x lebih banyak, tag obrolan VIP khusus, dan akses ke fitur F1 Pass eksklusif.",
		Icon = "rbxassetid://15682855589",
	},
	{
		ID = 1819643657,
		Name = "Lucky Boost x2",
		CostRobux = 250,
		Description = "Meningkatkan peluang (luck rate) mendapatkan mobil ber-rarity tinggi 2x lipat dari Gacha Box.",
		Icon = "rbxassetid://15682855590",
	},
	{
		ID = 1819787740,
		Name = "EXP Boost x2",
		CostRobux = 250,
		Description = "Meningkatkan perolehan EXP karakter 2x lebih cepat.",
		Icon = "rbxassetid://15682855592",
	},
	{
		ID = 1948437771,
		Name = "Steel Box Pass",
		CostRobux = 150,
		Description = "Memungkinkan Anda mencuri box dari plot pemain lain (mobil tidak bisa dicuri).",
		Icon = "rbxassetid://15682855591",
	},
}

-- Helper untuk mencari item berdasarkan level box
function ShopConfig.getItemByLevel(level: number)
	for _, item in ipairs(ShopConfig.Items) do
		if item.Level == level then
			return item
		end
	end
	return nil
end

-- Helper untuk mencari item berdasarkan product ID (Robux Developer Product)
function ShopConfig.getItemByProductId(productId: number)
	for _, item in ipairs(ShopConfig.Items) do
		if item.ProductID == productId then
			return item
		end
	end
	return nil
end

return ShopConfig
