fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

name 'rsg-medic'
description 'Death system and medic job for RSG Framework'
version '3.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
    'client/automedic.lua',
}

server_scripts {
    'server/sv_config.lua',
    'server/server.lua',
    'server/automedic_webhooks.lua',
    'server/automedic.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
}

lua54 'yes'
