local GameConfig = {}

GameConfig.MaxInventorySlots = 50

-- =============================================================================
-- GAME CONFIG: RARITIES CONFIGURATION
-- =============================================================================
GameConfig.Rarities = {
	["Common"] = {
		Weight = 10000,
		BasePrice = 1000,
		PriceMod = 1.0,
		Color = Color3.fromRGB(180, 180, 180),
	},
	["Uncommon"] = {
		Weight = 4000,
		BasePrice = 2500,
		PriceMod = 1.2,
		Color = Color3.fromRGB(100, 255, 100),
	},
	["Rare"] = {
		Weight = 1500,
		BasePrice = 6000,
		PriceMod = 1.5,
		Color = Color3.fromRGB(50, 150, 255),
	},
	["Epic"] = {
		Weight = 400,
		BasePrice = 15000,
		PriceMod = 2.0,
		Color = Color3.fromRGB(180, 50, 255),
	},
	["Legendary"] = {
		Weight = 100,
		BasePrice = 35000,
		PriceMod = 3.5,
		Color = Color3.fromRGB(255, 165, 0),
	},
	["Mythic"] = {
		Weight = 20,
		BasePrice = 80000,
		PriceMod = 6.0,
		Color = Color3.fromRGB(255, 50, 50),
	},
	["God"] = {
		Weight = 4,
		BasePrice = 200000,
		PriceMod = 12.0,
		Color = Color3.fromRGB(255, 255, 0),
	},
	["Celestial"] = {
		Weight = 1,
		BasePrice = 500000,
		PriceMod = 25.0,
		Color = Color3.fromRGB(255, 255, 255),
	},
	["Admin"] = {
		Weight = 1,
		BasePrice = 500000,
		PriceMod = 25.0,
		Color = Color3.fromRGB(255, 0, 0),
	},
}

-- =============================================================================
-- GAME CONFIG: CAR LIST BY RARITY
-- =============================================================================
GameConfig.CarRarityList = {
	["Common"] = {
		"Haas – VF-23 (Nico Hulkenberg)",
		"AlphaTauri – AT04 (Yuki Tsunoda)",
		"Alfa Romeo – C43 (Standar) (Zhou Guanyu)",
	},
	["Uncommon"] = {
		"Haas – VF-23 (Kevin Magnussen)",
		"AlphaTauri – AT04 (Daniel Ricciardo)",
		"Williams – FW45 (Standar) (Logan Sargeant)",
	},
	["Rare"] = {
		"Alpine – A523 (Esteban Ocon)",
		"Aston Martin – AMR23 (Lance Stroll)",
		"Kick Sauber – C44 (Zhou Guanyu)",
	},
	["Epic"] = {
		"Alpine – A523 (Pierre Gasly)",
		"Williams – FW45 (Standar) (Alex Albon)",
		"Kick Sauber – C44 (Valtteri Bottas)",
		"Ferrari – SF23 (Standar) (Carlos Sainz)",
		"Mercedes – W14 (George Russell)",
		"McLaren – MCL38 (Oscar Piastri)",
	},
	["Legendary"] = {
		"Aston Martin – AMR23 (Fernando Alonso)",
		"Ferrari – SF23 (Standar) (Charles Leclerc)",
		"Mercedes – W14 (Lewis Hamilton)",
		"McLaren – MCL38 (Lando Norris)",
		"Red Bull – RB19 (Mobil Juara Dunia) (Sergio Perez)",
		"Alfa Romeo – C43 (Italy Edition) (Valtteri Bottas)",
	},
	["Mythic"] = {
		"Red Bull – RB19 (Mobil Juara Dunia) (Max Verstappen)",
		"Ferrari – SF23 (Las Vegas Edition) (Charles Leclerc)",
		"McLaren – MCL60 (Stealth Mode Edition) (Oscar Piastri)",
		"Alfa Romeo – C43 (Italy Edition) (Zhou Guanyu)",
		"Red Bull – RB22 (Mobil masa depan/konsep) (Sergio Perez)",
	},
	["God"] = {
		"Williams – FW45 (Gulf Heritage Edition) (Logan Sargeant)",
		"Red Bull – RB22 (Mobil masa depan/konsep) (Max Verstappen)",
		"Ferrari – SF23 (Las Vegas Edition) (Carlos Sainz)",
		"McLaren – MCL60 (Stealth Mode Edition) (Lando Norris)",
	},
	["Celestial"] = {
		"Williams – FW45 (Gulf Heritage Edition) (Alex Albon)",
		"McLaren – MCL60 (Triple Crown Edition) (Lando Norris)",
		"McLaren – MCL60 (Triple Crown Edition) (Oscar Piastri)",
	},
	["Admin"] = {
		"Paindre Edition",
	},
}

