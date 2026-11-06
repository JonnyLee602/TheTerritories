fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'grumpy-drawpoker'
description 'Five-Card Draw for grumpy-gambling: players against each other at a card table'
version '0.1.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    '@grumpy-gambling/lib/init.lua',
    '@grumpy-gambling/lib/cards.lua',
    '@grumpy-gambling/lib/poker.lua',
    '@grumpy-gambling/lib/betting.lua',
    '@grumpy-gambling/lib/npc_brain.lua',
}

server_scripts {
    '@grumpy-gambling/lib/server.lua',
    'server/game.lua',
}

files { 'locales/*.json' }

dependencies { 'rsg-core', 'grumpy-gambling' }
