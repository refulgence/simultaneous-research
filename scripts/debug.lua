local tracking = require("scripts/tracking_utils")

---@class Debug
local debug = {}

function debug.research(command)
    if not command.parameter then command.parameter = "1" end
    local index = tonumber(command.parameter)
    local tech_queue = game.forces["player"].research_queue
    local tech = tech_queue[index]
    if not tech then return end
    ---@diagnostic disable-next-line: param-type-mismatch
    research_tech(tech)
end

function debug.set_speed(command)
    if not command.parameter then command.parameter = "1" end
    game.print("Speed multiplier set to " .. command.parameter)
    CHEAT_SPEED_MULTIPLIER = tonumber(command.parameter)
end

function debug.set_productivity(command)
    if not command.parameter then command.parameter = "1" end
    game.print("Productivity multiplier set to " .. command.parameter)
    CHEAT_PRODUCTIVITY_MULTIPLIER = tonumber(command.parameter)
end

function debug.reprocess_all_labs(command)
    game.print("Reprocessing all labs.")
    storage.all_labs_assigned = false
    for _, lab in pairs(storage.labs) do
        tracking.remove_lab(lab)
    end
    storage.lab_count = 0
    tracking.initialize_labs()
    process_research_queue()
end

function debug.refill_labs(command)
    if not command.parameter then command.parameter = "10" end
    local amount = tonumber(command.parameter)
    game.print("Refilling all labs with " .. amount .. " science packs of each type.")
    for _, lab in pairs(storage.labs) do
        local inputs = lab.entity.prototype.lab_inputs
        if inputs then
            for _, input in pairs(inputs) do
                if not lab.digital_inventory[input] then
                    lab.digital_inventory[input] = amount
                else
                    lab.digital_inventory[input] = lab.digital_inventory[input] + amount
                end
                
            end
        end
    end
end

function debug.list_labs(command)
    for _, lab in pairs(storage.labs) do
        local tech_name = "none"
        if type(lab.assigned_tech) == "table" then
            tech_name = lab.assigned_tech.name
        elseif type(lab.assigned_tech) == "string" then
            ---@diagnostic disable-next-line: cast-local-type
            tech_name = lab.assigned_tech
        end
        local packs = ""
        for pack_name, pack_amount in pairs(lab.digital_inventory) do
            packs = packs .. "[img=item." .. pack_name .. "] " .. math.floor(pack_amount * 100) / 100 .. ", "
        end
        game.print("Lab #" .. lab.unit_number .. " assigned to " .. tech_name .. " with packs: " .. packs)
    end
end

commands.add_command("sr_list_labs", nil, function(command) debug.list_labs(command) end)
commands.add_command("sr_research", nil, function(command) debug.research(command) end)
commands.add_command("sr_research_speed", nil, function(command) debug.set_speed(command) end)
commands.add_command("sr_research_productivity", nil, function(command) debug.set_productivity(command) end)
commands.add_command("sr_refill_labs", nil, function(command) debug.refill_labs(command) end)
commands.add_command("sr_reprocess_all_labs", nil, function(command) debug.reprocess_all_labs(command) end)