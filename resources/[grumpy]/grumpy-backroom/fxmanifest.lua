fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Grumpy'
name 'grumpy-backroom'
description 'Back-room card rooms: bribe the doorman, the rsg-doorlock doors open for a while, everyone inside is shown out when time runs out.'
version '0.2.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/zone.lua',
}

client_scripts {
    '@rsg-core/client/zones.lua',
    'client/main.lua',
    'client/admin.lua',
    'client/reup.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
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
    'rsg-doorlock',
    'rsg-target',
    'rsg-gizmo',
    'rsg-menubase',
    'oxmysql',
}
