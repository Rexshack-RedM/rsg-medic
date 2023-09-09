local Translations = {
error = {
    not_online = 'Jogador não está online',
    no_player = 'Nenhum jogador próximo',
    no_firstaid = 'Você precisa de um Kit de Primeiros Socorros',
    no_bandage = 'Você precisa de um Band-Aid',
    not_medic = 'Você não é um médico',
},
success = {
    revived = 'Você reviveu uma pessoa',
},
info = {
    revive_player_a = 'Reviver um Jogador ou a Si Mesmo (Apenas Admin)',
    kill_player = 'Matar um Jogador (Apenas Admin)',
    player_id = 'ID do Jogador (pode estar vazio)',
    blip_text = 'Alerta Médico - %{text}',
    new_call = 'Nova Chamada',
},
}

if GetConvar('rsg_locale', 'en') == 'pt-br' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
