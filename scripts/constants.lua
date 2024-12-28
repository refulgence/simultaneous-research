LABS_PER_SECOND_PROCESSED = 6 --Should be a clean divisor of 60 or it would be less accurate
NTH_TICK_FOR_LAB_PROCESSING = math.ceil(60 / LABS_PER_SECOND_PROCESSED)

-- How often we are going to recheck for new labs
NTH_TICK_FOR_LAB_RECHECK = 299

-- How often we update labs with their current speed/productivity (1 lab at a time)
NTH_TICK_FOR_LAB_UPDATE = 58

-- How many science packs are digitized per attempt
DIGITIZED_AMOUNT = 10

CHEAT_SPEED_MULTIPLIER = 1
CHEAT_PRODUCTIVITY_MULTIPLIER = 1

LAB_SCIENCE_DRAIN_RATE = {}
LAB_SCIENCE_DRAIN_RATE["lab"] = 1
LAB_SCIENCE_DRAIN_RATE["biolab"] = 0.5


-- GUI stuff
DEFAULT_PADDING = 8
RESEARCH_GUI_SIZE = {width = 240, height = 40}
RESEARCH_GUI_ICON_SIZE = {width = 32, height = 32}

-- Custom status
CUSTOM_STATUS_WORKING = {diode = defines.entity_status_diode.green, label = {"simultaneous-research.custom-status-active"}}
CUSTOM_STATUS_NO_RESEARCH = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-no-research"}}
CUSTOM_STATUS_NO_PACKS = {diode = defines.entity_status_diode.red, label = {"simultaneous-research.custom-status-no-packs"}}