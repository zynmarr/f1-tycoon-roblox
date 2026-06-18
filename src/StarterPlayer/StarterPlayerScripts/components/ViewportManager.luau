-- ===============================================
-- VIEWPORT MANAGER - Shared viewport rendering utilities
-- ===============================================

local ViewportManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))

local function formatPrice(price)
	return GameUtils.formatPrice(price)
end

-- ===== CACHE MANAGEMENT =====
local function createCache()
	return {
		renderCache = {},
		MAX_CACHE_SIZE = 10,
	}
end

local function clearCacheEntry(cache, carTool)
	if cache.renderCache[carTool] then
		local entry = cache.renderCache[carTool]
		if entry.ModelSource then
			pcall(function()
				entry.ModelSource:Destroy()
			end)
		end
		cache.renderCache[carTool] = nil
	end
end

local function trimCache(cache)
	local count = 0
	for _ in pairs(cache.renderCache) do
		count = count + 1
	end
	if count > cache.MAX_CACHE_SIZE then
		local excess = count - cache.MAX_CACHE_SIZE
		local removed = 0
		for key in pairs(cache.renderCache) do
			clearCacheEntry(cache, key)
			removed = removed + 1
			if removed >= excess then
				break
			end
		end
	end
end

-- ===== VIEWPORT SETUP =====
local function setupCarViewport(cache, viewport, carTool, options)
	options = options or {}
	local toolID = tostring(carTool)
	local levelAttr = carTool:GetAttribute("Level") or ""
	local variantAttr = carTool:GetAttribute("Variants") or carTool:GetAttribute("Variant") or ""
	local renderKey = toolID .. "_" .. tostring(levelAttr) .. "_" .. tostring(variantAttr)

	if viewport:GetAttribute("LastCar") == renderKey then
		return
	end

	viewport:SetAttribute("LastCar", renderKey)
	viewport.BackgroundTransparency = options.bgTransparency or 0.95

	-- Bersihkan model dan kamera lama dengan memanggil Destroy() agar bebas memory leak
	for _, child in pairs(viewport:GetChildren()) do
		if child:IsA("Camera") or child:IsA("Model") then
			pcall(function()
				child:Destroy()
			end)
		end
	end

	if not cache.renderCache[renderKey] then
		local originalModel = nil
		local retryCount = 0
		while not originalModel and retryCount < 20 do
			originalModel = carTool:FindFirstChild("Model") or carTool:FindFirstChildOfClass("Model")
			if not originalModel then
				task.wait(0.1)
				retryCount = retryCount + 1
			end
		end

		if not originalModel then
			warn("[ViewportManager] Model tidak ditemukan untuk: " .. tostring(carTool.Name))
			return
		end

		-- TUNGGU REPLIKASI DESENDAN STABIL (Mengatasi bug render melar / 100% full)
		local lastDescendantCount = #originalModel:GetDescendants()
		local stableFrames = 0
		local maxWaitTime = 0.5
		local startTime = tick()

		while stableFrames < 3 and (tick() - startTime) < maxWaitTime do
			task.wait(0.05)
			local currentCount = #originalModel:GetDescendants()
			if currentCount == lastDescendantCount and currentCount > 0 then
				stableFrames = stableFrames + 1
			else
				lastDescendantCount = currentCount
				stableFrames = 0
			end
		end

		local carClone = originalModel:Clone()
		carClone:PivotTo(CFrame.new(0, 0, 0))
		task.wait(0.05)

		local minX, minY, minZ = math.huge, math.huge, math.huge
		local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
		local hasVisuals = false

		for _, p in pairs(carClone:GetDescendants()) do
			if p:IsA("BasePart") or p:IsA("MeshPart") then
				p.CastShadow = false
				if p.Name == "Hitbox" or p.Name == "Handle" then
					p.Transparency = 1
				end
				if p.Transparency < 1 then
					hasVisuals = true
					local pos, size = p.Position, p.Size
					minX = math.min(minX, pos.X - (size.X / 2))
					minY = math.min(minY, pos.Y - (size.Y / 2))
					minZ = math.min(minZ, pos.Z - (size.Z / 2))
					maxX = math.max(maxX, pos.X + (size.X / 2))
					maxY = math.max(maxY, pos.Y + (size.Y / 2))
					maxZ = math.max(maxZ, pos.Z + (size.Z / 2))
				end
			end
		end

		if not hasVisuals then
			carClone:Destroy()
			warn("[ViewportManager] Mobil tidak memiliki visual: " .. tostring(carTool.Name))
			return
		end

		local center = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
		local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
		local maxDim = math.max(size.X, size.Y, size.Z)
		if maxDim < 1 then
			maxDim = 15
		end

		local CollectionService = game:GetService("CollectionService")
		local isBox = CollectionService:HasTag(carTool, "Box")
			or string.find(carTool.Name:lower(), "box") ~= nil
			or carTool:GetAttribute("Level") ~= nil

		local targetFov = 30 -- Zoomed in for cars
		local distMultiplier = 0.95 -- Closer distance for cars

		if isBox then
			targetFov = 45 -- Zoomed out/wider perspective for boxes
			distMultiplier = 2 -- Further distance for boxes
		end

		task.wait(0.05)

		-- Hitung parameter kamera dan CFrame
		local halfFov = targetFov / 2
		local dist = (maxDim / 2) / math.tan(math.rad(halfFov)) * distMultiplier
		local camPos = center + Vector3.new(-dist * 0.5, dist * 0.4, -dist * 0.7)
		local camCFrame = CFrame.new(camPos, center + Vector3.new(0, maxDim * 0.1, 0))

		-- Simpan ModelSource (untuk diclone ulang) dan koordinat kamera di cache render
		cache.renderCache[renderKey] = { ModelSource = carClone, CameraCFrame = camCFrame, FieldOfView = targetFov }
		trimCache(cache)
	end

	local entry = cache.renderCache[renderKey]
	if entry then
		-- Selalu kloning model segar ke dalam viewport agar tidak hilang saat viewport lama di-destroy oleh React
		local modelClone = entry.ModelSource:Clone()
		modelClone.Parent = viewport

		-- Buat kamera baru yang terikat langsung dengan lifetime viewport ini
		local cam = Instance.new("Camera")
		cam.FieldOfView = entry.FieldOfView
		cam.CFrame = entry.CameraCFrame
		cam.Parent = viewport

		viewport.CurrentCamera = cam
		viewport.Ambient = options.ambientColor or Color3.fromRGB(200, 200, 200)
		viewport.LightColor = options.lightColor or Color3.fromRGB(255, 255, 255)
	end
end

-- ===== PUBLIC API =====
function ViewportManager.new()
	return createCache()
end

function ViewportManager.setupViewport(cache, viewport, carTool, options)
	setupCarViewport(cache, viewport, carTool, options)
end

function ViewportManager.clearCache(cache, carTool)
	local prefix = tostring(carTool)
	for key in pairs(cache.renderCache) do
		if type(key) == "string" and string.sub(key, 1, string.len(prefix)) == prefix then
			clearCacheEntry(cache, key)
		elseif key == carTool then
			clearCacheEntry(cache, key)
		end
	end
end

function ViewportManager.clearAllCache(cache)
	for carTool in pairs(cache.renderCache) do
		clearCacheEntry(cache, carTool)
	end
end

function ViewportManager.formatPrice(price)
	return formatPrice(price)
end

return ViewportManager
