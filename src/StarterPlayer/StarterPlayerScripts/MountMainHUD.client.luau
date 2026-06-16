--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local MainHUD = require(script.Parent.components.MainHUD.MainHUD)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== SCREENGUI INDUK =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ===== REACT ROOT =====
local root = ReactRoblox.createRoot(screenGui)

-- ===== DYNAMIC SIDEBAR REGISTRY =====
local RegisterSidebarButton = ReplicatedStorage:FindFirstChild("RegisterSidebarButton")
if not RegisterSidebarButton then
	local bindable = Instance.new("BindableEvent")
	bindable.Name = "RegisterSidebarButton"
	bindable.Parent = ReplicatedStorage
	RegisterSidebarButton = bindable
end

local UnregisterSidebarButton = ReplicatedStorage:FindFirstChild("UnregisterSidebarButton")
if not UnregisterSidebarButton then
	local bindable = Instance.new("BindableEvent")
	bindable.Name = "UnregisterSidebarButton"
	bindable.Parent = ReplicatedStorage
	UnregisterSidebarButton = bindable
end

local registeredButtons = {}

local function updateUIRender()
	root:render(React.createElement(MainHUD, {
		Buttons = registeredButtons,
	}))
end

-- Hubungkan BindableEvents untuk update props dinamis
(RegisterSidebarButton :: BindableEvent).Event:Connect(function(config: { Name: string, Label: string, Icon: string, Callback: () -> (), Order: number? })
	if config and config.Name then
		registeredButtons[config.Name] = config
		updateUIRender()
	end
end)

(UnregisterSidebarButton :: BindableEvent).Event:Connect(function(name: string)
	if name and registeredButtons[name] then
		registeredButtons[name] = nil
		updateUIRender()
	end
end)

-- Render awal
updateUIRender()

print("[Client] React MountMainHUD diinisialisasi. Registrasi sidebar dinamis siap!")
