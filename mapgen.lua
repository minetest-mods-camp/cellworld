-- mapgen.lua - code that actually writes the game world based on the structures in the allocation map.


local mg_verbose = function() end
--local mg_verbose = cellworld.debug

-- on mapgen init, set the mapgen to singlenode
minetest.register_on_mapgen_init(function(mgparams)
	minetest.set_mapgen_setting("mg_name", "singlenode", true)
	-- TODO maybe fixate the structure set in the cellworld meta.
end)

-- placeholder for when something goes wrong with the mapgen
minetest.register_node("cellworld:placeholder", {
	description = "Cellworld Unknown Node Placeholder",
	tiles = {"cellworld_placeholder.png"},
	is_ground_content = false,
	groups = {cracky = 3,},
})

local placeholder_content_id = minetest.get_content_id("cellworld:placeholder")

-- file-scoped buffer for vm node data
local vm_data = {}

local function place_cell_actions(basepos, actions, area, clipminw, clipmaxw)
	for _, action in ipairs(actions) do
		if action.action == "fill" then
			local nodeid = minetest.get_content_id(action.node)
			if not nodeid then
				cellworld.warn("Unknown node",action.node,", filling with placeholder");
				nodeid = placeholder_content_id
			end
			local rxl, ryl, rzl, rxu, ryu, rzu = unpack(action.coords) -- these are relative
			if rxu<rxl then rxl,rxu = rxu,rxl end
			if ryu<ryl then ryl,ryu = ryu,ryl end
			if rzu<rzl then rzl,rzu = rzu,rzl end
			
			local cxl, cyl, czl = rxl+basepos.x, ryl+basepos.y, rzl+basepos.z
			local cxu, cyu, czu = rxu+basepos.x, ryu+basepos.y, rzu+basepos.z -- these are absolute
			
			mg_verbose("Placing action fill with",action.node,"coords",cxl, cyl, czl,"-",cxu, cyu, czu)
			-- limit to generation area
			local axl, ayl, azl = math.max(cxl, clipminw.x), math.max(cyl, clipminw.y), math.max(czl, clipminw.z)
			local axu, ayu, azu = math.min(cxu, clipmaxw.x), math.min(cyu, clipmaxw.y), math.min(czu, clipmaxw.z)
			--place on vmanip
			mg_verbose("clipped coords",axl, ayl, azl,"-",axu, ayu, azu)
			if axu>=axl and ayu>=ayl and azu>=azl then
				--local i = 0
				for index in area:iter(axl, ayl, azl, axu, ayu, azu) do
					--i = i + 1
					--mg_verbose("va iter",i,"index",index,"pos",area:position(index))
					vm_data[index] = nodeid
				end
			else
				mg_verbose("Outside of voxel area!")
			end
		elseif action.action == "log" then
			cellworld.log("Cell Generation Log:",action.message)
		end
	end
end


local function place_cell_on_vmanip(cellpos, cell, borders, area, clipminw, clipmaxw)
	local basepos = cellworld.cell_to_world_pos(cellpos)
	-- place "structure"
	mg_verbose("plave_cell_on_vmanip structure at basepos",basepos)
	place_cell_actions(basepos, cell.structure, area, clipminw, clipmaxw)
	-- check exits
	if cell.exits then
		for _,border in ipairs(borders) do
			if cell.exits[border] then
				-- does this exit match one in the neighbor?
				local n_cellpos = vector.add(cellpos, cellworld.direction_to_vector[border])
				local n_stname, n_relpos = cellworld.alloc_get_structure_at(n_cellpos)
				if n_stname then
					local n_struct = cellworld.structures[n_stname]
					if n_struct then
						local n_border = cellworld.opposite_directions[border]
						local n_cell = cellworld.get_structure_cell(n_struct, n_relpos)
						if n_cell.exits and n_cell.exits[n_border] then
							-- place exit
							mg_verbose("border",border,"exit matches to",n_stname,n_relpos)
							place_cell_actions(basepos, cell.exits[border], area, clipminw, clipmaxw)
						end
					end
				end
			end
		end
	end
end


local function allocate_chunk(minp, maxp)
	local minwpos = cellworld.world_to_cell_pos(minp)
	local maxwpos = cellworld.world_to_cell_pos(maxp)
	local margin = vector.new(2,2,2)
	
	local allocmin = vector.subtract(minwpos, margin)
	local allocmax = vector.subtract(maxwpos, margin)
	
	cellworld.gridgen_generate_cells(allocmin, allocmax)
end


local function run_chunk_generation(minposgen, maxposgen, emin, emax, vm, area)
	vm:get_data(vm_data)
	
	local mincell = cellworld.world_to_cell_pos(minposgen)
	local maxcell = cellworld.world_to_cell_pos(maxposgen)
	local i = 0
	-- iterate over the current area
	for x,y,z,cid in cellworld.alloc_get_area_iterator(mincell, maxcell) do
		-- back to world position
		local cellpos = vector.new(x,y,z)
		--local basepos = cellworld.cell_to_world_pos(vector.new(x,y,z))
		local stname, relcell = cellworld.alloc_resolve_cid(x,y,z,cid)
		if not stname then
			cellworld.warn("Cell at",basepos," is not allocated during mapgen callback. Ignoring!")
		else
			local struct = cellworld.structures[stname]
			if not struct then
				cellworld.warn("Cell at",basepos," has unknown structure",stname,". Ignoring!")
			else
				mg_verbose("At cellpos",cellpos,"placing",stname,"cell",relcell)
				-- resolve structure cell
				local cell = cellworld.get_structure_cell(struct, relcell)
				local borders = cellworld.get_border_sides(relcell, struct.size, true)
				place_cell_on_vmanip(cellpos, cell, borders, area, minposgen, maxposgen)
			end
		end
		i = i + 1
	end
	mg_verbose("run_chunk_generation generated",i,"cells")
	
	vm:set_data(vm_data)
end



-- this callback skeleton is taken from https://github.com/srifqi/superflat/blob/master/init.lua
minetest.register_on_generated(function(minp, maxp, seed)
	cellworld.log("==================================================")
	cellworld.log("Generating chunk: ",minp, maxp)
	local t1 = os.clock()
	
	allocate_chunk(minp, maxp)
	
	local chugent = os.clock()-t1
	cellworld.log("Structure allocation took",string.format("%.2f", chugent*1000),"ms")
	local t2 = os.clock()
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	
	run_chunk_generation(minp, maxp, emin, emax, vm, area)
	
	vm:write_to_map()
	vm:set_lighting({day = 15, night = 15})
	vm:update_liquids()
	vm:calc_lighting()
	
	local chugent2 = os.clock()-t2
	local gentotal = os.clock()-t1
	cellworld.log("Generation took",string.format("%.2f", chugent2*1000),"ms, total", string.format("%.2f", gentotal*1000),"ms")
end)
