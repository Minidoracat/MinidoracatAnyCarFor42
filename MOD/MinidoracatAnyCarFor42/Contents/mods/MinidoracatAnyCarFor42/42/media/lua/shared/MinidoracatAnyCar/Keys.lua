-- 車鑰匙：配鑰匙、拆除短接沿用原版熱線動作（ISHotwireVehicle），多帶一個表參數；複製鑰匙是 craftRecipe（scripts/MinidoracatAnyCar_recipes.txt）。
-- 放在 shared：多人時 complete 與 OnCreate 在伺服器執行，條件由伺服器重新檢查。
require "Vehicles/TimedActions/ISHotwireVehicle"
require "MinidoracatAnyCar/Parts"

local D = MinidoracatAnyCar

-- make：替熱線的車配第一把鑰匙；unwire：拆掉短接，之後要鑰匙才能發動。
-- perks 是函式：門檻可以來自沙盒，竊賊特質照原版熱線免技能
D.KEYS = {
    make = {
        log = "KEYMAKE", time = 600,
        tools = { { "Base.Screwdriver", { ItemTag.SCREWDRIVER } }, { "Base.File", { ItemTag.FILE, ItemTag.SMALL_FILES } } },
        material = { "Base.SmallSheetMetal", 1 },
        perks = function()
            return { { Perks.MetalWelding, D.sandbox("KeysWelding", 3) }, { Perks.Mechanics, D.sandbox("KeysMechanics", 3) } }
        end,
    },
    unwire = {
        log = "UNWIRE", time = 200,
        tools = { { "Base.Screwdriver", { ItemTag.SCREWDRIVER } } },
        perks = function(character)
            if character:hasTrait(CharacterTrait.BURGLAR) then return {} end
            return { { Perks.Electricity, 1 }, { Perks.Mechanics, 2 } }
        end,
    },
}

local function notBroken(item)
    return not item:isBroken()
end

local function hasTool(inventory, tags)
    for _, tag in ipairs(tags) do
        if inventory:getFirstTagEvalRecurse(tag, notBroken) then return 1 end
    end
    return 0
end

-- 這台車的鑰匙在玩家身上（主背包或鑰匙圈，和原版發動引擎相同）、插在點火開關或車門上
function D.hasCarKey(character, vehicle)
    return character:getInventory():haveThisKeyId(vehicle:getKeyId()) ~= nil or vehicle:isKeysInIgnition() or vehicle:isKeyIsOnDoor()
end

-- 回傳：不能做的原因（可以做是 nil）、條件清單（給選單顯示）。兩個參數都要傳；車是玩家坐的那一台
-- 清單每列 { item = 物品全名 | perk = 技能, have = 現有, need = 需要 }
function D.keyNeeds(character, job)
    local spec = D.KEYS[job]
    local vehicle = character:getVehicle()
    if not spec or not vehicle or not vehicle:isDriver(character) then return "gone", {} end
    local inventory = character:getInventory()
    local rows, why = {}, nil
    local function row(entry, reason)
        table.insert(rows, entry)
        if entry.have < entry.need and not why then why = reason end
    end
    for _, perk in ipairs(spec.perks(character)) do
        row({ perk = perk[1], have = character:getPerkLevel(perk[1]), need = perk[2] }, "skill")
    end
    for _, tool in ipairs(spec.tools) do
        row({ item = tool[1], have = hasTool(inventory, tool[2]), need = 1 }, "tools")
    end
    if spec.material then
        row({ item = spec.material[1], have = inventory:getCountTypeRecurse(spec.material[1]), need = spec.material[2] }, "materials")
    end
    if not D.sandbox("Keys", true) then return "disabled", rows end
    if vehicle:isEngineRunning() or vehicle:isEngineStarted() then return "running", rows end
    if not vehicle:isHotwired() then return "nothotwired", rows end
    local hasKey = D.hasCarKey(character, vehicle)
    if job == "make" and hasKey then return "haskey", rows end
    if job == "unwire" and not hasKey then return "nokey", rows end
    return why, rows
end

