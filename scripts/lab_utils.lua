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
---@return boolean
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

return lab_utils