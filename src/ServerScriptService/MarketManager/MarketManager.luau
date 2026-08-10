local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local DataManager = require(game.ServerScriptService.DataManager.DataManager)
local Networker = require(ReplicatedStorage.Packages.Networker)

local MarketManager = {}

-- Active memory store table for market listings
local activeListings = {} -- { [listingId]: { ListingId: string, SellerUserId: number, SellerName: string, CarFullName: string, BasePrice: number, CurrentBid: number, HighestBidderUserId: number?, EndTime: number, BuyoutPrice: number } }

-- Helper function to generate unique ID
local function generateListingId(): string
	return "LISTING_" .. HttpService:GenerateGUID(false)
end

function MarketManager:createListing(player: Player, carFullName: string, startingBid: number, buyoutPrice: number)
	if not player or not player.Parent then
		return { Success = false, Error = "Pemain tidak valid." }
	end

	if startingBid <= 0 or buyoutPrice < startingBid then
		return { Success = false, Error = "Harga lelang atau beli instan tidak valid." }
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return { Success = false, Error = "Backpack tidak ditemukan." }
	end

	local item = backpack:FindFirstChild(carFullName)
	if not item then
		return { Success = false, Error = "Mobil tidak ditemukan di tas Anda." }
	end

	-- Deduct 1 car item from backpack
	local amount = item:GetAttribute("Amount") or 1
	if amount > 1 then
		item:SetAttribute("Amount", amount - 1)
	else
		item:Destroy()
	end

	local listingId = generateListingId()
	local newListing = {
		ListingId = listingId,
		SellerUserId = player.UserId,
		SellerName = player.Name,
		CarFullName = carFullName,
		BasePrice = startingBid,
		CurrentBid = startingBid,
		HighestBidderUserId = nil,
		BuyoutPrice = buyoutPrice,
		EndTime = os.time() + 3600, -- Default 1 jam
	}

	activeListings[listingId] = newListing
	print(`[MarketManager] 🛒 Listing baru dibuat oleh {player.Name}: {carFullName} (${startingBid} - ${buyoutPrice})`)
	return { Success = true, Message = "Berhasil mendaftarkan mobil ke Pasar Bursa!", Listing = newListing }
end

function MarketManager:fetchListings()
	local list = {}
	for _, listing in pairs(activeListings) do
		table.insert(list, listing)
	end
	return { Success = true, Listings = list }
end

function MarketManager:placeBid(player: Player, listingId: string, bidAmount: number)
	local listing = activeListings[listingId]
	if not listing then
		return { Success = false, Error = "Listing barang tidak ditemukan." }
	end

	if os.time() >= listing.EndTime then
		return { Success = false, Error = "Sesi lelang untuk mobil ini telah berakhir." }
	end

	if bidAmount <= listing.CurrentBid then
		return { Success = false, Error = "Penawaran harus lebih tinggi dari penawaran saat ini." }
	end

	local playerData = DataManager.getData(player)
	if not playerData or (playerData.Money or 0) < bidAmount then
		return { Success = false, Error = "Uang Cash Anda tidak mencukupi." }
	end

	-- Deduct bid amount
	DataManager.addMoney(player, -bidAmount)

	-- Refund previous highest bidder
	if listing.HighestBidderUserId then
		local prevPlayer = Players:GetPlayerByUserId(listing.HighestBidderUserId)
		if prevPlayer then
			DataManager.addMoney(prevPlayer, listing.CurrentBid)
		end
	end

	listing.CurrentBid = bidAmount
	listing.HighestBidderUserId = player.UserId
	print(`[MarketManager] 💰 {player.Name} memasang penawaran ${bidAmount} pada {listing.CarFullName}`)

	return { Success = true, Message = "Penawaran lelang berhasil dipasang!", CurrentBid = bidAmount }
end

function MarketManager:buyout(player: Player, listingId: string)
	local listing = activeListings[listingId]
	if not listing then
		return { Success = false, Error = "Listing barang tidak ditemukan." }
	end

	local playerData = DataManager.getData(player)
	if not playerData or (playerData.Money or 0) < listing.BuyoutPrice then
		return { Success = false, Error = "Uang Cash Anda tidak mencukupi untuk Beli Instan." }
	end

	-- Process Buyout
	DataManager.addMoney(player, -listing.BuyoutPrice)

	-- Calculate 5% transaction tax fee
	local netProceeds = math.floor(listing.BuyoutPrice * 0.95)
	local seller = Players:GetPlayerByUserId(listing.SellerUserId)
	if seller then
		DataManager.addMoney(seller, netProceeds)
	end

	-- Deliver car item to buyer
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local ServerStorage = game:GetService("ServerStorage")
		local carTemplate = ServerStorage:FindFirstChild(listing.CarFullName)
		if carTemplate then
			local clone = carTemplate:Clone()
			clone.Parent = backpack
		end
	end

	activeListings[listingId] = nil
	print(`[MarketManager] ⚡ {player.Name} membeli instan {listing.CarFullName} seharga ${listing.BuyoutPrice}!`)
	return { Success = true, Message = "Pembelian instan berhasil! Mobil telah masuk ke tas Anda." }
end

function MarketManager.Init()
	Networker.server.new("MarketService", MarketManager, {
		MarketManager.createListing,
		MarketManager.fetchListings,
		MarketManager.placeBid,
		MarketManager.buyout,
	})
	print("[MarketManager] ✅ MarketService Networker endpoints berhasil didaftarkan.")
end

return MarketManager
