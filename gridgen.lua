-- gridgen.lua
-- Actual cell generation process. These methods are called by the mapgen callback to allocate enough structure cells.
-- All randomness happens here.

--[[
The mapgen callback initiates the gridgen as follows:
1. mapgen builds a list of unallocated cells it requires to generate the current chunk
2. as long as there are some left, pick one cell that has at least one neighbor generated, randomly
The neighbor cell should have an exit towards the picked unallocated cell, only if there are no such cells it may fall back to any cell.
3. instruct gridgen to generate from the cell that is present, into the direction of the missing cell.

Given a cell and a direction, the gridgen then performs the following heuristic:
1. initialize an area with the unallocated cell that was passed.
2. assuming the passed direction as "forward", expand the area left, right, up and down as long as there's free space or the maximum structure size is hit.
3. expand the area forward as long as there's space or the maximum structure size is hit
 -> maybe extend randomly into each of the 5 directions. Could lead to problems otherwise
The area now represents the maximum size of structures that would fit.
4. filter the structures that do not fit into the frame.
5. randomly select one of the remaining structures, taking their chance into account.
6. using the degrees of freedom the structure has inside the frame, choose a random position of the new structure.
if the origin cell had an exit: try to find a position so that the exit matches one of the new structure
]]--

local gg_verbose = function() end
--local gg_verbose = cellworld.log

