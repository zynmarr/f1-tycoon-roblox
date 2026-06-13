local GameConfig = {}

GameConfig.MaxInventorySlots = 50

-- =============================================================================
-- GAME CONFIG: RE-BALANCED RARITIES CONFIGURATION
-- (Angka Weight disesuaikan untuk kombinasi rumus math.pow)
-- =============================================================================

GameConfig.Rarities = {
	-- Kasta Dasar (Sangat mudah didapat saat awal main)
	["Common"] = {
		Weight = 10000, -- Base pool paling besar
		BasePrice = 1000,
		PriceMod = 1.0,
		Color = Color3.fromRGB(180, 180, 180),
	},
	["Uncommon"] = {
		Weight = 4000,
		BasePrice = 3000,
		PriceMod = 1.5,
		Color = Color3.fromRGB(100, 255, 100),
	},
	["Rare"] = {
		Weight = 1500,
		BasePrice = 8000,
		PriceMod = 2.5,
		Color = Color3.fromRGB(50, 150, 255),
	},

	-- Kasta Menengah (Mulai menantang, butuh hoki/upgrade)
	["Epic"] = {
		Weight = 400,
		BasePrice = 20000,
		PriceMod = 5.0,
		Color = Color3.fromRGB(180, 50, 255),
	},
	["Legendary"] = {
		Weight = 100,
		BasePrice = 50000,
		PriceMod = 12.0,
		Color = Color3.fromRGB(255, 165, 0),
	},

	-- Kasta Dewa (Sangat amat langka tanpa bantuan luck/event)
	["Mythic"] = {
		Weight = 20,
		BasePrice = 150000,
		PriceMod = 30.0,
		Color = Color3.fromRGB(255, 50, 50),
	},
	["God"] = {
		Weight = 4,
		BasePrice = 500000,
		PriceMod = 100.0,
		Color = Color3.fromRGB(255, 255, 0),
	},
	["Celestial"] = {
		Weight = 1, -- Keramat! Rasio murni tanpa luck adalah 1 banding ~16.0000
		BasePrice = 1500000,
		PriceMod = 500.0,
		Color = Color3.fromRGB(255, 255, 255),
	},
}

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
		"Alfa Romeo – C43 (Italy Edition) (Zhou Guanyu)", -- Sisa Masuk Sini (Zhou)
		"Red Bull – RB22 (Mobil masa depan/konsep) (Sergio Perez)", -- Sisa Masuk Sini (Perez)
	},
	["God"] = {
		"Williams – FW45 (Gulf Heritage Edition) (Logan Sargeant)",
		"Red Bull – RB22 (Mobil masa depan/konsep) (Max Verstappen)",
		"Ferrari – SF23 (Las Vegas Edition) (Carlos Sainz)", -- Sisa Masuk Sini (Sainz)
		"McLaren – MCL60 (Stealth Mode Edition) (Lando Norris)", -- Sisa Masuk Sini (Norris)
	},
	["Celestial"] = {
		"Williams – FW45 (Gulf Heritage Edition) (Alex Albon)",
		"McLaren – MCL60 (Triple Crown Edition) (Lando Norris)",
		"McLaren – MCL60 (Triple Crown Edition) (Oscar Piastri)", -- Sisa Masuk Sini (Piastri)
	},
	["Admin"] = {
		-- KHUSUS GIFT EVENT / COMMAND OWNER (Tidak bisa didapat dari gacha box)
		--"Paindre – Hyperion F1 Chassis (Hyper-Concept)", -- Model 1: Konsep Hypercar F1 Masa Depan
		--"Paindre – Horizon Neon-Livery (Creator Edition)" -- Model 2: Edisi Khusus Kreator penuh lampu neon
	},
}

