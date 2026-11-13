-- 完好車的右鍵選單「拆解車輛」。燒毀與撞毀的車原版已有選項（ISVehicleMenu.lua:618-648），不重複加。
require "Vehicles/ISUI/ISVehicleMenu"
require "MinidoracatAnyCar/Dismantle"
require "TimedActions/ISTimedActionQueue"

local D = MinidoracatAnyCar

-- 以下兩個照抄原版的 local 函式（ISVehicleMenu.lua:5、:592）
local function predicateWeldingMask(item)
    return item:hasTag(ItemTag.WELDING_MASK) or item:getType() == "WeldingMask"
end

local function comparatorDrainableUsesInt(item1, item2)
    return item1:getCurrentUses() - item2:getCurrentUses()
end

local function requirementLine(ok, text)
    return " <LINE> <RGB:1," .. (ok and "1,1" or "0,0") .. "> " .. text
end

local function predicateBlowTorch(item)
    return (item:hasTag(ItemTag.BLOW_TORCH) or item:getType() == "BlowTorch") and item:getCurrentUses() >= 10
end

-- 照 ISVehicleMenu.onRemoveBurntVehicle（:883-892），多帶玩家看到的車內物品數：之後數量比它多，動作就中止
local function start(playerObj, vehicle, items)
    if vehicle:isRemovedFromWorld() then return end
    if luautils.walkAdj(playerObj, vehicle:getSquare()) then
        ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), predicateBlowTorch, true)
        local mask = playerObj:getInventory():getFirstEvalRecurse(predicateWeldingMask)
        if mask then
            ISInventoryPaneContextMenu.wearItem(mask, playerObj:getPlayerNum())
        end
        ISTimedActionQueue.add(ISRemoveBurntVehicle:new(playerObj, vehicle, { dismantleItems = items }))
    end
end

local function onConfirm(shown, button, playerObj, vehicle)
    if button.internal ~= "YES" or vehicle:isRemovedFromWorld() then return end
    -- 確認框開著時物品被拿走：用比較小的數當基準，之後再有人放東西進去才擋得到
    local _, now = D.count(vehicle)
    start(playerObj, vehicle, math.min(shown, now))
end

function D.onDismantle(playerObj, vehicle)
    local _, items = D.count(vehicle)
    if items == 0 then
        start(playerObj, vehicle, 0)
        return
    end
    -- 寫法照 ISVehicleMechanics.onCheatRemove（ISVehicleMechanics.lua:607-618）
    local playerNum = playerObj:getPlayerNum()
    local modal = ISModalDialog:new(0, 0, 350, 150, getText("IGUI_MinidoracatAnyCar_ConfirmItems", items),
        true, items, onConfirm, playerNum, playerObj, vehicle)
    modal:initialise()
    modal.moveWithMouse = true
    modal:addToUIManager()
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, modal)
    end
end

-- 佇列被取消的次數（佇列裡還有動作時才算）：玩家取消、動作被中止都會經過 cancelQueue（ISTimedActionQueue.lua:46-56、101-113）
local vanillaCancelQueue = ISTimedActionQueue.cancelQueue
function ISTimedActionQueue:cancelQueue()
    if #self.queue > 0 then self.anycarCancels = (self.anycarCancels or 0) + 1 end
    return vanillaCancelQueue(self)
end

-- 排了一個動作之後，等它離開佇列再決定要不要接下一步：
--   做完（perform）：等結果出現（done()）；結果一直沒變（例：狀況 0 的零件擲骰失敗）過 CHAIN_NOCHANGE 也算試過，接下去
--   沒做完但結果出現：多人時同步先到、動作被自動中止，接下去
--   沒做完也沒結果：玩家取消或伺服器拒絕，過 CHAIN_TIMEOUT 停下
-- 動作離開佇列之後佇列又被取消（玩家取消後面的開關門等動作）、或玩家死了，就停下。
-- 單人是 perform 先、complete 後；多人的結果要等伺服器同步
D.CHAIN_TIMEOUT = 5000
D.CHAIN_NOCHANGE = 1500
D.CHAIN_SETTLE = 500 -- 結果出現後再等一下，讓同一次的其他同步（材料、背包）也到
function D.afterAction(playerObj, action, done, nextStep)
    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local perform = action.perform
    action.perform = function(self)
        self.anycarPerformed = true
        return perform(self)
    end
    local leftAt, cancels, doneAt, tick
    tick = function()
        local now = getTimestampMs()
        if not leftAt then
            for _, queued in ipairs(queue.queue) do
                if queued == action then return end
            end
            leftAt, cancels = now, queue.anycarCancels or 0 -- 動作自己結束時的取消不算
        end
        if (queue.anycarCancels or 0) ~= cancels or playerObj:isDead() then
            Events.OnTick.Remove(tick)
            return
        end
        if not doneAt then
            if done() or (action.anycarPerformed and now - leftAt >= D.CHAIN_NOCHANGE) then
                doneAt = now
            elseif now - leftAt >= D.CHAIN_TIMEOUT then
                Events.OnTick.Remove(tick)
            end
            return
        end
        if now - doneAt < D.CHAIN_SETTLE then return end
        Events.OnTick.Remove(tick)
        nextStep()
    end
    Events.OnTick.Add(tick)
