-- 零件分類：只看物品腳本，客戶端與伺服器在開機時各做一次，結果相同。
-- 分好的零件填進 scripts 的修法（fixing）與拆解配方（craftRecipe），新車的零件不用另外列清單。
MinidoracatAnyCar = MinidoracatAnyCar or {}
local D = MinidoracatAnyCar

D.LOG = "[MinidoracatAnyCarFor42] "

function D.sandbox(key, default)
    local value = SandboxVars.MinidoracatAnyCar and SandboxVars.MinidoracatAnyCar[key]
    if value == nil then return default end
    return value
end

-- 帳號名稱可以有空白與等號，直接寫進 log 會多出假欄位
function D.who(character)
    return string.gsub(tostring(character:getUsername()), "[%c%s=%[%]]", "_")
end

-- 倍率換成擲骰次數：整數部分是次數，小數部分是多擲一次的機率
function D.rolls(base, mult)
    local total = base * mult
    local rolls = math.floor(total)
    if total > rolls and ZombRandFloat(0, 1) < total - rolls then rolls = rolls + 1 end
    return rolls
end

-- 照順序比對物品短名（小寫）裡的字，第一個符合的就是類別；都不符合的歸 Accessory
D.RULES = {
    { "Armor", { "armor", "armour", "protection" } },
    { "Tire", { "tire", "tyre", "wheel" } },
    { "Brake", { "brake" } },
    { "Suspension", { "suspension" } },
    { "Window", { "windshield", "window" } },
    { "Hood", { "enginedoor", "hood" } },
    { "TrunkLid", { "trunkdoor", "trunklid", "tailgate" } },
    { "GasTank", { "gastank" } },
    { "GloveBox", { "glovebox" } },
    { "Trunk", { "trunk", "roofrack", "toolbox", "bedcover", "bedcap" } },
    { "Door", { "door" } },
    { "Seat", { "seat" } },
    { "Muffler", { "muffler" } },
    { "Battery", { "battery" } },
    { "Armor", { "bumper", "bullbar", "guard" } },
}

function D.classify(typeName)
    local name = string.lower(typeName)
    for _, rule in ipairs(D.RULES) do
        for _, word in ipairs(rule[2]) do
            if string.find(name, word, 1, true) then return rule[1] end
        end
    end
    return "Accessory"
end

-- 本 MOD 的修法名稱是 AnyCar_<類別>_<修法>；回傳類別與修法，別人的修法回 nil
function D.fixName(fixing)
    return string.match(fixing:getName(), "^AnyCar_(%a+)_(%a+)$")
end

D.partsByClass = {} -- 類別 -> { 物品全名, ... }

function D.registerParts()
    local scripts = getScriptManager()
    local ours, taken = {}, {}
    local fixings = scripts:getAllFixing(ArrayList.new())
    for i = 0, fixings:size() - 1 do
        local fixing = fixings:get(i)
        local class = D.fixName(fixing)
        if class then
            ours[class] = ours[class] or {}
            table.insert(ours[class], fixing)
        else
            -- 原版或別的 MOD 已經有修法的零件，不再加一套
            local required = fixing:getRequiredItem()
            for j = 0, required and required:size() - 1 or -1 do taken[required:get(j)] = true end
        end
    end

    D.partsByClass = {}
    local items = scripts:getAllItems()
    for i = 0, items:size() - 1 do
        local script = items:get(i)
        -- 車輛零件：物品腳本有 VehicleType（工具、油桶、燈泡、收音機都沒有）
        if script:isMechanicsLoot() and script:getConditionMax() > 0 then
            local full = script:getFullName()
            local item = instanceItem(full)
            if item and item:getMechanicType() > 0 then
                local class = D.classify(script:getName())
                D.partsByClass[class] = D.partsByClass[class] or {}
                table.insert(D.partsByClass[class], full)
                if not taken[full] then
                    for _, fixing in ipairs(ours[class] or {}) do
                        if not fixing:getRequiredItem():contains(full) then fixing:addRequiredItem(full) end
                    end
                end
            end
        end
    end

    -- 拆解配方：腳本只寫工具，零件那一列在這裡加上。這一類沒有零件就不加（配方由 OnTest 關掉）
    for class, list in pairs(D.partsByClass) do
        local recipe = scripts:getCraftRecipe("AnyCarSalvage" .. class)
        local pool = D.SALVAGE[class]
        if recipe and pool and recipe:getInputs():size() == pool.tools then
            recipe:Load(recipe:getName(), "craftRecipe " .. recipe:getName() .. " { inputs { item 1 ["
                .. table.concat(list, ";") .. "] mode:destroy flags[AllowDestroyedItem;ItemCount], } }")
        end
    end
end

Events.OnGameBoot.Add(D.registerParts)
