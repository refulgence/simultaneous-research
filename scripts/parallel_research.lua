local flib_table = require("__flib__.table")
local tracking = require("scripts/tracking_utils")
local gui = require("scripts/gui/research")
local lab_utils = require("scripts/lab_utils")

---Updates one lab at a time.
function update_research()
    if storage.mod_enabled then
        for i = 1,LABS_PER_TICK_PROCESSED do
            if next(storage.labs) then
                ::again::
                storage.labs_index = flib_table.for_n_of(storage.labs, storage.labs_index, 1, function(lab_data)
                    return execute_research(lab_data)
                end)
                -- We need to do this to eliminate an empty update that happens at the end of every loop for some reason
                if storage.labs_index == nil then goto again end
            end
        end
    end
end

---Processes research for a lab
---@param lab_data LabData
---@return nil
---@return boolean --true to remove the data from the table, false to keep it
---@return boolean
function execute_research(lab_data)
    local entity = lab_data.entity
    if not entity.valid then
        -- Can't just call remove_lab here cause it will break the loop
        storage.lab_count = storage.lab_count - 1
        if lab_data.energy_source_type == "electric" then
            lab_data.energy_proxy.destroy()
        end
        tracking.recalc_count_multiplier()
        return nil, true, false
    end

    local tech
    if type(lab_data.assigned_tech) == "string" then
        tech = game.forces["player"].technologies[lab_data.assigned_tech]
    else
        tech = lab_data.assigned_tech
    end
    -- If there is no assigned tech, then just return
    if not tech then return nil, false, false end
    -- If the assigned tech is already researched, then the research queue wasn't reprocessed due to a bug, so we force it to happen
    if tech.researched then
        process_research_queue()
        return nil, false, false
    end

    -- For some inexplicable reason the saved progress for the currently researched tech is accessed in a completely different way.
    local is_currently_researching = false
    if game.forces["player"].current_research and game.forces["player"].current_research.name == tech.name then
        is_currently_researching = true
    end
    
    local research_unit_count = tech.research_unit_count --units total
    local research_unit_energy = tech.research_unit_energy / 60 --seconds per research unit
    local lab_multiplier = lab_data.speed * storage.lab_count_multiplier * CHEAT_SPEED_MULTIPLIER / research_unit_energy

    -- Give progress to the assigned technology and research it once it progress reaches 100%
    local science_produced = lab_multiplier * lab_data.productivity * CHEAT_PRODUCTIVITY_MULTIPLIER
    local progress_gained = science_produced / research_unit_count
    local new_progress
    local overshoot_multiplier = 1
    if is_currently_researching then
        new_progress = game.forces["player"].research_progress + progress_gained
    else
        new_progress = tech.saved_progress + progress_gained
    end
    if new_progress >= 1 then
        overshoot_multiplier = (1 + progress_gained - new_progress) / progress_gained
        -- Manually reset research progress because the game doesn't do it for us for infinite techs
        if is_currently_researching then
            game.forces["player"].research_progress = 0
        else
            tech.saved_progress = 0
        end
    else
        if is_currently_researching then
            game.forces["player"].research_progress = new_progress
        else
            tech.saved_progress = new_progress
        end
        storage.current_research_data[tech.name].progress = math.floor(new_progress * 100)
        gui.update_tech_button(tech.name)
    end

    -- Consume fractions of science packs roughtly equal to what an actual lab would consume in the approximate amount of time since the last update
    lab_multiplier = lab_multiplier * lab_data.science_pack_drain_rate * overshoot_multiplier
    if not lab_utils.consume_science_packs(lab_data, lab_multiplier, tech.research_unit_ingredients) then storage.all_labs_assigned = false end

    -- Consume energy for non-electric labs
    if not lab_utils.consume_energy(lab_data) then storage.all_labs_assigned = false end

    -- research_tech also triggers process_research_queue, so we need this thing to make sure it doesn't happen twice
    if new_progress >= 1 then
        ---@diagnostic disable-next-line: param-type-mismatch
        research_tech(tech)
    end

    add_statistics({{name = "science", type = "item", count = science_produced * overshoot_multiplier, surface_index = entity.surface_index}})
    add_pollution(lab_data)

    return nil, false, false
end

---@param tech LuaTechnology
function research_tech(tech)
    local tech_prototype = tech.prototype
    local message = {"", "[technology="..tech.name.."]",{"simultaneous-research.research-completed"}}
    if tech_prototype.max_level > 1 and tech.level < tech_prototype.max_level then
        --Clarifying the *actual* level of researched infinite tech, because the game doesn't properly support rich text for infinite techs
        local number = tonumber(tech.name:match("(%d+)$"))
        if  number ~= tech.level and (number or tech.level > 1) then
            message = {"", "[technology="..tech.name.."]",{"simultaneous-research.infinite-research-level", tech.level},{"simultaneous-research.research-completed"}}
        end
        tech.level = tech.level + 1
    else
        --Manually removing the researched tech from the research queue is needed for certain cases
        local research_queue = game.forces["player"].research_queue
        for i = #research_queue, 1 -1 do
            if research_queue[i].name == tech.name then
                table.remove(research_queue, i)
                break
            end
        end
        tech.researched = true
        game.forces["player"].research_queue = research_queue
    end
    game.print(message, {sound_path = "utility/research_completed"})
    process_research_queue()
end

---@param items DigitizedItemsData[]
function add_statistics(items)
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
function add_pollution(lab_data)
    -- return if pollution is disabled or lab doesn't emit pollution
    if not game.map_settings.pollution.enabled or not lab_data.emissions_per_second then return end
    local surface = lab_data.entity.surface
    local pollutant_type = surface.pollutant_type
    -- return if the surface has no pollutant or lab doesn't emit pollution of that type
    if not pollutant_type or not lab_data.emissions_per_second[pollutant_type.name] then return nil end
    local pollution = lab_data.emissions_per_second[pollutant_type.name] * lab_data.energy_consumption * storage.lab_count_multiplier * lab_data.pollution
    surface.pollute(lab_data.position, pollution, lab_data.entity)
end


script.on_nth_tick(NTH_TICK.lab_processing, update_research)