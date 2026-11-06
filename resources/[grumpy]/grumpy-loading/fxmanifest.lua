fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Grumpy'
name 'grumpy-loading'
description 'The Territories Gazette: an 1890s frontier newspaper loading screen with live population, rotating stories, a telegraph progress line and music.'
version '1.0.0'

shared_script 'shared/config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/config.js',
    'html/music/*',
    'html/images/*',
    'locales/*.json',
}
