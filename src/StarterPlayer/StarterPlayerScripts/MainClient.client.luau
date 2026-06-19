--!strict
-- src/StarterPlayer/StarterPlayerScripts/MainClient.client.luau
-- Bootstrapper Terpusat untuk seluruh sistem Client F1-Tycoon

print("[MainClient] Memulai inisialisasi seluruh sistem client...")

local CORE_MODULES: {string} = {
	"ScreenOrientation",
	"NotifHandlerGui",
	"ChatAnnounceHandler",
	"ChatTags",
	"OverheadClient",
}

local FEATURE_MODULES: {string} = {
	"ShopGui",
	"SellGui",
	"MenuSellGui",
	"UpgradeMachineArea",
	"AnnouncementGui",
	"MountMainHUD",
	"MountMainGuiHub",
	"MountAdminEventPanel",
	"MountRacePanel",
	"MountTradeGui",
}

-- Fungsi pembantu untuk memuat dan menginisialisasi ModuleScript secara aman
local function loadModule(name: string, isAsync: boolean)
	local scriptObj = script.Parent:WaitForChild(name, 10)
	if not scriptObj or not scriptObj:IsA("ModuleScript") then
		warn("[MainClient] ❌ Gagal menemukan ModuleScript: " .. name)
		return
	end

	local success, module = pcall(require, scriptObj)
	if not success then
		warn("[MainClient] ❌ Gagal require modul: " .. name .. " | Error: " .. tostring(module))
		return
	end

	if module and typeof(module.init) == "function" then
		if isAsync then
			task.spawn(function()
				local ok, err = pcall(module.init)
				if not ok then
					warn("[MainClient] ❌ Runtime error pada init() modul: " .. name .. " | Error: " .. tostring(err))
				end
			end)
		else
			local ok, err = pcall(module.init)
			if not ok then
				warn("[MainClient] ❌ Runtime error pada init() modul: " .. name .. " | Error: " .. tostring(err))
			end
		end
	else
		warn("[MainClient] ⚠️ Modul " .. name .. " tidak mengekspos fungsi init() yang valid.")
	end
end

-- =============================================================================
-- EKSEKUSI PEMUATAN
-- =============================================================================

-- 1. Eksekusi Core Modules secara sinkron (blocking / berurutan ketat)
for _, moduleName in ipairs(CORE_MODULES) do
	loadModule(moduleName, false)
end

-- 2. Eksekusi Feature & UI Modules secara asinkron (tidak saling memblokir jika yield)
for _, moduleName in ipairs(FEATURE_MODULES) do
	loadModule(moduleName, true)
end

print("[MainClient] ✅ Seluruh modul client berhasil dijadwalkan / dimuat!")
