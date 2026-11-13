-- 機械介面的零件右鍵選單：修理、修理全部零件、翻新引擎、修理暖氣。
-- 原版只對少數零件顯示「修理」（ISVehicleMechanics.lua:224），選項也只寫材料；這裡自己畫一份，寫修法名稱與缺的條件。
require "Vehicles/ISUI/ISVehicleMechanics"
require "ISUI/ISInventoryPaneContextMenu"
require "MinidoracatAnyCar/Repair"
require "MinidoracatAnyCar/Salvage"

local D = MinidoracatAnyCar

local MAX_LINES = 12 -- 「修理全部零件」說明框每一段最多列幾個零件

local function notBroken(item)
    return not item:isBroken()
end

local function predicateWeldingMask(item)
    return item:hasTag(ItemTag.WELDING_MASK) or item:getType() == "WeldingMask"
end

local function partName(part)
    return getTextOrNull("IGUI_VehiclePart" .. part:getId()) or part:getInventoryItem():getDisplayName()
end

local function newTooltip(option, name, description)
    local toolTip = ISToolTip:new()
    toolTip:initialise()
    toolTip:setVisible(false)
    toolTip:setName(name)
    toolTip.description = description
    option.toolTip = toolTip
end

-- 一列條件：夠的用好色，不夠的用壞色並加「不足」兩個字（不只靠顏色分辨）
local function needLine(name, have, need)
    if have >= need then return " <LINE> " .. ISVehicleMechanics.ghs .. " " .. name .. " " .. have .. "/" .. need end
    return " <LINE> " .. ISVehicleMechanics.bhs .. " " .. name .. " " .. have .. "/" .. need
        .. " " .. getText("Tooltip_MinidoracatAnyCar_Short")
end

-- 選項名稱：本 MOD 的修法寫修法名稱，同一個修法有幾種材料時加上材料；別人的修法照原版寫「數量 材料」
local function fixLabel(fixing, fixer)
    local material = getItemName(fixer:getFixerName())
    local _, method = D.fixName(fixing)
    if not method then return fixer:getNumberOfUse() .. " " .. material end
    local label = getText("ContextMenu_MinidoracatAnyCar_Fix_" .. method)
    if fixing:getFixers():size() > 1 then label = label .. " (" .. material .. ")" end
    return label
end

-- 這個修法的條件，每列 { name, have, need }。reserved：同一輪前面的零件要用掉的次數（物品全名 -> 次數），沒有就傳空表
local function requirements(playerObj, item, fixing, fixer, reserved)
    local rows = {}
    local function material(entry, broken)
        local name = entry:getFixerName()
        table.insert(rows, { name = getItemName(name), need = entry:getNumberOfUse(),
            have = math.max(0, fixing:countUses(playerObj, entry, broken) - (reserved[name] or 0)) })
    end
    if fixing:getGlobalItem() then material(fixing:getGlobalItem(), nil) end
    material(fixer, item)
    local skills = fixer:getFixerSkills()
    for i = 0, skills and skills:size() - 1 or -1 do
        local perk = Perks.FromString(skills:get(i):getSkillName())
        table.insert(rows, { name = PerkFactory.getPerk(perk):getName(), need = skills:get(i):getSkillLevel(),
            have = playerObj:getPerkLevel(perk) })
    end
    return rows
end

local function firstShort(rows)
    for _, row in ipairs(rows) do
        if row.have < row.need then return row end
    end
    return nil
end

-- 走到零件旁（和原版卸零件相同）；零件沒有區域時走到車旁
local function walkTo(playerObj, part)
    local uninstall = part:getTable("uninstall")
    local area = (uninstall and uninstall.area) or part:getArea()
    if area then
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, part:getVehicle(), area))
    else
        luautils.walkAdj(playerObj, part:getVehicle():getSquare())
    end
end

