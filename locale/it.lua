local Translations = {
    error = {
        not_online = 'Player Non Online',
        no_player = 'Nessun giocatore nelle vicinanze',
        no_firstaid = 'Hai bisogno di un kit di pronto soccorso',
        no_bandage = 'Hai bisogno di una benda',
        not_medic = 'Non sei un medico',
    },
    success = {
        revived = 'Hai rianimato una persona',
    },
    info = {
        revive_player_a = 'Rianima un giocatore o te stesso (solo Admin)',
        kill_player = 'Kill a Player (Admin Only)',
        player_id = 'Player ID (può essere vuoto)',
        blip_text = 'Allarme medico - %{text}',
		new_call = 'Nuova Chiamata',
    },
}

if GetConvar('rsg_locale', 'en') == 'it' then
  Lang = Locale:new({
      phrases = Translations,
      warnOnMissing = true,
      fallbackLang = Lang,
  })
end
