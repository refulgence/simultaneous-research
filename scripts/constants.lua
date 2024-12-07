LABS_PER_SECOND_PROCESSED = 6 --Should be a clean divisor of 60 or it would be less accurate
NTH_TICK_FOR_LAB_PROCESSING = math.ceil(60 / LABS_PER_SECOND_PROCESSED)

-- How often we are going to recheck for new labs
NTH_TICK_FOR_LAB_RECHECK = 299

CHEAT_SPEED_MULTIPLIER = 1
CHEAT_PRODUCTIVITY_MULTIPLIER = 1

LAB_SCIENCE_DRAIN_RATE = {}
LAB_SCIENCE_DRAIN_RATE["lab"] = 1
LAB_SCIENCE_DRAIN_RATE["biolab"] = 0.5

DEBUG = true