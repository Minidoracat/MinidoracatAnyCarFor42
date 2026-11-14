-- 零件修理：沿用原版的修理動作（ISFixVehiclePartAction、ISFixAction），修法在 scripts/MinidoracatAnyCar_fixing.txt。
-- 翻新引擎與修理暖氣沿用原版修引擎的動作（ISRepairEngine），多帶一個表參數。
-- 放在 shared：多人時 complete 在伺服器執行，條件由伺服器重新檢查。
require "TimedActions/ISFixVehiclePartAction"
require "TimedActions/ISFixAction"
require "Vehicles/TimedActions/ISRepairEngine"
require "MinidoracatAnyCar/Dismantle"

local D = MinidoracatAnyCar

D.REPAIR_DIST = 12 -- 修理時玩家到車中心的格數上限；聯結車的車尾離中心約 8 格
D.FIX_TIME = 150 -- 本 MOD 修法的動作時間（tick），再乘沙盒 RepairTimeMult；原版修法維持 60
D.XP_BONUS = 4 -- 原版每項技能給 3–5 點（FixingManager.addXp）；RepairXPMult 多出來的部分照平均值補

-- 翻新引擎、修理沒有物品的零件的條件與效果。materials 是函式：數量可以來自沙盒
D.ENGINE = {
    rebuild = {
        tool = "WRENCH", toolItem = "Base.Wrench", mechanics = 5, time = 600, xp = 10,
        step = 10, -- 每次加幾點品質，最高 100
        materials = function() return { { "Base.EngineParts", D.sandbox("EngineRebuildParts", 10) } } end,
    },
    -- 沒有物品、不是容器的零件：加熱器
    heater = {
        tool = "SCREWDRIVER", toolItem = "Base.Screwdriver", mechanics = 3, time = 300, xp = 5,
        gain = 25, perLevel = 5, -- 每次修回 gain + perLevel × 機械等級
        materials = function() return { { "Base.ElectronicsScrap", 2 }, { "Base.ElectricWire", 1 } } end,
    },
    -- 沒有物品的容器：車輛 MOD 自己加的置物槽
    bin = {
        tool = "SCREWDRIVER", toolItem = "Base.Screwdriver", mechanics = 2, time = 300, xp = 5,
        gain = 25, perLevel = 5,
        materials = function() return { { "Base.SmallSheetMetal", 1 }, { "Base.Screws", 4 } } end,
    },
}

-- 這個零件用 D.ENGINE 的哪一組：引擎是翻新；沒有物品的零件照是不是容器分兩組；其他回 nil。
-- 警示燈原版有自己的修理，機械介面不列的零件（nodisplay）玩家點不到
function D.partJob(part)
    local id = part:getId()
    if id == "Engine" then return "rebuild" end
    local types = part:getItemType()
    if types and not types:isEmpty() or id == "lightbar" or part:getCategory() == "nodisplay" then return nil end
    return part:isContainer() and "bin" or "heater"
end

-- 選單與進度條上的名稱：翻新引擎用自己的字，其他用原版的「修理」
function D.jobName(job)
    return getText(job == "rebuild" and "ContextMenu_MinidoracatAnyCar_rebuild" or "ContextMenu_Repair")
end

local function notBroken(item)
    return not item:isBroken()
end

-- 某種物品的可用次數（消耗品算剩餘次數）。deep：含袋子；FixingManager.useFixer 只從主背包扣
local function uses(inventory, fullType, broken, deep)
    local total, items = 0, deep and inventory:getAllTypeRecurse(fullType) or inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= broken and item:getFullType() == fullType then
            total = total + (instanceof(item, "DrainableComboItem") and item:getCurrentUses() or 1)
        end
    end
    return total
end

-- 玩家身上（含袋子）某種物品的總次數；給選單算條件（原版 Fixing:countUses 湊夠需求量就停，不是總量）
function D.available(character, fullType, broken)
    return uses(character:getInventory(), fullType, broken, true)
end

-- 材料在主背包而且技能夠
function D.fixerReady(character, fixing, fixer, broken)
    local inventory = character:getInventory()
    if uses(inventory, fixer:getFixerName(), broken, false) < fixer:getNumberOfUse() then return false end
    local global = fixing:getGlobalItem()
    if global and uses(inventory, global:getFixerName(), broken, false) < global:getNumberOfUse() then return false end
    local skills = fixer:getFixerSkills()
    for i = 0, skills and skills:size() - 1 or -1 do
        local skill = skills:get(i)
        if character:getPerkLevel(Perks.FromString(skill:getSkillName())) < skill:getSkillLevel() then return false end
    end
    return true
