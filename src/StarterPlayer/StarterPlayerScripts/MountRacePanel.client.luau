--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Networker = require(Packages.Networker)

local RacePanel = require(script.Parent.components.RacePanel.RacePanel)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== RETRIEVE NETWORKER SERVICE =====
local clientService = {}
local raceService = Networker.client.new("RaceService", clientService)

-- ===== REACT ROOT =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RacePanelGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

local root = ReactRoblox.createRoot(screenGui)

local uiIsOpen = false

local function updateUIRender()
	if not uiIsOpen then
		screenGui.Enabled = false
		root:render(nil)
		return
	end

	screenGui.Enabled = true

	root:render(React.createElement(RacePanel, {
		onClose = function()
			uiIsOpen = false
			updateUIRender()
		end,
		raceService = raceService,
	}))
end

-- ===== PROXIMITY PROMPT TRIGGER =====
ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "RacePrompt" then
		local plot = prompt:FindFirstAncestorOfClass("Folder")
		if plot and plot:GetAttribute("Owner") == player.Name then
			uiIsOpen = not uiIsOpen
			updateUIRender()
		else
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Akses Ditolak";
					Text = "Anda hanya bisa menggunakan stasiun balap di plot Anda sendiri!";
					Duration = 3;
				})
			end)
		end
	end
end)

-- ===== KEYBOARD TOGGLE FOR DEVELOPMENT (F5) =====
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F5 then
		uiIsOpen = not uiIsOpen
		updateUIRender()
	end
end)

print("[Client] React RacePanel mounting controller siap! Gunakan ProximityPrompt stasiun balap atau tekan F5.")
