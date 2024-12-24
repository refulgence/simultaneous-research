local flib_table = require("__flib__.table")
local tracking = require("scripts/tracking_utils")
local utils = require("scripts/utils")

---@class CurrentResearchData
---@field tech LuaTechnology
---@field labs uint[]
---@field labs_num uint
---@field progress double

---@class DigitizedPacksData
---@field name string
---@field count uint
---@field surface_index uint
---@field quality? string

---Distributes labs between available techs
function process_research_queue()
    local labs = storage.labs
    local queue = game.forces["player"].research_queue
    refresh_labs_inventory(labs)
    ---@type CurrentResearchData[]
    storage.current_research_data = {}
    if settings.global["sr-research-mode"].value == "parallel" then
        distribute_research(labs, queue)
    else
        distribute_research_smart(labs, queue)
    end
    if storage.mod_enabled then
        for _, player in pairs(game.players) do
            build_main_gui(player)
        end
    end
end

---Checks both inventories of all labs, digitizing science packs if necessary
---@param labs_data table <uint, LabData>
function refresh_labs_inventory(labs_data)
    local packs_digitized = {}

    ---@param lab_data LabData
    local function refresh_lab_inventory(lab_data)
        local inventory_contents = lab_data.inventory.get_contents()
        local digital_inventory = lab_data.digital_inventory
        local surface_index = lab_data.entity.surface_index
        for _, item in pairs(inventory_contents) do
            if not digital_inventory[item.name] then digital_inventory[item.name] = 0 end
            if digital_inventory[item.name] < 1 then
                local digitized = digitize_science_packs(item, lab_data)
                if digitized > 0 then
                    local name = surface_index .. "/" .. item.name .. "/" .. item.quality
                    if not packs_digitized[name] then packs_digitized[name] = {name = item.name, quality = item.quality, surface_index = surface_index, count = 0} end
                    packs_digitized[name].count = packs_digitized[name].count - digitized
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
---@param item ItemWithQualityCounts
---@param lab_data LabData
---@return uint --Returns number of science packs digitized
function digitize_science_packs(item, lab_data)
    local durability = prototypes.item[item.name].get_durability(item.quality)
    local removed = lab_data.inventory.remove({name = item.name, quality = item.quality, count = DIGITIZED_AMOUNT})
    lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] + durability * removed
    return removed
end

---Returns true if a technology can be researched right now.
---@param technology LuaTechnology
---@return boolean
function is_researchable(technology)
    for _, prerequisite in pairs(technology.prerequisites) do
        if not prerequisite.researched then
            return false
        end
    end
    return true
end

---Returns true is a given lab has access to all required science packs.
---@param lab LabData
---@param science_packs table
---@return boolean
function has_all_packs(lab, science_packs)
    for pack, _ in pairs(science_packs) do
        if not lab.digital_inventory[pack] or lab.digital_inventory[pack] <= 0 then
            return false
        end
    end
    return true
end

---For each lab assigns the first researchable tech in a queue to it
---@param labs table <uint, LabData>
---@param queue LuaTechnology[]
function distribute_research_smart(labs, queue)
    storage.all_labs_assigned = true
    for _, lab in pairs(labs) do
        lab.assigned_tech = nil
        for _, tech in pairs(queue) do
            if is_researchable(tech) and has_all_packs(lab, utils.normalize_to_set(tech.research_unit_ingredients)) then
                lab.assigned_tech = tech
                -- Adds research to the table to be used in GUI
                add_to_research_data(tech, lab)
                -- If the assigned tech isn't the first tech in the queue, then we'd need to recheck the queue later
                if game.forces["player"].current_research and game.forces["player"].current_research.name ~= tech.name then
                    storage.all_labs_assigned = false
                end
                break
            end
        end
        if not lab.assigned_tech then storage.all_labs_assigned = false end
    end
end

---@param tech LuaTechnology
---@param lab LabData
function add_to_research_data(tech, lab)
    local progress = 0
    if game.forces["player"].current_research and game.forces["player"].current_research.name == tech.name then
        progress = game.forces["player"].research_progress
    else
        progress = tech.saved_progress
    end
    if not storage.current_research_data[tech.name] then storage.current_research_data[tech.name] = {tech = tech, labs = {}, labs_num = 0, progress = math.floor(progress * 100)} end
    table.insert(storage.current_research_data[tech.name].labs, lab.unit_number)
    storage.current_research_data[tech.name].labs_num = storage.current_research_data[tech.name].labs_num + 1
end

---Distributes technologies between all labs.
---@param labs table <uint, LabData>
---@param queue LuaTechnology[]
function distribute_research(labs, queue)
    -- Step 1. Turn the queue table into something more useful

    ---Table indexed by technology name containing a set of science packs
    ---@type table <string, table <string, boolean>>
    local tech_pack_key_sets = {}
    for _, technology in pairs(queue) do
        -- Check if the technology can be researched
        if is_researchable(technology) then
            local ingredient_set = {}
            for _, ingredient in pairs(technology.research_unit_ingredients) do
                ingredient_set[ingredient.name] = true
            end
            tech_pack_key_sets[technology.name] = ingredient_set
        end
    end

    -- Step 2: Compute relevance scores for each lab against each technology pack
    local relevance_scores = {}
    for lab_index, lab in pairs(labs) do
        relevance_scores[lab_index] = {}
        for name, key_set in pairs(tech_pack_key_sets) do
            relevance_scores[lab_index][name] = has_all_packs(lab, key_set) and 1 or 0
        end
    end

    -- Step 3: Initialize table assignment counts
    local tech_pack_counts = {}
    for name, _ in pairs(tech_pack_key_sets) do
        tech_pack_counts[name] = 0
    end

    storage.all_labs_assigned = true
    -- Step 4: Assign labs to the best matching technology
    for lab_index, _ in pairs(labs) do
        local best_pack = nil
        local min_count = math.huge

        for name, score in pairs(relevance_scores[lab_index]) do
            if score > 0 and tech_pack_counts[name] < min_count then
                best_pack = name
                min_count = tech_pack_counts[name]
            end
        end

        -- Assign only if a valid technology is found
        if best_pack then
            labs[lab_index].assigned_tech = best_pack
            tech_pack_counts[best_pack] = tech_pack_counts[best_pack] + 1
            add_to_research_data(game.forces["player"].technologies[best_pack], labs[lab_index])
        else
            labs[lab_index].assigned_tech = nil -- Explicitly set to nil if no tech is valid
            storage.all_labs_assigned = false -- If any lab is unassigned, then we'll be occasionally reprocess them to reassign
        end
    end
end

---If at least one lab doesn't have assigned tech, then reprocess the queue
function update_lab_recheck()
    if not storage.all_labs_assigned and storage.mod_enabled then
        process_research_queue()
    end
end
script.on_nth_tick(NTH_TICK_FOR_LAB_RECHECK, update_lab_recheck)

---Updates lab data for speed/productivity effects
function update_labs()
    if storage.mod_enabled then
        if next(storage.labs) then
            storage.labs_update_index = flib_table.for_n_of(storage.labs, storage.labs_update_index, 1, function(lab_data)
                tracking.update_lab(lab_data)
            end)
        end
    end
end
script.on_nth_tick(NTH_TICK_FOR_LAB_UPDATE, update_labs)