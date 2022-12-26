local Translations = {
    error = {
        not_online = 'Player Not Online',
		no_player = 'No Player Nearby',
		no_firstaid = 'You need a First Aid Kit',
    },
    success = {
        revived = 'You revived a person',
    },
    info = {
        revive_player_a = 'Revive A Player or Yourself (Admin Only)',
        player_id = 'Player ID (may be empty)',
    },
}

Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
