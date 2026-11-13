--[[
煙霧測試骨架：用假的 PZ 全域載入**真正的** MOD Lua，跑行為情境並斷言結果。

    lua scripts/smoke_harness.lua        （repo 根目錄執行；標準 Lua 5.2 以上：參數名斷言用 debug.getlocal(函式, n)）

為什麼需要（兩類 luac -p 抓不到的錯誤，皆為正式服實際事故）：
- 改函式簽章漏改呼叫點：語法完全合法，要等該路徑真的執行才炸
  （實例：hotspotKey 兩參數改三參數，刪除成功後的 log 聚合路徑必崩）
- 邏輯回歸：安全把關（範圍／阻隔／保護規則）被改壞時，「執行到並斷言」是唯一防線

限制（必須誠實面對）：這是標準 Lua，不是遊戲的 Kahlua。
- 標準 Lua 有 next/xpcall，Kahlua 沒有——本 harness **測不出**誤用，
  那由 scripts/verify_mod.py 的靜態掃描負責（發版前兩者都要跑）
- Kahlua 專屬行為（table.sort 遞迴深度、Java instance field 不暴露、rawget 呼叫形式、
  每個 table 都是 LinkedHashMap 的記憶體成本）只能靠反編譯查證與實機測試

寫情境的原則：
- 情境要「執行到會炸的路徑」——刪除後的收尾、跨 tick 的第二輪、聚合輸出，都是重災區
- 安全邊界要有**反面**斷言（範圍外／被阻隔／受保護的對象必須存活），不是只測 happy path
- 新防線寫完先「植入違規證明它會抓」再信任它——測不出來的測試等於沒有測試
]]

-- 家族佈局固定，直接填死最省事；scaffold 時由模板替換佔位符
local MEDIA = "MOD/MinidoracatAnyCarFor42/Contents/mods/MinidoracatAnyCarFor42/42/media/lua"

-- ===== 假的 PZ 全域（依 MOD 實際用到的 API 增補）=====
-- 起始時間要夠大：週期類邏輯常寫成 now - lastAt >= interval 而 lastAt 初值 0，
-- 從 0 起跳會讓第一輪永遠不觸發（遊戲的 getTimestampMs 本來就是大數）
local nowMs = 5000000
local logLines = {}

