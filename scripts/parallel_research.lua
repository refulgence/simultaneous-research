local flib_table = require("__flib__.table")
local tracking = require("scripts/tracking_utils")
local gui = require("scripts/gui/research")

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
    
    local reprocess_labs_flag = false
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
        ---@diagnostic disable-next-line: param-type-mismatch
        research_tech(tech)
    else
        if is_currently_researching then
            game.forces["player"].research_progress = new_progress
        else
            tech.saved_progress = new_progress
        end
        storage.current_research_data[tech.name].progress = math.floor(new_progress * 100)
        gui.update_tech_button(tech.name)
        -- If a science pack got fully consumed and there is no replacement, then process research queue to redistribute labs
        -- No need to do this if a tech was researched, because that will trigger reprocessing as well
        if reprocess_labs_flag then process_research_queue() end
    end

    -- Consume fractions of science packs roughtly equal to what an actual lab would consume in the approximate amount of time since the last update
    lab_multiplier = lab_multiplier * lab_data.science_pack_drain_rate * overshoot_multiplier
    for _, item in pairs(tech.research_unit_ingredients) do
        local consumed = lab_multiplier * item.amount
        lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] - consumed
        if lab_data.digital_inventory[item.name] <= 0 then
            refresh_labs_inventory({lab_data})
            if lab_data.digital_inventory[item.name] <= 0 then
                lab_data.entity.custom_status = CUSTOM_STATUS.no_packs
                reprocess_labs_flag = true
            end
        end
    end

    add_statistics({{name = "science", count = science_produced * overshoot_multiplier, surface_index = entity.surface_index}})
    add_pollution(lab_data)

    return nil, false, false
end

---@param tech LuaTechnology
function research_tech(tech)
    local tech_prototype = tech.prototype
    if tech_prototype.max_level > 1 and tech.level < tech_prototype.max_level then
        tech.level = tech.level + 1
    else
        tech.researched = true
    end
    game.print({"", "[technology="..tech.name.."]",{"simultaneous-research.research-completed"}}, {sound_path = "utility/research_completed"})
    process_research_queue()
end

---@param items DigitizedPacksData[]
function add_statistics(items)
    local stats = {}
    for _, item in pairs(items) do
        local surface_index = item.surface_index
        if not stats[surface_index] then stats[surface_index] = game.forces["player"].get_item_production_statistics(surface_index) end
        stats[surface_index].on_flow({name = item.name, quality = item.quality}, item.count)
    end
end

---@param lab_data LabData
function add_pollution(lab_data)
    if not lab_data.emissions_per_second then return end
    local surface = lab_data.entity.surface
    local pollution = lab_data.emissions_per_second * lab_data.energy_consumption * storage.lab_count_multiplier * lab_data.pollution
    surface.pollute(lab_data.position, pollution, lab_data.entity)
end


script.on_nth_tick(NTH_TICK.lab_processing, update_research)