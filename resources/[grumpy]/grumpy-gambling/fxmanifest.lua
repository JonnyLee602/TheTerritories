fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'grumpy-gambling'
description 'Gambling core: tables, seating, tiers, stacks, rake and NPCs shared by grumpy-gambling game modules'
version '0.9.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/geometry.lua',
    'shared/models.lua',
}

client_scripts {
    'client/main.lua',
    'client/anim.lua',
    'client/world.lua',
    'client/seat.lua',
    'client/admin.lua',
    'client/view.lua',
    'client/table.lua',
    'client/turn.lua',
    'client/business.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/money.lua',
    'server/db.lua',
    'server/registry.lua',
    'server/tables.lua',
    'server/rake.lua',
    'server/house.lua',
    'server/hands.lua',
    'server/wallet.lua',
    'server/seats.lua',
    'server/npc.lua',
    'server/play.lua',
    'server/admin.lua',
    'server/business.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/table.js',
    'lib/*.lua',
}

dependencies {
    'rsg-core',
    'rsg-target',
    'rsg-gizmo',
    'rsg-inventory',
    'oxmysql',
}
