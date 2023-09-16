local Translations = {
    error = {
        not_online = 'Spieler ist nicht online',
        no_player = 'Kein Spieler in der Nähe',
        no_firstaid = 'Du benötigst ein Erste-Hilfe-Set',
        no_bandage = 'Du benötigst eine Bandage',
        not_medic = 'Du bist kein Sanitäter',
    },
    success = {
        revived = 'Du hast eine Person wiederbelebt',
    },
    info = {
        revive_player_a = 'Spieler oder dich selbst wiederbeleben (nur Admin)',
        kill_player = 'Einen Spieler töten (nur Admin)',
        player_id = 'Spieler-ID (kann leer sein)',
        blip_text = 'Sanitäter-Alarm - %{text}',
        new_call = 'Neuer Anruf',
    },
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
