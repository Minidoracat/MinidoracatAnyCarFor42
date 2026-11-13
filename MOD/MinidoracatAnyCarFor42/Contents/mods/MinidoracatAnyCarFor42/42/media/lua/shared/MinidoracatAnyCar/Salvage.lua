-- 零件拆解：卸下來的零件拆成材料。配方在 scripts/MinidoracatAnyCar_recipes.txt，零件清單由 Parts.lua 填。
-- 放在 shared：多人時 OnCreate 在伺服器執行，抽到的材料由伺服器放進背包。
require "MinidoracatAnyCar/Parts"

local D = MinidoracatAnyCar

D.SALVAGE_ROLLS = 3 -- 每拆一件抽幾次（再乘沙盒 SalvageMult）
D.SALVAGE_BASE = 40 -- 抽中率 %：SALVAGE_BASE + SALVAGE_PER_LEVEL ×（機械等級 + 這一類的技能等級）
D.SALVAGE_PER_LEVEL = 3

-- tools：腳本裡寫的工具列數（Parts.lua 用它判斷零件那一列加過沒有）
D.SALVAGE = {
    Door = { perk = "MetalWelding", tools = 2, items = { "Base.SheetMetal", "Base.SmallSheetMetal", "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal", "Base.Screws" } },
    Hood = { perk = "MetalWelding", tools = 2, items = { "Base.SheetMetal", "Base.SmallSheetMetal", "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal", "Base.Screws" } },
    TrunkLid = { perk = "MetalWelding", tools = 2, items = { "Base.SheetMetal", "Base.SmallSheetMetal", "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal", "Base.Screws" } },
    Trunk = { perk = "MetalWelding", tools = 2, items = { "Base.SheetMetal", "Base.SmallSheetMetal", "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal", "Base.Screws" } },
    Armor = { perk = "MetalWelding", tools = 2, items = { "Base.SheetMetal", "Base.SheetMetal", "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.MetalBar" } },
    GasTank = { perk = "MetalWelding", tools = 2, items = { "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal", "Base.MetalPipe" } },
    Muffler = { perk = "MetalWelding", tools = 2, items = { "Base.MetalPipe", "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal" } },
    Brake = { perk = "MetalWelding", tools = 2, items = { "Base.ScrapMetal", "Base.ScrapMetal", "Base.NutsBolts", "Base.SmallSheetMetal" } },
    Suspension = { perk = "MetalWelding", tools = 2, items = { "Base.MetalBar", "Base.ScrapMetal", "Base.ScrapMetal", "Base.NutsBolts" } },
    Accessory = { perk = "MetalWelding", tools = 2, items = { "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.ScrapMetal", "Base.Screws" } },
    Seat = { perk = "Tailoring", tools = 1, items = { "Base.RippedSheets", "Base.RippedSheets", "Base.LeatherStrips", "Base.ScrapMetal" } },
    Battery = { perk = "Electricity", tools = 1, items = { "Base.ElectricWire", "Base.ElectronicsScrap", "Base.ScrapMetal" } },
    GloveBox = { perk = "Mechanics", tools = 1, items = { "Base.SmallSheetMetal", "Base.ScrapMetal", "Base.Screws" } },
}

local function open(class)
    return D.sandbox("Salvage", true) and D.partsByClass[class] ~= nil
end

-- 配方的 OnTest（scripts 寫 MinidoracatAnyCar.salvageTest.<類別>）：沙盒關掉或這一類沒有零件時不能做
D.salvageTest = {}
for class in pairs(D.SALVAGE) do
    D.salvageTest[class] = function() return open(class) end
end

-- 配方的 OnAddToMenu：引擎只認全域函式名。和 OnTest 同一個條件，做不了的不列在製作清單
function MinidoracatAnyCar_salvageInMenu(params)
    local class = string.match(params.recipe:getName(), "^AnyCarSalvage(%a+)$")
    return class ~= nil and open(class)
end

function D.onSalvage(craftRecipeData, character)
    local class = string.match(craftRecipeData:getRecipe():getName(), "^AnyCarSalvage(%a+)$")
    local pool = class and D.SALVAGE[class]
    if not pool or not character then return end
    local chance = D.SALVAGE_BASE + D.SALVAGE_PER_LEVEL
        * (character:getPerkLevel(Perks.Mechanics) + character:getPerkLevel(Perks.FromString(pool.perk)))
    for _ = 1, D.rolls(D.SALVAGE_ROLLS, D.sandbox("SalvageMult", 1)) do
        if ZombRand(100) < chance then
            Actions.addOrDropItem(character, instanceItem(pool.items[ZombRand(#pool.items) + 1]))
        end
    end
end
