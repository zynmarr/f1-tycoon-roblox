-- ===============================================
-- VIEWPORT MANAGER - Shared viewport rendering utilities
-- ===============================================

local ViewportManager = {}

local function formatPrice(price)
	local str = tostring(price)
	return str:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
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
		if entry.Model then
			pcall(function()
				if entry.Model.Parent then
					entry.Model.Parent = nil
				end
				entry.Model:Destroy()
			end)
		end
		if entry.Camera then
			pcall(function()
				if entry.Camera.Parent then
					entry.Camera.Parent = nil
				end
				entry.Camera:Destroy()
			end)
		end
		cache.renderCache[carTool] = nil
	end
end

local function trimCache(cache)
	if #cache.renderCache > cache.MAX_CACHE_SIZE then
		local count = 0
		for key in pairs(cache.renderCache) do
			if count >= cache.MAX_CACHE_SIZE then
				clearCacheEntry(cache, key)
			end
			count = count + 1
		end
	end
end

-- ===== VIEWPORT SETUP =====
local function setupCarViewport(cache, viewport, carTool, options)
	options = options or {}
	local toolID = tostring(carTool)

	if viewport:GetAttribute("LastCar") == toolID then
		return
	end

	viewport:SetAttribute("LastCar", toolID)
	viewport.BackgroundTransparency = options.bgTransparency or 0.95

	for _, child in pairs(viewport:GetChildren()) do
		if child:IsA("Camera") or child:IsA("Model") then
			if child.Parent then
				child.Parent = nil
			end
		end
	end

	if not cache.renderCache[carTool] then
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

		local cam = Instance.new("Camera")
		cam.FieldOfView = options.fieldOfView or 40
		local dist = (maxDim / 2) / math.tan(math.rad(20)) * 1.2
		local camPos = center + Vector3.new(-dist * 0.5, dist * 0.4, -dist * 0.7)
		cam.CFrame = CFrame.new(camPos, center + Vector3.new(0, maxDim * 0.1, 0))

		cache.renderCache[carTool] = { Model = carClone, Camera = cam }
		trimCache(cache)
	end

	local entry = cache.renderCache[carTool]
	if entry then
		if entry.Model.Parent then
			entry.Model.Parent = nil
		end

		local success = pcall(function()
			entry.Model.Parent = viewport
		end)

		if not success then
			warn("[ViewportManager] Failed to parent model for: " .. tostring(carTool.Name))
			return
		end

		task.wait(0.02)

		if entry.Camera.Parent then
			entry.Camera.Parent = nil
		end
		entry.Camera.Parent = viewport
		viewport.CurrentCamera = entry.Camera
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
	clearCacheEntry(cache, carTool)
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
