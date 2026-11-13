-- 讓原版的拆殘骸動作也能拆完好的車，並由伺服器重新檢查。
-- 放在 shared：多人時 complete 在伺服器執行。
require "Vehicles/TimedActions/ISRemoveBurntVehicle"
require "MinidoracatAnyCar/Parts"

local D = MinidoracatAnyCar

D.MAX_DIST = 6 -- 拆車時玩家到車中心的格數上限；最長的車身一半約 4 格

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

-- 玩家離車中心超過 dist 格，或不在同一層
function D.far(character, vehicle, dist)
    local dx, dy = character:getX() - vehicle:getX(), character:getY() - vehicle:getY()
    return dx * dx + dy * dy > dist * dist or math.abs(character:getZ() - vehicle:getZ()) >= 1
end

-- 完好車的金工門檻（沙盒 DismantleWelding）；殘骸照原版不看技能
function D.dismantleSkill(vehicle)
    return D.isWreck(vehicle) and 0 or D.sandbox("DismantleWelding", 0)
end

-- 不能拆的原因；可以拆回 nil。"occupied"、"animals" 也給選單顯示用。
-- confirmedItems：玩家在確認框看到的車內物品數；nil 不檢查。三個參數都要傳（Kahlua 不替少傳的參數補 nil）
function D.blocked(character, vehicle, confirmedItems)
    if vehicle:isRemovedFromWorld() then return "gone" end
    -- 先查車的狀態再查距離：玩家從遠處按右鍵時，選單也要顯示這兩個原因
    if vehicle:hasPassenger() then return "occupied" end -- BaseVehicle.java:1848
    if vehicle:getAnimals():size() > 0 then return "animals" end -- BaseVehicle.java:10713
    if D.far(character, vehicle, D.MAX_DIST) then return "far" end
    local skill = D.dismantleSkill(vehicle)
    if skill > 0 and character:getPerkLevel(Perks.MetalWelding) < skill then return "skill" end
    if confirmedItems ~= nil then
        local _, items = D.count(vehicle)
        if items > confirmedItems then return "items" end
    end
    return nil
end

-- 車內物品數的確認；沒經過本 MOD 選單的動作（原版殘骸入口、其他 MOD）沒有，回 nil
local function confirmedItems(action)
    return action.confirmed and action.confirmed.dismantleItems or nil
end

-- 完好車的拆解時間乘沙盒 DismantleTimeMult；殘骸照原版
local vanillaGetDuration = ISRemoveBurntVehicle.getDuration
function ISRemoveBurntVehicle:getDuration()
    local time = vanillaGetDuration(self)
    if time <= 1 or not self.vehicle or D.isWreck(self.vehicle) then return time end
    return math.max(1, math.floor(time * D.sandbox("DismantleTimeMult", 1)))
end

-- 參數名要和動作表的欄位同名：引擎照 new 的參數名從動作表取值送到伺服器，再用它們重建動作。
-- confirmed 是 { dismantleItems = n }，不是裸數字：別人只傳兩個參數時，Kahlua 可能留下別的值，表加欄位名才認得出來
local vanillaNew = ISRemoveBurntVehicle.new
function ISRemoveBurntVehicle:new(character, vehicle, confirmed)
    local o = vanillaNew(self, character, vehicle)
    if vehicle ~= nil and o.vehicle == nil then
        o.vehicle = vehicle
        o.maxTime = o:getDuration()
    end
    if type(confirmed) == "table" and type(confirmed.dismantleItems) == "number" then o.confirmed = confirmed end
    return o
end

-- 客戶端：條件不符時動作直接中止，玩家看得到；伺服器在 complete 重新檢查
local vanillaIsValid = ISRemoveBurntVehicle.isValid
function ISRemoveBurntVehicle:isValid()
    if not vanillaIsValid(self) then return false end
    return D.blocked(self.character, self.vehicle, confirmedItems(self)) == nil
end

-- 噴燈進度條上的字：完好車顯示本 MOD 的選項名稱，殘骸照原版
local vanillaUpdate = ISRemoveBurntVehicle.update
function ISRemoveBurntVehicle:update()
    vanillaUpdate(self)
    if not D.isWreck(self.vehicle) then
        self.item:setJobType(getText("ContextMenu_MinidoracatAnyCar_Dismantle"))
    end
end

local vanillaComplete = ISRemoveBurntVehicle.complete
function ISRemoveBurntVehicle:complete()
    local character, vehicle = self.character, self.vehicle
    if not character or not vehicle then return false end
    local who = D.who(character)
    local why = D.blocked(character, vehicle, confirmedItems(self))
    if why then
        print(D.LOG .. "refused (" .. why .. "): " .. who)
        return false
    end
    -- 車移除前先取資料
    local parts, items = D.count(vehicle)
    local line = string.format("SCRAP player=%s vehicle=%s id=%d at=%d,%d,%d parts=%d items=%d",
        who, tostring(vehicle:getScriptName()), vehicle:getSqlId(),
        math.floor(vehicle:getX()), math.floor(vehicle:getY()), math.floor(vehicle:getZ()), parts, items)
    local ok = vanillaComplete(self)
    if ok then writeLog("MinidoracatAnyCar", line) end
    return ok
end

-- 產出倍率：每次擲骰重複 LootMult 次，小數部分當成多擲一次的機率。只有 complete 會呼叫，所以在伺服器生效
local vanillaCheckAddItem = ISRemoveBurntVehicle.checkAddItem
function ISRemoveBurntVehicle:checkAddItem(item, baseChance)
    local got = false
    for _ = 1, D.rolls(1, D.sandbox("LootMult", 1)) do
        if vanillaCheckAddItem(self, item, baseChance) then got = true end
    end
    return got
end
