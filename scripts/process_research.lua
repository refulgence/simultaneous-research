local flib_table = require("__flib__.table")
local tracking = require("scripts/tracking_utils")
local utils = require("scripts/utils")

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
    create_current_research_data_table(queue)
    if settings.global["sr-research-mode"].value == "parallel" then
        distribute_research(labs, queue)
    else
        distribute_research_smart(labs, queue)
    end
    if storage.mod_enabled then
        for _, player in pairs(game.players) do
            build_main_gui(player)
        end
        -- If the queue is empty OR all techs in the queue are paused, set custom status of all labs to no research
        if not next(game.forces["player"].research_queue) or all_techs_paused() then
            set_all_lab_status(CUSTOM_STATUS.no_research)
        end
    end
end

---Initializes a table from the current research queue while keeping existing entries, unless they are no longer in the queue
---@param queue LuaTechnology[]
function create_current_research_data_table(queue)
    local techs_in_queue = {}
    local index = 1
    for _, tech in pairs(queue) do
        add_tech_to_research_data(tech, index)
        techs_in_queue[tech.name] = index
        index = index + 1
    end
    -- Removes entries that are no longer in the queue
    for tech_name, _ in pairs(storage.current_research_data) do
        if not techs_in_queue[tech_name] then
            storage.current_research_data[tech_name] = nil
        end
    end
    utils.sort_by_index()
end

---Adds an entry to current_research_data for the given tech
---@param tech LuaTechnology
---@param index uint
function add_tech_to_research_data(tech, index)
    local progress = 0
    if game.forces["player"].current_research and game.forces["player"].current_research.name == tech.name then
        progress = game.forces["player"].research_progress
    else
        progress = tech.saved_progress
    end
    -- Resets entry's lab-related fields is the tech is paused, reinitializes them otherwise
    if storage.current_research_data[tech.name] and storage.current_research_data[tech.name].status == "paused" then
        storage.current_research_data[tech.name].labs = {}
        storage.current_research_data[tech.name].labs_num = 0
        storage.current_research_data[tech.name].sort_index = index
    else
        storage.current_research_data[tech.name] = {
            ---@diagnostic disable-next-line: assign-type-mismatch
            tech = tech,
            labs = {},
            labs_num = 0,
            progress = math.floor(progress * 100),
            status = "invalid",
            sort_index = index
        }
    end
end

---Update current_research_data with the given lab
---@param tech LuaTechnology
---@param lab LabData
function add_lab_to_research_data(tech, lab)
    if not storage.current_research_data[tech.name] then add_tech_to_research_data(tech, 1) end
    local data = storage.current_research_data[tech.name]
    table.insert(data.labs, lab.unit_number)
    data.labs_num = data.labs_num + 1
    data.status = "active"
end

---Checks both inventories of all labs, digitizing science packs if necessary
---@param labs_data table <uint, LabData>
function refresh_labs_inventory(labs_data)
    local packs_digitized = {}

    ---@param lab_data LabData
    local function refresh_lab_inventory(lab_data)
        local digital_inventory = lab_data.digital_inventory
        local surface_index = lab_data.entity.surface_index
        for i = 1, lab_data.inventory_size do
            local item = lab_data.inventory[i]
            if item.valid and item.valid_for_read and item.name then
                ---@type LabPackStackData
                local item_data = {
                    name = item.name,
                    quality = item.quality.name,
                    durability = item.durability or 1,
                    spoil_percent = 1 - item.spoil_percent,
                }
                if not digital_inventory[item_data.name] then digital_inventory[item_data.name] = 0 end
                if digital_inventory[item_data.name] < 1 then
                    local digitized = digitize_science_packs(item_data, lab_data)
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
function digitize_science_packs(item, lab_data)
    local removed = lab_data.inventory.remove({name = item.name, quality = item.quality, count = DIGITIZED_AMOUNT})
    if removed > 0 then
        lab_data.digital_inventory[item.name] = lab_data.digital_inventory[item.name] + item.spoil_percent * (item.durability + removed - 1)
    end
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
        unassign_lab(lab)
        for _, tech in pairs(queue) do
            if is_researchable(tech) and has_all_packs(lab, utils.normalize_to_set(tech.research_unit_ingredients)) and storage.current_research_data[tech.name].status ~= "paused"  then
                set_research(tech, lab)
                if game.forces["player"].current_research and game.forces["player"].current_research.name ~= tech.name then
                    storage.all_labs_assigned = false
                end
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
    -- Step 1. Turn the queue table into something more useful

    ---Table indexed by technology name containing a set of science packs
    ---@type table <string, table <string, boolean>>
    local tech_pack_key_sets = {}
    for _, technology in pairs(queue) do
        -- Check if the technology can be researched
        if is_researchable(technology) and storage.current_research_data[technology.name].status ~= "paused" then
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
    for lab_index, lab in pairs(labs) do
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
            set_research(game.forces["player"].technologies[best_pack], lab)
            tech_pack_counts[best_pack] = tech_pack_counts[best_pack] + 1
        else
            unassign_lab(lab)
            storage.all_labs_assigned = false -- If any lab is unassigned, then we'll be occasionally reprocess them to reassign
        end
    end
end

---Sets research to a given lab
---@param tech LuaTechnology
---@param lab LabData
function set_research(tech, lab)
    lab.assigned_tech = tech
    lab.entity.custom_status = CUSTOM_STATUS.working
    add_lab_to_research_data(tech, lab)
end

---Unassigns research from a given lab
---@param lab LabData
function unassign_lab(lab)
    lab.assigned_tech = nil
    lab.entity.custom_status = CUSTOM_STATUS.no_packs
end

---Sets given status to all labs
---@param status? CustomEntityStatus
function set_all_lab_status(status)
    for _, lab in pairs(storage.labs) do
        if lab.entity.valid then
            lab.entity.custom_status = status
        else
            tracking.remove_lab(lab)
        end
    end
end

---@return boolean --true if all techs in the queue are paused, false otherwise
function all_techs_paused()
    for _, tech in pairs(storage.current_research_data) do
        if tech.status == "active" then return false end
    end
    return true
end

---If at least one lab doesn't have assigned tech, then reprocess the queue
function update_lab_recheck()
    if not storage.all_labs_assigned and storage.mod_enabled then
        process_research_queue()
    end
end
script.on_nth_tick(NTH_TICK.new_lab_recheck, update_lab_recheck)

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
script.on_nth_tick(NTH_TICK.lab_update, update_labs)