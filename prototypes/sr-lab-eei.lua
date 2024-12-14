local entity = {
    name = "sr-lab-eei",
    type = "electric-energy-interface",
    icons = {{
        icon  = "__base__/graphics/icons/lab.png",
        icon_size = 64,
        icon_mipmaps = 4,
      }},
    picture = {
        filename = "__simultaneous-research__/graphics/nothing.png",
        height = 1,
        width = 1,
    },
    hidden = true,
    flags = {"placeable-neutral", "not-selectable-in-game", "not-on-map", "not-rotatable", "not-flammable", "placeable-off-grid"},
    collision_mask = {layers = {}},
	selectable_in_game = false,
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    energy_source = {
        type = "electric",
        buffer_capacity = "5MJ",
        usage_priority = "secondary-input",
    },
    energy_production = "0kW",
    energy_usage = "0kW",
    gui_mode = "none",
}

data:extend{entity}