end

-- 擋住這個零件的輪胎（煞車、懸吊要先卸輪胎，和原版卸下它們的條件相同）；沒有回 nil。
-- 只算車輪：KI5 的車頂架要先卸車頂備胎才卸得下，但備胎不擋修理
function D.coveredBy(part)
    local uninstall = part:getTable("uninstall")
    local id = uninstall and uninstall.requireUninstalled
    if not id or not string.find(id, "Tire", 1, true) then return nil end
    local cover = part:getVehicle():getPartById(id)
    return cover and cover:getInventoryItem() and cover:getWheelIndex() >= 0 and cover or nil
end

-- 本 MOD 的修法不能用在這個零件上的原因；可以修回 nil。四個參數都要傳
function D.repairBlocked(character, part, fixing, fixer)
    local vehicle = part and part:getVehicle()
    local item = part and part:getInventoryItem()
    if not vehicle or vehicle:isRemovedFromWorld() or not item then return "gone" end
    if not D.sandbox("Repair", true) then return "disabled" end
    if item:getCondition() >= item:getConditionMax() then return "full" end
    if D.coveredBy(part) then return "covered" end
    if D.far(character, vehicle, D.REPAIR_DIST) then return "far" end
    if not D.fixerReady(character, fixing, fixer, item) then return "materials" end
    return nil
end

local refuse = D.refuse

-- 修理成功後照沙盒 RepairXPMult 多給經驗
local function bonusXp(character, fixer)
    local extra = (D.sandbox("RepairXPMult", 1) - 1) * D.XP_BONUS
    local skills = fixer:getFixerSkills()
    if extra <= 0 or not skills then return end
    for i = 0, skills:size() - 1 do
        addXp(character, Perks.FromString(skills:get(i):getSkillName()), extra)
    end
end

-- ===== 裝在車上的零件 =====

-- 本 MOD 修法的時間（tick）：FIX_TIME 乘沙盒 RepairTimeMult；原版修法與瞬間完成照原版
local function fixTime(action, time)
    if time <= 1 or not D.fixName(action.fixing) then return time end
    return math.max(1, math.floor(D.FIX_TIME * D.sandbox("RepairTimeMult", 1)))
end

local vanillaPartDuration = ISFixVehiclePartAction.getDuration
function ISFixVehiclePartAction:getDuration()
    return fixTime(self, vanillaPartDuration(self))
end

-- 客戶端：條件不符時動作直接中止；伺服器在 complete 重新檢查。
-- 本 MOD 的修法不因材料、狀況已滿中止：多人時結果常比客戶端的動作先同步過來（材料扣掉、狀況變了），這時中止會連後面排的關引擎蓋一起清掉。
-- 原版 isValid 只看材料（ISFixVehiclePartAction.lua:5-7），用掉最後一份也會回 false，所以本 MOD 的修法不經過它
local vanillaPartIsValid = ISFixVehiclePartAction.isValid
function ISFixVehiclePartAction:isValid()
    if not D.fixName(self.fixing) then return vanillaPartIsValid(self) end
    local why = D.repairBlocked(self.character, self.vehiclePart, self.fixing, self.fixer)
    if why == "full" then -- full 排在 covered、far 前面，這兩條另外看
        return not D.coveredBy(self.vehiclePart) and not D.far(self.character, self.vehiclePart:getVehicle(), D.REPAIR_DIST)
    end
    return why == nil or why == "materials"
end

-- 用噴燈的修法（GlobalItem 是噴燈）：本 MOD、原版與別的 MOD 的都算
function D.usesTorch(fixing)
    local global = fixing:getGlobalItem()
    return global ~= nil and global:getFixerName() == "Base.BlowTorch"
end

-- 噴燈的修法而且主手拿著噴燈：焊接動畫、手上模型與聲音；本 MOD 其他修法用修車的動作；其餘照原版
local vanillaPartStart = ISFixVehiclePartAction.start
function ISFixVehiclePartAction:start()
    vanillaPartStart(self)
    local hand = self.character:getPrimaryHandItem()
    if D.usesTorch(self.fixing) and hand and hand:getFullType() == self.fixing:getGlobalItem():getFixerName() then
        self:setActionAnim("BlowTorch")
        self:setOverrideHandModels(hand, nil)
        self.sound = self.character:playSound("BlowTorch")
    elseif D.fixName(self.fixing) then
        self:setActionAnim("VehicleWorkOnMid")
    end