-- Make gridgen generate at least the area specified by gp_min, gp_max (in grid units)
-- Important: area may span 255x255x255 cells at maximum!
function cellworld.gridgen_generate_cells(gp_min, gp_max)
	cellworld.log("Gridgen: generating area", gp_min, gp_max)
	
	-- let the allocation efficiently check whether one, all or some cells are allocated
	local alloc = cellworld.alloc_check_some_cells_allocated(gp_min, gp_max)
	if alloc == 2 then
		-- nothing to do
		cellworld.log("All cells allocated, nothing to do")
		return
	elseif alloc == 0 then
		-- no cells allocated. seed a 1x1 structure somewhere
		local posx, posy, posz = cellworld.random(gp_min.x, gp_max.x), cellworld.random(gp_min.y, gp_max.y), cellworld.random(gp_min.z, gp_max.z)
		local posv = vector.new(posx, posy, posz)
		local ones = vector.new(1,1,1)
		local seedst = cellworld.structure_set.seed_structure
		assert(seedst, "No seed structure defined")
		cellworld.log("No cells allocated, seeding", seedst,"at",posv)
		assert(vector.equals(cellworld.structures[seedst].size, ones))
		cellworld.alloc_set_structure(posv, seedst, 0, ones, true)
	end
	
	gg_verbose("generate_cells searching sprout positions")
	local count = 0
	while true do
		-- find cells as starting points
		-- {cell = <pos>, dir = <dir>}
		local cells_with_exit = {}
		local cells_without_exit = {}
		local ox, oy, oz = gp_min.x, gp_min.y, gp_min.z
		for x,y,z,cid in cellworld.alloc_get_area_iterator(gp_min, gp_max) do
			local stname, relpos, rotation = cellworld.alloc_resolve_cid(x,y,z,cid)
			assert(stname, "alloc_resolve_cid failed to resolve")
			assert(rotation==0, "Rotation is not supported yet")
			local struct = cellworld.structures[stname]
			if struct then
				-- check_borders
				local borders = cellworld.get_border_sides(relpos, struct.size)
				for _,dir in ipairs(borders) do
					local off = cellworld.direction_to_vector[dir]
					if not cellworld.alloc_get_cid(x+off.x, y+off.y, z+off.z) then
						-- possible candidate
						local cell = cellworld.get_structure_cell(struct, relpos)
						-- has it an exit here?
						if cell.exits and cell.exits[dir] then
							--gg_verbose("   found with exit",x,y,z,"dir",cellworld.dirrev[dir])
							table.insert(cells_with_exit, {cell=vector.new(x,y,z), dir=dir})
						else
							--gg_verbose("   found without exit",x,y,z,"dir",cellworld.dirrev[dir])
							table.insert(cells_without_exit, {cell=vector.new(x,y,z), dir=dir})
						end
					end
				end
			end
		end
		gg_verbose("generate_cells sprouting, found",#cells_with_exit,"cells with exit,",#cells_without_exit,"without.")
		-- select one of the sprouts randomly
		local selected_sprout, exit_present
		if #cells_with_exit > 0 then
			selected_sprout = cellworld.select_random_element(cells_with_exit)
			exit_present = true
		elseif #cells_without_exit > 0 then
			selected_sprout = cellworld.select_random_element(cells_without_exit)
		else
			-- both lists are empty. We're either done, or there was another problem.
			cellworld.log("generate_cells sprouted",count,"times")
			return
		end
		
		cellworld.gridgen_fit_structure(selected_sprout.cell, selected_sprout.dir, exit_present)
		count = count + 1
	end
end

local function can_i_has_space(lx, ly, lz, ux, uy, uz)
	-- this calls the iterator once to see if it produces a result
	local res = cellworld.alloc_get_area_iterator_raw(lx, ly, lz, ux, uy, uz)() ~= nil
	gg_verbose("Space check for area",lx,ly,lz,"<->",ux,uy,uz,"resulted in",(res and "BLOCKED" or "FREE"))
	return not res
end

-- Allocate and place a random structure in the space ahead of sprout_pos towards sprout_dir, try to match exits if requested.
function cellworld.gridgen_fit_structure(sprout_pos, sprout_dir, exit_present)
	gg_verbose("fit_structure started with sprout",sprout_pos,"direction",cellworld.dirrev[sprout_dir],"exit present",exit_present)
	local start_pos = vector.add(sprout_pos, cellworld.direction_to_vector[sprout_dir])
	local stx, sty, stz = cellworld.v_decompose(start_pos) -- Start position
	local slx, sly, slz = stx, sty, stz -- lower bound of free space
	local sux, suy, suz = stx, sty, stz -- upper bound of free space
	
	local max_struct_size = cellworld.maximum_structure_size
	local msx, msy, msz = cellworld.v_decompose(max_struct_size) -- maximum structure size of all registered structures
	local can_into_dir = {0, 1, 2, 3, 4, 5}
	table.remove(can_into_dir, cellworld.opposite_directions[sprout_dir]+1)-- cannot into the sprout cell
	-- extend the space randomly into directions
	while #can_into_dir > 0 do
		gg_verbose("Directions left: ",table.concat(can_into_dir,","))
		local diridx = cellworld.random(1, #can_into_dir)
		local dir = can_into_dir[diridx]
		gg_verbose("area is now",slx,sly,slz,"<>",sux, suy, suz,", extending",cellworld.dirrev[dir],"(index",diridx,")")
		if dir == cellworld.NORTH then
			if suz-stz < msz and can_i_has_space(slx, sly, suz+1, sux, suy, suz+1)  then
				suz = suz + 1
			else
				gg_verbose("extending NORTH failed, hit limit",suz-stz < msz)
				table.remove(can_into_dir, diridx)
			end
		end
		if dir == cellworld.EAST then
			if sux-stx < msx and can_i_has_space(sux+1, sly, slz, sux+1, suy, suz)  then
				sux = sux + 1
			else
				gg_verbose("extending EAST failed, hit limit",sux-stx < msx)
				table.remove(can_into_dir, diridx)
			end
		end
		if dir == cellworld.SOUTH then
			if stz-slz < msz and can_i_has_space(slx, sly, slz-1, sux, suy, slz-1)  then
				slz = slz - 1
			else
				gg_verbose("extending SOUTH failed, hit limit",stz-slz < msz)
				table.remove(can_into_dir, diridx)
			end
		end
		if dir == cellworld.WEST then
			if stx-slx < msx and can_i_has_space(slx-1, sly, slz, slx-1, suy, suz)  then
				slx = slx - 1
			else
				gg_verbose("extending WEST failed, hit limit",sux-stx < msx)
				table.remove(can_into_dir, diridx)
			end
		end
		if dir == cellworld.UP then
			if suy-sty < msy and can_i_has_space(slx, suy+1, slz, sux, suy+1, suz)  then
				suy = suy + 1
			else
				gg_verbose("extending UP failed, hit limit",suy-sty < msy)
				table.remove(can_into_dir, diridx)
			end
		end
		if dir == cellworld.DOWN then
			if sty-sly < msy and can_i_has_space(slx, sly-1, slz, sux, sly-1, suz)  then
				sly = sly - 1
			else
				gg_verbose("extending DOWN failed, hit limit",sty-sly < msy)
				table.remove(can_into_dir, diridx)
			end
		end
	end
	
	-- determine how much space we have produced
	local spx, spy, spz = sux-slx+1, suy-sly+1, suz-slz+1
	gg_verbose("extending done, area is now",slx,sly,slz,"<>",sux, suy, suz,", space",spx, spy, spz)
	
	-- filter available structures by their size and insert according to probability
	local selstructs = {}
	for stname, struct in pairs(cellworld.structures) do
		local extx, exty, extz = cellworld.v_decompose(struct.size)
		if extx <= spx and exty <= spy and extz <= spz then
			gg_verbose("structure",stname,struct.size,"fits")
			-- structure fits. insert chance times
			for i=1,struct.chance do
				selstructs[#selstructs+1] = stname
			end
		else
			gg_verbose("structure",stname,struct.size,"doesnt fit")
		end
	end
	if #selstructs==0 then
		error("Failed to fit a structure into a space of",spx,spy,spz,", make sure that the structure set includes 1x1x1 structures as fallback!")
	end
	
	local stname = cellworld.select_random_element(selstructs)
	local struct = cellworld.structures[stname]
	gg_verbose("Selected ",stname, struct.size)
	
	-- determine degrees of freedom
	local extx, exty, extz = cellworld.v_decompose(struct.size)
	-- we still want the structure to overlap with our sprout cell
	local frlx, frly, frlz = math.max(slx, stx-extx+1), math.max(sly, sty-exty+1), math.max(slz, stz-extz+1)
	local frux, fruy, fruz = math.min(sux-extx+1, stx), math.min(suy-exty+1, sty), math.min(suz-extz+1, stz)
	
	gg_verbose("degrees of freedom",frlx, frly, frlz,"<>",frux, fruy, fruz)
	
	local posx, posy, posz
	if exit_present then
		local opp_dir = cellworld.opposite_directions[sprout_dir]
		-- find alignments with matching exits
		for x in iterate_random_order(frlx, frux) do
			for y in iterate_random_order(frly, fruy) do
				for z in iterate_random_order(frlz, fruz) do
					-- which structure cell borders our sprout cell?
					local pos_in_struct = vector.new(stx - x, sty - y, stz - z)
					local cell = cellworld.get_structure_cell(struct, pos_in_struct)
					if cell.exits and cell.exits[opp_dir] then
						gg_verbose("Alignment ",x,y,z,", in struct",pos_in_struct,", has matching exit")
						posx, posy, posz = x,y,z
						break --break out of the inner loop
					end
				end
				if posx then break end --break out of the outer loop if inner loop broken
			end
			if posx then break end --break out of the outer loop if inner loop broken
		end
	end
	-- if no matching exit found or none present on sprout cell, select one alignment randomly
	if not posx then
		posx, posy, posz = cellworld.random(frlx, frux), cellworld.random(frly, fruy), cellworld.random(frlz, fruz),
		gg_verbose("Alignment ",posx, posy, posz,"selected randomly")
	end
	
	-- place the structure
	gg_verbose("-!- placing",stname,"at",posx, posy, posz)
	cellworld.alloc_set_structure(vector.new(posx, posy, posz), stname, 0, struct.size, true)
end







