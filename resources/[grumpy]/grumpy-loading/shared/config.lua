Config = {}

-- Lua-side settings only. Everything the page itself uses (music, backgrounds, timers, Discord)
-- lives in html/config.js, because the loading screen runs before any Lua is loaded.
-- All on-screen text lives in locales/<lang>.json.

-- Close the loading screen when RSGCore:Client:OnPlayerLoaded fires.
-- rsg-character and rsg-core also close it, so leaving this on is a harmless safety net.
Config.CloseOnPlayerLoaded = true

-- Milliseconds to wait after telling the page to finish (lets the music fade) before shutting the screen.
Config.CloseDelay = 1200

-- Send the live player count and server name to the masthead while the player connects.
Config.ServerInfo = true
