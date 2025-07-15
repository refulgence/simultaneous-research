data:extend(
{
	{
		type = "mod-data",
		name = "sr-lab-data",
        data = {},
	}
})

for _, lab in pairs(data.raw["lab"]) do
    data.raw["mod-data"]["sr-lab-data"].data[lab.name] = {uses_quality_drain_modifier = lab.uses_quality_drain_modifier}
end