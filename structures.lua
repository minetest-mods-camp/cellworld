-- cellworld test structures. Later, put this into separate mods

--[[ cellworld structure table
struct = {
	structure_set = "foo" -- the expected structure set. 
	size = {
		x = 1 -- how many grid units this spans horizontally in x direction
		y = 1 -- how many grid units this spans vertically in y direction
		z = 1 -- how many grid units this spans horizontally in z direction
	}
	
	no_rotate = false -- whether structure may not be rotated
	
	chance = 20 -- Chance of spawning this structure. = number of times inserted into the selection table
	
	-- to specify the structure, two approaches can be used: either table-based, or function-based
	-- Table-based:
	cells = {
		-- due to the way cellworld works, nodes are generated on a per-cell level. so, each grid_size^3 cube needs to be specified independently.
		["x|y|z" ] = {
			structure = {
				action = "fill", -- action to perform. Can be registered, to be specified later. For now, only 'fill' supported.
				node="default:air", -- remaining parameters are action-dependent. Here: node to fill with.
				param2 = 0, -- optional: param2 to set, defaults to 0, or
				param2 = {0,1,2,3}, -- table with 4 entries, per structure rotation
				coords = {-x,-y,-z, +x,+y,+z} -- specify bounds of filled area. Relative to node origin and rotated with structure rotation
			}
			exits = {
				[cellworld.EAST] = { -- the exit on the specified side of the structure exists and should be carved by this description if the neighboring structure also has an exit at this place.
					... actions ...
				}
			}
			-- exit definitions do nothing if the specified wall is not on the outside of the structure
			-- vertical exits do not exist currently.
			-- a missing exits table is synonym to an empty exits table.
		}
	}
	-- If an entry in cells does not exist (or the entire cells table), can also use
	cell = {
		..actions.. -- fallback if not in nodes table
	}
	
	-- function-based:
	make_node(gridnode_pos, vmiface) -- to be specified
	exit_exists(gridnode_pos, exit_dir)
	make_exit(gridnode_pos, exit_dir, vmiface)
}
]]--

-- Configure the current structure set. There can only be one active structure set at a time, so calling this twice results in an error.
cellworld.config_structure_set("space",{
	mapgen_base_node = "air",
	grid_size = 9,
	seed_structure = "space:platform",
})

cellworld.register_structure("space:nothing", {
	structure_set = "space", -- this could maybe also be a list... is there an use case for this?
	size = {
		x=1,
		y=1,
		z=1,
	},
	
	chance = 5,
	
	cell = {
		-- do nothing
		structure={},
		exits={}
	}
})

cellworld.register_structure("space:platform", {
	structure_set = "space",
	size = {
		x=1,
		y=1,
		z=1,
	},
	
	chance = 10,
	
	cell = {
		structure = {
			{action="fill", node="default:stone", coords = {2, 1, 2, 6, 1, 6}},
		},
		exits = {
			[cellworld.EAST] = {
				{action="fill", node="default:stone", coords = {7, 1, 3, 8, 1, 5}},
			},
			[cellworld.WEST] = {
				{action="fill", node="default:stone", coords = {0, 1, 3, 1, 1, 5}},
			},
			[cellworld.NORTH] = {
				{action="fill", node="default:stone", coords = {3, 1, 7, 5, 1, 8}},
			},
			[cellworld.SOUTH] = {
				{action="fill", node="default:stone", coords = {3, 1, 0, 5, 1, 1}},
			},
		}
	}
})

