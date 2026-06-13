# Design Spec: F1-Tycoon Client/Server Performance Optimizations

**Date:** 2026-06-13
**Status:** Approved by User
**Problem Statement:** Certain parts of the client/server runtime execute redundant loops or memory allocations, creating potential garbage collection spikes and CPU load:
1. `OverheadClient.client.luau` calls `CollectionService:GetTagged` inside `Heartbeat` (60-144+ times per second), creating garbage tables.
2. `GameConfig.cleanupAndWeldCar` runs two separate loops over `model:GetDescendants()`.

---

## 1. Component Design & Changes

### 1.1. `src/StarterPlayer/StarterPlayerScripts/OverheadClient.client.luau`

We optimize this script to maintain an event-driven cache of tagged gradients:

```lua
--!strict
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local gradients = {}

local function addGradient(gradient: Instance)
	if gradient:IsA("UIGradient") and not table.find(gradients, gradient) then
		table.insert(gradients, gradient)
	end
end

local function removeGradient(gradient: Instance)
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
		-- ... existing gradient styling color / sequence calculations ...
	end
end)
```

### 1.2. `src/ReplicatedStorage/GameConfig.luau`

We merge the cleanup and welding steps of `cleanupAndWeldCar` into a single loop:

```lua
function GameConfig.cleanupAndWeldCar(model)
	local primary = model.PrimaryPart
	if not primary then
		print("Model tidak memiliki PrimaryPart")
		return
	end

	for _, p in pairs(model:GetDescendants()) do
		if p:IsA("Script") or p:IsA("LocalScript") then
			p.Enabled = false
			pcall(function() p:Destroy() end)
		elseif
			p:IsA("Sound")
			or p:IsA("BodyMover")
			or p:IsA("Constraint")
			or p:IsA("Attachment")
			or p:IsA("JointInstance")
		then
			pcall(function() p:Destroy() end)
		elseif p:IsA("Seat") or p:IsA("VehicleSeat") then
			p.Disabled = true
		elseif p:IsA("ClickDetector") or p:IsA("ProximityPrompt") then
			pcall(function() p:Destroy() end)
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
```

---

## 2. Testing & Verification

1. **Rainbow Tag Performance Check**: Enter the game and verify that the owner's rainbow gradient text and VIP shimmer remain visually perfect and compile without any errors.
2. **Car Spawning Weld Test**: Open a box, spawn a car, and verify that it is welded and scaled correctly without falling apart.
