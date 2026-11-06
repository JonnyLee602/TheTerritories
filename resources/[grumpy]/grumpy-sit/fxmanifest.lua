fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Grumpy'
name 'grumpy-sit'
description 'Sit on chairs, stools and benches anywhere with rsg-target. Replaces the base game sit prompt.'
version '1.1.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'rsg-target',
}
