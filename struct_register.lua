-- struct_register.lua - registration callbacks for structures.

--[[
The cellworld table contains the following structure-related entries:
cellworld = {
	structures = {
		[st_name] = {...} -- all registered structures.
	}
	structure_set = {
		-- the active structure set config, which determines grid size, mapgen base node a.s.o as passed to config_structure_set()
		name = "foo" -- name of the active structure set (which is actually the first parameter), not specified in table.
		grid_size = 7 -- how many nodes form a cell.
		mapgen_base_node = "air" -- which node to place by default in map, passed to singlenode mg. TODO not implemented yet.
	}
	-- the most important settings from structure set are copied for easier access
	grid_size = structure_set.grid_size,
	
	-- of all registered structures, the maximum extents in x, y and z direction.
	maximum_structure_size = vector.new(1,1,1)
}
]]--

cellworld.structures = {}

function cellworld.config_structure_set(name, definition)
	if cellworld.structure_set then
		error("Cellworld: Trying to register structure set '"..name.."', but '"..cellworld.structure_set.name..
			"' has already been registered. There can only be one active structure set at a time.")
	end
	cellworld.structure_set = {
		name = name,
		grid_size = 9,
		seed_structure = definition.seed_structure,
	}
	if definition.grid_size then
		cellworld.structure_set.grid_size = definition.grid_size
	end
	
	cellworld.grid_size = cellworld.structure_set.grid_size
	
	cellworld.maximum_structure_size = vector.new(1,1,1)
end

function cellworld.register_structure(name, def)
	-- make definition checks
	if not cellworld.structure_set then
		error("Cellworld: can not register structures when config_structure_set() hasn't been called!")
	elseif def.structure_set and def.structure_set ~= cellworld.structure_set.name then
		error("Cellworld: Structure '"..name.."' can not be registered because the structure set it was defined for ('"..name..
			"') doesn't match the active structure set ('"..cellworld.structure_set.name.."')!")
	end
	
	if not def.chance then
		def.chance = 50
	end
	
	-- TODO validate structure of cells
	
	cellworld.structures[name] = def
	
	-- update maxstructsize
	local mss = cellworld.maximum_structure_size
	mss.x = math.max(def.size.x, mss.x)
	mss.y = math.max(def.size.y, mss.y)
	mss.z = math.max(def.size.z, mss.z)
	
end
