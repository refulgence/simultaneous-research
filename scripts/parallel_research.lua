local flib_table = require("__flib__.table")

---Updates 1 lab at a time.
function update_research()
    if storage.mod_enabled then
        if next(storage.labs) then
            ::again::
            storage.labs_index = flib_table.for_n_of(storage.labs, storage.labs_index, 1, function(lab_data)
                return execute_research(lab_data)
            end)
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
    if not entity.valid then return nil, true, false end
    local tech
    if type(lab_data.assigned_tech) == "string" then
        tech = game.forces["player"].technologies[lab_data.assigned_tech]
    else
        tech = lab_data.assigned_tech
    end
    if not tech then return nil, false, false end
    local is_currently_researching = (game.forces["player"].current_research.name == tech.name)
    local reprocess_labs_flag = false
    local research_unit_count = tech.research_unit_count --units total
    local research_unit_energy = tech.research_unit_energy / 60 --seconds per research unit

    -- Consume fractions of science packs roughtly equal to what an actual lab would consume in the approximate amount of time since the last update
    for _, item in pairs(tech.research_unit_ingredients) do
        local consumed = item.amount / research_unit_energy * lab_data.speed * lab_data.science_pack_drain_rate * storage.lab_count_multiplier * CHEAT_SPEED_MULTIPLIER
        lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] - consumed
        if lab_data.digital_inventory[item.name] <= 0 then
            if DEBUG then
                game.print("Run out of science packs in a lab #" .. entity.unit_number ..", attempting digitization")
            end
            if not digitize_science_packs({name = item.name, count = 10, quality = "normal"}, lab_data) then
                reprocess_labs_flag = true
                if DEBUG then
                    game.print("Digitiztion failed")
                end
            end
        end
    end



    -- Give progress to the assigned technology and research it once it progress reaches 100%
    local progress_gained = 1 / research_unit_count / research_unit_energy * lab_data.speed * lab_data.productivity * storage.lab_count_multiplier * CHEAT_SPEED_MULTIPLIER * CHEAT_PRODUCTIVITY_MULTIPLIER
    
    local new_progress
    if is_currently_researching then
        new_progress = game.forces["player"].research_progress + progress_gained
    else
        new_progress = tech.saved_progress + progress_gained
    end
    if new_progress >= 1 then
        if DEBUG then
            game.print("Completed " .. tech.name .. " in a lab #" .. entity.unit_number)
        end
        research_tech(tech, lab_data)
    else
        if is_currently_researching then
            game.forces["player"].research_progress = new_progress
        else
            tech.saved_progress = new_progress
        end
        -- If a science pack got fully consumed and there is no replacement, then process research queue to redistribute labs
        -- No need to do this if a tech was researched, because that will trigger a reprocess as well
        if reprocess_labs_flag then process_research_queue() end
    end

    return nil, false, false
end

---@param tech LuaTechnology
---@param lab_data? LabData
function research_tech(tech, lab_data)
    tech.researched = true
    process_research_queue()
end


script.on_nth_tick(NTH_TICK_FOR_LAB_PROCESSING, update_research)