end

local function stopSound(action)
    if action.sound and action.sound ~= 0 then
        action.character:getEmitter():stopSound(action.sound)
        action.sound = nil
    end
end

local vanillaPartStop = ISFixVehiclePartAction.stop
function ISFixVehiclePartAction:stop()
    stopSound(self)
    vanillaPartStop(self)
end

local vanillaPartPerform = ISFixVehiclePartAction.perform
function ISFixVehiclePartAction:perform()
    stopSound(self)
    vanillaPartPerform(self)
end

local vanillaPartComplete = ISFixVehiclePartAction.complete
function ISFixVehiclePartAction:complete()
    local part, item = self.vehiclePart, self.item
    -- 動作進行中零件被換掉：不修舊的那件、也不把它的狀況寫到新的上
    if part:getInventoryItem() ~= item then return refuse("repair", "gone", self.character) end
    local ours = D.fixName(self.fixing) ~= nil
    if ours then
        local why = D.repairBlocked(self.character, part, self.fixing, self.fixer)
        if why then return refuse("repair", why, self.character) end
    end
    local before = item:getCondition()
    if part:isContainer() and not part:getItemContainer() then
        -- 輪胎、油箱：原版這一段讀了沒定義的變數（ISFixVehiclePartAction.lua:41），照它的步驟做完
        FixingManager.fixItem(item, self.character, self.fixing, self.fixer)
        part:setCondition(item:getCondition())
        part:doInventoryItemStats(item, part:getMechanicSkillInstaller())
        part:setContainerContentAmount(part:getContainerContentAmount())
        local vehicle = part:getVehicle()
        vehicle:updatePartStats()
        vehicle:updateBulletStats()
        vehicle:transmitPartItem(part)
    elseif not vanillaPartComplete(self) then
        return false
    end
    if not ours then return true end
    local after = item:getCondition()
    if after > before then bonusXp(self.character, self.fixer) end
    local vehicle = part:getVehicle()
    writeLog("MinidoracatAnyCar", string.format("REPAIR player=%s vehicle=%s id=%d part=%s item=%s fix=%s cond=%d>%d",
        D.who(self.character), tostring(vehicle:getScriptName()), vehicle:getSqlId(), tostring(part:getId()),
        item:getFullType(), self.fixing:getName(), before, after))
    return true
end

-- ===== 卸下來、放在背包裡的零件（原版的物品修理動作） =====

local vanillaItemDuration = ISFixAction.getDuration
function ISFixAction:getDuration()
    return fixTime(self, vanillaItemDuration(self))
end

local vanillaItemComplete = ISFixAction.complete
function ISFixAction:complete()
    if not D.fixName(self.fixing) then return vanillaItemComplete(self) end
    if not D.sandbox("Repair", true) then return refuse("repair", "disabled", self.character) end
    if not D.fixerReady(self.character, self.fixing, self.fixer, self.item) then
        return refuse("repair", "materials", self.character)
    end
    local before = self.item:getCondition()
    local ok = vanillaItemComplete(self)
    if ok and self.item:getCondition() > before then bonusXp(self.character, self.fixer) end
    return ok
end

-- ===== 翻新引擎、修理沒有物品的零件 =====

-- 回傳：不能做的原因（可以做是 nil）、條件清單（給選單顯示；伺服器照它扣材料）。三個參數都要傳
-- 清單每列 { item = 物品全名 | perk = 技能, have = 現有, need = 需要 }
function D.engineNeeds(character, part, job)
    local spec = D.ENGINE[job]
    local vehicle = part and part:getVehicle()
    if not spec or not vehicle or vehicle:isRemovedFromWorld() or D.partJob(part) ~= job then return "gone", {} end
    local inventory = character:getInventory()
    local rows, why = {}, nil
    local function row(entry)
        table.insert(rows, entry)
        if entry.have < entry.need and not why then why = entry.perk and "skill" or "materials" end
    end
    row({ item = spec.toolItem, have = inventory:getFirstTagEvalRecurse(ItemTag[spec.tool], notBroken) and 1 or 0, need = 1, keep = true })
    for _, material in ipairs(spec.materials()) do
        row({ item = material[1], have = inventory:getCountTypeRecurse(material[1]), need = material[2] })
    end
    row({ perk = Perks.Mechanics, have = character:getPerkLevel(Perks.Mechanics),
        need = math.max(spec.mechanics, vehicle:getScript():getEngineRepairLevel()) })
    if job == "rebuild" then
        if not D.sandbox("EngineRebuild", true) then return "disabled", rows end
        -- 先用原版把狀況修滿，才能翻新品質
        if part:getCondition() < 100 then return "condition", rows end
        if vehicle:getEngineQuality() >= 100 then return "full", rows end
    else
        if not D.sandbox("Repair", true) then return "disabled", rows end
        if part:getCondition() >= 100 then return "full", rows end
    end
    if D.far(character, vehicle, D.REPAIR_DIST) then return "far", rows end
    return why, rows
