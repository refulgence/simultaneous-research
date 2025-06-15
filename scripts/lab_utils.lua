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

---Checks both inventories of all labs, digitizing science packs if necessary
---@param labs_data table <uint, LabData>
function lab_utils.refresh_labs_inventory(labs_data)
    local packs_digitized = {}

    ---@param lab_data LabData
    local function refresh_lab_inventory(lab_data)
        local digital_inventory = lab_data.digital_inventory
        local surface_index = lab_data.entity.surface_index
        for i = 1, lab_data.inventory_size do
            local item = lab_data.inventory[i]
            if item.valid and item.valid_for_read and item.name and item.is_tool then
                ---@type LabPackStackData
                local item_data = {
                    name = item.name,
                    quality = item.quality.name,
                    durability = item.durability or 1,
                    spoil_percent = 1 - item.spoil_percent,
                }
                if not digital_inventory[item_data.name] then digital_inventory[item_data.name] = 0 end
                if digital_inventory[item_data.name] < 1 then
                    local digitized = lab_utils.digitize_science_packs(item_data, lab_data)
                    if digitized > 0 then
                        local name = surface_index .. "/" .. item_data.name .. "/" .. item_data.quality
                        if not packs_digitized[name] then packs_digitized[name] = {name = item_data.name, quality = item_data.quality, surface_index = surface_index, count = 0} end
                        packs_digitized[name].count = packs_digitized[name].count - digitized
                    end
                end
            end
        end
    end

    for _, lab_data in pairs(labs_data) do
        if not lab_data.entity.valid then
            tracking.remove_lab(lab_data)
        else
            refresh_lab_inventory(lab_data)
        end
    end

    add_statistics(packs_digitized)
end

---Removes some science packs from the lab's regular inventory and adds their durability to the lab's digital inventory.
---@param item LabPackStackData
---@param lab_data LabData
---@return uint --Returns number of science packs digitized
function lab_utils.digitize_science_packs(item, lab_data)
    local removed = lab_data.inventory.remove({name = item.name, quality = item.quality, count = DIGITIZED_AMOUNT})
    if removed > 0 then
        lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] + item.spoil_percent * (item.durability + removed - 1)
    end
    return removed
end

return lab_utils