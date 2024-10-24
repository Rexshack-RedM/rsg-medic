local Translations = {

    client = {
        lang_1 = 'Abrir',
        lang_2 = 'RENASCER EM ',
        lang_3 = ' SEGUNDOS..',
        lang_4 = 'PRESSIONE [E] PARA RENASCER',
        lang_5 = 'PRESSIONE [E] PARA RENASCER - PRESSIONE [J] PARA PEDIR AJUDA',
        lang_6 = 'PRESSIONE [J] PARA PEDIR AJUDA',
        lang_7 = 'Uma pessoa precisa de ajuda médica!',
        lang_8 = 'Médico foi chamado!',
        lang_9 = 'Você não é um médico!',
        lang_10 = 'Gerenciar funcionários',
        lang_11 = 'Gerenciar funcionários e negócios',
        lang_12 = 'Alternar serviço',
        lang_13 = 'Suprimentos médicos',
        lang_14 = 'Armazém médico',
        lang_15 = 'Você não é um médico',
        lang_16 = 'Você precisa de um kit de primeiros socorros',
        lang_17 = 'Nenhum jogador por perto',
        lang_18 = 'Revivendo...',
        lang_19 = 'Você precisa de uma bandagem',
        lang_20 = 'Nenhum jogador por perto',
        lang_21 = 'Tratando feridas...',
        lang_22 = 'Distância para o jogador: ',
        lang_23 = ' metros',
        lang_24 = 'Coordenadas do jogador: ',
        lang_25 = 'Marcador removido: ',
    },
    
    server = {
        lang_1 = 'Reviver um jogador ou a si mesmo (Apenas Admin)',
        lang_2 = 'ID do jogador (pode estar vazio)',
        lang_3 = 'Jogador não está online',
        lang_4 = 'Matar um jogador (Apenas Admin)',
        lang_5 = 'ID do jogador (pode estar vazio)',
        lang_6 = 'Jogador não está online',
        lang_7 = 'você perdeu todos os seus pertences!',
        lang_8 = 'você perdeu todo o seu dinheiro!',
        lang_9 = 'Você não é um médico',
    },

    logs = {
        death_log_title = "%{playername} (%{playerid}) is dead",
        death_log_message = "%{killername} has killed %{playername} with a **%{weaponlabel}** (%{weaponname})",
    }

}

if GetConvar('rsg_locale', 'en') == 'pt-br' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
