-- Utils related to production statistics

---@class Stats_utils
local stats_utils = {}

---Processes debt for that item and returns amount to be added to the statistics
---@param name string
---@param quality string
---@param amount int
---@param surface_index int
---@return int
function stats_utils.process_debt(name, quality, amount, surface_index)
    local result = 0
    stats_utils.initialize_debt(name, quality, surface_index)
    if storage.production_debt[surface_index][name][quality] > 0 then
        if storage.production_debt[surface_index][name][quality] > amount then
            result = 0
            storage.production_debt[surface_index][name][quality] = storage.production_debt[surface_index][name][quality] - amount
        else
            result = amount - storage.production_debt[surface_index][name][quality]
            storage.production_debt[surface_index][name][quality] = 0
        end
    else
        result = amount
    end
    return result
end

---@param name string
---@param quality string
---@param amount int
---@param surface_index int
function stats_utils.add_debt(name, quality, amount, surface_index)
    stats_utils.initialize_debt(name, quality, surface_index)
    storage.production_debt[surface_index][name][quality] = storage.production_debt[surface_index][name][quality] + amount
end

---@param name string
---@param quality string
---@param surface_index int
function stats_utils.initialize_debt(name, quality, surface_index)
    if not storage.production_debt[surface_index] then storage.production_debt[surface_index] = {} end
    if not storage.production_debt[surface_index][name] then storage.production_debt[surface_index][name] = {} end
    if not storage.production_debt[surface_index][name][quality] then storage.production_debt[surface_index][name][quality] = 0 end
end

---Updates a table with digitized item, accounting for production debt
---@param items_digitized table
---@param index_name string
---@param name string
---@param quality string
---@param type string
---@param surface_index int
---@param digitized int
function stats_utils.update_production_table(items_digitized, index_name, name, quality, type, surface_index, digitized)
    if not items_digitized[index_name] then items_digitized[index_name] = { name = name, quality = quality, type = type, surface_index = surface_index, count = 0 } end
    items_digitized[index_name].count = items_digitized[index_name].count - stats_utils.process_debt(name, quality, digitized, surface_index)
end

---@param items DigitizedItemsData[]
function stats_utils.add_statistics(items)
    local item_stats = {}
    local fluid_stats = {}
    for _, item in pairs(items) do
        local surface_index = item.surface_index
        if not item_stats[surface_index] then item_stats[surface_index] = game.forces["player"].get_item_production_statistics(surface_index) end
        if not fluid_stats[surface_index] then fluid_stats[surface_index] = game.forces["player"].get_fluid_production_statistics(surface_index) end
        if item.type == "item" then
            item_stats[surface_index].on_flow({name = item.name, quality = item.quality}, item.count)
        else
            fluid_stats[surface_index].on_flow(item.name, item.count)
        end
    end
end

---@param lab_data LabData
function stats_utils.add_pollution(lab_data)
    -- return if pollution is disabled or lab doesn't emit pollution
    if not game.map_settings.pollution.enabled or not lab_data.emissions_per_second then return end
    local surface = lab_data.entity.surface
    local pollutant_type = surface.pollutant_type
    -- return if the surface has no pollutant or lab doesn't emit pollution of that type
    if not pollutant_type or not lab_data.emissions_per_second[pollutant_type.name] then return nil end
    local pollution = lab_data.emissions_per_second[pollutant_type.name] * lab_data.energy_consumption * storage.lab_count_multiplier * lab_data.pollution
    surface.pollute(lab_data.position, pollution, lab_data.entity)
end

return stats_utils