-- 排一次修理：搬材料、走到零件旁、焊接的修法拿噴燈並戴面罩、引擎室裡的零件先開引擎蓋。回傳修理動作，材料不夠回 nil
local function queueFix(playerObj, part, fixingNum, fixerNum)
    local item = part:getInventoryItem()
    local fixing = FixingManager.getFixes(item):get(fixingNum)
    local fixer = fixing:getFixers():get(fixerNum)
    local items = fixing:getRequiredItems(playerObj, fixer, item)
    if not items then return nil end
    if playerObj:getVehicle() then ISVehicleMenu.onExit(playerObj) end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, items)
    walkTo(playerObj, part)
    if D.usesTorch(fixing) then
        local torchType = fixing:getGlobalItem():getFixerName()
        for i = 0, items:size() - 1 do
            if items:get(i):getFullType() == torchType then
                ISWorldObjectContextMenu.equip(playerObj, playerObj:getPrimaryHandItem(), items:get(i), true)
                break
            end
        end
        local mask = playerObj:getInventory():getFirstEvalRecurse(predicateWeldingMask)
        if mask then ISInventoryPaneContextMenu.wearItem(mask, playerObj:getPlayerNum()) end
    end
    -- 引擎蓋的做法照 ISVehiclePartMenu.onUninstallPart（ISVehiclePartMenu.lua:216-231）
    local install = part:getTable("install")
    local cover = install and install.door and part:getVehicle():getPartById(install.door)
    if cover and not (cover:getDoor() and cover:getInventoryItem() and not cover:getDoor():isOpen()) then cover = nil end
    local action = ISFixVehiclePartAction:new(playerObj, part, fixingNum, fixerNum)
    if cover then ISTimedActionQueue.add(ISOpenVehicleDoor:new(playerObj, part:getVehicle(), cover)) end
    ISTimedActionQueue.add(action)
    if cover then ISTimedActionQueue.add(ISCloseVehicleDoor:new(playerObj, part:getVehicle(), cover)) end
    return action
end

function D.onRepair(playerObj, part, fixingNum, fixerNum)
    queueFix(playerObj, part, fixingNum, fixerNum)
end

local function addRepair(context, playerObj, part)
    local item = part:getInventoryItem()
    if not item or item:getCondition() >= item:getConditionMax() or not D.sandbox("Repair", true) then return end
    local fixes = FixingManager.getFixes(item)
    if fixes:isEmpty() then return end
    local name = getText("ContextMenu_Repair")
    if part:getScriptPart():isRepairMechanic() then context:removeOptionByName(name) end -- 原版那一份
    local option = context:addOptionOnTop(name, nil, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    local cover = D.coveredBy(part)
    for i = 0, fixes:size() - 1 do
        local fixing = fixes:get(i)
        for j = 0, fixing:getFixers():size() - 1 do
            local fixer = fixing:getFixers():get(j)
            local label = fixLabel(fixing, fixer)
            local rows = requirements(playerObj, item, fixing, fixer, {})
            local description = ""
            for _, row in ipairs(rows) do description = description .. needLine(row.name, row.have, row.need) end
            if cover then
                description = description .. " <LINE> " .. ISVehicleMechanics.bhs .. " "
                    .. getText("Tooltip_MinidoracatAnyCar_RemoveFirst", partName(cover))
            end
            description = description .. " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_potentialRepair") .. " "
                .. math.ceil(FixingManager.getCondRepaired(item, playerObj, fixing, fixer)) .. "% <LINE> "
                .. getText("Tooltip_chanceSuccess") .. " "
                .. math.ceil(100 - FixingManager.getChanceOfFail(item, playerObj, fixing, fixer)) .. "%"
            local fixOption = subMenu:addOption(label, playerObj, D.onRepair, part, i, j)
            newTooltip(fixOption, label, description)
            if cover or firstShort(rows) then fixOption.notAvailable = true end
        end
    end
end

