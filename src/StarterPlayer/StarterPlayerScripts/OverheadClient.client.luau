--!strict
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- CONFIGURATIONS
local ROTATION_SPEED = 120 -- Degrees per second for border rotation
local SHIMMER_SPEED = 1.2  -- Speed of the shine wave

RunService.Heartbeat:Connect(function(dt: number)
	-- 1. Animasikan Rotasi Outline Border (RotatingGradient)
	local rotationOffset = (dt * ROTATION_SPEED) % 360
	for _, gradient in ipairs(CollectionService:GetTagged("RotatingGradient")) do
		if gradient:IsA("UIGradient") then
			gradient.Rotation = (gradient.Rotation + rotationOffset) % 360
		end
	end

	-- 2. Animasikan Efek Berkilau/Shimmer pada Teks Badge (ShimmeringGradient)
	-- Menggunakan sweep transisi dari kiri (-1.5) ke kanan (1.5) lalu jeda sejenak
	local time = tick()
	local progress = (time * SHIMMER_SPEED) % 2.5 -- Siklus total 2.5 detik (termasuk jeda)
	local offset = -1.5
	
	if progress < 1.5 then
		-- Menyapu dari kiri ke kanan dalam durasi 1.5 detik
		offset = -1.5 + (progress / 1.5) * 3.0
	else
		-- Berhenti di kanan (tidak terlihat) selama 1 detik sebagai jeda sebelum siklus berikutnya
		offset = 1.5
	end

	for _, gradient in ipairs(CollectionService:GetTagged("ShimmeringGradient")) do
		if gradient:IsA("UIGradient") then
			gradient.Offset = Vector2.new(offset, 0)
		end
	end
end)
