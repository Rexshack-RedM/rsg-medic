local RSGCore = exports['rsg-core']:GetCoreObject()

-- death actions remove inventory / cash
RegisterNetEvent('rsg-medic::server:deathactions', function()
	local src = source
	local Player = RSGCore.Functions.GetPlayer(src)
	if Config.WipeInventoryOnRespawn == true then
		Player.Functions.ClearInventory()
		MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
		TriggerClientEvent('RSGCore:Notify', src, 'you lost all your possessions!', 'primary')
	end
	if Config.WipeCashOnRespawn == true then
		Player.Functions.SetMoney('cash', 0)
		TriggerClientEvent('RSGCore:Notify', src, 'you lost all your cash!', 'primary')
	end
end)
