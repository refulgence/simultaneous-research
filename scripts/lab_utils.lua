local tracking = require("scripts/tracking_utils")
local stats_utils = require("scripts/stats_utils")

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

---Checks inventories of all labs, digitizing science packs and fuel if necessary. Returns true if all packs were digitized.
---@param labs_data [LabData]
---@return {all_packs_digitized: boolean}
function lab_utils.refresh_labs_inventory(labs_data)
    local items_digitized = {}
    local surface_index
    local result = {all_packs_digitized = true}

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
                        stats_utils.update_production_table(items_digitized, name, item_data.name, item_data.quality, "item", surface_index, digitized)
                    else
                        result.all_packs_digitized = false
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
            stats_utils.update_production_table(items_digitized, name, fuel_name, fuel_quality.name, "item", surface_index, digitized)

            -- add burnt results to the inventory if needed
            if burnt_result_item then
                burnt_result_item.count = digitized
                ---@diagnostic disable-next-line: need-check-nil
                burnt_result_inventory.insert(burnt_result_item)

                -- add to the statistics table (burnt results are always normal quality it seems)
                local br_name = surface_index .. "/" .. burnt_result_item.name .. "/" .. "normal"
                stats_utils.update_production_table(items_digitized, br_name, burnt_result_item.name, "normal", "item", surface_index, digitized * -1)
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
        stats_utils.update_production_table(items_digitized, name, fluid.name, "normal", "fluid", surface_index, fluid.amount)
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

    stats_utils.add_statistics(items_digitized)

    return result
end

---Returns digitized packs and fuel (soon) to physical state
---@param labs_data [LabData]
---@return {all_packs_undigitized: boolean}
function lab_utils.undigitize_inventory(labs_data)
    local surface_index
    local result = {all_packs_undigitized = true}

    ---@param lab_data LabData
    local function undigitize_packs(lab_data)
        local digital_inventory = lab_data.digital_inventory
        local done = {}
        for i = 1, lab_data.inventory_size do
            local item = lab_data.inventory[i]
            if item.valid and item.valid_for_read and item.name and item.is_tool then
                local research_points = digital_inventory[item.name]
                if research_points > 0 then
                    local research_points_to_remove = research_points
                    local count = item.count
                    local stack_size = item.prototype.stack_size
                    local durability = item.durability
                    local max_durability = item.prototype.get_durability(item.quality.name)
                    local spoil_percent = 1 - item.spoil_percent
                    local converted_packs = research_points / max_durability / spoil_percent

                    -- Check how many packs we can add to the inventory
                    local insertable = (stack_size - count - durability / max_durability + 1)
                    if insertable < converted_packs then
                        research_points_to_remove = research_points * insertable / converted_packs
                        converted_packs = insertable
                        result.all_packs_undigitized = false
                    end

                    local converted_packs_int, converted_packs_dec = math.modf(converted_packs)
                    local converted_durability = converted_packs_dec * max_durability
                    
                    -- Adjust durability
                    if durability + converted_durability > max_durability then
                        converted_durability = durability + converted_durability - max_durability
                        converted_packs_int = converted_packs_int + 1
                    end
                    if converted_durability > durability then
                        item.add_durability(converted_durability - durability)
                    else
                        item.drain_durability(durability - converted_durability)
                    end

                    -- Add packs to the inventory
                    item.count = count + converted_packs_int

                    -- Add to the production debt table to not count them as consumed again
                    stats_utils.add_debt(item.name, item.quality.name, converted_packs_int, surface_index)

                    -- Remove research points from digital inventory
                    digital_inventory[item.name] = digital_inventory[item.name] - research_points_to_remove
                end
                done[item.name] = true
            end
        end

        for name, research_points in pairs(digital_inventory) do
            if research_points >= 1 and not done[name] then
                local prototype = prototypes.item[name]
                local stack_size = prototype.stack_size
                local to_insert = research_points
                if to_insert > stack_size then
                    to_insert = stack_size
                    result.all_packs_undigitized = false
                else
                    to_insert = math.floor(to_insert)
                end

                stats_utils.add_debt(name, "normal", to_insert, surface_index)
                
                lab_data.inventory.insert({name = name, count = to_insert, quality = "normal"})
                digital_inventory[name] = digital_inventory[name] - to_insert
            end
        end
    end

    ---@param lab_data LabData
    local function undigitize_fuel(lab_data)
        -- TODO (or maybe not)
    end

    for _, lab_data in pairs(labs_data) do
        surface_index = lab_data.entity.surface_index
        undigitize_packs(lab_data)
        if lab_data.energy_source_type == "burner" then
            undigitize_fuel(lab_data)
        end
    end
    return result
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
    if not flag then
        flag = lab_utils.refresh_labs_inventory({lab_data}).all_packs_digitized
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