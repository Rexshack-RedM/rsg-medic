local Translations = {

    client = {
        lang_1 = 'Open',
        lang_2 = 'RESPAWN IN ',
        lang_3 = ' SECONDS..',
        lang_4 = 'PRESS [E] TO RESPAWN',
        lang_5 = 'PRESS [E] TO RESPAWN - PRESS [J] TO CALL FOR ASSISTANCE',
        lang_6 = 'PRESS [J] TO CALL FOR ASSISTANCE',
        lang_7 = 'A person needs medical help!',
        lang_8 = 'Medic has been called!',
        lang_9 = 'You are not a Medic!',
        lang_10 = 'Manage employees',
        lang_11 = 'Manage employees and business',
        lang_12 = 'Toggle Duty',
        lang_13 = 'Medical Supplies',
        lang_14 = 'Medic Storage',
        lang_15 = 'You are not a medic',
        lang_16 = 'You need a First Aid Kit',
        lang_17 = 'No Player Nearby',
        lang_18 = 'Reviving...',
        lang_19 = 'You need a Bandage',
        lang_20 = 'No Player Nearby',
        lang_21 = 'Treating Wounds...',
        lang_22 = 'Distance to Player Blip: ',
        lang_23 = ' metres',
        lang_24 = 'Blip Coords: ',
        lang_25 = 'Blip Removed: ',
    },

    server = {
        lang_1 = 'Revive A Player or Yourself (Admin Only)',
        lang_2 = 'Player ID (may be empty)',
        lang_3 = 'Player Not Online',
        lang_4 = 'Kill a Player (Admin Only)',
        lang_5 = 'Player ID (may be empty)',
        lang_6 = 'Player Not Online',
        lang_7 = 'you lost all your possessions!',
        lang_8 = 'you lost all your cash!',
        lang_9 = 'You are not a medic',
    },

    logs = {
        death_log_title = "%{playername} (%{playerid}) is dead",
        death_log_message = "%{killername} has killed %{playername} with a **%{weaponlabel}** (%{weaponname})",
    }

}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})

-- Lang:t('client.lang_1')
-- Lang:t('server.lang_1')