function D.keyWork(character, job)
    local spec = D.KEYS[job]
    local why = D.keyNeeds(character, job)
    if why then return D.refuse(string.lower(spec.log), why, character) end
    local vehicle = character:getVehicle()
    if job == "make" then
        local key = vehicle:createVehicleKey()
        if not key then return D.refuse("keymake", "nokey", character) end
        D.takeItems(character:getInventory(), spec.material[1], spec.material[2])
        Actions.addOrDropItem(character, key)
    else
        vehicle:cheatHotwire(false, false) -- 伺服器上會同步給所有客戶端
    end
    writeLog("MinidoracatAnyCar", string.format("%s player=%s vehicle=%s id=%d keyid=%d", spec.log, D.who(character),
        tostring(vehicle:getScriptName()), vehicle:getSqlId(), vehicle:getKeyId()))
    return true
end

-- 參數名要和動作表的欄位同名（多人照參數名送值）。anycar 是 { job = "make" | "unwire" }；
-- 原版與別的 MOD 只傳一個參數，這時不是表，照原版熱線
local vanillaNew = ISHotwireVehicle.new
function ISHotwireVehicle:new(character, anycar)
    local o = vanillaNew(self, character)
    if type(anycar) == "table" and D.KEYS[anycar.job] then
        o.anycar = anycar
        o.maxTime = o:getDuration()
    end
    return o
end

local vanillaDuration = ISHotwireVehicle.getDuration
function ISHotwireVehicle:getDuration()
    if not self.anycar then return vanillaDuration(self) end
    if self.character:isTimedActionInstant() then return 1 end
    return D.KEYS[self.anycar.job].time
end

-- 客戶端：只因沙盒關掉中止。其他條件（熱線、鑰匙、材料）會被做完那一刻的同步改掉，
-- 在這裡中止會連後面排的動作一起清掉；這些由伺服器在 complete 重新檢查
local vanillaIsValid = ISHotwireVehicle.isValid
function ISHotwireVehicle:isValid()
    if not vanillaIsValid(self) then return false end
    return not self.anycar or D.sandbox("Keys", true)
end

local vanillaComplete = ISHotwireVehicle.complete
function ISHotwireVehicle:complete()
    if not self.anycar then return vanillaComplete(self) end
    return D.keyWork(self.character, self.anycar.job)
end

-- ===== 複製鑰匙（craftRecipe AnyCarCopyCarKey） =====

-- 配方的 OnTest，每個輸入物品各呼叫一次：沙盒關掉時不能做；車鑰匙要有編號
function D.copyKeyTest(item, character)
    local isKey = item:hasTag(ItemTag.CAR_KEY)
    if not D.sandbox("Keys", true) then
        if isServer() and isKey and character then D.refuse("keycopy", "disabled", character) end
        return false
    end
    return not isKey or item:getKeyId() ~= -1
end

-- 配方的 OnAddToMenu：引擎只認全域函式名
function MinidoracatAnyCar_keysInMenu()
    return D.sandbox("Keys", true)
end

-- 來源鑰匙是玩家選的那一把：背包右鍵時引擎把點的物品放進輸入（HandcraftLogic.setRecipeFromContextClick）
function D.onCopyKey(craftRecipeData, character)
    local source, made = craftRecipeData:getFirstInputItemWithTag(ItemTag.CAR_KEY), craftRecipeData:getFirstCreatedItem()
    if not source or not made or not character then return end
    local key = instanceItem("Base.CarKey")
    key:setKeyId(source:getKeyId())
    -- 原版車鑰匙的名稱本來就是伺服器端取的（BaseVehicle.keyNamerVehicle），照抄才和來源鑰匙一致；getName 會加損壞等前綴
    key:setName(source:getDisplayName())
    key:setColor(source:getColor())
    key:setCustomColor(true)
    -- 產出在 OnCreate 之前就已經送給客戶端（ISHandcraftAction.performRecipe），換成設好的這一把，客戶端才拿得到編號
    local container, onFloor = made:getContainer(), made:getWorldItem()
    if container then
        container:DoRemoveItem(made)
        sendRemoveItemFromContainer(container, made)
    elseif onFloor then -- 背包超重時 addOrDropItem 放在地上（同 ISTransferAction 撿起地上物品）
        onFloor:getSquare():transmitRemoveItemFromSquare(onFloor)
        onFloor:getSquare():removeWorldObject(onFloor)
        made:setWorldItem(nil)
    end
    Actions.addOrDropItem(character, key)
    writeLog("MinidoracatAnyCar", string.format("KEYCOPY player=%s keyid=%d", D.who(character), key:getKeyId()))
end
