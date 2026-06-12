-- local Players = game:GetService("Players")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- local Packages = ReplicatedStorage:WaitForChild("Packages")
-- local React = require(Packages.React)
-- local ReactRoblox = require(Packages.ReactRoblox)

-- -- Ambil komponen yang tadi kita buat
-- local ShopGui = require(script.Parent.components.ShopGui.ShopGui)

-- local player = Players.LocalPlayer
-- local playerGui = player:WaitForChild("PlayerGui")

-- -- 1. Buat React Virtual Root mengarah ke PlayerGui
-- local root = ReactRoblox.createRoot(playerGui)

-- -- 2. Render komponen Anda ke dalam root tersebut
-- root:render(React.createElement(ShopGui, {
-- 	-- Anda bisa mengirimkan data/state global ke sini sebagai props jika diperlukan
-- 	CurrentCash = 1000,
-- }))

-- print("[Client] React ShopGui telah berhasil di-mount ke PlayerGui!")
