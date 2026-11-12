-- 讓原版的拆殘骸動作也能拆完好的車，並由伺服器重新檢查。
-- 放在 shared：多人時 complete 在伺服器執行。
require "Vehicles/TimedActions/ISRemoveBurntVehicle"

MinidoracatDismantle = MinidoracatDismantle or {}
local D = MinidoracatDismantle

local LOG = "[MinidoracatDismantleFor42] "
D.MAX_DIST = 6 -- 玩家到車中心的格數上限；最長的車身一半約 4 格

-- 原版只收這兩種（ISRemoveBurntVehicle.lua:195-196）
function D.isWreck(vehicle)
    local name = vehicle:getScript():getName()
    return string.match(name, "Burnt") ~= nil or string.match(name, "Smashed") ~= nil
end

-- 回傳：已安裝的零件數、車內各容器的物品總數
function D.count(vehicle)
    local parts, items = 0, 0
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part:getInventoryItem() ~= nil then parts = parts + 1 end
        local container = part:getItemContainer()
        if container ~= nil then items = items + container:getItems():size() end
    end
    return parts, items
end

-- 不能拆的原因；可以拆回 nil。"occupied"、"animals" 也給選單顯示用。
-- confirmedItems：玩家在確認框看到的車內物品數（沒經過本 MOD 選單的動作是 nil，不檢查）
function D.blocked(character, vehicle, confirmedItems)
    if vehicle:isRemovedFromWorld() then return "gone" end
    local dx, dy = character:getX() - vehicle:getX(), character:getY() - vehicle:getY()
    if dx * dx + dy * dy > D.MAX_DIST * D.MAX_DIST or math.abs(character:getZ() - vehicle:getZ()) >= 1 then
        return "far"
    end
    if vehicle:hasPassenger() then return "occupied" end -- BaseVehicle.java:1848
    if vehicle:getAnimals():size() > 0 then return "animals" end -- BaseVehicle.java:10713
    if confirmedItems ~= nil then
        local _, items = D.count(vehicle)
        if items > confirmedItems then return "items" end
    end
    return nil
end

-- 參數名要和動作表的欄位同名：引擎照 new 的參數名從動作表取值送到伺服器，再用它們重建動作
local vanillaNew = ISRemoveBurntVehicle.new
function ISRemoveBurntVehicle:new(character, vehicle, confirmedItems)
    local o = vanillaNew(self, character, vehicle)
    if vehicle ~= nil and o.vehicle == nil then
        o.vehicle = vehicle
        o.maxTime = o:getDuration()
    end
    if type(confirmedItems) == "number" then o.confirmedItems = confirmedItems end
    return o
end

-- 客戶端：條件不符時動作直接中止，玩家看得到；伺服器在 complete 重新檢查
local vanillaIsValid = ISRemoveBurntVehicle.isValid
function ISRemoveBurntVehicle:isValid()
    if not vanillaIsValid(self) then return false end
    return D.blocked(self.character, self.vehicle, self.confirmedItems) == nil
end

local vanillaComplete = ISRemoveBurntVehicle.complete
function ISRemoveBurntVehicle:complete()
    local character, vehicle = self.character, self.vehicle
    if not character or not vehicle then return false end
    local why = D.blocked(character, vehicle, self.confirmedItems)
    if why then
        print(LOG .. "refused (" .. why .. "): " .. tostring(character:getUsername()))
        return false
    end
    -- 車移除前先取資料
    local parts, items = D.count(vehicle)
    local line = string.format("SCRAP player=%s vehicle=%s id=%d at=%d,%d,%d parts=%d items=%d",
        tostring(character:getUsername()), tostring(vehicle:getScriptName()), vehicle:getSqlId(),
        math.floor(vehicle:getX()), math.floor(vehicle:getY()), math.floor(vehicle:getZ()), parts, items)
    local ok = vanillaComplete(self)
    if ok then writeLog("MinidoracatDismantle", line) end
    return ok
end

-- 產出倍率：每次擲骰重複 LootMult 次，小數部分當成多擲一次的機率。只有 complete 會呼叫，所以在伺服器生效
local vanillaCheckAddItem = ISRemoveBurntVehicle.checkAddItem
function ISRemoveBurntVehicle:checkAddItem(item, baseChance)
    local mult = SandboxVars.MinidoracatDismantle and SandboxVars.MinidoracatDismantle.LootMult or 1
    local rolls = math.floor(mult)
    local extra = mult - rolls
    if extra > 0 and ZombRandFloat(0, 1) < extra then rolls = rolls + 1 end
    local got = false
    for _ = 1, rolls do
        if vanillaCheckAddItem(self, item, baseChance) then got = true end
    end
    return got
end
