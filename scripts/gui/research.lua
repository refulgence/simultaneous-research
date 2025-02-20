---@class GUI
local gui = {}

---@param player LuaPlayer
function gui.destroy_gui(player)
    if player.gui.screen.sr_research_gui then player.gui.screen.sr_research_gui.destroy() end
end

---@param player LuaPlayer
function build_main_gui(player)
    if player.gui.screen.sr_research_gui then player.gui.screen.sr_research_gui.destroy() end
    local main_frame = player.gui.screen.add{
        type = "frame",
        name = "sr_research_gui",
        direction = "horizontal",
    }
    main_frame.tags = {on_left_click_action = "open_technology_screen"}
    main_frame.style.margin = 0
    main_frame.style.padding = 0
    gui.update_gui_position(player)

    if next(storage.current_research_data) then
        add_research_icons(player, main_frame)
    else
        local caption
        if next(game.forces["player"].research_queue) then
            caption = {"simultaneous-research.cannot-research-anything"}
        else
            caption = {"simultaneous-research.empty-research-queue"}
        end
        local stupid_gui_flow = main_frame.add{
            type = "flow",
            direction = "vertical",
        }
        stupid_gui_flow.add{type = "empty-widget"}.style.vertically_stretchable = true
        local stupider_gui_flow = stupid_gui_flow.add{
            type = "flow",
            direction = "horizontal",
        }
        stupider_gui_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
        local no_research_label = stupider_gui_flow.add{
            type = "label",
            caption = caption,
        }
        stupid_gui_flow.tags = {on_left_click_action = "open_technology_screen"}
        stupider_gui_flow.tags = {on_left_click_action = "open_technology_screen"}
        no_research_label.tags = {on_left_click_action = "open_technology_screen"}
        no_research_label.style.font = "default-bold"
        no_research_label.style.font_color = {r = 0.9, g = 0.2, b = 0.2}
        no_research_label.style.horizontal_align = "center"
        stupider_gui_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
        stupid_gui_flow.add{type = "empty-widget"}.style.vertically_stretchable = true
    end
end

function add_research_icons(player, parent_frame)
    local research_table = parent_frame.add{
        type = "table",
        name = "sr_research_table",
        direction = "horizontal",
        column_count = 7
    }
    research_table.style.cell_padding = 0
    research_table.style.margin = 0
    research_table.style.left_padding = 1
    research_table.style.horizontal_spacing = 1
    local current_research = storage.current_research_data
    for _, data in pairs(current_research) do
        add_research_icon(player, research_table, data)
    end
end

---@param player LuaPlayer
---@param parent_frame LuaGuiElement
---@param data CurrentResearchData
function add_research_icon(player, parent_frame, data)
    local tooltip
    if data.status == "invalid" then
        tooltip = {"", {"simultaneous-research.tech-button-tooltip-invalid-status", data.labs_num}, "\n", {"simultaneous-research.tech-button-tooltip-help-open-gui"}}
    else
        tooltip = {"", {"simultaneous-research.tech-button-tooltip", data.labs_num}, "\n", {"simultaneous-research.tech-button-tooltip-help-open-gui"}, "\n", {"simultaneous-research.tech-button-tooltip-help-toggle-pause"}}
    end
    local tech_name = data.tech.name
    local icon = parent_frame.add{
        type = "sprite-button",
        sprite = "technology/" .. tech_name,
        name = "sr_button_" .. tech_name,
        elem_tooltip = {type = "technology", name = tech_name},
        tooltip = tooltip,
        number = data.progress
    }
    icon.tags = {on_left_click_action = "open_technology_screen", on_right_click_action = "pause_technology_research", technology_name = tech_name}
    icon.style = TECH_BUTTON_STATUS_STYLE_LINK[data.status]
    icon.style.size = RESEARCH_GUI_ICON_SIZE
    icon.style.margin = 0
    icon.style.padding = 0
end

---@param tech_name string
function gui.update_tech_button(tech_name)
    local current_tech_data = storage.current_research_data[tech_name]
    for _, player in pairs(game.players) do
        local main_frame = player.gui.screen.sr_research_gui
        if not main_frame then return end
        local button = main_frame.sr_research_table["sr_button_" .. tech_name]
        if not button then return end
        button.number = current_tech_data.progress
        button.style = TECH_BUTTON_STATUS_STYLE_LINK[current_tech_data.status]
        ---@diagnostic disable-next-line: inject-field
        button.style.size = RESEARCH_GUI_ICON_SIZE
    end
end

---@param player LuaPlayer
function gui.update_gui_position(player)
    local main_frame = player.gui.screen.sr_research_gui
    if not main_frame then return end
    local position_type = "normal"
    if player.controller_type == defines.controllers.remote then
        position_type = "remote"
    end
    local resolution = player.display_resolution
    local scale = player.display_scale
    main_frame.style.size = RESEARCH_GUI_SIZE
    local location = {
        x = resolution.width - RESEARCH_GUI_SIZE.width * scale - DEFAULT_PADDING * scale - GUI_ADJUST[position_type].x * scale,
        y = DEFAULT_PADDING * scale + GUI_ADJUST[position_type].y * scale
    }
    main_frame.location = location
end

return gui