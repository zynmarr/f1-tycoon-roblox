local script = script.Parent
local model = script:FindFirstChild("Model")

for _, child in pairs(model:GetDescendants()) do
	if child:IsA("BasePart") then
		child.Anchored = true
		child.CanCollide = true
	end
end
