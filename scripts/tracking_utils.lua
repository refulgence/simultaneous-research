---@class Tracking
local tracking = {}


function tracking.initialize_labs()
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities_filtered({type = "lab"})) do
            if entity.get_inventory(defines.inventory.lab_input) then
                if not storage.labs[entity.unit_number] then
                    tracking.add_lab(entity)
                else
                    tracking.refresh_lab(entity)
                end
            end
        end
    end
    storage.all_labs_assigned = false
end

---Fully refreshes lab_data for all labs, while retaining inventories and energy
function tracking.reinitialize_labs()
    local temp_storage = {}
    for unit_number, lab_data in pairs(storage.labs) do
        temp_storage[unit_number] = {
            digital_inventory = lab_data.digital_inventory,
            stored_energy = lab_data.stored_energy
        }
        tracking.remove_lab(lab_data.entity)
    end
    tracking.initialize_labs()
    for unit_number, data in pairs(temp_storage) do
        storage.labs[unit_number].digital_inventory = data.digital_inventory or {}
        storage.labs[unit_number].stored_energy = data.stored_energy or 0
    end
end

---Adds lab_data for the given lab entity and handles creation of energy_proxy
---@param entity LuaEntity
function tracking.add_lab(entity)
    local inventory = entity.get_inventory(defines.inventory.lab_input)
    entity.active = not storage.mod_enabled

    local lab_data = {
        entity = entity,
        inventory = inventory,
        unit_number = entity.unit_number,
        digital_inventory = {},
        position = entity.position,
        stored_energy = 0,
    }

    local prototype = entity.prototype
    if prototype.electric_energy_source_prototype then
        lab_data.energy_source_type = "electric"
        -- only electric labs use energy_proxy
        local energy_proxy = entity.surface.create_entity{
            name = "sr-lab-eei",
            position = entity.position,
            force = entity.force
        }
        energy_proxy.destructible = false
        energy_proxy.operable = false
        energy_proxy.active = storage.mod_enabled
        lab_data.energy_proxy = energy_proxy
    elseif prototype.burner_prototype then
        lab_data.energy_source_type = "burner"
        lab_data.burner_inventory = entity.get_inventory(defines.inventory.fuel)
        lab_data.burnt_result_inventory = entity.get_inventory(defines.inventory.burnt_result)
        lab_data.effectivity = prototype.burner_prototype.effectivity
    elseif prototype.heat_energy_source_prototype then
        lab_data.energy_source_type = "heat"
        lab_data.specific_heat = prototype.heat_energy_source_prototype.specific_heat
        lab_data.min_working_temperature = prototype.heat_energy_source_prototype.min_working_temperature
    elseif prototype.fluid_energy_source_prototype then
        lab_data.energy_source_type = "fluid"
        lab_data.effectivity = prototype.fluid_energy_source_prototype.effectivity
        lab_data.burns_fluid = prototype.fluid_energy_source_prototype.burns_fluid
        lab_data.fluidbox = entity.fluidbox
    elseif prototype.void_energy_source_prototype then
        lab_data.energy_source_type = "void"
    end

    storage.labs[entity.unit_number] = lab_data
    storage.lab_count = storage.lab_count + 1
    tracking.recalc_count_multiplier()
    tracking.refresh_lab(entity)
end

---Refreshes prototype-related parts of lab_data for the given lab entity
---@param entity LuaEntity
function tracking.refresh_lab(entity)
    local inventory = entity.get_inventory(defines.inventory.lab_input)
    local prototype = entity.prototype
    local lab_data = storage.labs[entity.unit_number]
    lab_data.inventory_size = #inventory
    lab_data.base_speed = prototype.get_researching_speed(entity.quality) or 1
    lab_data.science_pack_drain_rate = prototype.science_pack_drain_rate_percent / 100
    lab_data.emissions_per_second = tracking.get_emissions_per_second(entity)
    tracking.update_lab(lab_data)
end

---Returns pollution emissions per 60 joules (not per second despite the name) for this entity or nil if pollution is disabled or not present.
---@param entity LuaEntity
---@return double?
function tracking.get_emissions_per_second(entity)
    if not entity.surface.pollutant_type or not entity.surface.pollutant_type.name == "pollution" or not game.map_settings.pollution.enabled then return nil end
    local emissions_table = entity.electric_emissions_per_joule
    if not emissions_table or not emissions_table["pollution"] or emissions_table["pollution"] == 0 then return nil end
    -- We are multiplying it by 60 because this value is in ticks
    return emissions_table["pollution"] * 60
end

---Updates speed, productivity and pollution of a lab, as they can change during runtime.
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
    if storage.labs[entity.unit_number].energy_source_type == "electric" then
        storage.labs[entity.unit_number].energy_proxy.destroy()
    end
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
            if lab_data.energy_source_type == "electric" then
                lab_data.energy_proxy.active = storage.mod_enabled
            end
        end
    end
end

---@param lab_data LabData
function tracking.update_energy_usage(lab_data)
    local entity = lab_data.entity
    lab_data.energy_consumption = entity.prototype.get_max_energy_usage(entity.quality) * (1 + entity.consumption_bonus)
    -- Only electric labs use energy_proxy
    if lab_data.energy_source_type == "electric" then
        if storage.mod_enabled and lab_data.assigned_tech then
            lab_data.energy_proxy.power_usage = lab_data.energy_consumption
        else
            lab_data.energy_proxy.power_usage = 0
        end
    end
end

---Because the update rate of labs will vary depending on the number of labs
function tracking.recalc_count_multiplier()
    storage.lab_count_multiplier = 1 / LABS_PER_SECOND_PROCESSED * storage.lab_count
end

return tracking