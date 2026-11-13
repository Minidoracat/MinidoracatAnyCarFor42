-- 補胎劑的掉落：加進原版修車相關的掉落表（伺服器與單人；多人的客戶端不生成容器內容）。
-- OnPostDistributionMerge 是引擎解析掉落表之前最後能改表的時機。
if isClient() then return end

local SEALANT = "MinidoracatAnyCar.TireSealant"

-- 掉落表名稱 -> 權重。對照：原版打氣筒在這些表的權重是 4–20
local PLACES = {
    MechanicShelfTools = 6,
    MechanicShelfWheels = 8,
    MechanicSpecial = 6,
    CarSupplyTools = 8,
    StoreShelfMechanics = 6,
    GasStorageMechanics = 6,
    CrateMechanics = 4,
    GarageMechanics = 3,
}
-- 修車廠車輛的車廂與手套箱
local VEHICLE_PLACES = {
    MechanicTruckBed = 6,
    MechanicGloveBox = 4,
}

-- 掉落表在同一個行程裡不一定重建：先拿掉自己上次加的，再加一次
local function put(items, weight)
    for i = #items - 1, 1, -2 do
        if items[i] == SEALANT then
            table.remove(items, i + 1)
            table.remove(items, i)
        end
    end
    items[#items + 1] = SEALANT
    items[#items + 1] = weight
end

local function inject()
    for name, weight in pairs(PLACES) do
        local place = ProceduralDistributions.list[name]
        if place and place.items then put(place.items, weight) end
    end
    for name, weight in pairs(VEHICLE_PLACES) do
        local place = VehicleDistributions[name]
        if place and place.items then put(place.items, weight) end
    end
end

Events.OnPostDistributionMerge.Add(inject)
