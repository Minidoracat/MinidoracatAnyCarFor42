-- 車輛輪盤選單（坐駕駛座）：熱線的車加「配鑰匙」「拆除短接」。條件不足時照原版熱線項目的做法：熄火圖示、不能選、寫出缺什麼。
require "Vehicles/ISUI/ISVehicleMenu"
require "MinidoracatAnyCar/Keys"

local D = MinidoracatAnyCar

local ICON_ON = "media/ui/vehicles/vehicle_ignitionON.png"
local ICON_OFF = "media/ui/vehicles/vehicle_ignitionOFF.png"
local TEXT = { make = "ContextMenu_MinidoracatAnyCar_KeyMake", unwire = "ContextMenu_MinidoracatAnyCar_KeyUnwire" }
local REASON = { running = "Tooltip_MinidoracatAnyCar_EngineOff", nokey = "Tooltip_MinidoracatAnyCar_NeedKey" }

function D.onKeyJob(playerObj, job)
    ISTimedActionQueue.add(ISHotwireVehicle:new(playerObj, { job = job }))
end

local function addSlice(menu, playerObj, job)
    local why, rows = D.keyNeeds(playerObj, job)
    local text = getText(TEXT[job])
    if not why then
        menu:addSlice(text, getTexture(ICON_ON), D.onKeyJob, playerObj, job)
        return
    end
    -- 輪盤只認 \n（翻譯檔的 <br> 是 getText 換的）
    if REASON[why] then text = text .. "\n" .. getText(REASON[why]) end
    for _, row in ipairs(rows) do
        if row.have < row.need then
            local name = row.perk and PerkFactory.getPerk(row.perk):getName() or getItemName(row.item)
            text = text .. "\n" .. name .. " " .. row.have .. "/" .. row.need
        end
    end
    menu:addSlice(text, getTexture(ICON_OFF), nil, playerObj, job)
end

local vanillaShowRadialMenu = ISVehicleMenu.showRadialMenu
function ISVehicleMenu.showRadialMenu(playerObj)
    -- 原版在暫停時直接 return；選單開著時這次是關掉，會先清空項目（ISVehicleMenu.lua:57-75）
    local speed = UIManager.getSpeedControls()
    local paused = speed and speed:getCurrentGameSpeed() == 0
    vanillaShowRadialMenu(playerObj)
    local vehicle = playerObj:getVehicle()
    if paused or not vehicle or not vehicle:isDriver(playerObj) or not vehicle:isHotwired() or not D.sandbox("Keys", true) then return end
    local menu = getPlayerRadialMenu(playerObj:getPlayerNum())
    if #menu.slices == 0 then return end
    -- 有鑰匙時只列拆除短接；沒鑰匙時兩個都列，拆除短接寫明要鑰匙
    if not D.hasCarKey(playerObj, vehicle) then addSlice(menu, playerObj, "make") end
    addSlice(menu, playerObj, "unwire")
end