-- =============================================================================
-- GAME CONFIG: VARIANTS CONFIGURATION
-- =============================================================================
GameConfig.Variants = {
	["Normal"] = {
		Chance = 60,
		Multiplier = 1.0,
		Color = Color3.fromRGB(255, 255, 255),
	},
	["Rainy"] = {
		Chance = 12,
		Multiplier = 2.0,
		Color = Color3.fromRGB(0, 157, 255),
		Material = Enum.Material.Neon,
		-- Effect = "Shiny",
	},
	["Luck"] = {
		Chance = 12,
		Multiplier = 2.0,
		Color = Color3.fromRGB(10, 245, 2),
		Material = Enum.Material.Neon,
		-- Effect = "Shiny",
	},
	["Shiny"] = {
		Chance = 12,
		Multiplier = 2.0,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Effect = "Shiny",
	},
	["Carbon"] = {
		Chance = 15,
		Multiplier = 1.5,
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.CorrodedMetal,
		Effect = "WaterAura",
	},
	["Golden"] = {
		Chance = 5,
		Multiplier = 5.0,
		Color = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.Neon,
		Effect = "SpiritualAura",
	},
	["Rainbow"] = {
		Chance = 4,
		Multiplier = 10.0,
		Color = Color3.fromRGB(255, 0, 255),
	},
	["Frostbite"] = {
		Chance = 2.5,
		Multiplier = 20.0,
		Color = Color3.fromRGB(0, 64, 255),
		Material = Enum.Material.Glass,
	},
	["Galaxy"] = {
		Chance = 1,
		Multiplier = 50.0,
		Color = Color3.fromRGB(50, 0, 100),
		Material = Enum.Material.Foil,
	},
	["Hellfire"] = {
		Chance = 0.4,
		Multiplier = 150.0,
		Color = Color3.fromRGB(255, 69, 0),
		Material = Enum.Material.Neon,
	},
	["Cosmic"] = {
		Chance = 0.1,
		Multiplier = 500.0,
		Color = Color3.fromRGB(0, 255, 255),
		Material = Enum.Material.ForceField,
	},
	["Admin"] = {
		Chance = 0,
		Multiplier = 150.0,
		Color = Color3.fromRGB(255, 0, 0),
		Material = Enum.Material.Neon,
	},
}

-- =============================================================================
-- GAME CONFIG: BOX LEVELS CONFIGURATION
-- =============================================================================
GameConfig.BoxLevels = {
	[1] = { Name = "Starter Wooden Crate", MaxExp = 100, LuckMulti = 1.0 },
	[2] = { Name = "Rusty Iron Box", MaxExp = 180, LuckMulti = 1.2 },
	[3] = { Name = "Reinforced Steel Case", MaxExp = 280, LuckMulti = 1.4 },
	[4] = { Name = "Carbon Fiber Crate", MaxExp = 400, LuckMulti = 1.6 },
	[5] = { Name = "Bronze Tier Container", MaxExp = 550, LuckMulti = 1.8 },

	[6] = { Name = "Silver Tier Container", MaxExp = 750, LuckMulti = 2.2 },
	[7] = { Name = "Gold Tier Container", MaxExp = 1000, LuckMulti = 2.6 },
	[8] = { Name = "Platinum F1 Box", MaxExp = 1300, LuckMulti = 3.0 },
	[9] = { Name = "Diamond Grand Prix Crate", MaxExp = 1650, LuckMulti = 3.5 },
	[10] = { Name = "Emerald Paddock Case", MaxExp = 2100, LuckMulti = 4.0 },

	[11] = { Name = "Sapphire Circuit Box", MaxExp = 2600, LuckMulti = 5.0 },
	[12] = { Name = "Ruby Grid Container", MaxExp = 3200, LuckMulti = 6.0 },
	[13] = { Name = "Obsidian Aero Case", MaxExp = 3900, LuckMulti = 7.5 },
	[14] = { Name = "Titanium Chassis Box", MaxExp = 4700, LuckMulti = 9.0 },
	[15] = { Name = "Apex Racing Crate", MaxExp = 5600, LuckMulti = 11.0 },

	[16] = { Name = "Cybernetic Speed Box", MaxExp = 6600, LuckMulti = 14.0 },
	[17] = { Name = "High-Octane Fuel Case", MaxExp = 7700, LuckMulti = 17.0 },
	[18] = { Name = "Quantum Telemetry Box", MaxExp = 8900, LuckMulti = 20.0 },
	[19] = { Name = "Overclocked Engine Crate", MaxExp = 10200, LuckMulti = 24.0 },
	[20] = { Name = "Chrono Pitstop Container", MaxExp = 11600, LuckMulti = 28.0 },

	[21] = { Name = "Matrix Livery Box", MaxExp = 13100, LuckMulti = 35.0 },
	[22] = { Name = "Void Racer Crate", MaxExp = 14700, LuckMulti = 42.0 },
	[23] = { Name = "Nebula Hyper-Drive Case", MaxExp = 16400, LuckMulti = 50.0 },
	[24] = { Name = "Supernova Apex Box", MaxExp = 18200, LuckMulti = 60.0 },
	[25] = { Name = "Mythical Eclipse Crate", MaxExp = 20100, LuckMulti = 75.0 },

	[26] = { Name = "God-Tier Singularity Container", MaxExp = 22100, LuckMulti = 100.0 },
	[27] = { Name = "Celestial Horizon Box", MaxExp = 24200, LuckMulti = 130.0 },
	[28] = { Name = "Eternal Champion Crate", MaxExp = 26400, LuckMulti = 170.0 },
	[29] = { Name = "Paindre Legacy Vault", MaxExp = 28700, LuckMulti = 220.0 },
	[30] = { Name = "Master Creator Admin Box", MaxExp = 31100, LuckMulti = 500.0 },
}

