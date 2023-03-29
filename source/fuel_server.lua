ESX = nil

if Config.UseESX then
	TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

	RegisterServerEvent('fuel:pay')
	AddEventHandler('fuel:pay', function(price)
		local xPlayer = ESX.GetPlayerFromId(source)
		local amount = ESX.Math.Round(price)

		if price > 0 then
			xPlayer.removeMoney(amount)
		end
	end)

	if Config.UseJerryCanAsItem then
		RegisterServerEvent("fuel:purcahseJerryCan") 
		AddEventHandler("fuel:purcahseJerryCan", function(price)
			local xPlayer = ESX.GetPlayerFromId(source)
			local amount = ESX.Math.Round(price)
		
			if price > 0 then
				xPlayer.removeMoney(amount)
			end
			xPlayer.addInventoryItem('WEAPON_PETROLCAN', 1)
		end)
	end

	ESX.RegisterServerCallback('fuel:getCash', function (source, cb)
		local xPlayer = ESX.GetPlayerFromId(source)
		cb(xPlayer.getMoney())
	end)

	if Config.UseOXInventory then

		RegisterServerEvent("fuel:removeJerryCan")
		AddEventHandler("fuel:removeJerryCan",function()
			local ox_inventory = exports.ox_inventory
			local _source = source
			local xPlayer = ESX.GetPlayerFromId(_source)
			Wait(5000)
			ox_inventory:RemoveItem(_source, 'WEAPON_PETROLCAN', 1)
		end)
	end

elseif Config.UseQBCORE then
	local QBCore = exports['qb-core']:GetCoreObject()

	RegisterNetEvent('fuel:pay', function(price, source)
		local xPlayer = QBCore.Functions.GetPlayer(source)
		local amount = math.floor(price + 0.5)
		if price > 0 then
			xPlayer.Functions.RemoveMoney('cash', amount)
		end
	end)

	if Config.UseNewQBCORECallbacks then
		RegisterServerEvent("fuel:purcahseJerryCan") 
		AddEventHandler("fuel:purcahseJerryCan", function()
			local Player = QBCore.Functions.GetPlayer(source)
			Player.Functions.AddItem("weapon_petrolcan", 1, false)
		end)
	end

end