end

-- 引擎出力照原版生成引擎時的算法跟著品質走（Vehicles.lua 的 Vehicles.Create.Engine）
local function enginePower(vehicle, quality)
    return vehicle:getScript():getEngineForce() * math.max(0.6, math.min(100, quality * 1.6) / 100)
end

function D.engineWork(character, part, job)
    local why, rows = D.engineNeeds(character, part, job)
    if why then return refuse(job, why, character) end
    local spec, vehicle, inventory = D.ENGINE[job], part:getVehicle(), character:getInventory()
    for _, entry in ipairs(rows) do
        if entry.item and not entry.keep then D.takeItems(inventory, entry.item, entry.need) end
    end
    local before, after
    if job == "rebuild" then
        before = vehicle:getEngineQuality()
        after = math.min(100, before + spec.step)
        vehicle:setEngineFeature(after, vehicle:getEngineLoudness(), enginePower(vehicle, after))
        vehicle:transmitEngine()
    else
        before = part:getCondition()
        after = math.min(100, before + spec.gain + spec.perLevel * character:getPerkLevel(Perks.Mechanics))
        part:setCondition(after)
        vehicle:transmitPartCondition(part)
    end
    addXp(character, Perks.Mechanics, spec.xp)
    character:sendObjectChange(IsoObjectChange.MECHANIC_ACTION_DONE, { success = true })
    writeLog("MinidoracatAnyCar", string.format("%s player=%s vehicle=%s id=%d value=%d>%d%s", string.upper(job),
        D.who(character), tostring(vehicle:getScriptName()), vehicle:getSqlId(), before, after,
        job == "rebuild" and "" or " part=" .. tostring(part:getId())))
    return true
end

-- 參數名要和動作表的欄位同名（多人照參數名送值）。anycar 是 { job = "rebuild" | "heater" | "bin" }；
-- 原版與別的 MOD 只傳四個參數，這時不是表，照原版修引擎
local vanillaEngineNew = ISRepairEngine.new
function ISRepairEngine:new(character, part, item, maxTimeInit, anycar)
    local o = vanillaEngineNew(self, character, part, item, maxTimeInit)
    if type(anycar) == "table" and D.ENGINE[anycar.job] then
        o.anycar = anycar
        o.jobType = D.jobName(anycar.job)
        o.maxTime = o:getDuration()
    end
    return o
end

-- 本 MOD 的工作用規格裡的時間，不看傳進來的 maxTimeInit
local vanillaEngineDuration = ISRepairEngine.getDuration
function ISRepairEngine:getDuration()
    if not self.anycar then return vanillaEngineDuration(self) end
    if self.character:isTimedActionInstant() then return 1 end
    return D.ENGINE[self.anycar.job].time
end

-- 客戶端：本 MOD 的工作條件不符時直接中止。材料與「已滿」不在這裡擋：工作做完時伺服器扣材料、改狀況，
-- 這些同步可能比完成通知早到，做完的動作會被當成無效而中止，排在後面的關引擎蓋也一起被清掉；這兩項由伺服器在 complete 重新檢查
local vanillaEngineIsValid = ISRepairEngine.isValid
function ISRepairEngine:isValid()
    if not self.anycar then return vanillaEngineIsValid(self) end
    local why = D.engineNeeds(self.character, self.part, self.anycar.job)
    return why == nil or why == "materials" or why == "full"
end

local vanillaEngineStart = ISRepairEngine.start
function ISRepairEngine:start()
    vanillaEngineStart(self)
    if self.anycar then self.item:setJobType(self.jobType) end
end

local vanillaEngineComplete = ISRepairEngine.complete
function ISRepairEngine:complete()
    if not self.anycar then return vanillaEngineComplete(self) end
    return D.engineWork(self.character, self.part, self.anycar.job)
end
