--!strict
local RoleConfig = {}

export type Permission =
	"UseAdminCommands" -- Mengizinkan penggunaan command chat khusus admin
	| "AccessDevConsole" -- Memiliki izin akses developer console
	| "VIPMultiplier" -- Mendapatkan multiplier bonus Cash
	| "ModeratePlayers" -- Mengizinkan moderasi pemain (kick, ban, mute)
	| "EditGameConfigs" -- Mengizinkan memodifikasi konfigurasi event global

-- Struktur konfigurasi untuk masing-masing pangkat/role
RoleConfig.Roles = {
	["Player"] = {
		Rank = 1,
		DisplayName = "Player",
		Color = Color3.fromRGB(175, 175, 175),
		Emoji = "",
		Permissions = {},
	},
	["VIP"] = {
		Rank = 2,
		DisplayName = "VIP",
		Color = Color3.fromRGB(255, 200, 0), -- Gold
		Emoji = "👑",
		Permissions = { "VIPMultiplier" },
	},
	["Moderator"] = {
		Rank = 3,
		DisplayName = "Moderator",
		Color = Color3.fromRGB(0, 200, 255), -- Sky Blue
		Emoji = "🛡️",
		Permissions = { "UseAdminCommands", "ModeratePlayers" },
	},
	["Developer"] = {
		Rank = 4,
		DisplayName = "Developer",
		Color = Color3.fromRGB(26, 0, 224), -- Vibrant Red
		Emoji = "🛠️",
		Permissions = { "UseAdminCommands", "ModeratePlayers", "AccessDevConsole", "EditGameConfigs", "VIPMultiplier" },
	},
	["Owner"] = {
		Rank = 5,
		DisplayName = "Owner",
		Color = Color3.fromRGB(255, 0, 0), -- Royal Purple
		Emoji = "⚡",
		Permissions = { "UseAdminCommands", "ModeratePlayers", "AccessDevConsole", "EditGameConfigs", "VIPMultiplier" },
	},
}

return RoleConfig