function getTimestampMs() return nowMs end
function isClient() return false end
function isServer() return true end
function writeLog(_, text) logLines[#logLines + 1] = text end
function getText(key) return key end

local tickHandlers, clientCommandHandlers = {}, {}
Events = setmetatable({}, {
    __index = function(_, name)
        return {
            Add = function(fn)
                if name == "OnTick" then tickHandlers[#tickHandlers + 1] = fn
                elseif name == "OnClientCommand" then clientCommandHandlers[#clientCommandHandlers + 1] = fn end
            end,
            Remove = function(fn)
                for i = #tickHandlers, 1, -1 do if tickHandlers[i] == fn then table.remove(tickHandlers, i) end end
            end,
        }
    end,
})

-- java 風格清單（size()/get(i)，0-based）——PZ 回傳的容器幾乎都是這個形狀
local function javaList(items)
    return {
        size = function() return #items end,
        get = function(_, i) return items[i + 1] end,
        _raw = items,
    }
end

-- ===== 載入受測程式碼 =====
local loaded = {}
function require(name)
    if loaded[name] then return true end
    loaded[name] = true
    for _, dir in ipairs({ "shared", "server", "client" }) do
        local chunk = loadfile(MEDIA .. "/" .. dir .. "/" .. name .. ".lua")
        if chunk then chunk() return true end
    end
    error("require 找不到: " .. name)
end

-- 假的原版動作：只保留本 MOD 會包到的行為（ISRemoveBurntVehicle.lua:60-203）
local rolls, randFloat = 0, 0.99
function ZombRandFloat() return randFloat end
SandboxVars = { MinidoracatAnyCar = { LootMult = 1.0 } }
ISRemoveBurntVehicle = {}
ISRemoveBurntVehicle.__index = ISRemoveBurntVehicle
function ISRemoveBurntVehicle:new(character, vehicle)
    local o = setmetatable({ character = character }, self)
    local name = vehicle and vehicle:getScript():getName() or ""
    if name:match("Burnt") or name:match("Smashed") then o.vehicle = vehicle end
    o.maxTime = o:getDuration()
    return o
end
function ISRemoveBurntVehicle:getDuration() return self.vehicle and 800 or 0 end
function ISRemoveBurntVehicle:isValid() return self.vehicle ~= nil and not self.vehicle:isRemovedFromWorld() end
function ISRemoveBurntVehicle:checkAddItem() rolls = rolls + 1; return true end
function ISRemoveBurntVehicle:complete()
    if not self.vehicle then return false end
    self:checkAddItem("ScrapMetal", 12)
    self.vehicle.removed = true
    return true
end
loaded["Vehicles/TimedActions/ISRemoveBurntVehicle"] = true

require "MinidoracatAnyCar/Dismantle"

local function fakeVehicle(script, opts)
    opts = opts or {}
    local v = { removed = false, x = 100.5, y = 200.5, z = 0, passengers = opts.passengers or 0, animals = opts.animals or {} }
    function v:getScript() return { getName = function() return script end } end
    function v:getScriptName() return "Base." .. script end
    function v:isRemovedFromWorld() return self.removed end
    function v:getX() return self.x end
    function v:getY() return self.y end
    function v:getZ() return self.z end
    function v:getSqlId() return 48213 end
    function v:hasPassenger() return self.passengers > 0 end
    function v:getAnimals() return javaList(self.animals) end
    local parts = {
        { getInventoryItem = function() return {} end, getItemContainer = function() return { getItems = function() return javaList({ 1, 2, 3 }) end } end },
        { getInventoryItem = function() return nil end, getItemContainer = function() return nil end },
    }
    function v:getPartCount() return #parts end
    function v:getPartByIndex(i) return parts[i + 1] end
    return v
end

local function fakePlayer(x, y, z, name)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z or 0 end,
        getUsername = function() return name or "tester" end }
end

-- ===== 測試工具 =====
local failures = 0
local function check(ok, label)
    if ok then print("  PASS  " .. label)
    else failures = failures + 1; print("  FAIL  " .. label) end
end

local function runTicks(count)
    for _ = 1, count do
        local handlers = {}
        for i, fn in ipairs(tickHandlers) do handlers[i] = fn end
        for _, fn in ipairs(handlers) do fn() end
    end
end

-- ===== 情境 =====
local near = fakePlayer(101.5, 201.5)

print("情境一：完好車也能建立動作，殘骸照原版")
local intact = fakeVehicle("CarNormal")
local action = ISRemoveBurntVehicle:new(near, intact)
check(action.vehicle == intact and action.maxTime == 800, "完好車：vehicle 補上、maxTime 重算")
check(ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormalBurnt")).maxTime == 800, "燒毀車：照原版")
check(ISRemoveBurntVehicle:new(near, nil).vehicle == nil, "沒有車：不補")

print("情境二：伺服器通過檢查，拆掉並記一行")
rolls = 0
check(action:complete() == true and intact.removed, "完好車移除")
check(#logLines == 1 and logLines[1] == "SCRAP player=tester vehicle=Base.CarNormal id=48213 at=100,200,0 parts=1 items=3",
    "log 一行：" .. tostring(logLines[1]))
check(action:complete() == false and #logLines == 1, "同一台再拆：已移除，不產出不記錄")

local spoof = ISRemoveBurntVehicle:new(fakePlayer(101.5, 201.5, 0, "a player=admin\nid=1"), fakeVehicle("CarNormal"), nil)
spoof:complete()
check(logLines[#logLines]:match("^SCRAP player=a_player_admin_id_1 vehicle=") ~= nil, "帳號名稱的空白、等號、換行不會變成假欄位")
table.remove(logLines)

print("情境三：檢查不過就不產出、不刪車、不記錄")
local function refused(label, player, vehicle, confirmed)
    rolls = 0
    local n = #logLines
    local a = ISRemoveBurntVehicle:new(player, vehicle, confirmed)
    check(a:complete() == false and not vehicle.removed and rolls == 0 and #logLines == n, label)
end
refused("距離太遠", fakePlayer(108, 200.5), fakeVehicle("CarNormal"))
refused("不同樓層", fakePlayer(101.5, 201.5, 1), fakeVehicle("CarNormal"))
refused("車上有人", near, fakeVehicle("CarNormal", { passengers = 1 }))
refused("拖車上有動物", near, fakeVehicle("TrailerAnimal", { animals = { {} } }))
refused("燒毀車也檢查距離", fakePlayer(108, 200.5), fakeVehicle("CarNormalBurnt"))
check(ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal", { passengers = 1 })):isValid() == false, "客戶端 isValid 同步中止")
check(MinidoracatAnyCar.blocked(fakePlayer(120, 200), fakeVehicle("CarNormal", { passengers = 1 }), nil) == "occupied", "從遠處看：先回車上有人，選單才顯示得出原因")
check(debug.getlocal(ISRemoveBurntVehicle.new, 2) == "character" and debug.getlocal(ISRemoveBurntVehicle.new, 3) == "vehicle" and debug.getlocal(ISRemoveBurntVehicle.new, 4) == "confirmed", "new 的參數名和動作欄位同名（多人靠它送參數）")

print("情境三之二：確認後車內物品變多就不拆")
local function withItems(n) return ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal"), n and { dismantleItems = n }) end
check(withItems(2):isValid() == false and withItems(2):complete() == false, "確認時 2 件、現在 3 件：中止且伺服器拒絕")
refused("確認時 0 件、現在 3 件（走 refused 斷言：不產出不刪車不記錄）", near, fakeVehicle("CarNormal"), { dismantleItems = 0 })
check(ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal"), 0):complete() == true, "第三個參數不是確認表（別人少傳留下的值）：當成沒有確認")
check(withItems(3):complete() == true and withItems(5):complete() == true, "確認的數量沒變或變少：照拆")
check(withItems(nil):complete() == true, "沒經過確認流程的動作（原版入口、其他 MOD）：不檢查數量")

print("情境四：LootMult 決定擲骰次數")
local function rollsAt(mult, rand)
    SandboxVars.MinidoracatAnyCar.LootMult = mult
    randFloat = rand
    rolls = 0
    local got = ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal")):checkAddItem("ScrapMetal", 12)
    return rolls, got
end
check(rollsAt(1.0, 0) == 1, "1.0：一次（原版）")
check(rollsAt(3.0, 0) == 3, "3.0：三次")
local n0, got0 = rollsAt(0.0, 0)
check(n0 == 0 and got0 == false, "0.0：不擲、不加額外經驗")
check(rollsAt(1.5, 0.4) == 2 and rollsAt(1.5, 0.6) == 1, "1.5：一半機率多擲一次")
SandboxVars.MinidoracatAnyCar = nil
rolls = 0
check(ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal")):checkAddItem("x", 1) == true and rolls == 1, "沒有沙盒值：當成 1.0")

-- ===== 修理、零件拆解、引擎：假的原版類別與 Java 物件 =====
SandboxVars.MinidoracatAnyCar = {}
local SB = SandboxVars.MinidoracatAnyCar
Perks = { Mechanics = "Mechanics", MetalWelding = "MetalWelding", FromString = function(name) return name end }
ItemTag = { WRENCH = "wrench", SCREWDRIVER = "screwdriver" }
IsoObjectChange = { MECHANIC_ACTION_DONE = "done" }
function instanceof(object, class) return type(object) == "table" and object.class == class end
local xpGiven = {}
function addXp(_, perk, amount) xpGiven[#xpGiven + 1] = perk .. "=" .. amount end
function sendRemoveItemFromContainer() end

local function fakeItem(full, opts)
    opts = opts or {}
    local item = { full = full, uses = opts.uses, cond = opts.cond or 100, max = 100, tag = opts.tag,
        class = opts.uses and "DrainableComboItem" or "InventoryItem" }
    function item:getFullType() return self.full end
    function item:getCurrentUses() return self.uses end
    function item:getCondition() return self.cond end
    function item:getConditionMax() return self.max end
    function item:isBroken() return false end
    function item:getContainer() return self.container end
    return item
end

-- main：主背包的物品；bag：背包裡的袋子裡的物品（Recurse 類的查得到，主背包清單沒有）
local function fakeInventory(main, bag)
    local inv = { main = main, bag = bag or {} }
    for _, item in ipairs(main) do item.container = inv end
    for _, item in ipairs(inv.bag) do item.container = inv end
    local function all()
        local list = {}
        for _, item in ipairs(inv.main) do list[#list + 1] = item end
        for _, item in ipairs(inv.bag) do list[#list + 1] = item end
        return list
    end
    function inv:getItems() return javaList(self.main) end
    function inv:getCountTypeRecurse(full)
        local n = 0
        for _, item in ipairs(all()) do if item.full == full then n = n + 1 end end
        return n
    end
    function inv:getSomeTypeRecurse(full, count)
        local list = {}
        for _, item in ipairs(all()) do if item.full == full and #list < count then list[#list + 1] = item end end
        return javaList(list)
    end
    function inv:getFirstTagEvalRecurse(tag, fn)
        for _, item in ipairs(all()) do if item.tag == tag and fn(item) then return item end end
        return nil
    end
    function inv:DoRemoveItem(item)
        for _, list in ipairs({ self.main, self.bag }) do
            for i = #list, 1, -1 do if list[i] == item then table.remove(list, i) end end
        end
    end
    return inv
end

local function mechanic(perks, main, bag, x)
    local inv = fakeInventory(main or {}, bag)
    local p = fakePlayer(x or 101.5, 201.5)
    function p:getPerkLevel(perk) return perks[perk] or 0 end
    function p:getInventory() return inv end
    function p:sendObjectChange() end
    function p:isTimedActionInstant() return false end
    return p, inv
end

local function fakeFixer(full, uses, skills)
    local list = {}
    for name, level in pairs(skills or {}) do
        list[#list + 1] = { getSkillName = function() return name end, getSkillLevel = function() return level end }
    end
    return { getFixerName = function() return full end, getNumberOfUse = function() return uses end,
        getFixerSkills = function() return skills and javaList(list) or nil end }
end

local function fakeFixing(name, fixers, global)
    local required = {}
    local f = {}
    function f:getName() return name end
    function f:getFixers() return javaList(fixers) end
    function f:getGlobalItem() return global end
    function f:getRequiredItem()
        local list = javaList(required)
        function list:contains(full) for _, v in ipairs(required) do if v == full then return true end end return false end
        return list
    end
    function f:addRequiredItem(full) required[#required + 1] = full end
    return f
end

-- 假的 FixingManager：修一次加 10 點，記下被呼叫幾次
local fixCalls = 0
FixingManager = { fixItem = function(item) fixCalls = fixCalls + 1; item.cond = item.cond + 10 end }

local vanillaPartCompletes, vanillaItemCompletes, vanillaEngineCompletes = 0, 0, 0
local function fakeAction(completeFn)
    local class = {}
    class.__index = class
    function class:getDuration() return 60 end
    function class:isValid() return true end
    function class:start() end
    function class:stop() end
    function class:perform() end
    class.complete = completeFn
    return class
end
ISFixVehiclePartAction = fakeAction(function(self)
    vanillaPartCompletes = vanillaPartCompletes + 1
    FixingManager.fixItem(self.item)
    return true
end)
function ISFixVehiclePartAction:new(character, vehiclePart, fixing, fixer)
    local o = setmetatable({ character = character, vehiclePart = vehiclePart, fixing = fixing, fixer = fixer }, self)
    o.item = vehiclePart:getInventoryItem()
    return o
end
ISFixAction = fakeAction(function(self)
    vanillaItemCompletes = vanillaItemCompletes + 1
    FixingManager.fixItem(self.item)
    return true
end)
ISRepairEngine = fakeAction(function() vanillaEngineCompletes = vanillaEngineCompletes + 1; return true end)
function ISRepairEngine:new(character, part, item, maxTimeInit)
    return setmetatable({ character = character, part = part, item = item, maxTime = maxTimeInit }, self)
end
loaded["TimedActions/ISFixVehiclePartAction"] = true
loaded["TimedActions/ISFixAction"] = true
loaded["Vehicles/TimedActions/ISRepairEngine"] = true
Actions = { addOrDropItem = function(_, item) rolls = rolls + 1 end }
function instanceItem(full) return fakeItem(full) end
function ZombRand() return 0 end

require "MinidoracatAnyCar/Repair"
require "MinidoracatAnyCar/Salvage"
local D = MinidoracatAnyCar

-- 一台有車門、右前輪胎、右前煞車、引擎、暖氣的車
local function garage(opts)
    opts = opts or {}
    local v = fakeVehicle("CarNormal")
    local parts = {}
    local function part(id, item, tables, container)
        local p = { cond = opts.cond or 100 }
        function p:getId() return id end
        function p:getVehicle() return v end
        function p:getInventoryItem() return item end
        function p:getTable(name) return tables and tables[name] end
        function p:isContainer() return container == true end
        function p:getItemContainer() return nil end
        function p:getCondition() return self.cond end
        function p:setCondition(c) self.cond = c end
        function p:doInventoryItemStats() end
        function p:getMechanicSkillInstaller() return 0 end
        function p:getContainerContentAmount() return 30 end
        function p:setContainerContentAmount() end
        parts[id] = p
        return p
    end
    part("DoorFrontLeft", fakeItem("Base.ModDoor2", { cond = 40 }))
    part("TireFrontRight", opts.noTire == nil and fakeItem("Base.ModTire2", { cond = 50 }) or nil, nil, true)
    part("BrakeFrontRight", fakeItem("Base.ModBrake2", { cond = 30 }), { uninstall = { requireUninstalled = "TireFrontRight" } })
    part("Engine", nil)
    part("Heater", nil)
    function v:getPartById(id) return parts[id] end
    function v:getScript()
        return { getName = function() return "CarNormal" end, getEngineRepairLevel = function() return 4 end,
            getEngineForce = function() return 4000 end }
    end
    v.quality, v.power = opts.quality or 62, 0
    function v:getEngineQuality() return self.quality end
    function v:getEngineLoudness() return 100 end
    function v:setEngineFeature(q, _, power) self.quality, self.power = q, power end
    function v:transmitEngine() end
    function v:transmitPartCondition() end
    function v:transmitPartItem() end
    function v:updatePartStats() end
    function v:updateBulletStats() end
    return v, parts
end

print("情境五：零件照物品名稱分類")
local function class(name, expect) check(D.classify(name) == expect, name .. " -> " .. expect) end
class("93fordF350FrontDoor2", "Door")
class("85gmBbodyFrontWindowArmorW", "Armor")
class("3rdGenChevyCKseriesFrontSideWindow2", "Window")
class("93chevySuburbanEngineDoor2", "Hood")
class("86chevyK5Tailgate2", "TrunkLid")
class("VanSeatsTrunk2", "Trunk")
class("GloveBox2", "GloveBox")
class("leafSuspension2", "Suspension")
class("W460SnorkelM", "Accessory")
class("93chevySuburbanBumperRear0", "Armor")

print("情境六：載入時把零件填進修法與拆解配方")
local doorWeld = fakeFixing("AnyCar_Door_Welding", { fakeFixer("Base.SheetMetal", 1, { MetalWelding = 2, Mechanics = 2 }) },
    fakeFixer("Base.BlowTorch", 2))
local tirePatch = fakeFixing("AnyCar_Tire_Patch", { fakeFixer("Base.TirePiece", 1, { Mechanics = 2 }) }, fakeFixer("Base.Glue", 1))
local vanillaDoor = fakeFixing("Fix Door Welding", { fakeFixer("Base.SheetMetal", 1, { MetalWelding = 3 }) }, fakeFixer("Base.BlowTorch", 2))
vanillaDoor:addRequiredItem("Base.FrontCarDoor1")
doorWeld:addRequiredItem("") -- 腳本裡 Require 留空時引擎放進去的空字串
local recipeLoads, recipeInputs = {}, 2
local function scriptItem(module, name, mechanic, vehicleType)
    return { getFullName = function() return module .. "." .. name end, getName = function() return name end,
        isMechanicsLoot = function() return mechanic end, getConditionMax = function() return 100 end, vehicleType = vehicleType }
end
local scriptItems = {
    scriptItem("Base", "FrontCarDoor1", true, 1), scriptItem("Base", "ModDoor2", true, 2), scriptItem("Base", "ModTire2", true, 2),
    scriptItem("Base", "Jack", true, 0), scriptItem("Base", "Apple", false, 0),
}
function instanceItem(full)
    local item = fakeItem(full)
    for _, s in ipairs(scriptItems) do if s.getFullName() == full then item.vehicleType = s.vehicleType end end
    function item:getMechanicType() return self.vehicleType or 0 end
    return item
end
ArrayList = { new = function() return {} end }
function getScriptManager()
    return {
        getAllFixing = function() return javaList({ doorWeld, tirePatch, vanillaDoor }) end,
        getAllItems = function() return javaList(scriptItems) end,
        getCraftRecipe = function(_, name)
            return { getName = function() return name end, getInputs = function() return { size = function() return recipeInputs end } end,
                Load = function(_, _, body) recipeLoads[#recipeLoads + 1] = body; recipeInputs = recipeInputs + 1 end }
        end,
    }
end
D.registerParts()
check(doorWeld:getRequiredItem():contains("Base.ModDoor2"), "MOD 車門填進本 MOD 的車門修法")
check(not doorWeld:getRequiredItem():contains("Base.FrontCarDoor1"), "原版已有修法的車門不再加一套")
check(tirePatch:getRequiredItem():contains("Base.ModTire2") and not tirePatch:getRequiredItem():contains("Base.ModDoor2"), "輪胎只進輪胎的修法")
check(#D.partsByClass.Door == 2 and D.partsByClass.Accessory == nil, "拆解清單含原版車門；千斤頂、蘋果不是車輛零件")
check(#recipeLoads == 1 and recipeLoads[1]:find("Base.FrontCarDoor1;Base.ModDoor2", 1, true) ~= nil, "車門拆解配方加上零件那一列")
D.registerParts()
check(#recipeLoads == 1 and doorWeld:getRequiredItem():size() == 2, "再跑一次不會重複加")
check(D.salvageTest.Door() == true and D.salvageTest.Armor() == false, "沒有零件的類別，拆解配方關著")
SB.Salvage = false
check(D.salvageTest.Door() == false and MinidoracatAnyCar_salvageInMenu({ recipe = { getName = function() return "AnyCarSalvageDoor" end } }) == false,
    "沙盒關掉零件拆解：不能做、不列在清單")
SB.Salvage = nil

print("情境七：伺服器修理裝在車上的零件")
local function torch() return fakeItem("Base.BlowTorch", { uses = 10 }) end
check(D.usesTorch(doorWeld) and D.usesTorch(vanillaDoor) and not D.usesTorch(tirePatch), "噴燈修法：本 MOD 與原版的焊接都算，補胎不算")
local function repair(player, part, fixing)
    local n, calls = #logLines, fixCalls
    local action = ISFixVehiclePartAction:new(player, part, fixing, fixing:getFixers():get(0))
    local ok = action:complete()
    return ok, fixCalls - calls, #logLines - n
end
local car, carParts = garage()
local welder = mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() })
local ok, fixed, logged = repair(welder, carParts.DoorFrontLeft, doorWeld)
check(ok == true and fixed == 1 and logged == 1, "材料與技能都夠：修好並記一行")
check(logLines[#logLines] == "REPAIR player=tester vehicle=Base.CarNormal id=48213 part=DoorFrontLeft item=Base.ModDoor2 fix=AnyCar_Door_Welding cond=40>50",
    "log 一行：" .. tostring(logLines[#logLines]))
local function refusedRepair(label, player, part, fixing)
    local r, f, l = repair(player, part, fixing)
    check(r == false and f == 0 and l == 0, label)
end
refusedRepair("材料放在袋子裡、不在主背包", mechanic({ MetalWelding = 2, Mechanics = 2 }, { torch() }, { fakeItem("Base.SheetMetal") }),
    carParts.DoorFrontLeft, doorWeld)
refusedRepair("噴燈剩 1 單位", mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), fakeItem("Base.BlowTorch", { uses = 1 }) }),
    carParts.DoorFrontLeft, doorWeld)
refusedRepair("金工不夠", mechanic({ MetalWelding = 1, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }), carParts.DoorFrontLeft, doorWeld)
refusedRepair("離車太遠", mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }, nil, 120), carParts.DoorFrontLeft, doorWeld)
SB.Repair = false
refusedRepair("沙盒關掉零件修理", welder, carParts.DoorFrontLeft, doorWeld)
local before = vanillaPartCompletes
check(repair(welder, carParts.DoorFrontLeft, vanillaDoor) == true and vanillaPartCompletes == before + 1, "關掉時原版的修法照常（不檢查、不記錄）")
SB.Repair = nil
carParts.DoorFrontLeft:getInventoryItem().cond = 100
refusedRepair("零件已經是滿的", mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }), carParts.DoorFrontLeft, doorWeld)

local brakeFix = fakeFixing("AnyCar_Brake_Bolts", { fakeFixer("Base.SmallSheetMetal", 1, { Mechanics = 3 }) }, fakeFixer("Base.NutsBolts", 2))
local function brakeGuy() return mechanic({ Mechanics = 3 }, { fakeItem("Base.SmallSheetMetal"), fakeItem("Base.NutsBolts"), fakeItem("Base.NutsBolts") }) end
refusedRepair("煞車被輪胎擋住", brakeGuy(), carParts.BrakeFrontRight, brakeFix)
local _, bareParts = garage({ noTire = true })
check(repair(brakeGuy(), bareParts.BrakeFrontRight, brakeFix) == true, "卸下輪胎後可以修煞車")

before = vanillaPartCompletes
local tireGuy = mechanic({ Mechanics = 2 }, { fakeItem("Base.TirePiece"), fakeItem("Base.Glue", { uses = 5 }) })
ok, fixed, logged = repair(tireGuy, carParts.TireFrontRight, tirePatch)
check(ok == true and fixed == 1 and logged == 1 and vanillaPartCompletes == before and carParts.TireFrontRight.cond == 60,
    "輪胎：不經原版那一段也修好、零件狀況跟著物品")

xpGiven = {}
SB.RepairXPMult = 2.0
carParts.DoorFrontLeft:getInventoryItem().cond = 40
repair(mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }), carParts.DoorFrontLeft, doorWeld)
table.sort(xpGiven)
check(#xpGiven == 2 and tonumber(xpGiven[1]:match("^Mechanics=(.+)$")) == 4 and tonumber(xpGiven[2]:match("^MetalWelding=(.+)$")) == 4,
    "經驗倍率 2.0：每項技能多給 4 點（" .. table.concat(xpGiven, ",") .. "）")
SB.RepairXPMult = nil

local slow = ISFixVehiclePartAction:new(welder, carParts.DoorFrontLeft, doorWeld, doorWeld:getFixers():get(0))
SB.RepairTimeMult = 2.0
check(slow:getDuration() == 300 and ISFixVehiclePartAction:new(welder, carParts.DoorFrontLeft, vanillaDoor, vanillaDoor:getFixers():get(0)):getDuration() == 60,
    "時間倍率只算本 MOD 的修法；原版修法維持 60")
check(setmetatable({ fixing = doorWeld }, ISFixAction):getDuration() == 300 and setmetatable({ fixing = vanillaDoor }, ISFixAction):getDuration() == 60,
    "背包裡修（ISFixAction）也照時間倍率；原版修法維持 60")
SB.RepairTimeMult = nil

local swapCar, swapParts = garage()
local swap = ISFixVehiclePartAction:new(welder, swapParts.DoorFrontLeft, doorWeld, doorWeld:getFixers():get(0))
local newDoor = fakeItem("Base.ModDoor2", { cond = 20 })
swapParts.DoorFrontLeft.getInventoryItem = function() return newDoor end
local calls0, logs0 = fixCalls, #logLines
check(swap:complete() == false and fixCalls == calls0 and #logLines == logs0 and newDoor.cond == 20 and swap.item.cond == 40,
    "動作進行中零件被換掉：拒絕，新舊零件都不動")

print("情境七之二：背包裡卸下的零件")
local loose = fakeItem("Base.ModDoor2", { cond = 40 })
local function looseFix(player, fixing)
    local action = setmetatable({ character = player, item = loose, fixing = fixing, fixer = fixing:getFixers():get(0) }, ISFixAction)
    return action:complete()
end
check(looseFix(mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }), doorWeld) == true and loose.cond == 50, "材料夠：修好")
check(looseFix(mechanic({ MetalWelding = 2, Mechanics = 2 }, { torch() }), doorWeld) == false and loose.cond == 50, "沒有鐵片：拒絕")
check(looseFix(mechanic({}, {}), vanillaDoor) == true, "原版的修法不檢查")

print("情境八：翻新引擎與修理暖氣")
local function engineParts(n)
    local list = { fakeItem("Base.Wrench", { tag = "wrench" }), fakeItem("Base.Screwdriver", { tag = "screwdriver" }) }
    for _ = 1, n do list[#list + 1] = fakeItem("Base.EngineParts") end
    return list
end
local function engineJob(player, part, job)
    return ISRepairEngine:new(player, part, nil, 600, { job = job }):complete()
end
local car2, parts2 = garage()
local ace, aceInv = mechanic({ Mechanics = 6 }, engineParts(12))
check(engineJob(ace, parts2.Engine, "rebuild") == true and car2.quality == 72 and aceInv:getCountTypeRecurse("Base.EngineParts") == 2
    and car2.power == 4000, "翻新：用 10 個引擎零件、品質 62 -> 72、出力照品質重算")
check(logLines[#logLines] == "REBUILD player=tester vehicle=Base.CarNormal id=48213 value=62>72", "log：" .. tostring(logLines[#logLines]))
check(engineJob(ace, parts2.Engine, "rebuild") == false and car2.quality == 72, "只剩 2 個引擎零件：拒絕")
check(engineJob(mechanic({ Mechanics = 4 }, engineParts(12)), parts2.Engine, "rebuild") == false, "機械 4 級不夠")
parts2.Engine.cond = 80
check(engineJob(mechanic({ Mechanics = 6 }, engineParts(12)), parts2.Engine, "rebuild") == false, "引擎狀況沒滿：先用原版修理")
parts2.Engine.cond = 100
SB.EngineRebuild = false
check(engineJob(mechanic({ Mechanics = 6 }, engineParts(12)), parts2.Engine, "rebuild") == false, "沙盒關掉翻新引擎")
SB.EngineRebuild = nil
SB.EngineRebuildParts = 3
local thrifty, thriftyInv = mechanic({ Mechanics = 6 }, engineParts(3))
check(engineJob(thrifty, parts2.Engine, "rebuild") == true and thriftyInv:getCountTypeRecurse("Base.EngineParts") == 0, "沙盒改成每次 3 個")
SB.EngineRebuildParts = nil
check(engineJob(mechanic({ Mechanics = 6 }, engineParts(12)), parts2.Heater, "rebuild") == false, "對暖氣翻新引擎：拒絕")
local _, fullParts = garage({ quality = 100 })
check(engineJob(mechanic({ Mechanics = 6 }, engineParts(12)), fullParts.Engine, "rebuild") == false, "品質已經 100")

parts2.Heater.cond = 20
local sparky = mechanic({ Mechanics = 4 }, { fakeItem("Base.Screwdriver", { tag = "screwdriver" }), fakeItem("Base.ElectronicsScrap"),
    fakeItem("Base.ElectronicsScrap"), fakeItem("Base.ElectricWire") })
check(engineJob(sparky, parts2.Heater, "heater") == true and parts2.Heater.cond == 65, "修暖氣：20 -> 65（25 + 5 × 機械 4）")
check(engineJob(sparky, parts2.Heater, "heater") == false, "材料用完：拒絕")
before = vanillaEngineCompletes
check(ISRepairEngine:new(ace, parts2.Engine, nil, 300):complete() == true and vanillaEngineCompletes == before + 1, "原版修引擎（四個參數）照原版")
check(ISRepairEngine:new(ace, parts2.Engine, nil, 300, 7).anycar == nil, "第五個參數不是表：當成原版")
check(debug.getlocal(ISRepairEngine.new, 5) == "maxTimeInit" and debug.getlocal(ISRepairEngine.new, 6) == "anycar",
    "ISRepairEngine.new 的參數名和動作欄位同名")
local quick = ISRepairEngine:new(ace, parts2.Engine, nil, 0, { job = "rebuild" })
check(quick.maxTime == 600 and quick:getDuration() == 600 and ISRepairEngine:new(ace, parts2.Heater, nil, 0, { job = "heater" }).maxTime == 300,
    "本 MOD 的工作用規格的時間，不看傳進來的 maxTimeInit（0）與 item（nil）")
check(ISRepairEngine:new(ace, parts2.Engine, nil, 0).maxTime == 0, "原版修引擎的時間照原版")

print("情境九：零件拆解的額外材料")
local function salvage(mult, perks)
    SB.SalvageMult = mult
    rolls = 0
    D.onSalvage({ getRecipe = function() return { getName = function() return "AnyCarSalvageDoor" end } end }, (mechanic(perks, {})))
    return rolls
end
check(salvage(1.0, {}) == 3 and salvage(2.0, {}) == 6 and salvage(0.0, {}) == 0, "抽 3 次，照倍率變 6 次、0 次")
function ZombRand() return 45 end
check(salvage(1.0, {}) == 0 and salvage(1.0, { Mechanics = 1, MetalWelding = 1 }) == 3, "抽中率 40% 起，技能每級加 3%")
function ZombRand() return 0 end
SB.SalvageMult = nil

print("情境十：整車拆解的金工門檻與時間倍率")
SB.DismantleWelding = 3
local rookie, veteran = mechanic({ MetalWelding = 2 }, {}), mechanic({ MetalWelding = 3 }, {})
check(ISRemoveBurntVehicle:new(rookie, fakeVehicle("CarNormal")):complete() == false, "金工 2、門檻 3：拒絕")
check(ISRemoveBurntVehicle:new(veteran, fakeVehicle("CarNormal")):complete() == true, "金工 3：照拆")
check(ISRemoveBurntVehicle:new(rookie, fakeVehicle("CarNormalBurnt")):complete() == true, "殘骸不看門檻")
SB.DismantleWelding = nil
SB.DismantleTimeMult = 2.5
check(ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal")).maxTime == 2000 and ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormalBurnt")).maxTime == 800,
    "時間倍率 2.5：完好車 2000，殘骸照原版 800")
SB.DismantleTimeMult = nil

print("情境十一：拆車前先卸零件，等上一個零件真的卸下才排下一個")
-- 單人的順序是 perform（動作離開佇列）→ complete（零件離開車）；多人時結果由伺服器同步，時間不定
ISVehicleMenu = { FillMenuOutsideVehicle = function() end }
loaded["Vehicles/ISUI/ISVehicleMenu"] = true
require "MinidoracatAnyCar/Menu"
local queue, dismantled = {}, 0
ISTimedActionQueue = { getTimedActionQueue = function() return { queue = queue } end }
D.onDismantle = function() dismantled = dismantled + 1 end
local stripCar, stripParts = fakeVehicle("CarNormal"), {}
local function stripPart(id)
    local p = { id = id, item = fakeItem("Base." .. id), cond = 100 }
    function p:getId() return self.id end
    function p:getInventoryItem() return self.item end
    function p:getCondition() return self.cond end
    function p:getTable(name) return name == "uninstall" and {} or nil end
    stripParts[#stripParts + 1] = p
    return p
end
local tire, brake = stripPart("TireFrontLeft"), stripPart("BrakeFrontLeft")
brake.needs = tire
function stripCar:getPartCount() return #stripParts end
function stripCar:getPartByIndex(i) return stripParts[i + 1] end
function stripCar:canUninstallPart(_, part) return part.needs == nil or part.needs.item == nil end
ISVehiclePartMenu = { onUninstallPart = function(_, part) queue[#queue + 1] = { Type = "ISUninstallVehiclePart", part = part } end }
local function step(ms) nowMs = nowMs + ms; runTicks(1) end
D.onStrip(near, stripCar, {})
check(#queue == 1 and queue[1].part == tire, "先排輪胎（煞車被擋住）")
table.remove(queue, 1) -- perform：動作離開佇列，零件還在車上
step(100)
check(#queue == 0 and dismantled == 0, "動作結束但輪胎還沒卸下：不排下一個、不拆車")
tire.item = nil -- complete
step(100)
step(D.CHAIN_SETTLE)
check(#queue == 1 and queue[1].part == brake and dismantled == 0, "輪胎卸下後才排煞車")
table.remove(queue, 1)
brake.cond = 93 -- 卸失敗：扣了狀況、零件留在車上
step(100)
step(D.CHAIN_SETTLE)
check(#queue == 0 and dismantled == 1, "煞車卸失敗不重試，零件都試過才拆車")
tire.item, brake.cond = fakeItem("Base.TireFrontLeft"), 100
D.onStrip(near, stripCar, {})
queue = {}
step(100)
step(D.CHAIN_TIMEOUT)
step(D.CHAIN_SETTLE)
check(#queue == 0 and dismantled == 1, "玩家取消（沒有結果）：逾時後停下，不拆車")

print()
if failures > 0 then
    print(failures .. " 項失敗")
    os.exit(1)
end
print("全部通過")
