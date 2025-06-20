data:extend(
{
    {
        type = "string-setting",
        order = "af",
        name = "sr-research-mode",
        setting_type = "runtime-global",
        default_value = "parallel",
        allowed_values = {"parallel", "smart"},
    },
    {
        type = "double-setting",
        order = "aa",
        name = "sr-labs-per-second-processed", 
        setting_type = "startup",
        default_value = 12,
        allowed_values = {1,2,3,4,5,6,10,12,15,20,30,60,120,180,240,300,360,600,1200,1800,2400}, --Should be a clean divisor or multiple of 60 or it would be less accurate
    },
    -- {
    --     type = "double-setting",
    --     order = "aa",
    --     name = "sr-lab-update",
    --     setting_type = "startup",
    --     default_value = 58,
    -- },
    -- {
    --     type = "double-setting",
    --     order = "aa",
    --     name = "sr-new-lab-recheck",
    --     setting_type = "startup",
    --     default_value = 294,
    -- }
})