--!strict
-- ==========================================================
-- ANTICHEAT MANAGER (SERVER-AUTHORITATIVE CHEAT DETECTION)
-- ==========================================================

local AntiCheatManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _ = game:GetService("Workspace")

local RoleManager = require(script.Parent.Parent.RoleManager.RoleManager)

-- Config Thresholds
local MAX_WALKSPEED = 36 -- Toleransi maksimal walkspeed server (Base 16 + Upgrades/Buffs)
local MAX_JUMPHEIGHT = 30 -- Max JumpPower/Height threshold
local MAX_DIST_DELTA_PER_SEC = 60 -- Teleport / Speed Hack threshold distance per second
local VIOLATION_STRIKE_LIMIT = 5 -- Jumlah pelanggaran sebelum diban/kicked
local STRIKE_RESET_TIME = 60 -- Reset strike setelah 60 detik tanpa pelanggaran

-- Player AntiCheat Tracker
local playerTrackers: { [Player]: {
	LastPosition: Vector3?,
	LastCheckTime: number,
	Strikes: number,
	LastStrikeTime: number,
} } =
	{}

local function sendWarningNotif(player: Player, message: string)
	local NotifEvent = ReplicatedStorage:FindFirstChild("NotifEvent")
	if NotifEvent then
		pcall(function()
			NotifEvent:FireClient(player, "⚠️ Peringatan Anti-Cheat", message, 4)
		end)
	end
end

local function handleViolation(player: Player, reason: string)
	-- Skip check jika player adalah Staff / Owner / Developer
	local role = RoleManager.getPlayerRole(player)
	-- if role == "Owner" or role == "Developer" then
	-- 	return
	-- end

	local tracker = playerTrackers[player]
	if not tracker then
		return
	end

	local now = os.clock()
	tracker.Strikes = tracker.Strikes + 1
	tracker.LastStrikeTime = now

	warn(
		string.format(
			"[AntiCheat] 🚨 Detect %s (%s) - Violation: %s (Strike %d/%d)",
			player.Name,
			tostring(player.UserId),
			reason,
			tracker.Strikes,
			VIOLATION_STRIKE_LIMIT
		)
	)
	sendWarningNotif(player, "Deteksi perilaku tidak wajar: " .. reason)

	-- Teleport kembali ke posisi valid jika terkena Speed/Teleport Hack
	if tracker.LastPosition and player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.new(tracker.LastPosition)
		end
	end

	-- Jika melebihi batas strike, keluarkan pemain
	if tracker.Strikes >= VIOLATION_STRIKE_LIMIT then
		if role == "Owner" or role == "Developer" then
			sendWarningNotif(
				player,
				"⚠️ Anda telah melebihi batas pelanggaran anti-cheat, tetapi karena Anda adalah Staff/Owner/Developer, Anda tidak akan dikeluarkan. Harap periksa perilaku Anda."
			)
			return
		else
			warn(string.format("[AntiCheat] ⛔ KICKING %s karena melebihi batas pelanggaran anti-cheat!", player.Name))
			player:Kick("🚫 Terdeteksi aktivitas tidak wajar/eksploitasi pada karakter Anda (" .. reason .. ").")
		end
	end
end

local function monitorCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

	if not humanoid or not hrp then
		return
	end

	local tracker = playerTrackers[player]
	if not tracker then
		return
	end

	tracker.LastPosition = hrp.Position
	tracker.LastCheckTime = os.clock()

	-- 1. Anti-Noclip & Anti-Teleport Check Loop
	task.spawn(function()
		while character and character.Parent and player.Parent and tracker do
			task.wait(0.5)

			local currentPos = hrp.Position
			local now = os.clock()
			local dt = now - tracker.LastCheckTime

			if dt <= 0 then
				continue
			end

			-- A. Cek WalkSpeed Tampering
			if humanoid.WalkSpeed > MAX_WALKSPEED then
				humanoid.WalkSpeed = 16
				handleViolation(player, "Speed Hack (WalkSpeed > " .. MAX_WALKSPEED .. ")")
			end

			-- B. Cek Jump Power Tampering
			if humanoid.UseJumpPower and humanoid.JumpPower > 60 then
				humanoid.JumpPower = 50
				handleViolation(player, "High Jump Hack (JumpPower > 60)")
			elseif not humanoid.UseJumpPower and humanoid.JumpHeight > MAX_JUMPHEIGHT then
				humanoid.JumpHeight = 7.2
				handleViolation(player, "High Jump Hack (JumpHeight > " .. MAX_JUMPHEIGHT .. ")")
			end

			-- C. Cek Teleportasi / Speed Vector Hack
			if tracker.LastPosition then
				local dist = (currentPos - tracker.LastPosition).Magnitude
				local speed = dist / dt

				-- Abaikan jika pemain sedang respawn / teleport resmi (misal ke plot)
				local isSeated = humanoid.SeatPart ~= nil
				if speed > MAX_DIST_DELTA_PER_SEC and not isSeated then
					handleViolation(player, "Speed / Teleport Hack (Speed: " .. math.floor(speed) .. " studs/s)")
				else
					tracker.LastPosition = currentPos
				end
			else
				tracker.LastPosition = currentPos
			end

			tracker.LastCheckTime = now

			-- Reset strike jika sudah lama tidak melanggar
			if tracker.Strikes > 0 and (now - tracker.LastStrikeTime) > STRIKE_RESET_TIME then
				tracker.Strikes = math.max(0, tracker.Strikes - 1)
			end
		end
	end)
end

local function onPlayerAdded(player: Player)
	playerTrackers[player] = {
		LastPosition = nil,
		LastCheckTime = os.clock(),
		Strikes = 0,
		LastStrikeTime = os.clock(),
	}

	player.CharacterAdded:Connect(function(character)
		monitorCharacter(player, character)
	end)

	if player.Character then
		task.spawn(monitorCharacter, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	playerTrackers[player] = nil
end

function AntiCheatManager.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	print("[AntiCheatManager] ✅ Server-authoritative Anti-Cheat System aktif & berjalan!")
end

return AntiCheatManager
