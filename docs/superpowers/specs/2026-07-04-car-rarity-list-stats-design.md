# Design Spec: CarRarityList Stat Binding

**Date**: 2026-07-04  
**Topic**: Implement static income & price bindings from GameConfig.CarRarityList

---

## 1. Problem Statement

Currently, F1-Tycoon calculates car price and income on-the-fly using global mathematical formulas starting from a baseline rarity price. The user has requested to directly bind the `income` and `price` values defined inside `GameConfig.CarRarityList` to the car tool's attributes when they are obtained (via open box, admin gift, trading, or parking calculation).

---

## 2. Proposed Changes

### A. GameConfig Updates (`GameConfig.luau`)
Extend `GameConfig.CalculatePrice` to accept a `carName` parameter. If `carName` is supplied and exists within `GameConfig.CarRarityList[rarityName][carName]`, we:
1. Use the configured `price` as the `basePrice`.
2. Apply the variant and rarity multipliers directly to the configured `income`.

If not found, fallback to mathematical scaling.

### B. Spawner Integration
Pass the `carName` parameter to `GameConfig.CalculatePrice` calls in:
1. `BoxManager.luau`
2. `EventManager.luau`
3. `TradeSession.luau`
4. `ParkingAreaManager.luau`

---

## 3. Detailed Interface & API Changes

### `GameConfig.CalculatePrice`
```lua
function GameConfig.CalculatePrice(base: number?, rName: string, vNameString: string?, carName: string?): (number, number)
	local rData = GameConfig.Rarities[rName] or GameConfig.Rarities.Common
	local totalVariantMulti = 1.0

	if vNameString and vNameString ~= "" then
		local activeVariants = string.split(vNameString, ",")
		for _, vName in pairs(activeVariants) do
			local vData = GameConfig.Variants[vName]
			if vData then
				totalVariantMulti = totalVariantMulti + (vData.Multiplier - 1.0)
			end
		end
	end

	local basePrice = base or 1000
	local baseIncomeVal = nil

	if carName and GameConfig.CarRarityList[rName] and GameConfig.CarRarityList[rName][carName] then
		local carStats = GameConfig.CarRarityList[rName][carName]
		basePrice = carStats.price or basePrice
		baseIncomeVal = carStats.income
	end

	local rawPrice = basePrice * rData.PriceMod * totalVariantMulti
	local sellPrice = math.floor(100000000 * rawPrice / (rawPrice + 90000000))

	local income
	if baseIncomeVal then
		income = math.floor(baseIncomeVal * rData.PriceMod * totalVariantMulti)
	else
		income = math.floor(300000 * rawPrice / (rawPrice + 3000000))
	end

	return income, sellPrice
end
```

---

## 4. Test Plan
1. **Unboxing Car**: Open a box, obtain a car, and verify its `Price` and `Income` matches the values configured in `GameConfig.CarRarityList` for that model.
2. **Gift Admin Car**: Gift an admin car and check that the attributes are correctly loaded from the config.
3. **Variants Multipliers**: Check that variant multipliers (e.g. Golden, Galaxy) properly multiply the base income and price from `CarRarityList`.
