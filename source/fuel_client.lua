
ESX = nil
QBCore = nil
CurrentWeaponData = {}

if Config.UseESX then
	Citizen.CreateThread(function()
		while not ESX do
			TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

			Citizen.Wait(500)
		end
	end)
elseif Config.UseQBCORE then

	QBCore = exports['qb-core']:GetCoreObject()

end


local isFueling = false
local currentFuel = 0.0
local currentCost = 0.0
local currentCash = 1000
local fuelSynced = false
local inBlacklisted = false
local ShutOffPump = false
local isBusy = false

function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))

		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end

Citizen.CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)

	for index = 1, #Config.Blacklist do
		if type(Config.Blacklist[index]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[index])] = true
		else
			Config.Blacklist[Config.Blacklist[index]] = true
		end
	end

	for index = #Config.Blacklist, 1, -1 do
		table.remove(Config.Blacklist, index)
	end

	while true do
		Citizen.Wait(1000)

		local ped = PlayerPedId()

		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)

			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end

			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end

			if inBlacklisted then
				inBlacklisted = false
			end
		end
	end
end)

AddEventHandler('fuel:startFuelUpTick', function(pumpObject, ped, vehicle)
	currentFuel = GetVehicleFuelLevel(vehicle)
	while isFueling do
		Citizen.Wait(500)

		local oldFuel = DecorGetFloat(vehicle, Config.FuelDecor)
		local fuelToAdd = math.random(10, 20) / 10.0
		local extraCost = fuelToAdd / 1.5 * Config.CostMultiplier

		if not pumpObject then
			if Config.UseOXInventory then
				Citizen.Wait(10000)
				currentFuel = 101
				TriggerEvent('ox_inventory:disarm')
				Wait(500)
				TriggerServerEvent("fuel:removeJerryCan")
			else
				if GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100 >= 0 then
					currentFuel = oldFuel + fuelToAdd
					local currentAmmo = math.floor(GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100)
					if Config.UseQBCORE then
						TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, currentAmmo)
					end
					SetPedAmmo(ped, 883325847, currentAmmo)
				else
					isFueling = false
				end
			end
		else
			currentFuel = oldFuel + fuelToAdd
		end

		if currentFuel > 100.0 then
			currentFuel = 100.0
			ShutOffPump = true
		end

		currentCost = currentCost + extraCost

		if Config.UseQBCORE then
			currentCash = QBCore.Functions.GetPlayerData().money['cash']
		end
		if currentCash >= currentCost or not pumpObject then
			SetFuel(vehicle, currentFuel)
		else
			ShutOffPump = true
		end

		if ShutOffPump then 
			ShutOffPump = false
			Citizen.Wait(Config.WaitTimeAfterRefuel)
			isFueling = false
		end

	end

	if pumpObject then
		TriggerServerEvent('fuel:pay', currentCost, GetPlayerServerId(PlayerId()))
	end

	currentCost = 0.0
end)

AddEventHandler('fuel:stopRefuelFromPump', function()
	if isFueling then
		ShutOffPump = true
	end
end)

AddEventHandler('fuel:refuelFromPump', function(ped, vehicle)
	if not isBusy then
		isBusy = true
		local _ped = ped
		local _vehicle = vehicle
		if Config.UseESX then
			ESX.TriggerServerCallback('fuel:getCash', function(cash)
				isBusy = false
				currentCash = cash
				if currentCash < Config.MinimumCash then
					ShowNotification(Config.Strings.NotEnoughCash)
				else
					isFueling = true
					TriggerEvent('fuel:startFuelUpTick', true, _ped, _vehicle)
					while isFueling do
						local vehicleCoords = GetEntityCoords(_vehicle)
						local extraString = ""
						extraString = "\n" .. Config.Strings.TotalCost .. ": ~g~$" .. Round(currentCost, 1)
						DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(currentFuel, 1) .. "%" .. extraString)
						Citizen.Wait(0)
					end
				end
			end)
		elseif Config.UseQBCORE then
			isBusy = false
			currentCash = QBCore.Functions.GetPlayerData().money['cash']
			if currentCash < Config.MinimumCash then
				ShowNotification(Config.Strings.NotEnoughCash)
			else
				isFueling = true
				TriggerEvent('fuel:startFuelUpTick', true, _ped, _vehicle)
				while isFueling do
					local vehicleCoords = GetEntityCoords(_vehicle)
					local extraString = ""
					extraString = "\n" .. Config.Strings.TotalCost .. ": ~g~$" .. Round(currentCost, 1)
					DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(currentFuel, 1) .. "%" .. extraString)
					Citizen.Wait(0)
				end
			end
		else
			isBusy = false
			isFueling = true
			TriggerEvent('fuel:startFuelUpTick', true, ped, vehicle)
			while isFueling do
				local vehicleCoords = GetEntityCoords(vehicle)
				local extraString = ""

				if Config.UseESX then
					extraString = "\n" .. Config.Strings.TotalCost .. ": ~g~$" .. Round(currentCost, 1)
				end
				DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(currentFuel, 1) .. "%" .. extraString)
				Citizen.Wait(0)
			end
		end
	end
