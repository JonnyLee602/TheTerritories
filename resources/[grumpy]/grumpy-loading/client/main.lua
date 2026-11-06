-- Closes the loading screen once the character is in the world.
-- The page fades its music out on 'grumpy-loading:finish', then we shut the NUI down.
-- Calling ShutdownLoadingScreenNui after another script already did is harmless.
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    if not Config.CloseOnPlayerLoaded then return end
    CreateThread(function()
        SendLoadingScreenMessage(json.encode({ type = 'grumpy-loading:finish' }))
        Wait(Config.CloseDelay or 0)
        ShutdownLoadingScreenNui()
    end)
end)
