# rsg-lottery hook (for grumpy-bartender "Play the lottery")

rsg-lottery opens its UI with a function inside its own client (`OpenLotteryUI`) and has no export or event for
other resources. Its server callbacks don't check where the player is, so a client export is all that's needed.

This is a local change to an RSG resource. Re-apply it after updating rsg-lottery, or ask the RSG authors to add
the export upstream. Don't redistribute a modified rsg-lottery.

## client/client.lua

At the end of the file add:

```lua
-- Open the lottery UI from another resource (e.g. grumpy-bartender)
exports('OpenLottery', function() OpenLotteryUI() end)
```

Opening the UI also collects any prizes waiting for the player, the same as at a ticket seller.
