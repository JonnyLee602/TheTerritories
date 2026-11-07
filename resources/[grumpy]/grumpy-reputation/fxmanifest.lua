fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Grumpy'
name 'grumpy-reputation'
description 'One legit/outlaw standing per character, moved by legal and illegal work and by reported crimes, honor/infamy merchant prices, plus a /rep panel for every rep value.'
version '1.1.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/tiers.lua',
    'shared/pricing.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/hooks.lua',
    'server/pricing.lua',
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
    'oxmysql',
}
