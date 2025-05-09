---@class Tracking
local tracking = {}


function tracking.initialize_labs()
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered({type = "lab"})) do
            tracking.add_lab(entity)
        end
    end
    storage.all_labs_assigned = false
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
            local energy_proxy = entity.surface.create_entity{
                name = "sr-lab-eei",
                position = entity.position,
                force = entity.force
            }
            energy_proxy.destructible = false
            energy_proxy.operable = false
            energy_proxy.active = storage.mod_enabled
            entity.active = not storage.mod_enabled
            ---@type LabData
            local data = {
                entity = entity,
                inventory = inventory,
                inventory_size = #inventory,
                unit_number = entity.unit_number,
                digital_inventory = {},
                base_speed = prototype.get_researching_speed(entity.quality) or 1,
                science_pack_drain_rate = prototype.science_pack_drain_rate_percent / 100;
                speed = 1,  -- will be updated later
                productivity = 1,   -- will be updated later
                pollution = 1, -- will be updated later
                energy_consumption = 0, -- will be updated later
                energy_proxy = energy_proxy,
                position = entity.position
            }
            tracking.update_lab(data)
            data.emissions_per_second = tracking.get_emissions_per_second(entity, data.energy_consumption)
            storage.labs[entity.unit_number] = data
            storage.lab_count = storage.lab_count + 1
            tracking.recalc_count_multiplier()
        end
    end
end

---Returns pollution emissions per 60 joules (not per second despite the name) for this entity or nil if pollution is disabled or not present.
---@param entity LuaEntity
---@return double?
function tracking.get_emissions_per_second(entity, energy_consumption)
    if not entity.surface.pollutant_type or not entity.surface.pollutant_type.name == "pollution" or not game.map_settings.pollution.enabled then return nil end
    local emissions_table = entity.electric_emissions_per_joule
    if not emissions_table or not emissions_table["pollution"] or emissions_table["pollution"] == 0 then return nil end
    -- We are multiplying it by 60 because this value is in ticks
    return emissions_table["pollution"] * 60
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
    lab_data.pollution = 1 + entity.pollution_bonus

    local force_index = entity.force.index
    -- Adjusting productivity for techs that do and do not allow force productivity
    if game.forces[force_index].current_research and game.forces[force_index].current_research.prototype.allows_productivity then
        if lab_data.assigned_tech and not lab_data.assigned_tech.prototype.allows_productivity then
            lab_data.productivity = lab_data.productivity - game.forces[force_index].laboratory_productivity_bonus
        end
    else
        if lab_data.assigned_tech and lab_data.assigned_tech.prototype.allows_productivity then
            lab_data.productivity = lab_data.productivity + game.forces[force_index].laboratory_productivity_bonus
        end
    end

    tracking.update_energy_usage(lab_data)
end

---@param entity LuaEntity|LabData
function tracking.remove_lab(entity)
    storage.labs[entity.unit_number].energy_proxy.destroy()
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
            lab_data.energy_proxy.active = storage.mod_enabled
        end
    end
end

---@param lab_data LabData
function tracking.update_energy_usage(lab_data)
    local entity = lab_data.entity
    lab_data.energy_consumption = entity.prototype.get_max_energy_usage(entity.quality) * (1 + entity.consumption_bonus)
    if storage.mod_enabled and lab_data.assigned_tech then
        lab_data.energy_proxy.power_usage = lab_data.energy_consumption
    else
        lab_data.energy_proxy.power_usage = 0
    end
end

return tracking