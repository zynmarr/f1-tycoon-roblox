--!strict
local OverheadClient = {}

function OverheadClient.init()
	local RunService = game:GetService("RunService")
	local CollectionService = game:GetService("CollectionService")

	local gradients = {}

	local function lerpColor(c1: Color3, c2: Color3, alpha: number): Color3
		return (c1 :: any):Lerp(c2, alpha)
	end

	local function addGradient(gradient: UIGradient)
		if gradient:IsA("UIGradient") and not table.find(gradients, gradient) then
			table.insert(gradients, gradient)
		end
	end

	local function removeGradient(gradient: UIGradient)
		local index = table.find(gradients, gradient)
		if index then
			table.remove(gradients, index)
		end
	end

	CollectionService:GetInstanceAddedSignal("RoleGradient"):Connect(addGradient)
	CollectionService:GetInstanceRemovedSignal("RoleGradient"):Connect(removeGradient)

	for _, gradient in ipairs(CollectionService:GetTagged("RoleGradient")) do
		addGradient(gradient)
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local time = tick()

		for _, gradient in ipairs(gradients) do
			if not gradient.Parent then
				continue
			end

			local roleName = gradient:GetAttribute("RoleName")

			if roleName == "Owner" then
				-- 1. OWNER: Rainbow/Chroma Wave
				local t = time * 0.35
				local c1 = Color3.fromHSV(t % 1, 0.8, 1)
				local c2 = Color3.fromHSV((t + 0.33) % 1, 0.8, 1)
				local c3 = Color3.fromHSV((t + 0.66) % 1, 0.8, 1)

				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.0, c1),
					ColorSequenceKeypoint.new(0.5, c2),
					ColorSequenceKeypoint.new(1.0, c3),
				})
				gradient.Offset = Vector2.new(0, 0)
				gradient.Rotation = 0
			elseif roleName == "Developer" then
				-- 2. DEVELOPER: Fire Pulse
				local t = time * 3.0
				local pulse = math.sin(t) * 0.5 + 0.5
				local c1 = lerpColor(Color3.fromRGB(255, 45, 45), Color3.fromRGB(255, 140, 0), pulse)
				local c2 = lerpColor(Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 230, 0), pulse)

				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.0, c1),
					ColorSequenceKeypoint.new(0.5, c2),
					ColorSequenceKeypoint.new(1.0, c1),
				})
				gradient.Offset = Vector2.new(0, 0)
				gradient.Rotation = 0
			elseif roleName == "Moderator" then
				-- 3. MODERATOR: Shield Pulse
				local t = time * 2.0
				local pulse = math.sin(t) * 0.5 + 0.5
				local c1 = lerpColor(Color3.fromRGB(0, 160, 255), Color3.fromRGB(0, 255, 220), pulse)
				local c2 = lerpColor(Color3.fromRGB(0, 255, 220), Color3.fromRGB(0, 80, 255), pulse)

				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.0, c1),
					ColorSequenceKeypoint.new(0.5, c2),
					ColorSequenceKeypoint.new(1.0, c1),
				})
				gradient.Offset = Vector2.new(0, 0)
				gradient.Rotation = 0
			elseif roleName == "VIP" then
				-- 4. VIP: Gold Shimmer Sweep
				local progress = (time * 1.2) % 2.5
				local offset = -1.5
				if progress < 1.2 then
					offset = -1.5 + (progress / 1.2) * 3.0
				else
					offset = 1.5
				end
				gradient.Offset = Vector2.new(offset, 0)
				gradient.Rotation = 0

				local goldBase = Color3.fromRGB(255, 190, 0)
				local goldShine = Color3.fromRGB(255, 255, 220)
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.0, goldBase),
					ColorSequenceKeypoint.new(0.5, goldShine),
					ColorSequenceKeypoint.new(1.0, goldBase),
				})
			end
		end
	end)
end

return OverheadClient
