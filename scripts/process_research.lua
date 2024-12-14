local flib_table = require("__flib__.table")
local tracking = require("scripts/tracking_utils")
local utils = require("scripts/utils")

---Distriubtes labs between available research
function process_research_queue()
    local labs = storage.labs
    local queue = game.forces["player"].research_queue
    refresh_lab_inventory(labs)
    if settings.global["sr-research-mode"].value == "parallel" then
        distribute_research(labs, queue)
    else
        distribute_research_smart(labs, queue)
    end
end

---Checks both inventories of labs, digitizing science packs if necessary
---@param labs_data table <uint, LabData>
function refresh_lab_inventory(labs_data)
    for _, lab_data in pairs(labs_data) do
        local inventory_contents = lab_data.inventory.get_contents()
        local digital_inventory = lab_data.digital_inventory
        for _, item in pairs(inventory_contents) do
            if not digital_inventory[item.name] then digital_inventory[item.name] = 0 end
            if digital_inventory[item.name] < 1 then
                digitize_science_packs(item, lab_data)
            end
        end
    end
end

---Removes some science packs from the lab's regular inventory and adds their durability to the lab's digital inventory.
---@param item ItemWithQualityCounts
---@param lab_data LabData
---@return boolean --Returns true if at least one science pack was digitized
function digitize_science_packs(item, lab_data)
    local durability = prototypes.item[item.name].get_durability(item.quality)
    local removed = lab_data.inventory.remove({name = item.name, quality = item.quality, count = DIGITIZED_AMOUNT})
    lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] + durability * removed
    return removed > 0
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

---Assigns the first researchable tech in a queue to each lab
---@param labs table <uint, LabData>
---@param queue LuaTechnology[]
function distribute_research_smart(labs, queue)
    storage.all_labs_assigned = true
    for _, lab in pairs(labs) do
        lab.assigned_tech = nil
        for _, tech in pairs(queue) do
            if is_researchable(tech) and has_all_packs(lab, utils.normalize_to_set(tech.research_unit_ingredients)) then
                lab.assigned_tech = tech
                break
            end
        end
        if not lab.assigned_tech then storage.all_labs_assigned = false end
    end
end

---Distributes technologies between all labs.
---@param labs table <uint, LabData>
---@param queue LuaTechnology[]
function distribute_research(labs, queue)
    -- Step 1. Turn the queue array into something more useful

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
        else
            labs[lab_index].assigned_tech = nil -- Explicitly set to nil if no tech is valid
            storage.all_labs_assigned = false -- If any lab is unassigned, then we'll be occasionally reprocess them to reassign
        end
    end
end

---If at least one lab doesn't have assigned tech, then reprocess the queue
function update_lab_recheck()
    if not storage.all_labs_assigned then
        process_research_queue()
    end
end

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
script.on_nth_tick(NTH_TICK_FOR_LAB_RECHECK, update_lab_recheck)