function GameConfig.setupCarViewport(frame, carTool)
	-- 1. Setup ViewportFrame
	local viewport = frame:FindFirstChild("CarView")
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

	-- 2. Clone Model
	local carModel = carTool:FindFirstChild("Model") or carTool:FindFirstChildOfClass("Model")
	if not carModel then
		return
	end

	local carClone = carModel:Clone()
	carClone.Parent = viewport
	carClone:PivotTo(CFrame.new(0, 0, 0))

	-- 3. Setup Camera
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40 -- FOV lebih kecil membuat mobil terlihat lebih padat/fokus
	viewport.CurrentCamera = cam
	cam.Parent = viewport

	-- 4. PERHITUNGAN POSISI KAMERA (DEPAN - SERONG KIRI - MENUNDUK)
	local size = carClone:GetExtentsSize()
	local dist = size.Magnitude * 0.9 -- Jarak kamera

	-- Penjelasan Koordinat:
	-- X (dist * 0.7) -> Membuat kamera serong ke kiri
	-- Y (dist * 0.4) -> Tinggi kamera (agak naik sedikit)
	-- Z (-dist * 0.8) -> Berada di DEPAN mobil (Sumbu Z negatif biasanya depan untuk model)

	local cameraPos = Vector3.new(-dist * 0.7, dist * 0.4, -dist * 0.8)
	local lookAt = Vector3.new(0, -dist * 0.1, 0) -- Titik fokus diturunkan sedikit agar kamera terlihat "menunduk"

	cam.CFrame = CFrame.new(cameraPos, lookAt)

	-- 5. Lighting (WAJIB agar terlihat terang)
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1, 1) -- Menyesuaikan arah cahaya dari depan

	if frame:FindFirstChild("toolName") then
		frame.toolName.Visible = false
	end
end

function GameConfig.GetDeviceType()
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = game.Players.LocalPlayer
	--local newInstance =  player.AddAttribute("DeviceType", "Unknown")
	--print("UserInputService.KeyboardEnabled: ", UserInputService.KeyboardEnabled)
	--print("UserInputService.MouseEnabled: ", UserInputService.MouseEnabled)
	--print("UserInputService.TouchEnabled: ", UserInputService.TouchEnabled)
	--print("UserInputService.GamepadEnabled: ", UserInputService.GamepadEnabled)
	--print("GuiService:IsTenFootInterface(): ", GuiService:IsTenFootInterface())

	local deviceType = "Unknown"
	-- Jika punya keyboard dan mouse, berarti ini PC / Laptop
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		deviceType = "PC"
		local playerDevice = player:SetAttribute("DeviceType", deviceType)
		--print("PLAYER DEVICE: "..deviceType)

		-- Jika mendukung layar sentuh dan tidak ada keyboard bawaan aktif, ini Mobile/Tablet
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		deviceType = "Mobile/Tablet"
		local playerDevice = player:SetAttribute("DeviceType", deviceType)
		--print("PLAYER DEVICE: "..deviceType)

		-- Jika menggunakan stik konsol (Xbox/PlayStation)
	elseif UserInputService.GamepadEnabled or GuiService:IsTenFootInterface() then
		deviceType = "Console"
		--return "Console"
		local playerDevice = player:SetAttribute("DeviceType", deviceType)
		--print("PLAYER DEVICE: "..deviceType)
	else
		return "Tidak Diketahui"
	end
end

function GameConfig.checkResolution()
	local kamera = workspace.CurrentCamera
	local ukuran = kamera.ViewportSize
	local lebar = ukuran.X
	local tinggi = ukuran.Y

	print("Resolusi Layar: " .. lebar .. " x " .. tinggi)

	-- Logika mendeteksi berdasarkan ukuran (biasanya layar HP lebarnya di bawah 800 atau tingginya sangat kecil)
	if lebar > 1000 then
		return "PC atau Tablet Layar Besar"
	elseif lebar > 700 then
		return "Tablet (iPad / Galaxy Tab)"
	else
		return "Mobile (Smartphone)"
	end
end

