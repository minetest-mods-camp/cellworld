-- misc. utilities

-- returns a list of directions to where this cell in a structure is at the structure border.
-- returns an empty list for inner nodes
-- horizontal_only restricts search to only the horizontal plane (no y)
function cellworld.get_border_sides(rel_pos, str_size, horizontal_only)
	local borders = {}
	
	if rel_pos.z == str_size.z-1 then
		borders[#borders+1] = cellworld.NORTH
	end
	if rel_pos.x == str_size.x-1 then
		borders[#borders+1] = cellworld.EAST
	end
	
	if rel_pos.z == 0 then
		borders[#borders+1] = cellworld.SOUTH
	end
	if rel_pos.x == 0 then
		borders[#borders+1] = cellworld.WEST
	end
	
	if not horizontal_only then
		if rel_pos.y == str_size.y-1 then
			borders[#borders+1] = cellworld.UP
		end
		if rel_pos.y == 0 then
			borders[#borders+1] = cellworld.DOWN
		end
	end
	
	return borders
	
end

cellworld.opposite_directions = {
	[cellworld.EAST] = cellworld.WEST,
	[cellworld.WEST] = cellworld.EAST,
	[cellworld.NORTH]= cellworld.SOUTH,
	[cellworld.SOUTH]= cellworld.NORTH,
	[cellworld.UP]   = cellworld.DOWN,
	[cellworld.DOWN] = cellworld.UP,
}

cellworld.direction_to_vector = {
	[cellworld.EAST] = vector.new(1,0,0),
	[cellworld.WEST] = vector.new(-1,0,0),
	[cellworld.NORTH]= vector.new(0,0,1),
	[cellworld.SOUTH]= vector.new(0,0,-1),
	[cellworld.UP]   = vector.new(0,1,0),
	[cellworld.DOWN] = vector.new(0,-1,0),
}

-- quickly hash a position. Only suitable for relative positions, limited to a range of 0..255 each coordinate
function cellworld.small_pos_hash(x,y,z)
	return y*65536 + x*256 + z
end

-- returns the relative structure cell definition
function cellworld.get_structure_cell(struct, relpos)
	if struct.cells then
		local pstr = relpos.x.."|"..relpos.y.."|"..relpos.z
		if struct.cells[pstr] then
			return struct.cells[pstr]
		end
	end
	return struct.cell
end

cellworld.pcgrandom = PcgRandom(os.time())

function cellworld.random(min, max)
	return cellworld.pcgrandom:next(min,max)
end

-- returns random element from the list
function cellworld.select_random_element(list)
	local r = cellworld.random(1, #list)
	return list[r]
end

-- returns a for iterator that iterates from 'from' to 'to' integers but in random order
function iterate_random_order(from, to)
	local list = {}
	for i=from,to do
		list[#list+1] = i
	end
	return function()
		if #list==0 then return nil end
		local r = cellworld.random(1, #list)
		return table.remove(list, r)
	end
end

function cellworld.v_decompose(vec)
	return vec.x, vec.y, vec.z
end

-- convert back and forth
function cellworld.world_to_cell_pos(wpos)
	if not cellworld.grid_size then
		error("Grid size hasn't been configured yet, is a structure set loaded?")
	end
	return vector.new(
		math.floor(wpos.x / cellworld.grid_size),
		math.floor(wpos.y / cellworld.grid_size),
		math.floor(wpos.z / cellworld.grid_size)
	)
end

-- upper: output the upper corner of the cell
function cellworld.cell_to_world_pos(cpos, upper)
	if not cellworld.grid_size then
		error("Grid size hasn't been configured yet, is a structure set loaded?")
	end
	local wi=0
	if upper then
		wi = cellworld.grid_size-1
	end
	return vector.new(
		cpos.x * cellworld.grid_size + wi,
		cpos.y * cellworld.grid_size + wi,
		cpos.z * cellworld.grid_size + wi
	)
end