-- 修理全部零件：每個零件挑現在材料與技能都夠、修最多的修法。
-- 回傳 todo（每列 { part, fixingNum, fixerNum, label }）與 skipped（每列 { part, reason }）。tried：這一輪修過的零件 id
function D.planRepairAll(playerObj, vehicle, tried)
    local todo, skipped, reserved = {}, {}, {}
    for index = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(index)
        local item = part:getInventoryItem()
        local fixes = item and item:getCondition() < item:getConditionMax() and FixingManager.getFixes(item)
        if fixes and not fixes:isEmpty() and not tried[part:getId()] then
            local cover = D.coveredBy(part)
            local best, short
            for i = 0, not cover and fixes:size() - 1 or -1 do
                local fixing = fixes:get(i)
                for j = 0, fixing:getFixers():size() - 1 do
                    local fixer = fixing:getFixers():get(j)
                    local lack = firstShort(requirements(playerObj, item, fixing, fixer, reserved))
                    local gain = FixingManager.getCondRepaired(item, playerObj, fixing, fixer)
                    if lack then
                        short = short or lack
                    elseif not best or gain > best.gain then
                        best = { part = part, fixingNum = i, fixerNum = j, gain = gain, fixing = fixing, fixer = fixer,
                            label = fixLabel(fixing, fixer) }
                    end
                end
            end
            if best then
                local global = best.fixing:getGlobalItem()
                if global then
                    reserved[global:getFixerName()] = (reserved[global:getFixerName()] or 0) + global:getNumberOfUse()
                end
                local name = best.fixer:getFixerName()
                reserved[name] = (reserved[name] or 0) + best.fixer:getNumberOfUse()
                table.insert(todo, best)
            elseif cover then
                table.insert(skipped, { part = part, reason = getText("Tooltip_MinidoracatAnyCar_RemoveFirst", partName(cover)) })
            elseif short then
                table.insert(skipped, { part = part, reason = short.name .. " " .. short.have .. "/" .. short.need })
            end
        end
    end
    return todo, skipped
end

-- 一次只排一個零件，修完再排下一個：前一個用掉材料之後，下一個才知道還剩什麼
function D.onRepairAll(playerObj, vehicle, tried)
    if vehicle:isRemovedFromWorld() then return end
    local entry = D.planRepairAll(playerObj, vehicle, tried)[1]
    if not entry then return end
    tried[entry.part:getId()] = true
    local action = queueFix(playerObj, entry.part, entry.fixingNum, entry.fixerNum)
    if not action then return D.onRepairAll(playerObj, vehicle, tried) end
    action.perform = function(self)
        ISFixVehiclePartAction.perform(self)
        D.onRepairAll(playerObj, vehicle, tried)
    end
end