GameConfig.Variants = {
	["Normal"] = {
		Chance = 60,
		Multiplier = 1.0,
		Color = Color3.fromRGB(255, 255, 255),
	},
	["Carbon"] = {
		-- [BARU]: Tema sasis serat karbon mentah khas F1, sangat ringan & aerodinamis!
		Chance = 15,
		Multiplier = 1.5,
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.CorrodedMetal,
		Effect = "WaterAura",
	},
	["Shiny"] = {
		Chance = 12,
		Multiplier = 2.0,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Effect = "Shiny",
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
		Color = Color3.fromRGB(255, 0, 255), -- Nanti di script visual di-looping warnanya (RGB)
	},
	["Frostbite"] = {
		-- [BARU]: Tema Es membeku, bodi mobil dilapisi es transparan yang dingin
		Chance = 2.5,
		Multiplier = 20.0,
		Color = Color3.fromRGB(135, 206, 250),
		Material = Enum.Material.Glass,
	},
	["Galaxy"] = {
		Chance = 1,
		Multiplier = 50.0,
		Color = Color3.fromRGB(50, 0, 100),
		Material = Enum.Material.Foil,
	},
	["Hellfire"] = {
		-- [BARU]: Tema Api Neraka! Sangat cocok dipadukan dengan efek ParticleEmitter api di knalpot
		Chance = 0.4,
		Multiplier = 150.0,
		Color = Color3.fromRGB(255, 69, 0),
		Material = Enum.Material.Neon,
	},
	["Cosmic"] = {
		-- [BARU]: Kasta Tertinggi! Kekuatan alam semesta, multiplier raksasa murni untuk kolektor dewa
		Chance = 0.1,
		Multiplier = 500.0,
		Color = Color3.fromRGB(0, 255, 255),
		Material = Enum.Material.ForceField, -- Efek animasi tameng bergerak bawaan Roblox, keren parah!
	},
}

GameConfig.BoxLevels = {
	-- TIER 1: ROOKIE / BASIC (Luck landai)
	[1] = { Name = "Starter Wooden Crate", MaxExp = 100, LuckMulti = 1.0 },
	[2] = { Name = "Rusty Iron Box", MaxExp = 180, LuckMulti = 1.2 },
	[3] = { Name = "Reinforced Steel Case", MaxExp = 280, LuckMulti = 1.4 },
	[4] = { Name = "Carbon Fiber Crate", MaxExp = 400, LuckMulti = 1.6 },
	[5] = { Name = "Bronze Tier Container", MaxExp = 550, LuckMulti = 1.8 },

	-- TIER 2: PROFESSIONAL / PREMIUM
	[6] = { Name = "Silver Tier Container", MaxExp = 750, LuckMulti = 2.2 },
	[7] = { Name = "Gold Tier Container", MaxExp = 1000, LuckMulti = 2.6 },
	[8] = { Name = "Platinum F1 Box", MaxExp = 1300, LuckMulti = 3.0 },
	[9] = { Name = "Diamond Grand Prix Crate", MaxExp = 1650, LuckMulti = 3.5 },
	[10] = { Name = "Emerald Paddock Case", MaxExp = 2100, LuckMulti = 4.0 },

	-- TIER 3: GRAND PRIX / ADVANCED
	[11] = { Name = "Sapphire Circuit Box", MaxExp = 2600, LuckMulti = 5.0 },
	[12] = { Name = "Ruby Grid Container", MaxExp = 3200, LuckMulti = 6.0 },
	[13] = { Name = "Obsidian Aero Case", MaxExp = 3900, LuckMulti = 7.5 },
	[14] = { Name = "Titanium Chassis Box", MaxExp = 4700, LuckMulti = 9.0 },
	[15] = { Name = "Apex Racing Crate", MaxExp = 5600, LuckMulti = 11.0 },

	-- TIER 4: HYPER-TECH
	[16] = { Name = "Cybernetic Speed Box", MaxExp = 6600, LuckMulti = 14.0 },
	[17] = { Name = "High-Octane Fuel Case", MaxExp = 7700, LuckMulti = 17.0 },
	[18] = { Name = "Quantum Telemetry Box", MaxExp = 8900, LuckMulti = 20.0 },
	[19] = { Name = "Overclocked Engine Crate", MaxExp = 10200, LuckMulti = 24.0 },
	[20] = { Name = "Chrono Pitstop Container", MaxExp = 11600, LuckMulti = 28.0 },

	-- TIER 5: MYTHICAL / COSMIC
	[21] = { Name = "Matrix Livery Box", MaxExp = 13100, LuckMulti = 35.0 },
	[22] = { Name = "Void Racer Crate", MaxExp = 14700, LuckMulti = 42.0 },
	[23] = { Name = "Nebula Hyper-Drive Case", MaxExp = 16400, LuckMulti = 50.0 },
	[24] = { Name = "Supernova Apex Box", MaxExp = 18200, LuckMulti = 60.0 },
	[25] = { Name = "Mythical Eclipse Crate", MaxExp = 20100, LuckMulti = 75.0 },

	-- TIER 6: GOD-TIER / ADMIN
	[26] = { Name = "God-Tier Singularity Container", MaxExp = 22100, LuckMulti = 100.0 },
	[27] = { Name = "Celestial Horizon Box", MaxExp = 24200, LuckMulti = 130.0 },
	[28] = { Name = "Eternal Champion Crate", MaxExp = 26400, LuckMulti = 170.0 },
	[29] = { Name = "Paindre Legacy Vault", MaxExp = 28700, LuckMulti = 220.0 },
	[30] = { Name = "Master Creator Admin Box", MaxExp = 31100, LuckMulti = 500.0 },
}
--for i = 1, 30 do GameConfig.BoxLevels[i] = { MaxExp = 100 + (i * 50), LuckMulti = 2 + (i * 5) } end

