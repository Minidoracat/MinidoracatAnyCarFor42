-- 拆車袋子的名稱：伺服器只記拆車人，名稱由每台客戶端用自己的語言組。
-- 伺服器替物品取的名字會照伺服器的語言存檔並送給所有玩家；客戶端取的名字只在本機。
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPage"
require "MinidoracatAnyCar/Dismantle"

local D = MinidoracatAnyCar

-- 是拆車袋子就取名；玩家自己改過名字的不動
function D.nameBag(item)
    if item:getFullType() ~= D.BAG or not item:hasModData() or item:isCustomName() then return end
    local who = item:getModData()[D.BAG_BY]
    if not who then return end
    local name = getItemName(D.BAG) .. " (" .. tostring(who) .. ")"
    if item:getDisplayName() ~= name then item:setName(name) end
end

-- 容器裡（含裡面的袋子）每個拆車袋子，以及這個容器自己所屬的袋子
function D.nameBags(container)
    if not container then return end
    local own = container:getContainingItem()
    if own then D.nameBag(own) end
    local bags = container:getAllTypeRecurse(D.BAG)
    for i = 0, bags:size() - 1 do D.nameBag(bags:get(i)) end
end

-- 客戶端收到物品時沒有事件；物品清單每次重整前先替要列出的袋子取名
local vanillaRefresh = ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer(...)
    D.nameBags(self.inventory)
    return vanillaRefresh(self, ...)
end

-- 地上袋子的按鈕標題在清單重整前就用物品名稱建好，而且原版會直接選中袋子：建按鈕前先替腳邊九格的袋子取名
local vanillaBackpacks = ISInventoryPage.refreshBackpacks
function ISInventoryPage:refreshBackpacks(...)
    local playerObj = not self.onCharacter and getSpecificPlayer(self.player)
    local at = playerObj and playerObj:getCurrentSquare()
    if at then
        for dy = -1, 1 do
            for dx = -1, 1 do
                local square = getCell():getGridSquare(at:getX() + dx, at:getY() + dy, at:getZ())
                local objects = square and square:getWorldObjects()
                for i = 0, objects and objects:size() - 1 or -1 do
                    local item = objects:get(i):getItem()
                    if item then D.nameBag(item) end
                end
            end
        end
    end
    return vanillaBackpacks(self, ...)
end
