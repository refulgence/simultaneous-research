local tracking = require("scripts/tracking_utils")

---@class Lab
local lab_utils = {}

---@param lab_data LabData
---@return boolean --true if the lab is active and working
function lab_utils.is_active(lab_data)
    local entity = lab_data.entity
    if storage.mod_enabled and lab_data.assigned_tech then
        return true
    else
        return false
    end
end

---@param lab_data LabData
---@param science_packs table
---@return boolean -- true if the lab can research a tech requiring given science packs
function lab_utils.can_research(lab_data, science_packs)
    return lab_utils.has_energy(lab_data) and lab_utils.has_all_packs(lab_data, science_packs)
end

---@param lab_data LabData
---@return boolean --true if the lab has energy to spend ("real" or simulated)
function lab_utils.has_energy(lab_data)
    local entity = lab_data.entity
    if lab_data.energy_source_type == "electric" then
        return lab_data.energy_proxy.energy > 0
    elseif lab_data.energy_source_type == "burner" then
        return lab_data.stored_energy > 0
    elseif lab_data.energy_source_type == "heat" then
        return entity.temperature > lab_data.min_working_temperature
    elseif lab_data.energy_source_type == "fluid" then
        return lab_data.stored_energy > 0
    elseif lab_data.energy_source_type == "void" then
        return true
    end
    lab_data.entity.custom_status = CUSTOM_STATUS.no_energy
    return false
end

---Returns true is a given lab has access to all required science packs.
---@param lab_data LabData
---@param science_packs table
---@return boolean
function lab_utils.has_all_packs(lab_data, science_packs)
    for pack, _ in pairs(science_packs) do
        if not lab_data.digital_inventory[pack] or lab_data.digital_inventory[pack] <= 0 then
            return false
        end
    end
    return true
end