local function addRepairAll(context, playerObj, vehicle)
    if not D.sandbox("Repair", true) then return end
    local todo, skipped = D.planRepairAll(playerObj, vehicle, {})
    if #todo == 0 and #skipped == 0 then return end
    local name = getText("ContextMenu_MinidoracatAnyCar_RepairAll")
    local option = context:addOption(name, playerObj, D.onRepairAll, vehicle, {})
    local description = ""
    for i = 1, math.min(#todo, MAX_LINES) do
        description = description .. " <LINE> " .. ISVehicleMechanics.ghs .. " " .. partName(todo[i].part) .. ": " .. todo[i].label
    end
    if #todo > MAX_LINES then description = description .. " <LINE> +" .. (#todo - MAX_LINES) end
    for i = 1, math.min(#skipped, MAX_LINES) do
        description = description .. " <LINE> " .. ISVehicleMechanics.bhs .. " "
            .. getText("Tooltip_MinidoracatAnyCar_Skipped", partName(skipped[i].part), skipped[i].reason)
    end
    if #skipped > MAX_LINES then description = description .. " <LINE> +" .. (#skipped - MAX_LINES) end
    newTooltip(option, name, description)
    if #todo == 0 then option.notAvailable = true end
end

-- 排翻新引擎或修理暖氣；走位與開引擎蓋照 ISVehicleMechanics.onRepairEngine（ISVehicleMechanics.lua:418-447）
function D.onEngineJob(playerObj, part, job)
    local spec, vehicle = D.ENGINE[job], part:getVehicle()
    local tool = playerObj:getInventory():getFirstTagEvalRecurse(ItemTag[spec.tool], notBroken)
    if not tool then return end
    if playerObj:getVehicle() then ISVehicleMenu.onExit(playerObj) end
    ISVehiclePartMenu.toPlayerInventory(playerObj, tool)
    walkTo(playerObj, part)
    local cover = vehicle:getPartById("EngineDoor")
    if cover and not (cover:getDoor() and cover:getInventoryItem() and not cover:getDoor():isOpen()) then cover = nil end
    if cover then
        if cover:getDoor():isLocked() and VehicleUtils.RequiredKeyNotFound(cover, playerObj) then
            ISTimedActionQueue.add(ISUnlockVehicleDoor:new(playerObj, cover))
        end
        ISTimedActionQueue.add(ISOpenVehicleDoor:new(playerObj, vehicle, cover))
    end
    ISTimedActionQueue.add(ISRepairEngine:new(playerObj, part, tool, spec.time, { job = job }))
    if cover then ISTimedActionQueue.add(ISCloseVehicleDoor:new(playerObj, vehicle, cover)) end
end

local function addEngineJob(context, playerObj, part, job)
    local why, rows = D.engineNeeds(playerObj, part, job)
    -- 關掉、已經滿了、引擎狀況還沒修滿（先用原版的修理引擎）時不列
    if why == "gone" or why == "disabled" or why == "full" or why == "condition" then return end
    local name = getText("ContextMenu_MinidoracatAnyCar_" .. job)
    local option = context:addOption(name, playerObj, D.onEngineJob, part, job)
    local description = ""
    for _, row in ipairs(rows) do
        local label = row.item and getItemName(row.item) or PerkFactory.getPerk(row.perk):getName()
        description = description .. needLine(label, row.have, row.need)
    end
    local spec, vehicle = D.ENGINE[job], part:getVehicle()
    if job == "rebuild" then
        local quality = vehicle:getEngineQuality()
        description = description .. " <LINE> <LINE> <RGB:1,1,1> "
            .. getText("Tooltip_MinidoracatAnyCar_rebuild", quality, math.min(100, quality + spec.step))
    else
        local condition = part:getCondition()
        description = description .. " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_MinidoracatAnyCar_heater", condition,
            math.min(100, condition + spec.gain + spec.perLevel * playerObj:getPerkLevel(Perks.Mechanics)))
    end
    newTooltip(option, name, description)
    if why then option.notAvailable = true end
end

local vanillaPartMenu = ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(part, x, y)
    self.context = nil -- 原版在遊戲暫停或人在車上時不開選單，這時留著 nil
    vanillaPartMenu(self, part, x, y)
    local context = self.context
    if not context then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    addRepair(context, playerObj, part)
    if part:getId() == "Engine" then addEngineJob(context, playerObj, part, "rebuild") end
    if part:getId() == "Heater" then addEngineJob(context, playerObj, part, "heater") end
    addRepairAll(context, playerObj, part:getVehicle())
    -- 原版沒有選項時把選單藏起來（ISVehicleMechanics.lua:408-415）；這裡加了選項就再打開
    if context.numOptions > 1 and not context:getIsVisible() then
        context:setVisible(true)
        if JoypadState.players[self.playerNum + 1] then
            context.mouseOver = 1
            context.origin = self
            JoypadState.players[self.playerNum + 1].focus = context
            updateJoypadFocus(JoypadState.players[self.playerNum + 1])
        end
    end
end

-- 沙盒關掉零件修理時，背包的修理選單不列本 MOD 的修法
local vanillaFixingMenu = ISInventoryPaneContextMenu.buildFixingMenu
ISInventoryPaneContextMenu.buildFixingMenu = function(brokenObject, player, fixing, fixingNum, fixOption, subMenuFix, vehiclePart)
    if D.fixName(fixing) and not D.sandbox("Repair", true) then return end
    return vanillaFixingMenu(brokenObject, player, fixing, fixingNum, fixOption, subMenuFix, vehiclePart)
end
