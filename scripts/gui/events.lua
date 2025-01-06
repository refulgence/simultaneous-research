local gui = require("scripts/gui/research")

function on_gui_click(event)
    local player = game.get_player(event.player_index)
    local tags = event.element.tags
    local button = event.button
    if button == defines.mouse_button_type.left then
        if tags.on_left_click_action == "open_technology_screen" then
            ---@diagnostic disable-next-line: need-check-nil
            player.open_technology_gui(tags.technology_name)
            storage.all_labs_assigned = false
        end
    elseif button == defines.mouse_button_type.right then
        if tags.on_right_click_action == "pause_technology_research" then
            pause_technology_research(tags.technology_name)
        end
    end
end

---Toggles the pause state of the given technology
---@param technology_name string
function pause_technology_research(technology_name)
    if storage.current_research_data[technology_name].status == "active" then
        storage.current_research_data[technology_name].status = "paused"
    elseif storage.current_research_data[technology_name].status == "paused" then
        storage.current_research_data[technology_name].status = "active"
    end
    process_research_queue()
end


script.on_event(defines.events.on_gui_click, on_gui_click)