---Checks inventories of all labs, digitizing science packs and fuel if necessary
---@param labs_data [LabData]
function lab_utils.refresh_labs_inventory(labs_data)
    local items_digitized = {}
    local surface_index

    local function digitize_science_packs(lab_data)
        local digital_inventory = lab_data.digital_inventory
        for i = 1, lab_data.inventory_size do
            local item = lab_data.inventory[i]
            if item.valid and item.valid_for_read and item.name and item.is_tool then
                ---@type LabPackStackData
                local item_data = {
                    name = item.name,
                    quality = item.quality.name,
                    durability = item.durability or 1,
                    max_durability = item.prototype.get_durability(item.quality.name),
                    spoil_percent = 1 - item.spoil_percent,
                    count = item.count
                }
                if not digital_inventory[item_data.name] then digital_inventory[item_data.name] = 0 end
                if digital_inventory[item_data.name] < 1 then
                    local digitized = lab_data.inventory.remove({ name = item_data.name, quality = item_data.quality, count = item_data.count })
                    if digitized > 0 then
                        local added_value = item_data.spoil_percent * (item_data.durability + (digitized - 1) * item_data.max_durability)
                        -- weak compatibility with Corrundum mod (Pressure Labs will digitize normal quality science packs at reduced efficiency)
                        if lab_data.entity.name == "pressure-lab" and item_data.quality == "normal" then added_value = added_value / 20 end
                        lab_data.digital_inventory[item_data.name] = lab_data.digital_inventory[item_data.name] + added_value
                        local name = surface_index .. "/" .. item_data.name .. "/" .. item_data.quality
                        if not items_digitized[name] then items_digitized[name] = { name = item_data.name, quality = item_data.quality, type = "item", surface_index = surface_index, count = 0 } end
                        items_digitized[name].count = items_digitized[name].count - digitized
                    end
                end
            end
        end
    end

    ---@param lab_data LabData
    local function digitize_fuel(lab_data)
        local burner_inventory = lab_data.burner_inventory
        local burnt_result_inventory = lab_data.burnt_result_inventory
        local fuel_item
        local burnt_result_item
        -- burner inventories can have multiple slots, so we check them all and break after discovering the first valid item
        for i = 1, #burner_inventory do
            ---@diagnostic disable-next-line: need-check-nil
            fuel_item = burner_inventory[i]
            if fuel_item.valid and fuel_item.valid_for_read then
                -- we will not digitize fuel items with burnt results, unless we can insert these result into the inventory
                if not fuel_item.prototype.burnt_result then
                    break
                else
                    burnt_result_item = {name = fuel_item.prototype.burnt_result.name, count = fuel_item.count}
                    ---@diagnostic disable-next-line: need-check-nil
                    if burnt_result_inventory.can_insert(burnt_result_item) then
                        break
                    else
                        fuel_item = nil
                        burnt_result_item = nil
                    end
                end
            end
        end
        -- return if we didn't found a valid fuel item
        if not fuel_item or not fuel_item.valid or not fuel_item.valid_for_read then return false end
        -- calculate how many items we can remove
        local insertable = fuel_item.count
        if burnt_result_item then
            ---@diagnostic disable-next-line: need-check-nil
            insertable = math.min(insertable, burnt_result_inventory.get_insertable_count(burnt_result_item))
        end
        local energy_per_fuel = fuel_item.prototype.fuel_value * lab_data.effectivity
        local fuel_name = fuel_item.name
        local fuel_quality = fuel_item.quality
        ---@diagnostic disable-next-line: need-check-nil
        local digitized = burner_inventory.remove({ name = fuel_item.name, count = insertable })
        if digitized > 0 then
            lab_data.stored_energy = lab_data.stored_energy + energy_per_fuel * digitized

            -- add to the statistics table
            local name = surface_index .. "/" .. fuel_name .. "/" .. fuel_quality.name
            if not items_digitized[name] then items_digitized[name] = {name = fuel_name, quality = fuel_quality, type = "item", surface_index = surface_index, count = 0} end
            items_digitized[name].count = items_digitized[name].count - digitized

            -- add burnt results to the inventory if needed
            if burnt_result_item then
                burnt_result_item.count = digitized
                ---@diagnostic disable-next-line: need-check-nil
                burnt_result_inventory.insert(burnt_result_item)

                -- add to the statistics table (burnt results are always normal quality it seems)
                local br_name = surface_index .. "/" .. burnt_result_item.name .. "/" .. "normal"
                if not items_digitized[br_name] then items_digitized[br_name] = {name = burnt_result_item.name, quality = "normal", type = "item", surface_index = surface_index, count = 0} end
                items_digitized[br_name].count = items_digitized[br_name].count + digitized
            end
        end
    end

        ---@param lab_data LabData
    local function digitize_fluid(lab_data)
        local fluidbox = lab_data.fluidbox
        if not fluidbox then return false end
        local fluid = fluidbox[#fluidbox]
        if not fluid then return false end
        local fluid_prototype = prototypes.fluid[fluid.name]
        local converted_energy = 0
        if lab_data.burns_fluid then
            converted_energy = fluid_prototype.fuel_value * lab_data.effectivity * fluid.amount
        else
            local temperature_value = fluid.temperature - fluid_prototype.default_temperature
            if temperature_value > 0 then
                converted_energy = temperature_value * fluid_prototype.heat_capacity * lab_data.effectivity * fluid.amount
            else
                return false
            end
        end
        lab_data.stored_energy = lab_data.stored_energy + converted_energy
        local name = surface_index .. "/" .. fluid.name .. "/" .. "normal"
        if not items_digitized[name] then items_digitized[name] = {name = fluid.name, type = "fluid", surface_index = surface_index, count = 0} end
        items_digitized[name].count = items_digitized[name].count - fluid.amount
        lab_data.entity.fluidbox[#fluidbox] = nil
    end

    for _, lab_data in pairs(labs_data) do
        if not lab_data.entity.valid then
            tracking.remove_lab(lab_data)
        else
            surface_index = lab_data.entity.surface_index
            digitize_science_packs(lab_data)
            if lab_data.stored_energy <= 0 then
                if lab_data.energy_source_type == "burner" then
                    digitize_fuel(lab_data)
                elseif lab_data.energy_source_type == "fluid" then
                    digitize_fluid(lab_data)
                end
            end
        end
    end

    add_statistics(items_digitized)
end

---@param lab_data LabData
---@param lab_multiplier double
---@param science_packs table
---@return boolean --false if run out of some packs
function lab_utils.consume_science_packs(lab_data, lab_multiplier, science_packs)
    local flag = true
    for _, item in pairs(science_packs) do
        lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] - lab_multiplier * item.amount
        if lab_data.digital_inventory[item.name] <= 0 then
            flag = false
        end
    end
    return flag
end

---@param lab_data LabData
---@return boolean --false if run out of energy
function lab_utils.consume_energy(lab_data)
    if lab_data.energy_source_type == "burner" or lab_data.energy_source_type == "fluid" then
        lab_data.stored_energy = lab_data.stored_energy - (lab_data.energy_consumption * storage.lab_count_multiplier * 60)
        return lab_data.stored_energy > 0
    elseif lab_data.energy_source_type == "heat" then
        local temperature = lab_data.entity.temperature
        local temperature_lost = lab_data.energy_consumption * storage.lab_count_multiplier * 60 / lab_data.specific_heat
        ---@diagnostic disable-next-line: cast-local-type
        if temperature_lost > temperature then temperature_lost = temperature end
        lab_data.entity.temperature = temperature - temperature_lost
        return temperature >= lab_data.min_working_temperature
    end
    return lab_utils.has_energy(lab_data)
end


return lab_utils