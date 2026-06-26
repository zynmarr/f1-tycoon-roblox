--!strict
local EventVariantConfig = {
	Variants = {
		Rainy = {
			DisplayName = "Rainy",
			Icon = "🌧️",
			Color = Color3.fromRGB(0, 157, 255),
			Boost = 40,
			AssetName = "Rain",
			AssetType = "Rain", -- Spawns physically on the plot baseplate
		},
		Shiny = {
			DisplayName = "Shiny",
			Icon = "✨",
			Color = Color3.fromRGB(255, 255, 255),
			Boost = 40,
			AssetName = "ShinySky",
			AssetType = "Sky",  -- Spawns locally in game.Lighting
		},
		Golden = {
			DisplayName = "Golden",
			Icon = "🪙",
			Color = Color3.fromRGB(255, 215, 0),
			Boost = 40,
			AssetName = "GoldenSky",
			AssetType = "Sky",
		},
		Rainbow = {
			DisplayName = "Rainbow",
			Icon = "🌈",
			Color = Color3.fromRGB(255, 100, 255),
			Boost = 40,
			AssetName = "RainbowSky",
			AssetType = "Sky",
		},
		Frostbite = {
			DisplayName = "Frostbite",
			Icon = "❄️",
			Color = Color3.fromRGB(150, 220, 255),
			Boost = 40,
			AssetName = "FrostbiteSky",
			AssetType = "Sky",
		},
	},
	Chances = {
		Rest = 70,    -- 70% chance to start in Rest state on join
		Active = 30,  -- 30% chance to start in Active state on join
	},
	Durations = {
		Active = 300,        -- 5 minutes in seconds
		RestMin = 180,       -- 3 minutes in seconds
		RestMax = 300,       -- 5 minutes in seconds
	}
}

return EventVariantConfig