end)

AddEventHandler('fuel:refuelFromJerryCan', function(ped, vehicle)
	TriggerEvent("pump:disableRefuelText", true)
	RequestAnimDict("weapon@w_sp_jerrycan")
	while not HasAnimDictLoaded('weapon@w_sp_jerrycan') do
		Wait(100)
	end
	TaskTurnPedToFaceEntity(ped, vehicle, 1000)
	isFueling = true
	Citizen.Wait(1000)
	TaskPlayAnim(ped, "weapon@w_sp_jerrycan", "fire", 8.0, 1.0, -1, 1, 0, 0, 0, 0 )
	TriggerEvent('fuel:startFuelUpTick', false, ped, vehicle)

	while isFueling do
		for _, controlIndex in pairs(Config.DisableKeys) do
			DisableControlAction(0, controlIndex)
		end

		local vehicleCoords = GetEntityCoords(vehicle)
		DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Config.Strings.CancelFuelingJerryCan .. "\nGas can: ~g~" .. Round(GetAmmoInPedWeapon(ped, 883325847) / 4500 * 100, 1) .. "% | Vehicle: " .. Round(currentFuel, 1) .. "%")

		if IsControlJustReleased(0, 38) or DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
			isFueling = false
		end

		Citizen.Wait(0)
	end
	TriggerEvent("pump:disableRefuelText", false)
	StopAnimTask(ped, "weapon@w_sp_jerrycan", "fire", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
end)

AddEventHandler('fuel:requestJerryCanPurchase', function()
	if Config.UseESX then
		if not isBusy then
			isBusy = true
			ESX.TriggerServerCallback('fuel:getCash', function(cash)
				isBusy = false
				currentCash = cash
				
				local ped = PlayerPedId()
				if not HasPedGotWeapon(ped, 883325847) then
					if currentCash >= Config.JerryCanCost then
						ShowNotification(Config.Strings.PurchaseJerryCan)
						if Config.UseJerryCanAsItem then
							TriggerServerEvent('fuel:purcahseJerryCan', Config.JerryCanCost)
						else
							GiveWeaponToPed(ped, 883325847, 4500, false, true)
							TriggerServerEvent('fuel:pay', Config.JerryCanCost)
						end
					else
						ShowNotification(Config.Strings.NotEnoughCash)
					end
				else
					local refillCost = Round(Config.RefillCost * (1 - GetAmmoInPedWeapon(ped, 883325847) / 4500))

					if refillCost > 0 then
						if currentCash >= refillCost then
							ShowNotification(Config.Strings.RefillJerryCan .. "~g~$" .. refillCost)
							TriggerServerEvent('fuel:pay', refillCost)
							SetPedAmmo(ped, 883325847, 4500)
						else
							ShowNotification(Config.Strings.NotEnoughCashJerryCan)
						end
					else
						ShowNotification(Config.Strings.JerryCanFull)
					end
				end
				
			end)
		end

	elseif Config.UseQBCORE then
		isBusy = false
		currentCash = QBCore.Functions.GetPlayerData().money['cash']
		local ped = PlayerPedId()
		if not HasPedGotWeapon(ped, 883325847) then
			if currentCash >= Config.JerryCanCost then
				ShowNotification(Config.Strings.PurchaseJerryCan)
				if Config.UseNewQBCORECallbacks then
					TriggerServerEvent('fuel:purcahseJerryCan')
				else
					TriggerServerEvent('QBCore:Server:AddItem', "weapon_petrolcan", 1)
				end
				TriggerEvent("inventory:client:ItemBox", QBCore.Shared.Items["weapon_petrolcan"], "add")
				TriggerServerEvent('fuel:pay', Config.JerryCanCost, GetPlayerServerId(PlayerId()))
			else
				ShowNotification(Config.Strings.NotEnoughCash)
			end
			
		else
			local refillCost = Round(Config.RefillCost * (1 - GetAmmoInPedWeapon(ped, 883325847) / 4500))

			if refillCost > 0 then
				if currentCash >= refillCost then
					ShowNotification(Config.Strings.RefillJerryCan .. "~g~$" .. refillCost)
					TriggerServerEvent('fuel:pay', refillCost, GetPlayerServerId(PlayerId()))
					SetPedAmmo(ped, 883325847, 4500)
					TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, tonumber(4500))
				else
					ShowNotification(Config.Strings.NotEnoughCashJerryCan)
				end
			else
				ShowNotification(Config.Strings.JerryCanFull)
			end
		end
	else
		isBusy = false
		local ped = PlayerPedId()
		if not HasPedGotWeapon(ped, 883325847) then
			ShowNotification(Config.Strings.PurchaseJerryCan)
			GiveWeaponToPed(ped, 883325847, 4500, false, true)
		else
			ShowNotification(Config.Strings.RefillJerryCan)
			SetPedAmmo(ped, 883325847, 4500)
		end

	end
