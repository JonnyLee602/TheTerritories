-- Wages, tax and repossession.
local RSGCore = POB.Core()

local Upkeep = {}
POB.Upkeep = Upkeep

local Acc = POB.Acc

function Upkeep.TaxAmount(biz)
    return POB.Type(biz).tax or Config.Tax.Default
end

-- Puts a business back on the market. reason = locale text for the ledger / owner message. kind = why, for other
-- resources ('tax' unpaid tax, 'admin' an admin reset or gave it away, 'deleted' the business was deleted).
-- Fires grumpy-pob:server:ownerChanged (id, oldCid, nil, kind).
function POB.Repossess(biz, reason, kind)
    if not biz.owner then return end
    local oldOwner = biz.owner
    POB.Jobs.RemoveAll(biz)
    if Config.Repossess.BalanceToGovernment then
        Acc.Drain(POB.AccountId(biz), Acc.GOV, 'repossess', locale('ledger_repossessed', biz.label))
    end
    if Config.Repossess.WipeStock then POB.Shop.Wipe(biz) end
    if Config.Repossess.WipeStashes then POB.Craft.WipeStashes(biz) end
    MySQL.update.await('DELETE FROM grumpy_pob_applications WHERE business_id = ?', { biz.id })
    biz.owner, biz.taxDue, biz.taxOwedSince = nil, nil, nil
    biz.settings.backroom = nil -- the back room goes with the owner
    POB.SaveBiz(biz)
    Acc.Log(POB.AccountId(biz), 'owner', 0, nil, reason or locale('ledger_repossessed', biz.label))
    POB.Refresh(biz)
    local src = POB.SrcByCid(oldOwner.cid)
    if src then POB.Notify(src, locale('repossessed_owner', biz.label), 'error') end
    print(('[grumpy-pob] business %d "%s" repossessed from %s (%s)'):format(biz.id, biz.label, oldOwner.name, reason or 'tax'))
    TriggerEvent('grumpy-pob:server:ownerChanged', biz.id, oldOwner.cid, nil, kind or 'tax')
end

-- Tries to pay the current bill. Returns true when nothing is owed afterwards.
function Upkeep.TryTax(biz)
    if not Config.Tax.Enabled or not biz.owner or not biz.taxDue then return true end
    local now = os.time()
    if now < biz.taxDue then return true end
    local amount = Upkeep.TaxAmount(biz)
    if Acc.Transfer(POB.AccountId(biz), Acc.GOV, amount, 'tax', nil, locale('ledger_tax', biz.label)) then
        biz.taxDue = biz.taxDue + Config.Tax.IntervalDays * 86400
        if biz.taxDue <= now then biz.taxDue = now + Config.Tax.IntervalDays * 86400 end
        biz.taxOwedSince = nil
        POB.SaveBiz(biz)
        POB.NotifyStaff(biz, 'viewAccount', locale('tax_paid', amount, biz.label))
        return true
    end
    if not biz.taxOwedSince then
        biz.taxOwedSince = now
        POB.SaveBiz(biz)
    end
    if now - biz.taxOwedSince >= Config.Tax.GraceDays * 86400 then
        POB.Repossess(biz, locale('ledger_repossessed_tax', biz.label), 'tax')
        return false
    end
    local daysLeft = math.ceil((biz.taxOwedSince + Config.Tax.GraceDays * 86400 - now) / 86400)
    POB.NotifyStaff(biz, 'viewAccount', locale('tax_overdue', amount, biz.label, daysLeft))
    return false
end

CreateThread(function()
    while true do
        Wait(Config.Tax.CheckMinutes * 60000)
        if POB.Ready and Config.Tax.Enabled then
            for _, biz in pairs(POB.Businesses) do Upkeep.TryTax(biz) end
        end
    end
end)

---------------------------------------------------------------------
-- Wages: on-duty staff (not the owner) every Config.Wages.IntervalMinutes
---------------------------------------------------------------------
local warned = {} -- [bizId] = true once "can't pay" has been sent this interval

CreateThread(function()
    while true do
        Wait(Config.Wages.IntervalMinutes * 60000)
        if POB.Ready and Config.Wages.Enabled then
            warned = {}
            local byJob = {}
            for _, biz in pairs(POB.Businesses) do if biz.owner then byJob[biz.job] = biz end end
            for _, P in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
                local j = P.PlayerData.job or {}
                local biz = j.onduty and byJob[j.name]
                local grade = biz and j.grade and tonumber(j.grade.level) or nil
                if biz and grade and grade < Config.OwnerGrade then
                    local amount = tonumber(biz.settings.wages[tostring(grade)]) or 0
                    if amount > 0 then
                        local who = Acc.Who(P)
                        if Acc.Remove(POB.AccountId(biz), amount, 'wage', who, locale('ledger_wage', Config.Grades[grade])) then
                            P.Functions.AddMoney('cash', amount, 'grumpy-pob:wage')
                            POB.Notify(P.PlayerData.source, locale('wage_paid', amount, biz.label), 'success')
                        else
                            POB.Notify(P.PlayerData.source, locale('wage_unpaid', biz.label), 'error')
                            if not warned[biz.id] then
                                warned[biz.id] = true
                                POB.NotifyStaff(biz, 'wages', locale('wage_unpaid_owner', biz.label))
                            end
                        end
                    end
                end
            end
        end
    end
end)
