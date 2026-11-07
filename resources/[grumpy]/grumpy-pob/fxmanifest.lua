fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'grumpy-pob'
description 'Player owned businesses: admin-built shops, saloons, hotels and stables with staff, stock, crafting, accounts, wages and tax'
version '1.3.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/interact.lua',
    'client/admin.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/main.lua',
    'server/accounts.lua',
    'server/jobs.lua',
    'server/shop.lua',
    'server/crafting.lua',
    'server/recipes.lua',
    'server/approval.lua',
    'server/stable.lua',
    'server/hotel.lua',
    'server/business.lua',
    'server/launder.lua',
    'server/gambling.lua',
    'server/upkeep.lua',
    'server/admin.lua',
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
    'rsg-stores',
    'oxmysql',
}