function GameConfig.CheckVariantBoost()
	local repStorage = game:GetService("ReplicatedStorage")
	local liveEvents = repStorage:FindFirstChild("LiveEvents")

	if liveEvents then
		local boostNode = liveEvents:FindFirstChild("VariantBoost")
		if boostNode then
			return boostNode.Value -- HARUS MENGGUNAKAN .Value
		end
	end

	return 0 -- Jika tidak ditemukan, kembalikan 0
end

function GameConfig.CheckLuckyChanceBoost()
	local repStorage = game:GetService("ReplicatedStorage")
	local liveEvents = repStorage:FindFirstChild("LiveEvents")

	if liveEvents then
		local boostNode = liveEvents:FindFirstChild("LuckyChanceBoost")
		if boostNode then
			return boostNode.Value -- HARUS MENGGUNAKAN .Value
		end
	end

	return 0 -- Jika tidak ditemukan, pastikan selalu mengembalikan 0 (bukan nil)
end

function GameConfig.CheckExpBoost()
	local repStorage = game:GetService("ReplicatedStorage")
	local liveEvents = repStorage:FindFirstChild("LiveEvents")

	if liveEvents then
		local boostNode = liveEvents:FindFirstChild("ExpBoost")
		if boostNode then
			return boostNode.Value
		end
	end

	return 0
end

-- === UNIVERSAL FUNCTIONS ===

-- PERBAIKAN: Fungsi ini sekarang selalu mengembalikan Objek BillboardGui
--function GameConfig.SetInfoHologram(location, forceNew)
--	local display = location:FindFirstChild("InfoHologram")

--	if not forceNew and display and display:IsA("BillboardGui") then
--		-- Jika sudah ada dan tidak dipaksa buat baru, kembalikan yang lama
--		--print("Done SetInfoHologram: ", display and display:GetFullName() or "none")
--		return display
--	else
--		-- Buat baru atau timpa yang lama
--		if display then display:Destroy() end

--		local bbGui = Instance.new("BillboardGui")
--		bbGui.Name = "InfoHologram"
--		bbGui.Size = UDim2.new(4, 0, 1.5, 0) -- Ukuran default
--		bbGui.StudsOffset = Vector3.new(0, 3, 0)
--		bbGui.AlwaysOnTop = false
--		bbGui.MaxDistance = 100
--		bbGui.DistanceLowerLimit = 2
--		bbGui.Parent = location
--		--print("SetInfoHologram: ", bbGui and bbGui:GetFullName() or "none")
--		return bbGui
--	end
--end

function GameConfig.CanPlayerPickUp(player)
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

