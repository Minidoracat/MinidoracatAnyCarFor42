--[[
煙霧測試骨架：用假的 PZ 全域載入**真正的** MOD Lua，跑行為情境並斷言結果。

    lua scripts/smoke_harness.lua        （repo 根目錄執行；標準 Lua 5.x 即可）

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
local MEDIA = "MOD/MinidoracatDismantleFor42/Contents/mods/MinidoracatDismantleFor42/42/media/lua"

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
SandboxVars = { MinidoracatDismantle = { LootMult = 1.0 } }
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

require "MinidoracatDismantle/Action"

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
        for _, fn in ipairs(tickHandlers) do fn() end
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
check(MinidoracatDismantle.blocked(fakePlayer(120, 200), fakeVehicle("CarNormal", { passengers = 1 }), nil) == "occupied", "從遠處看：先回車上有人，選單才顯示得出原因")
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
    SandboxVars.MinidoracatDismantle.LootMult = mult
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
SandboxVars.MinidoracatDismantle = nil
rolls = 0
check(ISRemoveBurntVehicle:new(near, fakeVehicle("CarNormal")):checkAddItem("x", 1) == true and rolls == 1, "沒有沙盒值：當成 1.0")

print()
if failures > 0 then
    print(failures .. " 項失敗")
    os.exit(1)
end
print("全部通過")
