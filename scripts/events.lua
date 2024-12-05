local tracking = require("scripts/tracking_utils")

---@class LabData
---@field entity LuaEntity
---@field inventory LuaInventory
---@field unit_number uint
---@field assigned_tech? LuaTechnology

function on_init()
    storage.mod_enabled = false
    ---@type table <uint, LabData>
    storage.labs = {}
    tracking.initialize_labs()
end

function on_config_changed()
end

function on_player_created(event)
    game.get_player(event.player_index).set_shortcut_toggled("sr-toggle-simultaneous-research", storage.mod_enabled)
end

function on_lua_shortcut(event)
    if event.prototype_name == "sr-toggle-simultaneous-research" then
        storage.mod_enabled = not storage.mod_enabled
        for _, player in pairs(game.players) do
            player.set_shortcut_toggled("sr-toggle-simultaneous-research", storage.mod_enabled)
        end
    end
end

function on_built_lab(event)
    tracking.add_lab(event.entity)
end

function on_destroyed_lab(event)
    tracking.remove_lab(event.entity)
end


script.on_init(on_init)
script.on_configuration_changed(on_config_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)

local lab_filter = {filter = "type", type = "lab"}
script.on_event(defines.events.on_built_entity, function(event) on_built_lab(event) end, {lab_filter})
script.on_event(defines.events.on_robot_built_entity, function(event) on_built_lab(event) end, {lab_filter})
script.on_event(defines.events.script_raised_revive, function(event) on_built_lab(event) end, {lab_filter})
script.on_event(defines.events.script_raised_built, function(event) on_built_lab(event) end, {lab_filter})

script.on_event(defines.events.on_player_mined_entity, function(event) on_destroyed_lab(event) end, {lab_filter})
script.on_event(defines.events.on_robot_mined_entity, function(event) on_destroyed_lab(event) end, {lab_filter})
script.on_event(defines.events.script_raised_destroy, function(event) on_destroyed_lab(event) end, {lab_filter})
script.on_event(defines.events.on_entity_died, function(event) on_destroyed_lab(event) end, {lab_filter})