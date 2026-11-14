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
function ISRemoveBurntVehicle:checkAddItem(item)
    rolls = rolls + 1
    self.vehicle:getSquare():AddWorldInventoryItem(item, 0.1, 0.2, 0)
    return true
end
function ISRemoveBurntVehicle:complete()
    if not self.vehicle then return false end
    for _, item in ipairs({ "ScrapMetal", "SteelBar", "ScrapMetal", "IronScrap " }) do self:checkAddItem(item, 12) end
    self.vehicle.removed = true
    return true
end
loaded["Vehicles/TimedActions/ISRemoveBurntVehicle"] = true

require "MinidoracatAnyCar/Dismantle"

local function fakeVehicle(script, opts)
    opts = opts or {}
    local v = { removed = false, x = 100.5, y = 200.5, z = 0, passengers = opts.passengers or 0, animals = opts.animals or {} }
    if not opts.noSquare then
        v.square = { dropped = {} }
        function v.square:AddWorldInventoryItem(item) self.dropped[#self.dropped + 1] = item; return item end
    end
    function v:getSquare() return self.square end
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
-- 假的袋子與物品：AddItem 建不出名稱不存在的物品（原版清單裡有一個尾巴多空白的名稱）
local stampLog = {}
local function fakeLootItem(name)
    local item = { name = name, stamps = {} }
    function item:getDisplayName() return "Garbage Bag" end
    function item:setName(text) self.custom = text end
    return item
end
local function fakeBag(full)
    local bag = fakeLootItem(full)
    bag.items = {}
    function bag:getInventory()
        local items = self.items
        return {
            AddItem = function(_, name)
                if name:match(" $") then return nil end
                items[#items + 1] = fakeLootItem(name)
                return items[#items]
            end,
            getItems = function() return { isEmpty = function() return #items == 0 end } end,
        }
    end
    return bag
end
instanceItem = fakeBag

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

print("情境四之二：拆車的產出收進一個袋子")
local function scrap(mult, player)
    SandboxVars.MinidoracatAnyCar = { LootMult = mult }
    local car = fakeVehicle("CarNormal")
    local a = ISRemoveBurntVehicle:new(player or near, car)
    check(a:complete() == true and a.vehicle == car and a.anycarLoot == nil, "倍率 " .. mult .. "：拆掉，動作上的車換回來")
    return car.square.dropped
end
local function names(bag)
    local list = {}
    for i, item in ipairs(bag.items) do list[i] = item.name end
    return table.concat(list, ",")
end
local dropped = scrap(1)
check(#dropped == 1 and dropped[1].name == "Base.Garbagebag", "地上只多一個袋子")
check(names(dropped[1]) == "ScrapMetal,ScrapMetal,SteelBar", "材料都在袋子裡、同種排在一起、建不出的跳過：" .. names(dropped[1]))
check(dropped[1].custom == "Garbage Bag (tester)", "袋子名稱帶拆車人：" .. tostring(dropped[1].custom))
check(next(dropped[1].stamps) == nil and next(dropped[1].items[1].stamps) == nil, "沒裝 Item Cleaner：不記")
check(#scrap(2)[1].items == 6, "倍率 2：六件都在同一個袋子")
check(#scrap(0) == 0, "倍率 0：沒有產出就沒有袋子")
check(scrap(1, fakePlayer(101.5, 201.5, 0, "a b=c"))[1].custom == "Garbage Bag (a_b_c)", "袋子名稱裡的帳號照 log 的規則清理")

local loose = fakeVehicle("CarNormal")
ISRemoveBurntVehicle:new(near, loose):checkAddItem("ScrapMetal", 12)
check(#loose.square.dropped == 1 and loose.square.dropped[1] == "ScrapMetal", "沒經過本 MOD 的 complete：照原版落地")
local noSquare = fakeVehicle("CarNormal", { noSquare = true })
check(pcall(function() return ISRemoveBurntVehicle:new(near, noSquare):complete() end) == false, "車沒有所在的格子：照原版（出錯、不吞產出）")

-- 有裝 Item Cleaner：袋子與袋內每件都記上拆車人，而且在袋子落地前
local traceOn = true
local onGround = 0
MinidoracatCleaner = {
    getOption = function(key) if key == "TouchTraceEnabled" then return traceOn end end,
    stampDrop = function(item, name) item.stamps.drop = name; stampLog[#stampLog + 1] = onGround end,
    stampMove = function(item, name) item.stamps.move = name end,
}
local stampedCar = fakeVehicle("CarNormal")
local vanillaDrop = stampedCar.square.AddWorldInventoryItem
function stampedCar.square:AddWorldInventoryItem(item) onGround = onGround + 1; return vanillaDrop(self, item) end
ISRemoveBurntVehicle:new(fakePlayer(101.5, 201.5, 0, "kenzo"), stampedCar):complete()
local stamped = stampedCar.square.dropped[1]
local allStamped = stamped.stamps.drop == "kenzo" and stamped.stamps.move == "kenzo"
for _, item in ipairs(stamped.items) do allStamped = allStamped and item.stamps.drop == "kenzo" and item.stamps.move == "kenzo" end
check(allStamped and #stampLog == 4, "袋子與三件材料都記上拆車人")
local late = false
for _, at in ipairs(stampLog) do late = late or at > 0 end
check(onGround == 1 and not late, "都在袋子落地前記好")
traceOn = false
check(next(scrap(1)[1].stamps) == nil, "Item Cleaner 關掉搬移紀錄：不記")
MinidoracatCleaner = nil

-- ===== 修理、零件拆解、引擎：假的原版類別與 Java 物件 =====
SandboxVars.MinidoracatAnyCar = {}
local SB = SandboxVars.MinidoracatAnyCar
Perks = { Mechanics = "Mechanics", MetalWelding = "MetalWelding", Electricity = "Electricity", FromString = function(name) return name end }
ItemTag = { WRENCH = "wrench", SCREWDRIVER = "screwdriver", FILE = "file", SMALL_FILES = "smallfiles", CAR_KEY = "carkey" }
CharacterTrait = { BURGLAR = "burglar" }
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
    function item:isBroken() return self.broken == true end
    function item:getContainer() return self.container end
    function item:hasTag(tag) return self.tag == tag end
    function item:getKeyId() return self.keyId or -1 end
    function item:setKeyId(id) self.keyId = id end
    -- 原版 getName 會加損壞、磨損等前綴，getDisplayName 才是存著的名字
    function item:getName() return "Worn, " .. (self.name or self.full) end
    function item:getDisplayName() return self.name or self.full end
    function item:setName(name) self.name = name end
    function item:getColor() return self.color end
    function item:setColor(color) self.color = color end
    function item:setCustomColor(custom) self.customColor = custom end
    function item:getWorldItem() return self.worldItem end
    function item:setWorldItem(w) self.worldItem = w end
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
    function inv:getAllTypeRecurse(full)
        local list = {}
        for _, item in ipairs(all()) do if item.full == full then list[#list + 1] = item end end
        return javaList(list)
    end
    function inv:getFirstTagEvalRecurse(tag, fn)
        for _, item in ipairs(all()) do if item.tag == tag and fn(item) then return item end end
        return nil
    end
    -- 原版只找主背包與鑰匙圈（ItemContainer.haveThisKeyId）
    function inv:haveThisKeyId(id)
        for _, item in ipairs(self.main) do if item.keyId == id then return item end end
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
-- 原版只看主背包有沒有材料（ISFixVehiclePartAction.lua:5-7）；測試用 vanillaValid 模擬「最後一份剛用掉」
function ISFixVehiclePartAction:isValid() return self.vanillaValid ~= false end
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
function instanceItem(full) return full == "Base.Garbagebag" and fakeBag(full) or fakeItem(full) end
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
        function p:getWheelIndex() return string.find(id, "^Tire") and 0 or -1 end
        parts[id] = p
        return p
    end
    part("DoorFrontLeft", fakeItem("Base.ModDoor2", { cond = 40 }))
    part("TireFrontRight", opts.noTire == nil and fakeItem("Base.ModTire2", { cond = 50 }) or nil, nil, true)
    part("BrakeFrontRight", fakeItem("Base.ModBrake2", { cond = 30 }), { uninstall = { requireUninstalled = "TireFrontRight" } })
    part("Engine", nil)
    part("Heater", nil)
    part("SpareTireRoof", fakeItem("Base.ModTire2"))
    part("Roofrack", fakeItem("Base.ModRoofrack2", { cond = 50 }), { uninstall = { requireUninstalled = "SpareTireRoof" } })
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
class("Tank125_2", "GasTank")
class("90pierceArrowWaterTank2", "GasTank")
class("93chevyK3500WreckerLid2", "TrunkLid")
class("E150CarSlideDoor2", "Door")
class("69miniMrBChair1", "Seat")
class("91rangeSunRoof2", "Window")

print("情境六：載入時把零件填進修法與拆解配方")
local doorWeld = fakeFixing("AnyCar_Door_Welding", { fakeFixer("Base.SheetMetal", 1, { MetalWelding = 2, Mechanics = 2 }) },
    fakeFixer("Base.BlowTorch", 2))
local tirePatch = fakeFixing("AnyCar_Tire_Patch", { fakeFixer("Base.TirePiece", 1, { Mechanics = 2 }) }, fakeFixer("Base.Glue", 1))
local vanillaDoor = fakeFixing("Fix Door Welding", { fakeFixer("Base.SheetMetal", 1, { MetalWelding = 3 }) }, fakeFixer("Base.BlowTorch", 2))
vanillaDoor:addRequiredItem("Base.FrontCarDoor1")
doorWeld:addRequiredItem("") -- 腳本裡 Require 留空時引擎放進去的空字串
-- 每個配方自己的輸入列數：車門照腳本是 2 列工具；消音器的腳本工具列數和 D.SALVAGE 對不上；引擎蓋 Load 丟例外
local recipeLoads, recipeInputs = {}, { AnyCarSalvageDoor = 2, AnyCarSalvageMuffler = 5, AnyCarSalvageHood = 2 }
local function scriptItem(module, name, mechanic, vehicleType)
    return { getFullName = function() return module .. "." .. name end, getName = function() return name end,
        isMechanicsLoot = function() return mechanic end, getConditionMax = function() return 100 end, vehicleType = vehicleType }
end
local scriptItems = {
    scriptItem("Base", "FrontCarDoor1", true, 1), scriptItem("Base", "ModDoor2", true, 2), scriptItem("Base", "ModTire2", true, 2),
    scriptItem("Base", "ModMuffler2", true, 2), scriptItem("Base", "ModEngineDoor2", true, 2),
    scriptItem("Base", "Jack", true, 0), scriptItem("Base", "Apple", false, 0),
}
function instanceItem(full)
    if full == "Base.Garbagebag" then return fakeBag(full) end
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
            if not recipeInputs[name] then return nil end
            return { getName = function() return name end, getInputs = function() return { size = function() return recipeInputs[name] end } end,
                Load = function(_, _, body)
                    if name == "AnyCarSalvageHood" then error("bad script") end
                    recipeLoads[#recipeLoads + 1] = body
                    recipeInputs[name] = recipeInputs[name] + 1
                end }
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
check(D.salvageTest.Muffler() == false and D.salvageTest.Hood() == false and #recipeLoads == 1,
    "工具列數對不上或 Load 失敗：零件那一列沒加上，配方關著")
check(MinidoracatAnyCar_salvageInMenu({ recipe = { getName = function() return "AnyCarSalvageMuffler" end } }) == false,
    "零件那一列沒加上的配方不列在製作清單")
SB.Salvage = false
check(D.salvageTest.Door() == false and MinidoracatAnyCar_salvageInMenu({ recipe = { getName = function() return "AnyCarSalvageDoor" end } }) == false,
    "沙盒關掉零件拆解：不能做、不列在清單")
SB.Salvage = nil

print("情境七：伺服器修理裝在車上的零件")
local function torch() return fakeItem("Base.BlowTorch", { uses = 10 }) end
check(D.usesTorch(doorWeld) and D.usesTorch(vanillaDoor) and not D.usesTorch(tirePatch), "噴燈修法：本 MOD 與原版的焊接都算，補胎不算")
local function startAnim(hand, fixing)
    local chr = { getPrimaryHandItem = function() return hand and fakeItem(hand) end, playSound = function() return 1 end }
    local a = setmetatable({ fixing = fixing, character = chr }, ISFixVehiclePartAction)
    function a:setActionAnim(name) self.anim = name end
    function a:setOverrideHandModels() end
    a:start()
    return a.anim
end
check(startAnim("Base.BlowTorch", vanillaDoor) == "BlowTorch" and startAnim("Base.Hammer", vanillaDoor) == nil
    and startAnim(nil, doorWeld) == "VehicleWorkOnMid" and startAnim("Base.BlowTorch", tirePatch) == "VehicleWorkOnMid",
    "焊接動畫只在主手拿著噴燈時播（原版焊接也算）；沒拿噴燈照原版或用修車動作")
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
check(D.coveredBy(carParts.Roofrack) == nil and D.coveredBy(carParts.BrakeFrontRight) == carParts.TireFrontRight,
    "只有車輪擋修理：車頂架要先卸的車頂備胎不算")

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

local function validAction(player, part, fixing, vanillaValid)
    local a = ISFixVehiclePartAction:new(player, part, fixing, fixing:getFixers():get(0))
    a.vanillaValid = vanillaValid
    return a:isValid()
end
local _, vParts = garage()
local noMats = mechanic({ MetalWelding = 2, Mechanics = 2 }, {})
check(validAction(noMats, vParts.DoorFrontLeft, doorWeld, false) == true,
    "客戶端 isValid（本 MOD）：材料剛好用完、原版那條回 false 也不中止（交給伺服器 complete）")
vParts.DoorFrontLeft:getInventoryItem().cond = 100
check(validAction(welder, vParts.DoorFrontLeft, doorWeld) == true, "客戶端 isValid（本 MOD）：狀況已滿（結果先同步到）不中止")
check(validAction(mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }, nil, 120), vParts.DoorFrontLeft, doorWeld) == false,
    "客戶端 isValid（本 MOD）：狀況已滿但離車太遠，照樣中止")
vParts.DoorFrontLeft:getInventoryItem().cond = 40
check(validAction(mechanic({ MetalWelding = 2, Mechanics = 2 }, { fakeItem("Base.SheetMetal"), torch() }, nil, 120), vParts.DoorFrontLeft, doorWeld) == false,
    "客戶端 isValid（本 MOD）：離車太遠中止")
local goneAction = ISFixVehiclePartAction:new(welder, vParts.DoorFrontLeft, doorWeld, doorWeld:getFixers():get(0))
vParts.DoorFrontLeft.getInventoryItem = function() return nil end
check(goneAction:isValid() == false, "客戶端 isValid（本 MOD）：零件被卸掉（gone）中止")
check(validAction(welder, carParts.DoorFrontLeft, vanillaDoor, false) == false and validAction(noMats, carParts.DoorFrontLeft, vanillaDoor) == true,
    "客戶端 isValid（原版修法）：照原版（只看材料）")

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
check(ISRepairEngine:new(ace, parts2.Engine, nil, 1, { job = "rebuild" }).maxTime == 600, "maxTimeInit 給 1 也照規格 600")
local farAce = mechanic({ Mechanics = 6 }, engineParts(12), nil, 120)
check(ISRepairEngine:new(ace, parts2.Engine, nil, 600, { job = "rebuild" }):isValid() == true
    and ISRepairEngine:new(farAce, parts2.Engine, nil, 600, { job = "rebuild" }):isValid() == false
    and ISRepairEngine:new(mechanic({ Mechanics = 6 }, engineParts(1)), parts2.Engine, nil, 600, { job = "rebuild" }):isValid() == true,
    "客戶端 isValid：太遠就中止；材料不夠交給伺服器（做完那一刻的同步不會把動作打斷）")

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
ISTimedActionQueue = { cancelQueue = function() end }
loaded["TimedActions/ISTimedActionQueue"] = true
require "MinidoracatAnyCar/Menu"
local q = setmetatable({ queue = {} }, { __index = ISTimedActionQueue })
ISTimedActionQueue.getTimedActionQueue = function() return q end
local dismantled = 0
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
local function removeFromQueue(action)
    for i = #q.queue, 1, -1 do if q.queue[i] == action then table.remove(q.queue, i) end end
end
ISVehiclePartMenu = { onUninstallPart = function(_, part)
    q.queue[#q.queue + 1] = { Type = "ISUninstallVehiclePart", part = part, perform = removeFromQueue }
end }
local mech = { dead = false }
function mech:isDead() return self.dead end
local function step(ms) nowMs = nowMs + ms; runTicks(1) end
local function settle() step(100); step(D.CHAIN_SETTLE) end
local function cancelAll() q:cancelQueue(); q.queue = {} end -- 玩家取消：經過 cancelQueue、佇列清空

D.onStrip(mech, stripCar, {})
check(#q.queue == 1 and q.queue[1].part == tire, "先排輪胎（煞車被擋住）")
q.queue[1]:perform() -- 動作離開佇列，零件還在車上（complete 還沒跑）
step(100)
check(#q.queue == 0 and dismantled == 0, "做完但輪胎還沒卸下：不排下一個、不拆車")
tire.item = nil -- complete
settle()
check(#q.queue == 1 and q.queue[1].part == brake and dismantled == 0, "輪胎卸下後才排煞車")
q.queue[1]:perform()
brake.cond = 93 -- 卸失敗：扣了狀況、零件留在車上
settle()
check(#q.queue == 0 and dismantled == 1, "煞車卸失敗不重試，零件都試過才拆車")

tire.item, brake.cond = fakeItem("Base.TireFrontLeft"), 100
D.onStrip(mech, stripCar, {})
cancelAll()
step(100)
step(D.CHAIN_TIMEOUT)
settle()
check(#q.queue == 0 and dismantled == 1, "玩家取消（沒做完、沒結果）：逾時後停下，不拆車")

D.onStrip(mech, stripCar, {})
q.queue = {} -- 多人：同步先到、動作被自動中止（沒有 perform）
tire.item = nil
settle()
check(#q.queue == 1 and q.queue[1].part == brake, "沒有 perform 但結果出現（多人同步先到）：接下一個")
q.queue[1]:perform()
step(100)
brake.item = nil
step(100)
cancelAll() -- 結果出現後、接下一步之前玩家取消
q.queue[#q.queue + 1] = { Type = "Other" }
cancelAll()
step(D.CHAIN_SETTLE)
step(D.CHAIN_SETTLE)
check(#q.queue == 0 and dismantled == 1, "結果出現後玩家取消：不接下一步、不拆車")

tire.item, brake.item, tire.cond = fakeItem("Base.TireFrontLeft"), fakeItem("Base.BrakeFrontLeft"), 0
brake.needs = nil
D.onStrip(mech, stripCar, {})
q.queue[1]:perform() -- 狀況 0 的零件卸失敗：狀況與零件都沒變
step(100)
step(D.CHAIN_NOCHANGE)
settle()
check(#q.queue == 1 and q.queue[1].part == brake, "做完但結果沒變（狀況 0 卸失敗）：算試過，接下一個")
mech.dead = true
q.queue[1]:perform()
brake.item = nil
settle()
check(dismantled == 1, "玩家死了：不接下一步")
mech.dead = false

print("情境十二：修理全部零件的規劃（兩個零件共用材料）")
ISVehicleMechanics = { doPartContextMenu = function() end, ghs = "<GHC>", bhs = "<BHC>" }
ISInventoryPaneContextMenu = { buildFixingMenu = function() end }
loaded["Vehicles/ISUI/ISVehicleMechanics"] = true
loaded["ISUI/ISInventoryPaneContextMenu"] = true
function getItemName(full) return full end
PerkFactory = { getPerk = function(perk) return { getName = function() return perk end } end }
local windowTape = fakeFixing("AnyCar_Window_Tape", { fakeFixer("Base.DuctTape", 3, { Mechanics = 1 }) })
FixingManager.getFixes = function(item)
    local list = javaList(item.full == "Base.FrontWindow1" and { windowTape } or {})
    function list:isEmpty() return self:size() == 0 end
    return list
end
FixingManager.getCondRepaired = function() return 30 end
require "MinidoracatAnyCar/RepairMenu"
local function windowCar()
    local v, list = fakeVehicle("CarNormal"), {}
    for _, id in ipairs({ "WindowFrontLeft", "WindowRearLeft" }) do
        local item = fakeItem("Base.FrontWindow1", { cond = 40 })
        list[#list + 1] = { getId = function() return id end, getInventoryItem = function() return item end, getTable = function() return nil end }
    end
    function v:getPartCount() return #list end
    function v:getPartByIndex(i) return list[i + 1] end
    return v
end
local function tapes(...)
    local items = {}
    for _, uses in ipairs({ ... }) do items[#items + 1] = fakeItem("Base.DuctTape", { uses = uses }) end
    return mechanic({ Mechanics = 2 }, items)
end
local todo, skipped = D.planRepairAll(tapes(3, 3), windowCar(), {})
check(#todo == 2 and #skipped == 0, "膠帶共 6 次：兩扇窗都排進去（不是只數到夠第一個就停）")
todo, skipped = D.planRepairAll(tapes(3, 2), windowCar(), {})
check(#todo == 1 and #skipped == 1 and skipped[1].reason == "Base.DuctTape 2/3", "膠帶共 5 次：第二扇略過，原因寫剩 2/3（" .. tostring(skipped[1] and skipped[1].reason) .. "）")

print("情境十三：配鑰匙、拆除短接（包原版熱線動作）")
local hotwireTries = 0
ISHotwireVehicle = {}
ISHotwireVehicle.__index = ISHotwireVehicle
function ISHotwireVehicle:isValid()
    local vehicle = self.character:getVehicle()
    return vehicle ~= nil and vehicle:isDriver(self.character)
end
function ISHotwireVehicle:complete()
    hotwireTries = hotwireTries + 1
    self.character:getVehicle():tryHotwire(self.character:getPerkLevel(Perks.Electricity))
    return true
end
function ISHotwireVehicle:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 200 - self.character:getPerkLevel(Perks.Electricity) * 3
end
function ISHotwireVehicle:new(character)
    local o = setmetatable({ character = character }, self)
    o.maxTime = o:getDuration()
    return o
end
loaded["Vehicles/TimedActions/ISHotwireVehicle"] = true
local given = {}
Actions.addOrDropItem = function(_, item) given[#given + 1] = item end
require "MinidoracatAnyCar/Keys"

-- opts：hotwired（預設 true）、running、ignition、door、notDriver
local function keyCar(opts)
    opts = opts or {}
    local v = fakeVehicle("CarNormal")
    v.hotwired = opts.hotwired ~= false
    function v:getKeyId() return 777 end
    function v:isHotwired() return self.hotwired end
    function v:isEngineRunning() return opts.running == true end
    function v:isEngineStarted() return false end
    function v:isKeysInIgnition() return opts.ignition == true end
    function v:isKeyIsOnDoor() return opts.door == true end
    function v:isDriver(chr) return not opts.notDriver and chr == self.driver end
    function v:cheatHotwire(hotwired, broken) self.hotwired, self.broken = hotwired, broken end
    function v:tryHotwire(level) self.triedLevel = level end
    function v:createVehicleKey() local key = fakeItem("Base.CarKey", { tag = "carkey" }); key.keyId = 777; return key end
    return v
end
local function carKey(id) local key = fakeItem("Base.CarKey", { tag = "carkey" }); key.keyId = id; return key end
local function screwdriver() return fakeItem("Base.Screwdriver", { tag = "screwdriver" }) end
local function file(tag) return fakeItem("Base.File", { tag = tag or "file" }) end
local function sheet() return fakeItem("Base.SmallSheetMetal") end
local function driver(car, perks, items, traits)
    local p, inv = mechanic(perks, items)
    function p:getVehicle() return car end
    function p:hasTrait(trait) return traits ~= nil and traits[trait] == true end
    car.driver = p
    return p, inv
end
local function keyJob(player, job) return ISHotwireVehicle:new(player, { job = job }) end
local function makeKey(car, perks, items, traits)
    local p, inv = driver(car, perks, items, traits)
    local n, g = #logLines, #given
    local ok = keyJob(p, "make"):complete()
    return ok, #given - g, #logLines - n, inv
end
local smith = { MetalWelding = 3, Mechanics = 3 }
local function kit() return { screwdriver(), file(), sheet() } end

local made = keyCar()
local ok, gotKeys, logged, inv = makeKey(made, smith, kit())
check(ok == true and gotKeys == 1 and given[#given].keyId == 777 and logged == 1 and inv:getCountTypeRecurse("Base.SmallSheetMetal") == 0
    and made.hotwired == true, "配鑰匙：拿到這台車的鑰匙、用掉 1 片小金屬片、車還是熱線")
check(logLines[#logLines] == "KEYMAKE player=tester vehicle=Base.CarNormal id=48213 keyid=777", "log：" .. tostring(logLines[#logLines]))
check(inv:getCountTypeRecurse("Base.Screwdriver") == 1 and inv:getCountTypeRecurse("Base.File") == 1, "工具不消耗")
check(makeKey(keyCar(), smith, { screwdriver(), file("smallfiles"), sheet() }) == true, "小銼刀組（base:smallfiles）也算銼刀")

local function refusedMake(label, car, perks, items, traits)
    local r, k, l, i = makeKey(car, perks, items, traits)
    check(r == false and k == 0 and l == 0 and i:getCountTypeRecurse("Base.SmallSheetMetal") == 1, label)
end
refusedMake("沒有熱線", keyCar({ hotwired = false }), smith, kit())
refusedMake("身上已經有這台車的鑰匙", keyCar(), smith, { screwdriver(), file(), sheet(), carKey(777) })
check(makeKey(keyCar(), smith, { screwdriver(), file(), sheet(), carKey(778) }) == true, "身上是別台車的鑰匙：照做")
refusedMake("鑰匙插在點火開關", keyCar({ ignition = true }), smith, kit())
refusedMake("鑰匙插在車門上", keyCar({ door = true }), smith, kit())
refusedMake("金工 2", keyCar(), { MetalWelding = 2, Mechanics = 3 }, kit())
refusedMake("技工 2", keyCar(), { MetalWelding = 3, Mechanics = 2 }, kit())
refusedMake("沒有螺絲起子", keyCar(), smith, { file(), sheet() })
refusedMake("沒有銼刀", keyCar(), smith, { screwdriver(), sheet() })
local brokenDriver = screwdriver()
brokenDriver.broken = true
refusedMake("只有壞掉的螺絲起子", keyCar(), smith, { brokenDriver, file(), sheet() })
local r0, k0, l0 = makeKey(keyCar(), smith, { screwdriver(), file() })
check(r0 == false and k0 == 0 and l0 == 0, "沒有小金屬片：不給鑰匙、不記錄")
refusedMake("引擎在跑", keyCar({ running = true }), smith, kit())
refusedMake("不是駕駛", keyCar({ notDriver = true }), smith, kit())
SB.Keys = false
refusedMake("沙盒關掉鑰匙功能", keyCar(), smith, kit())
SB.Keys = nil
SB.KeysWelding, SB.KeysMechanics = 5, 4
refusedMake("沙盒門檻改成金工 5、技工 4：金工 3 不夠", keyCar(), smith, kit())
check(makeKey(keyCar(), { MetalWelding = 5, Mechanics = 4 }, kit()) == true, "沙盒門檻 5／4：剛好夠就照做")
SB.KeysWelding, SB.KeysMechanics = nil, nil

local function unwire(car, perks, items, traits)
    local p = driver(car, perks, items, traits)
    local n = #logLines
    local ok = keyJob(p, "unwire"):complete()
    return ok, #logLines - n
end
local wire = { Electricity = 1, Mechanics = 2 }
local cut = keyCar()
ok, logged = unwire(cut, wire, { screwdriver(), carKey(777) })
check(ok == true and logged == 1 and cut.hotwired == false and cut.broken == false, "拆除短接：身上有鑰匙，熱線取消")
check(logLines[#logLines] == "UNWIRE player=tester vehicle=Base.CarNormal id=48213 keyid=777", "log：" .. tostring(logLines[#logLines]))
local inIgnition = keyCar({ ignition = true })
check(unwire(inIgnition, wire, { screwdriver() }) == true and inIgnition.hotwired == false, "鑰匙插在點火開關也可以")
local burglar = keyCar()
check(unwire(burglar, {}, { screwdriver(), carKey(777) }, { burglar = true }) == true and burglar.hotwired == false, "竊賊特質不看技能（和原版熱線相同）")
local function refusedUnwire(label, car, perks, items, traits)
    local wasHotwired = car.hotwired
    local r, l = unwire(car, perks, items, traits)
    check(r == false and l == 0 and car.hotwired == wasHotwired and car.broken == nil, label)
end
refusedUnwire("沒有鑰匙", keyCar(), wire, { screwdriver(), carKey(778) })
refusedUnwire("沒有熱線", keyCar({ hotwired = false }), wire, { screwdriver(), carKey(777) })
refusedUnwire("電工 0", keyCar(), { Mechanics = 2 }, { screwdriver(), carKey(777) })
refusedUnwire("技工 1", keyCar(), { Electricity = 1, Mechanics = 1 }, { screwdriver(), carKey(777) })
refusedUnwire("沒有螺絲起子", keyCar(), wire, { carKey(777) })
refusedUnwire("引擎在跑", keyCar({ running = true }), wire, { screwdriver(), carKey(777) })
SB.Keys = false
refusedUnwire("沙盒關掉鑰匙功能", keyCar(), wire, { screwdriver(), carKey(777) })
SB.Keys = nil

local timer = driver(keyCar(), { Electricity = 4 }, {})
check(keyJob(timer, "make").maxTime == 600 and keyJob(timer, "unwire").maxTime == 200 and ISHotwireVehicle:new(timer).maxTime == 188,
    "時間：配鑰匙 600、拆除短接 200；原版熱線照原版（200 - 電工 × 3）")
function timer:isTimedActionInstant() return true end
check(keyJob(timer, "make"):getDuration() == 1, "瞬間完成（除錯）照原版回 1")

local vanillaCar = keyCar({ hotwired = false })
local thief = driver(vanillaCar, { Electricity = 2 }, {})
local tries, logs1 = hotwireTries, #logLines
check(ISHotwireVehicle:new(thief):complete() == true and hotwireTries == tries + 1 and vanillaCar.triedLevel == 2 and #logLines == logs1,
    "沒有 anycar：原版熱線（tryHotwire 帶電工等級、不記錄）")
check(ISHotwireVehicle:new(thief, 7).anycar == nil and ISHotwireVehicle:new(thief, { job = "x" }).anycar == nil, "第二個參數不是本 MOD 的工作：當成原版")
check(debug.getlocal(ISHotwireVehicle.new, 2) == "character" and debug.getlocal(ISHotwireVehicle.new, 3) == "anycar",
    "ISHotwireVehicle.new 的參數名和動作欄位同名")

local synced = keyCar()
local queued = keyJob(driver(synced, wire, { screwdriver(), carKey(777) }), "unwire")
synced.hotwired = false -- 多人：結果比客戶端的動作先同步到
check(queued:isValid() == true, "客戶端 isValid：結果先同步到（已不是熱線）不中止")
SB.Keys = false
check(queued:isValid() == false, "客戶端 isValid：沙盒關掉時中止")
SB.Keys = nil
check(keyJob(driver(keyCar({ notDriver = true }), wire, {}), "unwire"):isValid() == false, "客戶端 isValid：不是駕駛照原版中止")

print("情境十四：複製鑰匙（craftRecipe OnCreate／OnTest）")
local source = carKey(777)
source.name, source.color = "Vehicle Key - Chevalier Nyala", "blue"
local output = fakeItem("Base.CarKey", { tag = "carkey" })
local copier, copierInv = mechanic({ MetalWelding = 2 }, { source, output })
local recipeData = {
    getFirstInputItemWithTag = function(_, tag) return tag == "carkey" and source or nil end,
    getFirstCreatedItem = function() return output end,
}
local g0, n0 = #given, #logLines
D.onCopyKey(recipeData, copier)
local copy = given[#given]
check(#given == g0 + 1 and copy.keyId == 777 and copy.name == source.name and copy.color == "blue" and copy.customColor == true,
    "新鑰匙的編號、名稱、顏色照來源鑰匙")
check(copierInv:getCountTypeRecurse("Base.CarKey") == 1 and copierInv.main[1] == source, "沒有編號的預設產出拿掉，來源鑰匙留著")
check(#logLines == n0 + 1 and logLines[#logLines] == "KEYCOPY player=tester keyid=777", "log：" .. tostring(logLines[#logLines]))
check(D.copyKeyTest(source, copier) == true and D.copyKeyTest(carKey(-1), copier) == false and D.copyKeyTest(file(), copier) == true,
    "OnTest：有編號的車鑰匙與其他輸入可以，沒有編號的車鑰匙不行")
SB.Keys = false
check(D.copyKeyTest(source, copier) == false and D.copyKeyTest(file(), copier) == false and MinidoracatAnyCar_keysInMenu() == false,
    "沙盒關掉：OnTest 全部不行、不列在製作清單")
SB.Keys = nil
check(MinidoracatAnyCar_keysInMenu() == true, "沙盒開著：列在製作清單")
-- 背包超重：預設產出被 addOrDropItem 放在地上（沒有容器、有 worldItem）
local floorCalls = {}
local floorSquare = {
    transmitRemoveItemFromSquare = function(_, w) floorCalls[#floorCalls + 1] = "transmit:" .. tostring(w.tag) end,
    removeWorldObject = function(_, w) floorCalls[#floorCalls + 1] = "remove:" .. tostring(w.tag) end,
}
local dropped = fakeItem("Base.CarKey", { tag = "carkey" })
dropped.worldItem = { tag = "w1", getSquare = function() return floorSquare end }
local heavyInv
copier, heavyInv = mechanic({ MetalWelding = 2 }, { source })
recipeData.getFirstCreatedItem = function() return dropped end
g0 = #given
D.onCopyKey(recipeData, copier)
check(#given == g0 + 1 and given[#given].keyId == 777, "超重：照樣給設好編號的鑰匙")
check(table.concat(floorCalls, ",") == "transmit:w1,remove:w1" and dropped.worldItem == nil and heavyInv.main[1] == source,
    "超重：地上那把沒有編號的預設產出移除並同步（" .. table.concat(floorCalls, ",") .. "）")
print()
if failures > 0 then
    print(failures .. " 項失敗")
    os.exit(1)
end
print("全部通過")
