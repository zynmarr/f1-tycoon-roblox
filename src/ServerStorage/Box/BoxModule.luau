local BoxModule = {}

function BoxModule.UpdateBoxText(newBox, curLvl, curExp, needed, bVariants)
	local GameConfig = require(game.ReplicatedStorage:WaitForChild("GameConfig"))

	local bbGui = newBox:WaitForChild("StatsDisplay")
	local BoxName = bbGui:WaitForChild("BoxName")
	local BoxVariants = bbGui:WaitForChild("BoxVariants")
	local BoxLuck = bbGui:WaitForChild("BoxLuck")
	local BoxLevel = bbGui:FindFirstChild("BoxLevel", true)

	local lvlData = GameConfig.BoxLevels[curLvl] or { LuckMulti = 1 }

	-- Panggil fungsi warna-warni kita tadi
	local variantDisplay = GameConfig.GetColoredVariantList(bVariants)
	-- box name di gabung dengan level dan exp
	BoxName.Text = newBox.Parent:GetAttribute("Name")
	BoxVariants.Text = variantDisplay
	BoxLevel.Text = "Level:  [" .. curLvl .. "] Exp: " .. math.floor(curExp) .. "/" .. needed
	BoxLuck.Text = "Luck: x" .. lvlData.LuckMulti
end

function BoxModule.UpdateBoxVisual(boxObject, currentLevel)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local BoxModels = ReplicatedStorage:WaitForChild("BoxModels")
	-- 1. Tentukan target nama model berdasarkan aturan level
	local targetModelName = "Level1"

	-- Jika level 2 atau lebih tinggi, gunakan model Level2
	if currentLevel >= 2 then
		targetModelName = "Level2"
	end

	-- 2. Cari model aslinya di gudang ReplicatedStorage
	local newVisualTemplate = BoxModels:FindFirstChild(targetModelName)
	if not newVisualTemplate then
		warn("Model " .. targetModelName .. " tidak ditemukan di ReplicatedStorage!")
		return
	end

	-- 3. Hapus visual (model) lama yang sedang menempel di Box (jika ada)
	local oldVisual = boxObject:FindFirstChild("Visual")
	if oldVisual then
		oldVisual:Destroy()
	end

	-- 4. Kloning visual baru dan pasang ke Box
	local newVisual = newVisualTemplate:Clone()
	newVisual.Name = "Visual" -- Beri nama standar agar mudah dihapus nanti

	-- Posisikan visual baru tepat di kordinat Box utama
	-- Pastikan boxObject adalah Part/BasePart, atau kalau Model gunakan GetPivot()
	local boxCFrame = boxObject:IsA("Model") and boxObject:GetPivot() or boxObject.CFrame
	newVisual:PivotTo(boxCFrame)

	-- Las (Weld) visual ke box jika box ini bisa bergerak/terjatuh
	if boxObject:IsA("BasePart") and newVisual.PrimaryPart then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = boxObject
		weld.Part1 = newVisual.PrimaryPart
		weld.Parent = newVisual

		-- Matikan collision di visual agar tidak bentrok dengan Hitbox utama
		for _, part in pairs(newVisual:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored = false
			end
		end
	end

	newVisual.Parent = boxObject
end

return BoxModule