cellworld.register_structure("space:fountain", {
	structure_set = "space",
	size = {
		x=3,
		y=1,
		z=3,
	},
	
	chance = 1,
	
	cells = {
		["1|0|0"]={ -- south exit
			structure = {
				{action="fill", node="default:stonebrick", coords = {2, 1, 2, 6, 1, 6}},
				{action="fill", node="default:stonebrick", coords = {0, 1, 7, 8, 1, 8}},
			},
			exits = {
				[cellworld.SOUTH] = {
					{action="fill", node="default:stone", coords = {3, 1, 0, 5, 1, 1}},
				},
			}
		},
		["1|0|2"]={ -- north exit
			structure = {
				{action="fill", node="default:stonebrick", coords = {2, 1, 2, 6, 1, 6}},
				{action="fill", node="default:stonebrick", coords = {0, 1, 0, 8, 1, 1}},
			},
			exits = {
				[cellworld.NORTH] = {
					{action="fill", node="default:stone", coords = {3, 1, 7, 5, 1, 8}},
				},
			}
		},
		["0|0|1"]={ -- west exit
			structure = {
				{action="fill", node="default:stonebrick", coords = {2, 1, 2, 6, 1, 6}},
				{action="fill", node="default:stonebrick", coords = {7, 1, 0, 8, 1, 8}},
			},
			exits = {
				[cellworld.WEST] = {
					{action="fill", node="default:stone", coords = {0, 1, 3, 1, 1, 5}},
				},
			}
		},
		["2|0|1"]={ -- east exit
			structure = {
				{action="fill", node="default:stonebrick", coords = {2, 1, 2, 6, 1, 6}},
				{action="fill", node="default:stonebrick", coords = {0, 1, 0, 1, 1, 8}},
			},
			exits = {
				[cellworld.EAST] = {
					{action="fill", node="default:stone", coords = {7, 1, 3, 8, 1, 5}},
				},
			}
		},
		["1|0|1"]={ -- center
			structure = {
				{action="fill", node="default:stonebrick", coords = {0, 1, 0, 8, 1, 8}},
				{action="fill", node="default:stonebrick", coords = {2, 2, 2, 6, 2, 6}},
				{action="fill", node="air", coords = {3, 2, 3, 5, 2, 5}},
				{action="fill", node="default:water_source", coords = {4, 4, 4, 4, 4, 4}},
			},
		},
	},
	
	cell = {
		structure = {
		},
	}
})

cellworld.register_structure("space:stair", {
	structure_set = "space",
	size = {
		x=3,
		y=2,
		z=1,
	},
	
	chance = 5,
	
	cells = {
		["0|0|0"]={
			structure = {
				{action="fill", node="default:stone", coords = {2, 1, 2, 8, 1, 6}},
			},
			exits = {
				[cellworld.WEST] = {
					{action="fill", node="default:stone", coords = {0, 1, 3, 1, 1, 5}},
				},
				[cellworld.NORTH] = {
					{action="fill", node="default:stone", coords = {3, 1, 7, 5, 1, 8}},
				},
				[cellworld.SOUTH] = {
					{action="fill", node="default:stone", coords = {3, 1, 0, 5, 1, 1}},
				},
			}
		},
		["1|0|0"]={ -- middle lower part
			structure = {
				{action="fill", node="default:stone", coords = {8, 8, 2, 8, 8, 6}},
				{action="fill", node="default:stone", coords = {7, 7, 2, 7, 7, 6}},
				{action="fill", node="default:stone", coords = {6, 6, 2, 6, 6, 6}},
				{action="fill", node="default:stone", coords = {5, 5, 2, 5, 5, 6}},
				{action="fill", node="default:stone", coords = {4, 4, 2, 4, 4, 6}},
				{action="fill", node="default:stone", coords = {3, 3, 2, 3, 3, 6}},
				{action="fill", node="default:stone", coords = {2, 2, 2, 2, 2, 6}},
				{action="fill", node="default:stone", coords = {0, 1, 2, 1, 1, 6}},
			},
		},
		["2|1|0"]={
			structure = {
				{action="fill", node="default:stone", coords = {1, 1, 2, 6, 1, 6}},
				{action="fill", node="default:stone", coords = {0, 0, 2, 0, 0, 6}},
			},
			exits = {
				[cellworld.EAST] = {
					{action="fill", node="default:stone", coords = {7, 1, 3, 8, 1, 5}},
				},
				[cellworld.NORTH] = {
					{action="fill", node="default:stone", coords = {3, 1, 7, 5, 1, 8}},
				},
				[cellworld.SOUTH] = {
					{action="fill", node="default:stone", coords = {3, 1, 0, 5, 1, 1}},
				},
			}
		},
	},
	
	cell = {
		structure = {
			--{action="fill", node="default:stone", coords = {4, 4, 4, 4, 4, 4}},
		},
	}
})