-- =============================================================================
-- GAME CONFIG: UTILITY FUNCTIONS
-- =============================================================================

function GameConfig.setupCarViewport(frame: GuiObject, carTool: Tool)
	local viewport = frame:FindFirstChild("CarView") :: ViewportFrame?
	if not viewport then
		viewport = Instance.new("ViewportFrame")
		viewport.Name = "CarView"
		viewport.Size = UDim2.new(0.9, 0, 0.9, 0)
		viewport.Position = UDim2.fromScale(0.5, 0.5)
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
		viewport.BackgroundTransparency = 1
		viewport.BorderSizePixel = 0
		viewport.Parent = frame
	end

	viewport:ClearAllChildren()

	local carModel = carTool:FindFirstChild("Model") or carTool:FindFirstChildOfClass("Model")
	if not carModel then
		return
	end

	local carClone = carModel:Clone()
	carClone.Parent = viewport
	carClone:PivotTo(CFrame.new(0, 0, 0))

	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	viewport.CurrentCamera = cam
	cam.Parent = viewport

	local size = carClone:GetExtentsSize()
	local dist = size.Magnitude * 0.9

	local cameraPos = Vector3.new(-dist * 0.7, dist * 0.4, -dist * 0.8)
	local lookAt = Vector3.new(0, -dist * 0.1, 0)

	cam.CFrame = CFrame.new(cameraPos, lookAt)

	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, 1)

	local toolLabel = frame:FindFirstChild("toolName") :: GuiObject?
	if toolLabel then
		toolLabel.Visible = false
	end
end

function GameConfig.GetDeviceType(): string
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = game.Players.LocalPlayer

	local deviceType = "Unknown"
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		deviceType = "PC"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		deviceType = "Mobile/Tablet"
	elseif UserInputService.GamepadEnabled or GuiService:IsTenFootInterface() then
		deviceType = "Console"
	else
		return "Tidak Diketahui"
	end

	if player then
		player:SetAttribute("DeviceType", deviceType)
	end
	return deviceType
end

function GameConfig.checkResolution(): string
	local kamera = workspace.CurrentCamera
	local ukuran = kamera.ViewportSize
	local lebar = ukuran.X

	print("Resolusi Layar: " .. lebar .. " x " .. ukuran.Y)

	if lebar > 1000 then
		return "PC atau Tablet Layar Besar"
	elseif lebar > 700 then
		return "Tablet (iPad / Galaxy Tab)"
	else
		return "Mobile (Smartphone)"
	end
end

-- =============================================================================
-- GAME CONFIG: EVENT BOOST CHECKS
-- =============================================================================

function GameConfig.CheckVariantBoost(): number
	local repStorage = game:GetService("ReplicatedStorage")
	local liveEvents = repStorage:FindFirstChild("LiveEvents")
	if liveEvents then
		local boostNode = liveEvents:FindFirstChild("VariantBoost") :: NumberValue?
		if boostNode then
			return boostNode.Value
		end
	end
	return 0
