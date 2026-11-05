fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Grumpy'
name 'grumpy-groups'
description 'Gangs (replaces rsg-gangmenu) and temporary posses in one resource, plus a single group-members API for other scripts.'
version '1.0.0'

-- lets scripts that list rsg-gangmenu as a dependency start; its server exports are aliased in server/api.lua
provide 'rsg-gangmenu'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/gang.lua',
    'client/posse.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/gangs.lua',
    'server/posse.lua',
    'server/api.lua',
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
    'oxmysql',
}
