---@class Tracking
local tracking = {}


function tracking.initialize_labs()
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered({type = "lab"})) do
            tracking.add_lab(entity)
        end
    end
end

---Because the update rate of labs will vary depending on the number of labs
local function recalc_count_multiplier()
    storage.lab_count_multiplier = 1 / LABS_PER_SECOND_PROCESSED * storage.lab_count
end

---@param entity LuaEntity
function tracking.add_lab(entity)
    if not storage.labs[entity.unit_number] then
        local inventory = entity.get_inventory(defines.inventory.lab_input)
        if inventory then
            ---@type LabData
            local data = {
                entity = entity,
                inventory = inventory,
                unit_number = entity.unit_number,
                digital_inventory = {},
            }
            storage.labs[entity.unit_number] = data
            storage.lab_count = storage.lab_count + 1
            recalc_count_multiplier()
        end
    end
end

---@param entity LuaEntity|LabData
function tracking.remove_lab(entity)
    storage.labs[entity.unit_number] = nil
    storage.lab_count = storage.lab_count - 1
    recalc_count_multiplier()
end

---Disables all labs when mod is enabled and vice versa
function tracking.toggle_labs()
    for _, lab_data in pairs(storage.labs) do
        lab_data.entity.active = not storage.mod_enabled
    end
end


return tracking