local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local GameUtils = require(ReplicatedStorage:WaitForChild("GameUtils"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local e = React.createElement

-- Warna per kategori
local CATEGORY_COLORS = {
	Easy   = Color3.fromRGB(50, 190, 100),
	Medium = Color3.fromRGB(60, 140, 230),
	Hard   = Color3.fromRGB(210, 80, 80),
}

local CATEGORY_LABELS = {
	Easy   = "🟢 EASY",
	Medium = "🔵 MEDIUM",
	Hard   = "🔴 HARD",
}

-- Buat satu baris upgrade card
local function UpgradeCard(props)
	local id      = props.Id
	local info    = props.Info
	local lvl     = props.Level
	local rp      = props.RebirthPoints
	local maxLevel = RebirthConfig.UPGRADE_CAPS[id] or 5
	local isMaxed  = lvl >= maxLevel

	local cost    = RebirthConfig.getUpgradeCost(id, lvl)
	local canBuy  = (not isMaxed) and (rp >= cost)

	-- Efek saat ini vs efek berikutnya
	local curEffect  = RebirthConfig.getUpgradeEffect(id, lvl)
	local nextEffect = isMaxed and curEffect or RebirthConfig.getUpgradeEffect(id, lvl + 1)
	local unit       = info.Unit or ""

	local effectText
	if isMaxed then
		effectText = string.format("Efek aktif: +%s%s (MAKS)", tostring(curEffect), unit)
	else
		effectText = string.format("Saat ini: +%s%s  →  Lv%d: +%s%s", tostring(curEffect), unit, lvl + 1, tostring(nextEffect), unit)
	end

	-- Warna tombol
	local btnColor, btnTextColor, btnText
	if isMaxed then
		btnColor     = Color3.fromRGB(50, 160, 60)
		btnTextColor = Color3.fromRGB(200, 255, 210)
		btnText      = "✓ MAXED"
	elseif canBuy then
		btnColor     = Color3.fromRGB(0, 170, 110)
		btnTextColor = Color3.fromRGB(255, 255, 255)
		btnText      = string.format("UPGRADE\n%d RP", cost)
	else
		btnColor     = Color3.fromRGB(75, 75, 90)
		btnTextColor = Color3.fromRGB(150, 150, 165)
		btnText      = string.format("UPGRADE\n%d RP", cost)
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Color3.fromRGB(32, 32, 42),
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Stroke = e("UIStroke", {
			Color = CATEGORY_COLORS[info.Category] or Color3.fromRGB(80, 80, 100),
			Thickness = 1,
			Transparency = 0.5,
		}),

		-- Icon emoji
		Icon = e("TextLabel", {
			Text = info.Icon or "⭐",
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(0, 6, 0.5, -18),
			BackgroundTransparency = 1,
			TextSize = 24,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
		}),

		-- Level badge
		LvlBadge = e("TextLabel", {
			Text = string.format("Lv%d/%d", lvl, maxLevel),
			Size = UDim2.new(0, 44, 0, 14),
			Position = UDim2.new(0, 48, 0, 6),
			BackgroundColor3 = CATEGORY_COLORS[info.Category] or Color3.fromRGB(80, 80, 100),
			BorderSizePixel = 0,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 8.5,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),

		-- Nama upgrade
		NameLabel = e("TextLabel", {
			Text = info.Name,
			Size = UDim2.new(1, -145, 0, 18),
			Position = UDim2.new(0, 48, 0, 22),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(240, 240, 255),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
		}),

		-- Efek dinamis
		EffectLabel = e("TextLabel", {
			Text = effectText,
			Size = UDim2.new(1, -145, 0, 14),
			Position = UDim2.new(0, 48, 1, -20),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(160, 200, 160),
			TextSize = 8.5,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
		}),

		-- Tombol upgrade
		UpgradeButton = e("TextButton", {
			Text = btnText,
			Size = UDim2.new(0, 80, 0, 38),
			Position = UDim2.new(1, -88, 0.5, -19),
			BackgroundColor3 = btnColor,
			TextColor3 = btnTextColor,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			BorderSizePixel = 0,
			Active = canBuy,
			TextScaled = true,
			[React.Event.Activated] = function()
				if canBuy and not isMaxed and props.onUpgrade then
					props.onUpgrade(id)
				end
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		}),
	})
end

-- Buat header section kategori
local function CategoryHeader(label, color)
	return e("TextLabel", {
		Text = label,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
	})
end

-- ============================================================
-- MAIN COMPONENT
-- ============================================================
return function(props)
	local rebirthLevel  = props.RebirthLevel  or 0
	local rebirthPoints = props.RebirthPoints or 0
	local cash          = props.Cash          or 0
	local upgrades      = props.RebirthUpgrades or {}

	-- Formula biaya rebirth yang baru
	local rebirthCost = math.floor(1000000 * (1.6 ^ rebirthLevel))
	local canRebirth  = cash >= rebirthCost
	local isRebirthMaxed = rebirthLevel >= RebirthConfig.MAX_REBIRTH

	-- Build upgrade list dikelompokkan per kategori
	local allChildren = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local order = 1
	for _, cat in ipairs({ "Easy", "Medium", "Hard" }) do
		local catIds = RebirthConfig.UPGRADE_ORDER[cat] or {}
		if #catIds > 0 then
			-- Header kategori
			allChildren["Header_" .. cat] = e("Frame", {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				LayoutOrder = order,
			}, {
				CategoryHeader(CATEGORY_LABELS[cat], CATEGORY_COLORS[cat]),
			})
			order = order + 1

			for _, id in ipairs(catIds) do
				local info = RebirthConfig.UPGRADE_META[id]
				if info then
					local lvl = upgrades[id] or 0
					allChildren[id] = e(UpgradeCard, {
						Id            = id,
						Info          = info,
						Level         = lvl,
						RebirthPoints = rebirthPoints,
						onUpgrade     = props.onUpgrade,
						LayoutOrder   = order,
					})
					order = order + 1
				end
			end
		end
	end

	-- RP total progress bar info
	local totalRP = 340 * rebirthLevel * (rebirthLevel + 1) / 2

	local isMobile = props.IsMobile

	-- Sizing & layout container
	local mainContent
	if isMobile then
		mainContent = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			ControlPanel = e("Frame", {
				Size = UDim2.new(1, 0, 0, 210),
				BackgroundColor3 = Color3.fromRGB(22, 22, 32),
				BorderSizePixel = 0,
				LayoutOrder = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(80, 80, 110),
					Thickness = 1,
				}),

				Title = e("TextLabel", {
					Text = "🔱 REBIRTH",
					Size = UDim2.new(1, -20, 0, 30),
					Position = UDim2.new(0, 10, 0, 8),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				LevelBadge = e("TextLabel", {
					Text = string.format("Level %d / %d", rebirthLevel, RebirthConfig.MAX_REBIRTH),
					Size = UDim2.new(0.44, 0, 0, 22),
					Position = UDim2.new(0.05, 0, 0, 42),
					BackgroundColor3 = Color3.fromRGB(40, 40, 60),
					BorderSizePixel = 0,
					TextColor3 = Color3.fromRGB(0, 220, 180),
					TextSize = 10,
					Font = Enum.Font.GothamBold,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),

				RPLabel = e("TextLabel", {
					Text = string.format("💎 %s RP", GameUtils.formatCompact(rebirthPoints)),
					Size = UDim2.new(0.44, 0, 0, 22),
					Position = UDim2.new(0.51, 0, 0, 42),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(200, 175, 255),
					TextSize = 10.5,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Details = e("TextLabel", {
					Text = "Rebirth mereset Cash & plot mesin. Mobil Admin tetap disimpan. Setiap rebirth memberikan permanen RP.",
					Size = UDim2.new(0.9, 0, 0, 32),
					Position = UDim2.new(0.05, 0, 0, 72),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(160, 160, 175),
					TextSize = 9.5,
					Font = Enum.Font.GothamMedium,
					TextWrapped = true,
				}),

				CostLabel = e("TextLabel", {
					Text = isRebirthMaxed
						and "✅ REBIRTH LEVEL MAKSIMUM"
						or string.format("Biaya: <font color='#FFD700'>$%s</font>", GameUtils.formatCompact(rebirthCost)),
					Size = UDim2.new(0.9, 0, 0, 20),
					Position = UDim2.new(0.05, 0, 1, -70),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(200, 200, 220),
					TextSize = 10.5,
					Font = Enum.Font.GothamMedium,
					RichText = true,
				}),

				RebirthBtn = e("TextButton", {
					Text = isRebirthMaxed and "LEVEL MAKS"
						or (canRebirth and "🔱 REBIRTH SEKARANG" or "⛔ CASH TIDAK CUKUP"),
					Size = UDim2.new(0.9, 0, 0, 36),
					Position = UDim2.new(0.05, 0, 1, -45),
					BackgroundColor3 = isRebirthMaxed and Color3.fromRGB(60, 60, 80)
						or (canRebirth and Color3.fromRGB(185, 40, 40) or Color3.fromRGB(70, 70, 85)),
					TextColor3 = isRebirthMaxed and Color3.fromRGB(130, 130, 150)
						or (canRebirth and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 160)),
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					BorderSizePixel = 0,
					Active = canRebirth and not isRebirthMaxed,
					[React.Event.Activated] = function()
						if canRebirth and not isRebirthMaxed and props.onRebirth then
							props.onRebirth()
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			UpgradesPanel = e("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(22, 22, 32),
				BorderSizePixel = 0,
				LayoutOrder = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(80, 80, 110),
					Thickness = 1,
				}),

				Title = e("TextLabel", {
					Text = "✨ UPGRADE PERMANEN",
					Size = UDim2.new(1, -20, 0, 30),
					Position = UDim2.new(0, 10, 0, 8),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 13,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				ScrollArea = e("Frame", {
					Size = UDim2.new(1, -20, 0, 0),
					Position = UDim2.new(0, 10, 0, 42),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutomaticSize = Enum.AutomaticSize.Y,
				}, allChildren),
			}),
		}
	else
		-- PC side-by-side layout (but wrapped in a single scroll container)
		mainContent = {
			ControlPanel = e("Frame", {
				Size = UDim2.new(0.36, 0, 0, 340),
				BackgroundColor3 = Color3.fromRGB(22, 22, 32),
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(80, 80, 110),
					Thickness = 1,
				}),

				Title = e("TextLabel", {
					Text = "🔱 REBIRTH",
					Size = UDim2.new(1, -20, 0, 40),
					Position = UDim2.new(0, 10, 0, 12),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				}),

				LevelBadge = e("TextLabel", {
					Text = string.format("Level %d / %d", rebirthLevel, RebirthConfig.MAX_REBIRTH),
					Size = UDim2.new(0.8, 0, 0, 28),
					Position = UDim2.new(0.1, 0, 0, 58),
					BackgroundColor3 = Color3.fromRGB(40, 40, 60),
					BorderSizePixel = 0,
					TextColor3 = Color3.fromRGB(0, 220, 180),
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextScaled = true,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),

				RPLabel = e("TextLabel", {
					Text = string.format("💎 %s RP dimiliki", GameUtils.formatCompact(rebirthPoints)),
					Size = UDim2.new(0.9, 0, 0, 22),
					Position = UDim2.new(0.05, 0, 0, 94),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(200, 175, 255),
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					TextScaled = true,
				}),

				TotalRPLabel = e("TextLabel", {
					Text = string.format("📊 Total RP diperoleh: %s", GameUtils.formatCompact(totalRP)),
					Size = UDim2.new(0.9, 0, 0, 18),
					Position = UDim2.new(0.05, 0, 0, 119),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(160, 160, 190),
					TextSize = 10,
					Font = Enum.Font.GothamMedium,
					TextScaled = true,
				}),

				Divider = e("Frame", {
					Size = UDim2.new(0.85, 0, 0, 1),
					Position = UDim2.new(0.075, 0, 0, 145),
					BackgroundColor3 = Color3.fromRGB(60, 60, 80),
					BorderSizePixel = 0,
				}),

				Details = e("TextLabel", {
					Text = "Rebirth akan mereset Cash & plot mesin Anda.\n\nMobil ber-varian <font color='#FF5555'>Admin</font> akan dipertahankan.\n\nSetiap rebirth memberikan Rebirth Points (RP) yang dapat digunakan untuk upgrade permanen.",
					Size = UDim2.new(0.88, 0, 0, 130),
					Position = UDim2.new(0.06, 0, 0, 152),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(180, 180, 200),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextWrapped = true,
					RichText = true,
				}),

				CostLabel = e("TextLabel", {
					Text = isRebirthMaxed
						and "✅ REBIRTH LEVEL MAKSIMUM"
						or string.format("Biaya: <font color='#FFD700'>$%s</font>", GameUtils.formatCompact(rebirthCost)),
					Size = UDim2.new(0.88, 0, 0, 20),
					Position = UDim2.new(0.06, 0, 1, -78),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(200, 200, 220),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextScaled = true,
					RichText = true,
				}),

				RebirthBtn = e("TextButton", {
					Text = isRebirthMaxed and "LEVEL MAKS"
						or (canRebirth and "🔱 REBIRTH SEKARANG" or "⛔ CASH TIDAK CUKUP"),
					Size = UDim2.new(0.88, 0, 0, 48),
					Position = UDim2.new(0.06, 0, 1, -52),
					BackgroundColor3 = isRebirthMaxed and Color3.fromRGB(60, 60, 80)
						or (canRebirth and Color3.fromRGB(185, 40, 40) or Color3.fromRGB(70, 70, 85)),
					TextColor3 = isRebirthMaxed and Color3.fromRGB(130, 130, 150)
						or (canRebirth and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 160)),
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					BorderSizePixel = 0,
					Active = canRebirth and not isRebirthMaxed,
					TextScaled = true,
					[React.Event.Activated] = function()
						if canRebirth and not isRebirthMaxed and props.onRebirth then
							props.onRebirth()
						end
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			UpgradesPanel = e("Frame", {
				Size = UDim2.new(0.61, -8, 0, 0),
				Position = UDim2.new(0.39, 8, 0, 0),
				BackgroundColor3 = Color3.fromRGB(22, 22, 32),
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.Y,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(80, 80, 110),
					Thickness = 1,
				}),

				Title = e("TextLabel", {
					Text = "✨ UPGRADE PERMANEN",
					Size = UDim2.new(1, -20, 0, 40),
					Position = UDim2.new(0, 10, 0, 10),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				}),

				RPInfo = e("TextLabel", {
					Text = string.format("💎 %s RP tersedia", GameUtils.formatCompact(rebirthPoints)),
					Size = UDim2.new(1, -20, 0, 20),
					Position = UDim2.new(0, 10, 0, 45),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(180, 150, 255),
					TextSize = 11,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = true,
				}),

				ScrollArea = e("Frame", {
					Size = UDim2.new(1, -20, 0, 0),
					Position = UDim2.new(0, 10, 0, 68),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutomaticSize = Enum.AutomaticSize.Y,
				}, allChildren),
			}),
		}
	end

	return e("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(100, 100, 130),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, mainContent)
end
