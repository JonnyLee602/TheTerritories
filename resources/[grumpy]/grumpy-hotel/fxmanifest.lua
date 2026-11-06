fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Grumpy'
name 'grumpy-hotel'
description 'Saloon rooms for rent: instanced rooms, shared stash, keys, knocking, law warrants. Rented through grumpy-bartender (or any script) via exports.'
version '1.2.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/room.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/rooms.lua',
    'server/rental.lua',
    'server/warrants.lua',
    'server/admin.lua',
    'server/debug.lua',
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
    'rsg-target',
    'rsg-gizmo',
    'oxmysql',
}
