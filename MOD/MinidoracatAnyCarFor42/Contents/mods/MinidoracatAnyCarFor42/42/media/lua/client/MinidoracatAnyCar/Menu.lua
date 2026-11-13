-- 完好車的右鍵選單「拆解車輛」。燒毀與撞毀的車原版已有選項（ISVehicleMenu.lua:618-648），不重複加。
require "Vehicles/ISUI/ISVehicleMenu"
require "MinidoracatAnyCar/Dismantle"

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

-- 拆車前先卸零件：一次排一個卸得動的零件，卸完再找下一個（卸了輪胎之後煞車才卸得動），都卸完才拆車。
-- tried：這一輪試過的零件 id；卸失敗的不重試
function D.onStrip(playerObj, vehicle, tried)
    if vehicle:isRemovedFromWorld() then return end
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part:getInventoryItem() and not tried[part:getId()] and part:getTable("uninstall")
            and vehicle:canUninstallPart(playerObj, part) then
            tried[part:getId()] = true
            ISVehiclePartMenu.onUninstallPart(playerObj, part)
            local queue = ISTimedActionQueue.getTimedActionQueue(playerObj).queue
            local last = queue[#queue]
            if last then
                local perform = last.perform
                last.perform = function(self)
                    perform(self)
                    D.onStrip(playerObj, vehicle, tried)
                end
                return
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