end)

if Config.UseQBCORE then

	AddEventHandler('weapons:client:SetCurrentWeapon', function(data, bool)
		if bool ~= false then
			CurrentWeaponData = data
		else
			CurrentWeaponData = {}
		end
	end)

end

if Config.ShowNearestGasStationOnly then
	Citizen.CreateThread(function()
		local currentGasBlip = 0

		while true do
			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords

			for _, gasStationCoords in pairs(Config.GasStations) do
				local dstcheck = GetDistanceBetweenCoords(coords, gasStationCoords)

				if dstcheck < closest then
					closest = dstcheck
					closestCoords = gasStationCoords
				end
			end

			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end

			currentGasBlip = CreateBlip(closestCoords)

			Citizen.Wait(10000)
		end
	end)
elseif Config.ShowAllGasStations then
	Citizen.CreateThread(function()
		for _, gasStationCoords in pairs(Config.GasStations) do
			CreateBlip(gasStationCoords)
		end
	end)
end

if Config.EnableHUD then
	local function DrawAdvancedText(x,y ,w,h,sc, text, r,g,b,a,font,jus)
		SetTextFont(font)
		SetTextProportional(0)
		SetTextScale(sc, sc)
		N_0x4e096588b13ffeca(jus)
		SetTextColour(r, g, b, a)
		SetTextDropShadow(0, 0, 0, 0,255)
		SetTextEdge(1, 0, 0, 0, 255)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		AddTextComponentString(text)
		DrawText(x - 0.1+w, y - 0.02+h)
	end

	local mph = 0
	local kmh = 0
	local fuel = 0
	local displayHud = false

	local x = 0.01135
	local y = 0.002

	Citizen.CreateThread(function()
		while true do
			local ped = PlayerPedId()

			if IsPedInAnyVehicle(ped) and not (Config.RemoveHUDForBlacklistedVehicle and inBlacklisted) then
				local vehicle = GetVehiclePedIsIn(ped)
				local speed = GetEntitySpeed(vehicle)

				mph = tostring(math.ceil(speed * 2.236936))
				kmh = tostring(math.ceil(speed * 3.6))
				fuel = tostring(math.ceil(GetVehicleFuelLevel(vehicle)))

				displayHud = true
			else
				displayHud = false

				Citizen.Wait(500)
			end

			Citizen.Wait(50)
		end
	end)

	Citizen.CreateThread(function()
		while true do
			if displayHud then
				DrawAdvancedText(0.130 - x, 0.77 - y, 0.005, 0.0028, 0.6, mph, 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.174 - x, 0.77 - y, 0.005, 0.0028, 0.6, kmh, 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.2195 - x, 0.77 - y, 0.005, 0.0028, 0.6, fuel, 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.148 - x, 0.7765 - y, 0.005, 0.0028, 0.4, "mp/h              km/h              Fuel", 255, 255, 255, 255, 6, 1)
			else
				Citizen.Wait(750)
			end

			Citizen.Wait(0)
		end
	end)
end

--These are only available when you set the DisplayStyle is set to EVENT inside the settings.ini
--Below is an example using cd_drawtextui
AddEventHandler('fuel:HideMessage', function()
	TriggerEvent('cd_drawtextui:HideUI')
end)

AddEventHandler('fuel:DisplayMessage', function(text)
	TriggerEvent('cd_drawtextui:ShowUI', 'show', text)
end)