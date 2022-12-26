Config = {}

-- settings
Config.JobRequired = 'medic'
Config.StorageMaxWeight = 4000000
Config.StorageMaxSlots = 48
Config.DeathTimer = 60 -- 300 = 5 mins / testing 60 = 1 min
Config.WipeInventoryOnRespawn = true
Config.WipeCashOnRespawn = true
Config.MaxHealth = 300
Config.MedicReviveTime = 5000

-- blip settings
Config.Blip = {
    blipName = 'Medic', -- Config.Blip.blipName
    blipSprite = 'blip_shop_doctor', -- Config.Blip.blipSprite
    blipScale = 0.2 -- Config.Blip.blipScale
}

-- prompt locations
Config.MedicJobLocations = {
    {name = 'Valentine Medic', prompt = 'valmedic', coords = vector3(-287.59, 811.28, 119.39 -0.8), showblip = true, showmarker = true}, --valentine
}

-- medic supplies items
Config.MedicSupplies = {
    [1] = { name = "bandage", price = 0, amount = 500, info = {}, type = "item", slot = 1, },
    [2] = { name = "firstaid", price = 0, amount = 500, info = {}, type = "item", slot = 2, },
}