end

-- 拆車前先卸零件：一次排一個卸得動的零件，卸完（零件真的離開車或卸失敗扣了狀況）再找下一個
-- （卸了輪胎之後煞車才卸得動），都卸完才拆車。tried：這一輪試過的零件 id；卸失敗的不重試
function D.onStrip(playerObj, vehicle, tried)
    if vehicle:isRemovedFromWorld() then return end
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        local item = part:getInventoryItem()
        if item and not tried[part:getId()] and part:getTable("uninstall")
            and vehicle:canUninstallPart(playerObj, part) then
            tried[part:getId()] = true
            local before = part:getCondition()
            ISVehiclePartMenu.onUninstallPart(playerObj, part)
            for _, action in ipairs(ISTimedActionQueue.getTimedActionQueue(playerObj).queue) do
                if action.Type == "ISUninstallVehiclePart" and action.part == part then
                    D.afterAction(playerObj, action, function()
                        return part:getInventoryItem() ~= item or part:getCondition() ~= before
                    end, function() D.onStrip(playerObj, vehicle, tried) end)
                    return
                end
            end
        end
    end
    D.onDismantle(playerObj, vehicle)
end

local vanillaFill = ISVehicleMenu.FillMenuOutsideVehicle
function ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)
    local result = vanillaFill(player, context, vehicle, test)
    if D.isWreck(vehicle) then return result end

    local playerObj = getSpecificPlayer(player)
    local name = getText("ContextMenu_MinidoracatAnyCar_Dismantle")
    local option = context:addOption(name, playerObj, D.onDismantle, vehicle)
    local toolTip = ISToolTip:new()
    toolTip:initialise()
    toolTip:setVisible(false)
    option.toolTip = toolTip
    toolTip:setName(name)
    local description = getText("Tooltip_MinidoracatAnyCar_Dismantle") .. " <LINE> <LINE> "

    local hasMask = playerObj:getInventory():containsEvalRecurse(predicateWeldingMask)
    description = description .. requirementLine(hasMask, getItemName("Base.WeldingMask") .. (hasMask and " 1/1" or " 0/1"))

    local blowTorch = playerObj:getInventory():getBestTypeEvalRecurse("Base.BlowTorch", comparatorDrainableUsesInt)
    local uses = blowTorch and blowTorch:getCurrentUses() or 0
    description = description .. requirementLine(uses >= 10,
        getItemName("Base.BlowTorch") .. " " .. getText("ContextMenu_Uses") .. " " .. uses .. "/10")

    local need = D.dismantleSkill(vehicle)
    local level = playerObj:getPerkLevel(Perks.MetalWelding)
    if need > 0 then
        description = description .. requirementLine(level >= need,
            PerkFactory.getPerk(Perks.MetalWelding):getName() .. " " .. level .. "/" .. need)
    end

    local why = D.blocked(playerObj, vehicle, nil)
    if why == "occupied" then
        description = description .. requirementLine(false, getText("Tooltip_MinidoracatAnyCar_Occupied"))
    elseif why == "animals" then
        description = description .. requirementLine(false, getText("Tooltip_MinidoracatAnyCar_Animals"))
    end

    toolTip.description = description
    local unavailable = not hasMask or uses < 10 or level < need or why == "occupied" or why == "animals"
    option.notAvailable = unavailable

    -- 先把卸得動的零件卸下來，再拆車
    local stripName = getText("ContextMenu_MinidoracatAnyCar_Strip")
    local strip = context:addOption(stripName, playerObj, D.onStrip, vehicle, {})
    local stripTip = ISToolTip:new()
    stripTip:initialise()
    stripTip:setVisible(false)
    stripTip:setName(stripName)
    stripTip.description = getText("Tooltip_MinidoracatAnyCar_Strip") .. " <LINE> <LINE> " .. description
    strip.toolTip = stripTip
    strip.notAvailable = unavailable
    return result
end
