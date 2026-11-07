fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'grumpy-livery'
description 'The Territories livery: horses and wagons in one resource (fork of rsg-stables 3.4.0 + rsg-wagons 3.0.0, GPLv3)'
version '1.1.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',      -- horses (loaded first: it creates Config)
    'shared/wagons.lua',      -- wagons
    'shared/liveries.lua',
    'shared/propsets.lua',
    'shared/huntingcart.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/money.lua',       -- LiveryMoney: markets, standing, cash/bloodmoney (used by server.lua + wagons.lua)
    'server/server.lua',
    'server/training.lua',
    'server/wagons.lua',
    'server/migrate.lua',
}

client_scripts {
    'client/dataview.lua',
    'client/coat.lua',
    'client/client.lua',
    'client/horseinfo.lua',
    'client/wildhorse.lua',
    'client/training.lua',
    'client/fence.lua',
    'client/actions.lua',
    'client/spook.lua',
    'client/salvage.lua',
    'client/races.lua',
    'client/wagons.lua',
}

dependencies {
    'rsg-core',
    'rsg-target',
    'rsg-inventory',
    'oxmysql',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/wagons.css',
    'html/app.js',
    'html/horsecard.js',
    'html/training.js',
    'html/actions.js',
    'html/papers.js',
    'html/wagons.js',
    'html/wagons-drag.js',
}
