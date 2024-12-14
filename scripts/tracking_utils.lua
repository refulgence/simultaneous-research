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
function tracking.recalc_count_multiplier()
    storage.lab_count_multiplier = 1 / LABS_PER_SECOND_PROCESSED * storage.lab_count
end

---@param entity LuaEntity
function tracking.add_lab(entity)
    if not storage.labs[entity.unit_number] then
        local inventory = entity.get_inventory(defines.inventory.lab_input)
        if inventory then
            local prototype = entity.prototype
            ---@type LabData
            local data = {
                entity = entity,
                inventory = inventory,
                unit_number = entity.unit_number,
                digital_inventory = {},
                base_speed = prototype.get_researching_speed(entity.quality) or 1,
                science_pack_drain_rate = LAB_SCIENCE_DRAIN_RATE[prototype.name] or 1, -- can't grab the actual value for some reason
                speed = 1,  -- will be updated later
                productivity = 1,   -- will be updated later
            }
            tracking.update_lab(data)
            storage.labs[entity.unit_number] = data
            storage.lab_count = storage.lab_count + 1
            tracking.recalc_count_multiplier()
        end
    end
end

---Updates speed and productivity of a lab, as they can change during runtime.
---@param lab_data LabData
function tracking.update_lab(lab_data)
    local entity = lab_data.entity
    if not entity.valid then
        tracking.remove_lab(lab_data)
        return
    end
    -- Stupid speed_bonus being stupid
    lab_data.speed = lab_data.base_speed * (1 + (entity.speed_bonus - storage.lab_speed_modifier)) * (1 + storage.lab_speed_modifier)
    lab_data.productivity = 1 + entity.productivity_bonus
end

---@param entity LuaEntity|LabData
function tracking.remove_lab(entity)
    storage.labs[entity.unit_number] = nil
    storage.lab_count = storage.lab_count - 1
    tracking.recalc_count_multiplier()
end

---Disables all labs when mod is enabled and vice versa
function tracking.toggle_labs()
    for _, lab_data in pairs(storage.labs) do
        if not lab_data.entity.valid then
            tracking.remove_lab(lab_data)
        else
            lab_data.entity.active = not storage.mod_enabled
        end
    end
end


return tracking