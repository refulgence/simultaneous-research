LABS_PER_SECOND_PROCESSED = 6 --Should be a clean divisor of 60 or it would be less accurate

NTH_TICK = {
    new_lab_recheck = 294, -- How often we are going to recheck for new labs
    lab_update = 58, -- How often we update labs with their current speed/productivity (1 lab at a time)
    lab_processing = math.ceil(60 / LABS_PER_SECOND_PROCESSED),
}

-- Debug multipliers
CHEAT_SPEED_MULTIPLIER = 1
CHEAT_PRODUCTIVITY_MULTIPLIER = 1

-- GUI stuff
DEFAULT_PADDING = 8
RESEARCH_GUI_SIZE = {width = 240, height = 40}
RESEARCH_GUI_ICON_SIZE = {width = 32, height = 32}
GUI_ADJUST = {
    normal = {x = 0, y = 0},
    remote = {x = 8 + 4 + 256, y = -8},
}

-- GUI style link
TECH_BUTTON_STATUS_STYLE_LINK = {
    active = "flib_slot_button_green",
    paused = "flib_slot_button_yellow",
    invalid = "flib_slot_button_red",
    neutral = "slot_button",
}

-- Custom status for labs
CUSTOM_STATUS = {
    working = {diode = defines.entity_status_diode.green, label = {"simultaneous-research.custom-status-active"}},
    no_research = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-no-research"}},
    no_packs = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-no-packs"}},
    no_fuel = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-no-fuel"}},
    no_fluid = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-no-fluid"}},
    low_temperature = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-low-temperature"}},
}