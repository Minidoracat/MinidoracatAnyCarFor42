-- 拆車袋子的名稱：伺服器只記拆車人，名稱由每台客戶端用自己的語言組。
-- 伺服器替物品取的名字會照伺服器的語言存檔並送給所有玩家；客戶端取的名字只在本機。
require "ISUI/ISInventoryPane"
require "MinidoracatAnyCar/Dismantle"

local D = MinidoracatAnyCar

-- 容器裡（含裡面的袋子）每個拆車袋子；玩家自己改過名字的不動
function D.nameBags(container)
    if not container then return end
    local bags = container:getAllTypeRecurse(D.BAG)
    for i = 0, bags:size() - 1 do
        local bag = bags:get(i)
        local who = bag:hasModData() and bag:getModData()[D.BAG_BY]
        if who and not bag:isCustomName() then
            local name = getItemName(D.BAG) .. " (" .. tostring(who) .. ")"
            if bag:getDisplayName() ~= name then bag:setName(name) end
        end
    end
end

-- 客戶端收到物品時沒有事件；物品清單每次重整前先替要列出的袋子取名
-- shortcut: 物品欄上方袋子按鈕的標題在清單重整前就建好，第一次可能是原名；有人回報再包 ISInventoryPage.refreshBackpacks
local vanillaRefresh = ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer(...)
    D.nameBags(self.inventory)
    return vanillaRefresh(self, ...)
end
