local flib_table = require("__flib__.table")
local tracking = require("scripts/tracking_utils")

---Updates one lab at a time.
function update_research()
    if storage.mod_enabled then
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

---Processes research for a lab
---@param lab_data LabData
---@return nil
---@return boolean --true to remove the data from the table, false to keep it
---@return boolean
function execute_research(lab_data)
    local entity = lab_data.entity
    if not entity.valid then
        -- Can't just call remova_lab here cause it will break the loop
        storage.lab_count = storage.lab_count - 1
        lab_data.energy_proxy.destroy()
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

    -- For some inexplicable reason the saved progress for the currently researched tech is accessed in a completely different way.
    local is_currently_researching = false
    if game.forces["player"].current_research and game.forces["player"].current_research.name == tech.name then
        is_currently_researching = true
    end
    
    local reprocess_labs_flag = false
    local research_unit_count = tech.research_unit_count --units total
    local research_unit_energy = tech.research_unit_energy / 60 --seconds per research unit
    local packs_consumed = {}

    -- Consume fractions of science packs roughtly equal to what an actual lab would consume in the approximate amount of time since the last update
    for _, item in pairs(tech.research_unit_ingredients) do
        local consumed = item.amount * lab_data.speed * lab_data.science_pack_drain_rate * storage.lab_count_multiplier * CHEAT_SPEED_MULTIPLIER / research_unit_energy
        lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] - consumed
        packs_consumed[item.name] = consumed * -1
        if lab_data.digital_inventory[item.name] <= 0 then
            if not digitize_science_packs({name = item.name, count = 10, quality = "normal"}, lab_data) then
                reprocess_labs_flag = true
            end
        end
    end

    -- Give progress to the assigned technology and research it once it progress reaches 100%
    local science_produced = lab_data.speed * lab_data.productivity * storage.lab_count_multiplier * CHEAT_SPEED_MULTIPLIER * CHEAT_PRODUCTIVITY_MULTIPLIER / research_unit_energy
    local progress_gained = science_produced / research_unit_count
    local new_progress
    if is_currently_researching then
        new_progress = game.forces["player"].research_progress + progress_gained
    else
        new_progress = tech.saved_progress + progress_gained
    end
    if new_progress >= 1 then
        -- Manually reset research progress because the game doesn't do it for us for infinite techs
        if is_currently_researching then
            game.forces["player"].research_progress = 0
        else
            tech.saved_progress = 0
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        research_tech(tech)
    else
        if is_currently_researching then
            game.forces["player"].research_progress = new_progress
        else
            tech.saved_progress = new_progress
        end
        -- If a science pack got fully consumed and there is no replacement, then process research queue to redistribute labs
        -- No need to do this if a tech was researched, because that will trigger reprocessing as well
        if reprocess_labs_flag then process_research_queue() end
    end

    add_statistics(entity.surface.index, packs_consumed, science_produced)

    return nil, false, false
end

---@param tech LuaTechnology
function research_tech(tech)
    game.print({"simultaneous-research.research-completed",tech.localised_name}, {sound_path = "utility/research_completed"})
    tech.researched = true
    process_research_queue()
end

---@param surface_index uint
---@param packs_consumed table <string, int>
---@param science_produced int
function add_statistics(surface_index, packs_consumed, science_produced)
    local stats = game.forces["player"].get_item_production_statistics(surface_index)
    for name, count in pairs(packs_consumed) do
        stats.on_flow(name, count)
    end
    stats.on_flow("science", science_produced)
end


script.on_nth_tick(NTH_TICK_FOR_LAB_PROCESSING, update_research)