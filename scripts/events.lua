function on_init()
    storage.mod_enabled = false
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

script.on_init(on_init)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)