---@class Tracking
local tracking = {}


function tracking.initialize_labs()
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered({type = "lab"})) do
            tracking.add_lab(entity)
        end
    end
end

---@param entity LuaEntity
function tracking.add_lab(entity)
    if not storage.labs[entity.unit_number] then
        local data = {
            entity = entity,
            inventory = entity.get_inventory(defines.inventory.lab_input),
            unit_number = entity.unit_number,
        }
        storage.labs[entity.unit_number] = data
    end
end

---@param entity LuaEntity|LabData
function tracking.remove_lab(entity)
    storage.labs[entity.unit_number] = nil
end


return tracking