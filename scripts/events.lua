local tracking = require("scripts/tracking_utils")

---@class LabData
---@field entity LuaEntity
---@field inventory LuaInventory
---@field unit_number uint
---@field digital_inventory table <string, uint>
---@field base_speed double
---@field speed double
---@field productivity double
---@field science_pack_drain_rate double
---@field assigned_tech? LuaTechnology|string

function on_init()
    storage.mod_enabled = false
    ---Main storage table for all tracked labs
    ---@type table <uint, LabData>
    storage.labs = {}
    ---Index for iterating storage.labs via flib_table.for_n_of for the sake of executing research
    storage.labs_index = 0
    ---Index for iterating storage.labs via flib_table.for_n_of for the sake of updating their speed/productivity
    storage.labs_update_index = 0
    storage.lab_count = 0
    ---Used to calculate the actual update rate of labs
    storage.lab_count_multiplier = 0
    ---True if all labs have assigned_tech. Used as a condition for reprocessing research queue
    storage.all_labs_assigned = false
    tracking.initialize_labs()
    process_research_queue()
end

function on_config_changed()
    tracking.initialize_labs()
    process_research_queue()
end

function on_runtime_mod_setting_changed(event)
    process_research_queue()
end

function on_player_created(event)
    game.get_player(event.player_index).set_shortcut_toggled("sr-toggle-simultaneous-research", storage.mod_enabled)
end

function on_lua_shortcut(event)
    if event.prototype_name == "sr-toggle-simultaneous-research" then
        storage.mod_enabled = not storage.mod_enabled
        tracking.toggle_labs()
        process_research_queue()
        for _, player in pairs(game.players) do
            player.set_shortcut_toggled("sr-toggle-simultaneous-research", storage.mod_enabled)
        end
    end
end

function on_built_lab(event)
    tracking.add_lab(event.entity)
    if storage.mod_enabled then event.entity.active = false end
    storage.all_labs_assigned = false
end

function on_destroyed_lab(event)
    tracking.remove_lab(event.entity)
end

function recheck_labs()
    storage.all_labs_assigned = false
end


script.on_init(on_init)
script.on_configuration_changed(on_config_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)
script.on_event("sr-open-research-gui", recheck_labs)

local lab_filter = {filter = "type", type = "lab"}
script.on_event(defines.events.on_built_entity, function(event) on_built_lab(event) end, {lab_filter})
script.on_event(defines.events.on_robot_built_entity, function(event) on_built_lab(event) end, {lab_filter})
script.on_event(defines.events.script_raised_revive, function(event) on_built_lab(event) end, {lab_filter})
script.on_event(defines.events.script_raised_built, function(event) on_built_lab(event) end, {lab_filter})

script.on_event(defines.events.on_player_mined_entity, function(event) on_destroyed_lab(event) end, {lab_filter})
script.on_event(defines.events.on_robot_mined_entity, function(event) on_destroyed_lab(event) end, {lab_filter})
script.on_event(defines.events.script_raised_destroy, function(event) on_destroyed_lab(event) end, {lab_filter})
script.on_event(defines.events.on_entity_died, function(event) on_destroyed_lab(event) end, {lab_filter})