function GameConfig.ApplyVisuals(tool: Tool, rarityName, variantString)
	-- variant effect dari server storage
	local variantFolder = game:GetService("ServerStorage"):FindFirstChild("VariantEffect")
	local model = tool:FindFirstChild("Model")

	--for _, part in pairs(model:GetChildren()) do
	--	if part:IsA("Highlight") then part:Destroy() end
	--	-- cari variant shiny dalam variantString
	--	--if variantString and string.find(variantString, "Shiny") then
	--	--	if part.Name == "Body" then
	--	--		-- ambil effect dari variant folder
	--	--		local shinyEffect = variantFolder and variantFolder:FindFirstChild("Shiny") and variantFolder.Shiny:FindFirstChild("Body")
	--	--		if shinyEffect then
	--	--			local clonedEffect = shinyEffect:Clone()
	--	--			clonedEffect.Parent = part
	--	--		end

	--	--	end
	--	--end
	--end

	if variantString and variantString ~= "Normal" then
		local variants = string.split(variantString, ",")
		local bestVariant = variants[#variants]
		local vData = GameConfig.Variants[bestVariant]
		--print("BODY DITEMUKAN")
		-- ambil effect dari variant folder

		local handle = tool:FindFirstChild("Handle")

		if vData then
			--print(vData)
			if vData.Effect then
				print(vData.Effect)
				if handle then
					for _, part in pairs(handle:GetChildren()) do
						if part.Name == vData.Effect then
							part:Destroy()
							print("effect dihapus")
							break
						end
					end
					local effect = variantFolder and variantFolder:FindFirstChild(vData.Effect)
					if effect then
						local clonedEffect = effect:Clone()
						clonedEffect.Parent = handle
						print("effect ditemukan")
					else
						warn("[GameConfig] Effect template '" .. tostring(vData.Effect) .. "' tidak ditemukan di ServerStorage.VariantEffect!")
					end
				end
			end
		end
		--if shinyEffect then
		--	if handle then
		--		for _, part in pairs(tool.Handle:GetChildren()) do
		--			if part.Name == shinyEffect.Name then
		--				part:Destroy()
		--				print("effect dihapus")
		--				break
		--				--break
		--			end
		--		end
		--		local clonedEffect = shinyEffect:Clone()
		--		clonedEffect.Parent = tool.Handle
		--		print("effect ditemukan")
		--	end

		--end
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

	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	--if root then
	--	GameConfig.SetInfoHologram(root, false)
	--end

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
	--task:wait(0.5)

	--print("Visuals applied for", model.Name, "Rarity:", rarityName, "Variant:", variantString or "Normal")
end

--function GameConfig.HoldItem(character, car)
--	print("HoldItem dipanggil")
--	local torso = character:FindFirstChild("HumanoidRootPart")
--	if torso then
--		print("Torso ditemukan")
--	else
--		print("Torso tidak ditemukan")
--	end
--	--if not torso or not car then return end

--	--local root = car.Model:IsA("Model") and car.PrimaryPart or car
--	--if car.Model:IsA("Model") and not root then
--	--	root = car.Model:FindFirstChildWhichIsA("BasePart", true)
--	--	if root then car.PrimaryPart = root else return end
--	--end

--	--if item:IsA("Tool") then
--		--if item:GetAttribute("Price") then  end

--		--local bbGui = GameConfig.SetInfoHologram(root, false)
--		--if bbGui then
--		--	-- UKURAN SAAT DIPEGANG: Dibuat lebih kecil agar tidak menutupi layar
--		--	bbGui.Size = UDim2.new(3, 0, 1.2, 0)
--		--	bbGui.StudsOffset = Vector3.new(0, 2.5, 0)
--		--end
--	--else
--	--	item.Anchored = false; item.CanCollide = false; item.Massless = true
--	--end
--	--car.Model:ScaleTo(0.2)
--	car:ScaleTo(0.2)
--	car.Handle.Anchored = false; car.Handle.CanCollide = true; car.Handle.Massless = true

--	--car.Parent = character

--	local weld = Instance.new("Weld")
--	weld.Name = "ItemHoldWeld"
--	weld.Part0 = torso
--	weld.Part1 = car.Handle

--	if weld then
--		print("Weld created")
--	else
--		print("Weld failed")
--	end

--	weld.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
--	--if car:GetAttribute("Price") then
--	--else
--	--	weld.C0 = CFrame.new(0, 0, -3)
--	--end

--	weld.Parent = car.Handle
--end

function GameConfig.ClearHands(player)
	--print("clear hands")
	local char = player.Character
	local inv = player:FindFirstChild("ItemInventory")
	if not char or not inv then
		return
	end

	local hotbar = inv:FindFirstChild("Hotbar")
	local bag = inv:FindFirstChild("Bag")
	local capacity = inv:FindFirstChild("HotbarCapacity")

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

function GameConfig.StoreItem(item, targetFolder)
	--print("StoreItem: " .. item.Name .. " to " .. targetFolder.Name)
	if not item then
		return
	end

	--item.PrimaryPart.Visible = false

	local root = item:IsA("Model") and item.PrimaryPart or item
	if item:IsA("Model") and not root then
		item:ScaleTo(0.2)
		root = item:FindFirstChildWhichIsA("BasePart", true)
	end

	-- local bbGui = GameConfig.SetInfoHologram(root, false)
	--if item:IsA("Model") then
	--print("Scale mobil sebelum disimpan: " .. tostring(item:GetScale()))
	--end

	--if bbGui then
	--	if targetFolder.Name == "MyCars" then
	--		-- UKURAN SAAT DIPARKIR: Dibuat besar agar mudah dibaca dari kejauhan
	--		bbGui.Size = UDim2.new(4, 0, 1.5, 0)
	--		bbGui.StudsOffset = Vector3.new(0, 3, 0)
	--	else
	--		-- Ukuran standar di dalam tas/hotbar
	--		bbGui.Size = UDim2.new(4, 0, 1.5, 0)
	--		bbGui.StudsOffset = Vector3.new(0, 3, 0)
	--	end

	--	local label = bbGui:FindFirstChildWhichIsA("TextLabel")
	--	if label then label.TextScaled = true end
	--end

	if root then
		local holdWeld = root:FindFirstChild("ItemHoldWeld")
		if holdWeld then
			holdWeld:Destroy()
		end
	end

	if item:IsA("Model") then
		if item:GetAttribute("Location") then
			--print("++++ ATRIBUT CAR: " .. item:GetAttribute("Location").."PUT TO: "..targetFolder.Name)
		end
		--print("Scale mobil setelah disimpan: " .. tostring(item:GetScale()))
		if targetFolder.Name == "MyCars" then
			item:ScaleTo(0.8)
			local bbGui = GameConfig.SetInfoHologram(root, false)
			if bbGui then
				-- UKURAN SAAT DIPEGANG: Dibuat lebih kecil agar tidak menutupi layar
				bbGui.Size = UDim2.new(8, 0, 4, 0)
				bbGui.StudsOffset = Vector3.new(0, 3, 0)
			end
		elseif targetFolder.Name == "Bag" or targetFolder.Name == "Hotbar" or targetFolder.Name == "Inventory" then
			item:ScaleTo(0.2)
			local bbGui = GameConfig.SetInfoHologram(root, false)
			if bbGui then
				-- UKURAN SAAT DIPEGANG: Dibuat lebih kecil agar tidak menutupi layar
				bbGui.Size = UDim2.new(3, 0, 1.2, 0)
				bbGui.StudsOffset = Vector3.new(0, 2.5, 0)
			end
		--elseif targetFolder.Name == "Hotbar" then
		--	item:ScaleTo(0.2)
		--	local bbGui = GameConfig.SetInfoHologram(root, false)
		--	if bbGui then
		--		-- UKURAN SAAT DIPEGANG: Dibuat lebih kecil agar tidak menutupi layar
		--		bbGui.Size = UDim2.new(3, 0, 1.2, 0)
		--		bbGui.StudsOffset = Vector3.new(0, 2.5, 0)
		--	end
		--elseif targetFolder.Name == "Inventory" then
		--	item:ScaleTo(0.2)
		--	local bbGui = GameConfig.SetInfoHologram(root, false)
		--	if bbGui then
		--		-- UKURAN SAAT DIPEGANG: Dibuat lebih kecil agar tidak menutupi layar
		--		bbGui.Size = UDim2.new(3, 0, 1.2, 0)
		--		bbGui.StudsOffset = Vector3.new(0, 2.5, 0)
		--	end
		else
			item:ScaleTo(0.2) -- default
			--local bbGui = GameConfig.SetInfoHologram(root, false)
			--if bbGui then
			--	-- UKURAN SAAT DIPEGANG: Dibuat lebih kecil agar tidak menutupi layar
			--	bbGui.Size = UDim2.new(3, 0, 1.2, 0)
			--	bbGui.StudsOffset = Vector3.new(0, 2.5, 0)
			--end
		end
	end

	item.Parent = targetFolder
end

-- =============================================================================
-- GAME CONFIG: BALANCE EDITION ROLLING GACHA (ANTI-INFLASI CELESTIAL)
-- =============================================================================

function GameConfig.RollRarity(luck)
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
				-- JURUS PENJINAK: Kita bagi tierPower dengan 2.5 atau 3.
				-- Ini gunanya biar lonjakan hoki untuk tier Celestial gak langsung meroket jutaan kali lipat,
				-- jadi tier Common-Epic masih punya pertahanan buat keluar pas dipam!
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

function GameConfig.CalculatePrice(base, rName, vNameString)
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

	return math.floor((base or 1000) * rData.PriceMod * totalVariantMulti)
end

function GameConfig.cleanupAndWeldCar(model)
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

function GameConfig.GetColoredVariantList(variantString)
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

--function GameConfig.UpdateBoxText(newBox, curLvl, curExp, needed, bVariants)
--	local label = newBox:FindFirstChild("TextLabel", true)
--	if not label then return end

--	local bbGui = label.Parent
--	bbGui.Size = UDim2.new(20, 0, 10, 0)
--	bbGui.StudsOffset = Vector3.new(0, 1, 0)
--	bbGui.AlwaysOnTop = false
--	bbGui.MaxDistance = 100

--	label.RichText = true
--	label.Visible = true
--	label.TextWrapped = true
--	label.TextXAlignment = Enum.TextXAlignment.Center
--	label.TextScaled = true
--	label.Font = Enum.Font.FredokaOne
--	label.LineHeight = 1.0

--	local lvlData = GameConfig.BoxLevels[curLvl] or {LuckMulti = 1}

--	-- Panggil fungsi warna-warni kita tadi
--	local variantDisplay = GameConfig.GetColoredVariantList(bVariants)

--	label.Text = string.format(
--		"<b>LVL: %d</b> (%d/%d)\n%s\n<font color='#00FFFF'>Luck: x%d</font>",
--		curLvl, math.floor(curExp), needed, variantDisplay, lvlData.LuckMulti
--	)
--end

--function GameConfig.CreateHologram(car)
--	local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
--	if not root then return end

--	local bVar = car:GetAttribute("Variant") or "Normal"
--	local rarity = car:GetAttribute("Rarity") or "Common"
--	local basePendapatan = car:GetAttribute("Pendapatan") or 0
--	local nama = car:GetAttribute("CarName") or car.Name
--	local rData = GameConfig.Rarities[rarity] or GameConfig.Rarities.Common

--	local bbGui = GameConfig.SetInfoHologram(root, true)

--	local txtInfo = bbGui:FindFirstChild("TextLabel") or Instance.new("TextLabel", bbGui)
--	txtInfo.Name = "TextLabel"
--	txtInfo.Size = UDim2.new(1, 0, 1, 0)
--	txtInfo.RichText = true
--	txtInfo.TextScaled = true
--	txtInfo.Font = Enum.Font.FredokaOne
--	txtInfo.BackgroundTransparency = 1
--	txtInfo.TextStrokeTransparency = 0

--	local function fMoney(n) return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "") end
--	local variantDisplay = GameConfig.GetColoredVariantList(bVar)

--	txtInfo.Text = string.format(
--		"<font color='#%s'>[%s] %s</font>\n%s\n<font color='#00FF00'>$%s</font>",
--		rData.Color:ToHex(), rarity:upper(), nama, variantDisplay, fMoney(basePendapatan)
--	)

--	return bbGui
--end

return GameConfig
