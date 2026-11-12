-- 完好車的右鍵選單「拆解車輛」。燒毀與撞毀的車原版已有選項（ISVehicleMenu.lua:618-648），不重複加。
require "Vehicles/ISUI/ISVehicleMenu"
require "MinidoracatDismantle/Action"

local D = MinidoracatDismantle

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

-- 照 ISVehicleMenu.onRemoveBurntVehicle（:883-892），多帶玩家看到的車內物品數：之後變多，動作就中止
local function start(playerObj, vehicle, items)
    if vehicle:isRemovedFromWorld() then return end
    if luautils.walkAdj(playerObj, vehicle:getSquare()) then
        ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), predicateBlowTorch, true)
        local mask = playerObj:getInventory():getFirstEvalRecurse(predicateWeldingMask)
        if mask then
            ISInventoryPaneContextMenu.wearItem(mask, playerObj:getPlayerNum())
        end
        ISTimedActionQueue.add(ISRemoveBurntVehicle:new(playerObj, vehicle, items))
    end
end

local function onConfirm(items, button, playerObj, vehicle)
    if button.internal == "YES" then start(playerObj, vehicle, items) end
end

function D.onDismantle(playerObj, vehicle)
    local _, items = D.count(vehicle)
    if items == 0 then
        start(playerObj, vehicle, 0)
        return
    end
    -- 寫法照 ISVehicleMechanics.onCheatRemove（ISVehicleMechanics.lua:607-618）
    local playerNum = playerObj:getPlayerNum()
    local modal = ISModalDialog:new(0, 0, 350, 150, getText("IGUI_MinidoracatDismantle_ConfirmItems", items),
        true, items, onConfirm, playerNum, playerObj, vehicle)
    modal:initialise()
    modal.moveWithMouse = true
    modal:addToUIManager()
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, modal)
    end
end

local vanillaFill = ISVehicleMenu.FillMenuOutsideVehicle
function ISVehicleMenu.FillMenuOutsideVehicle(player, context, vehicle, test)
    local result = vanillaFill(player, context, vehicle, test)
    if D.isWreck(vehicle) then return result end

    local playerObj = getSpecificPlayer(player)
    local name = getText("ContextMenu_MinidoracatDismantle_Dismantle")
    local option = context:addOption(name, playerObj, D.onDismantle, vehicle)
    local toolTip = ISToolTip:new()
    toolTip:initialise()
    toolTip:setVisible(false)
    option.toolTip = toolTip
    toolTip:setName(name)
    local description = getText("Tooltip_MinidoracatDismantle_Dismantle") .. " <LINE> <LINE> "

    local hasMask = playerObj:getInventory():containsEvalRecurse(predicateWeldingMask)
    description = description .. requirementLine(hasMask, getItemName("Base.WeldingMask") .. (hasMask and " 1/1" or " 0/1"))

    local blowTorch = playerObj:getInventory():getBestTypeEvalRecurse("Base.BlowTorch", comparatorDrainableUsesInt)
    local uses = blowTorch and blowTorch:getCurrentUses() or 0
    description = description .. requirementLine(uses >= 10,
        getItemName("Base.BlowTorch") .. " " .. getText("ContextMenu_Uses") .. " " .. uses .. "/10")

    local why = D.blocked(playerObj, vehicle)
    if why == "occupied" then
        description = description .. requirementLine(false, getText("Tooltip_MinidoracatDismantle_Occupied"))
    elseif why == "animals" then
        description = description .. requirementLine(false, getText("Tooltip_MinidoracatDismantle_Animals"))
    end

    toolTip.description = description
    if not hasMask or uses < 10 or why == "occupied" or why == "animals" then option.notAvailable = true end
    return result
end
