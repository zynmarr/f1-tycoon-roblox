game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		-- Script ini akan mengecek apakah yang masuk adalah akun milikmu
		if player.Name == "aceu9922" then 
			local humanoid = char:WaitForChild("Humanoid")

			-- Ubah angka ini sesuka hatimu (Default orang biasa adalah 16)
			-- Angka 50 sudah cukup untuk lari seperti The Flash!
			humanoid.WalkSpeed = 50 

			print("Developer " .. player.Name .. " masuk! Kecepatan ditingkatkan.")
		end
	end)
end)