end

function GameConfig.CheckLuckyChanceBoost(): number
	local repStorage = game:GetService("ReplicatedStorage")
	local liveEvents = repStorage:FindFirstChild("LiveEvents")
	if liveEvents then
		local boostNode = liveEvents:FindFirstChild("LuckyChanceBoost") :: NumberValue?
		if boostNode then
			return boostNode.Value
		end
	end
	return 0
end

function GameConfig.CheckExpBoost(): number
	local repStorage = game:GetService("ReplicatedStorage")
	local liveEvents = repStorage:FindFirstChild("LiveEvents")
	if liveEvents then
		local boostNode = liveEvents:FindFirstChild("ExpBoost") :: NumberValue?
		if boostNode then
			return boostNode.Value
		end
	end
	return 0
end

-- =============================================================================
-- GAME CONFIG: INVENTORY & ITEM MANAGEMENT
-- =============================================================================

function GameConfig.CanPlayerPickUp(player: Player): boolean
	local char = player.Character
	if not char then
		return false
	end
	for _, obj in pairs(char:GetChildren()) do
		if obj:GetAttribute("ItemName") then
			return false
		end
	end
	return true
end

function GameConfig.ApplyVisuals(tool: Tool, rarityName: string, variantString: string?)
	local variantFolder = game:GetService("ServerStorage"):FindFirstChild("VariantEffect")
	local model = tool:FindFirstChild("Model")
	if not model then
		return
	end

	if variantString and variantString ~= "Normal" then
		local variants = string.split(variantString, ",")
		local bestVariant = variants[#variants]
		local vData = GameConfig.Variants[bestVariant]
		local handle = tool:FindFirstChild("Handle")

		if vData and vData.Effect and handle then
			for _, part in pairs(handle:GetChildren()) do
				if part.Name == vData.Effect then
					part:Destroy()
					break
				end
			end
			local effect = variantFolder and variantFolder:FindFirstChild(vData.Effect)
			if effect then
				local clonedEffect = effect:Clone()
				clonedEffect.Parent = handle
			else
				warn(
					"[GameConfig] Effect template '"
						.. tostring(vData.Effect)
						.. "' tidak ditemukan di ServerStorage.VariantEffect!"
				)
			end
		end
	end

	local tierData = GameConfig.Rarities[rarityName]
	if tierData and rarityName ~= "Common" then
		local h = Instance.new("Highlight", model)
		h.Name = "RarityHighlight"
		h.OutlineColor = tierData.Color
		h.FillColor = tierData.Color
		h.FillTransparency = 0.85
		h.DepthMode = Enum.HighlightDepthMode.Occluded
	end

	if variantString and variantString ~= "Normal" then
		local variants = string.split(variantString, ",")
		local bestVariant = variants[#variants]
		local vData = GameConfig.Variants[bestVariant]

		if vData then
			local vh = Instance.new("Highlight", model)
			vh.Name = "VariantHighlight"
			vh.FillColor = (typeof(vData.Color) == "Color3") and vData.Color or Color3.fromRGB(255, 255, 255)
			vh.FillTransparency = 0.5
			vh.DepthMode = Enum.HighlightDepthMode.Occluded

			if bestVariant == "Rainbow" then
				task.spawn(function()
					while vh and vh.Parent do
						local hue = (tick() % 5) / 5
						vh.FillColor = Color3.fromHSV(hue, 1, 1)
						vh.OutlineColor = Color3.fromHSV(hue, 1, 1)
						task.wait()
					end
				end)
			end
		end
	end
end

function GameConfig.ClearHands(player: Player)
	local char = player.Character
	local inv = player:FindFirstChild("ItemInventory")
	if not char or not inv then
		return
	end

	local hotbar = inv:FindFirstChild("Hotbar")
	local bag = inv:FindFirstChild("Bag")
	local capacity = inv:FindFirstChild("HotbarCapacity") :: IntValue?

	for _, obj in pairs(char:GetChildren()) do
		if obj:GetAttribute("ItemName") then
			if hotbar and capacity and #hotbar:GetChildren() < capacity.Value then
				GameConfig.StoreItem(obj, hotbar)
				obj:SetAttribute("LastLocation", "Hotbar")
			elseif bag then
				GameConfig.StoreItem(obj, bag)
				obj:SetAttribute("LastLocation", "Bag")
			end
		end
	end
end

function GameConfig.StoreItem(item: Instance, targetFolder: Folder)
	if not item then
		return
	end

	local root = item:IsA("Model") and item.PrimaryPart or item
	if item:IsA("Model") and not root then
		item:ScaleTo(0.2)
		root = item:FindFirstChildWhichIsA("BasePart", true)
	end

	if root then
		local holdWeld = root:FindFirstChild("ItemHoldWeld")
		if holdWeld then
			holdWeld:Destroy()
		end
	end

	if item:IsA("Model") then
		if targetFolder.Name == "MyCars" then
			item:ScaleTo(0.8)
		elseif targetFolder.Name == "Bag" or targetFolder.Name == "Hotbar" or targetFolder.Name == "Inventory" then
			item:ScaleTo(0.2)
		else
			item:ScaleTo(0.2)
		end
	end

	item.Parent = targetFolder
end

-- =============================================================================
-- GAME CONFIG: GACHA ROLLING & PRICING
-- =============================================================================

function GameConfig.RollRarity(luck: number): string
	if not luck or luck < 1 then
		luck = 1
	end

	local total = 0
	local pool = {}
	local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "God", "Celestial" }

	for i, n in ipairs(rarityOrder) do
		local d = GameConfig.Rarities[n]
		if d then
			local w = d.Weight
			if n ~= "Common" then
				local tierPower = (i - 1) / 2.5
				w = d.Weight * math.pow(luck, tierPower)
			end
			total += w
			pool[n] = w
		end
	end

	local r = math.random() * total
	local cur = 0

	for i = #rarityOrder, 1, -1 do
		local n = rarityOrder[i]
		local w = pool[n]
		if w then
			cur += w
			if r <= cur then
				return n
			end
		end
	end

	return "Common"
end

function GameConfig.CalculatePrice(base: number?, rName: string, vNameString: string?): (number, number)
	local rData = GameConfig.Rarities[rName] or GameConfig.Rarities.Common
	local totalVariantMulti = 1.0

	if vNameString and vNameString ~= "" then
		local activeVariants = string.split(vNameString, ",")
		for _, vName in pairs(activeVariants) do
			local vData = GameConfig.Variants[vName]
			if vData then
				totalVariantMulti = totalVariantMulti + (vData.Multiplier - 1.0)
			end
		end
	end

	local rawPrice = (base or 1000) * rData.PriceMod * totalVariantMulti

	-- Compress values smoothly using f(x) = L * x / (x + k)
	-- Max sell price = 100,000,000, k = 90,000,000
	-- Max income = 300,000, k = 3,000,000
	local sellPrice = math.floor(100000000 * rawPrice / (rawPrice + 90000000))
	local income = math.floor(300000 * rawPrice / (rawPrice + 3000000))

	return income, sellPrice
end

function GameConfig.cleanupAndWeldCar(model: Model)
	local primary = model.PrimaryPart
	if not primary then
		print("Model tidak memiliki PrimaryPart")
		return
	end

	for _, p in pairs(model:GetDescendants()) do
		if p:IsA("Script") or p:IsA("LocalScript") then
			p.Enabled = false
			pcall(function()
				p:Destroy()
			end)
		elseif
			p:IsA("Sound")
			or p:IsA("BodyMover")
			or p:IsA("Constraint")
			or p:IsA("Attachment")
			or p:IsA("JointInstance")
		then
			pcall(function()
				p:Destroy()
			end)
		elseif p:IsA("Seat") or p:IsA("VehicleSeat") then
			p.Disabled = true
		elseif p:IsA("ClickDetector") or p:IsA("ProximityPrompt") then
			pcall(function()
				p:Destroy()
			end)
		elseif p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			if p ~= primary then
				local w = Instance.new("WeldConstraint")
				w.Part0 = primary
				w.Part1 = p
				w.Parent = primary
			end
		end
	end
	print("CLEAN UP BERHASIL")
end

function GameConfig.GetColoredVariantList(variantString: string?): string
	if not variantString or variantString == "" or variantString == "Normal" then
		return "<font color='#FFFFFF'>[Normal]</font>"
	end

	local variants = string.split(variantString, ",")
	local coloredText = ""
	for _, vName in pairs(variants) do
		local vData = GameConfig.Variants[vName]
		local color = (vData and typeof(vData.Color) == "Color3") and ("#" .. vData.Color:ToHex()) or "#FFFFFF"
		coloredText = coloredText .. "<font color='" .. color .. "'>[" .. vName .. "]</font>"
	end
	return coloredText
end

return GameConfig
