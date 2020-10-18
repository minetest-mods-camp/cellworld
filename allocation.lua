-- allocation.lua - Maintains the grid node allocation table
--[[
In contrast to classical mapgens, cellworld does not rely on perlin noise and "reproducable randomness".
Because structures can have varying size, and it is not specified which direction is explored first,
we cannot safely reconstruct the existing structures easily only from noise.

Gridmine instead stores an "allocation map" along with the map, which stores which structures have been placed where.
Generated structures are selected during generation on a "what fits" basis.

Binary file format:

1byte version
2byte number of structureID entries
[
2byte structure id
string structure name
\n
]
[
6byte cellPosition
4byte indirection entry or structure entry
]
EOF

Position:
<gnx 2byte><gny 2byte><gnz 2byte>

Indirection entry:
I<xoff 1byte><yoff 1byte><zoff 1byte>
This node is part of a structure whose origin is at x-xoff .. z-zoff

Structure entry:
S<rotation char><structureId 2bytes>

All entries have a length of 4 bytes.

]]--

local function int_to_bytes(i, clip)
	local x = i
	if clip then
		x=i+32768--clip to positive integers
	end
	local cH = math.floor(x /           256) % 256;
	local cL = math.floor(x                ) % 256;
	return(string.char(cH, cL));
end
local function bytes_to_int(bytes, clip)
	local t={string.byte(bytes,1,-1)}
	local n = 
		t[1] *           256 +
		t[2]
	if clip then
		return n-32768
	else
		return n
	end
end

-- quick unit test
assert(bytes_to_int(int_to_bytes(42))==42)
assert(bytes_to_int(int_to_bytes(-42))~=-42)-- this must not work!
assert(bytes_to_int(int_to_bytes(42,true),true)==42)
assert(bytes_to_int(int_to_bytes(-42,true),true)==-42)

--local variables for performance
local gma_structids={}
local gma_entries={}

local function gmaget(x,y,z)
	local ny=gma_entries[y]
	if ny then
		local nx=ny[x]
		if nx then
			return nx[z]
		end
	end
	return nil
end
cellworld.alloc_get_cid = gmaget

local function gmaset(x,y,z,v)
	if not gma_entries[y] then
		gma_entries[y]={}
	end
	if not gma_entries[y][x] then
		gma_entries[y][x]={}
	end
	gma_entries[y][x][z]=v
end

local function format_cid(x,y,z,cid)
	if not cid then
		return "<nil>"
	end

	local indirection = string.sub(cid, 1, 1)
	if indirection == "I" then
		local ox,oy,oz = string.byte(cid, 2, 4)
		
		local icid = gmaget(x-ox, y-oy, z-oz)
		return "I "..ox.." "..oy.." "..oz.." -> "..x-ox.." "..y-oy.." "..z-oz.." "..format_cid(x-ox, y-oy, z-oz, icid)
	elseif indirection == "S" then
		local rotation = string.sub(cid, 2, 2)
		local stid_char = string.sub(cid, 3, 4)
		local stid = bytes_to_int(stid_char)
		local stna = gma_structids[stid]
		return "S str="..stid.." ("..(stna or "?")..")"
	else
		return "???"
	end
end

local path=minetest.get_worldpath()..DIR_DELIM.."cellworld_allocation_map"
--load
function cellworld.load_allocation()
	cellworld.log("loading structure allocation map")
	local file, err = io.open(path, "rb")
	if not file then
		cellworld.log("Couldn't load the allocation database: ", err or "Unknown Error")
	else
		-- read version
		local vers_byte = file:read(1)
		local version = string.byte(vers_byte)
		if version~=1 then
			error("Doesn't support allocation file of version "..version)
		end
		
		-- read structure ids
		local nstr_byte = file:read(2)
		local nstr = bytes_to_int(nstr_byte)
		for i = 1,nstr do
			local stid_byte = file:read(2)
			local stid = bytes_to_int(stid_byte)
			local stna = file:read("*l")
			cellworld.log("structure id:", stid, "->", stna)
			gma_structids[stid] = stna
		end
		cellworld.log("read", nstr, "structure ids.")
	
		-- read nodes. code suspiciously resembles advtrains ndb, not that I copied it :) ...
		local cnt=0
		local hst_x=file:read(2)
		local hst_y=file:read(2)
		local hst_z=file:read(2)
		local cid=file:read(4)
		while hst_z and hst_y and hst_x and cid and #hst_z==2 and #hst_y==2 and #hst_x==2 and #cid==4 do
			gmaset(bytes_to_int(hst_x,true), bytes_to_int(hst_y,true), bytes_to_int(hst_z,true), cid)
			cnt=cnt+1
			hst_x=file:read(2)
			hst_y=file:read(2)
			hst_z=file:read(2)
			cid=file:read(4)
		end
		cellworld.log("read", cnt, "structure allocations.")
		file:close()
	end
end

--save
function cellworld.save_allocation()
	local tmppath = path
	local file, err = io.open(tmppath, "wb")
	if not file then
		cellworld.log("Couldn't save the allocation database: ", err or "Unknown Error")
	else
		cellworld.log("Saving allocation database...")
		-- write version
		file:write(string.char(1))
		
		-- how many structid entries
		local cnt = 0
		for _,_ in pairs(gma_structids) do
			cnt = cnt + 1
		end
		-- write structids
		local nstr = 0
		file:write(int_to_bytes(cnt))
		for stid,stna in pairs(gma_structids) do
			file:write(int_to_bytes(stid))
			file:write(stna)
			file:write("\n")
			nstr = nstr+1
		end
		cellworld.log("wrote", nstr, "structure ids.")
		
		-- write entries
		local cnt = 0
		for y, ny in pairs(gma_entries) do
			for x, nx in pairs(ny) do
				for z, cid in pairs(nx) do
					file:write(int_to_bytes(x,true))
					file:write(int_to_bytes(y,true))
					file:write(int_to_bytes(z,true))
					file:write(cid)
					cnt=cnt+1
				end
			end
		end
		cellworld.log("wrote", cnt, "structure allocations.")
		file:close()
	end
end

function cellworld.dump_allocation()
	for y, ny in pairs(gma_entries) do
		for x, nx in pairs(ny) do
			for z, cid in pairs(nx) do
				cellworld.log(x,y,z,format_cid(x,y,z,cid))
			end
		end
	end
end

function cellworld.alloc_dump_area(lx,ly,lz,ux,uy,uz)
	cellworld.log("-- allocation dumping area",lx,ly,lz,"<>",ux,uy,uz)
	for dx,dy,dz,dcid in cellworld.alloc_get_area_iterator_raw(lx,ly,lz,ux,uy,uz) do
		cellworld.log(dx,dy,dz,format_cid(dx,dy,dz,dcid))
	end
	cellworld.log("-- end of dump")
end

local function resolve_structure(cid, ox, oy, oz)
	local rotation = string.sub(cid, 2, 2)
	local stid_char = string.sub(cid, 3, 4)
	local stid = bytes_to_int(stid_char)
	local stna = gma_structids[stid]
	--cellworld.debug("  structure rot=",rotation,"stid=",stid,"stna=",stna)
	if stna then
		return stna, vector.new(ox,oy,oz), string.byte(rotation)
	end
	cellworld.log("[allocation] Warn: unknown structure name for id",stid,". Ignored")
	return nil
end

--cellworld.alloc_get_cid(x,y,z)
cellworld.alloc_get_cid = gmaget

-- returns:
-- structure_name, relative_pos, rotation
-- Note: structure rotation not calculated here yet
function cellworld.alloc_get_structure_at(cell_pos)
	local cid = gmaget(cell_pos.x, cell_pos.y, cell_pos.z)
	if not cid then return nil end
	return cellworld.alloc_resolve_cid(cell_pos.x, cell_pos.y, cell_pos.z, cid)
end

-- returns:
-- structure_name, relative_pos, rotation
function cellworld.alloc_resolve_cid(x, y, z, cid)
	--cellworld.debug("alloc_resolve_cid(", x, y, z,")")
	local indirection = string.sub(cid, 1, 1)
	if indirection == "I" then
		local ox,oy,oz = string.byte(cid, 2, 4)
		--cellworld.debug("alloc_resolve_cid(", x, y, z,")")
		local icid = gmaget(x-ox, y-oy, z-oz)
		--cellworld.debug("  indirection +",ox,oy,oz,format_cid(x-ox, y-oy, z-oz,icid))
		if not icid then
			cellworld.log("[allocation] Warn: Indirection at",vector.new(x,y,z),"has nil target. Ignored")
			cellworld.alloc_dump_area(x-3,y-3,z-3,x+3,y+3,z+3)
			return nil
		end
		indirection = string.sub(icid, 1, 1)
		if indirection ~= "S" then
			cellworld.log("[allocation] Warn: Indirection at",vector.new(x,y,z),"points to something other than S. Ignored")
			cellworld.alloc_dump_area(x-3,y-3,z-3,x+3,y+3,z+3)
			return nil
		end
		return resolve_structure(icid, ox, oy, oz)
	elseif indirection == "S" then
		return resolve_structure(cid, 0,0,0)
	else
		cellworld.log("[allocation] Warn: Unknown node type",indirection,"at gridpos",vector.new(x,y,z),". Ignored")
		return nil
	end
end

function cellworld.alloc_set_structure(cell_pos, structure_name, rotation, structure_extent, no_clobber)
	--cellworld.debug("alloc_set_structure(",cell_pos, structure_name, rotation, structure_extent, no_clobber,")")
	for x=0,structure_extent.x-1 do
		for y=0,structure_extent.y-1 do
			for z=0,structure_extent.z-1 do
				-- write indirection
				if x==0 and y==0 and z==0 then
					--continue
				elseif no_clobber and gmaget(cell_pos.x + x, cell_pos.y + y, cell_pos.z + z) then
					local ocid = gmaget(cell_pos.x + x, cell_pos.y + y, cell_pos.z + z)
					cellworld.log("[allocation] While trying to place",structure_name,"at grid position",cell_pos,"extent",structure_extent)
					cellworld.log("[allocation] Not clobbering ",vector.new(cell_pos.x + x, cell_pos.y + y, cell_pos.z + z),"which has entry",format_cid(cell_pos.x + x, cell_pos.y + y, cell_pos.z + z, ocid))
					error("Failed to place structure; see log...")
					--continue
				else
					local indir = "I"..string.char(x)..string.char(y)..string.char(z)
					--cellworld.debug("  indirection ",cell_pos,"+",x,y,z)
					gmaset(cell_pos.x + x, cell_pos.y + y, cell_pos.z + z, indir)
				end
			end
		end
	end
	if no_clobber and gmaget(cell_pos.x, cell_pos.y, cell_pos.z) then
		return
	end
	-- write structure
	local stid
	for istid, istna in ipairs(gma_structids) do
		if istna==structure_name then
			stid = istid
			break
		end
	end
	if not stid then
		stid = #gma_structids + 1
		cellworld.debug("  allocating new structure id ",stid,"for",structure_name)
		gma_structids[stid] = structure_name
	end
	local struct = "S"..string.char(rotation)..int_to_bytes(stid)
	--cellworld.debug("  structure ",cell_pos,"rot=",rotation,"stid=",stid)
	gmaset(cell_pos.x, cell_pos.y, cell_pos.z, struct)
end

function cellworld.alloc_has_space(cell_pos, structure_extent)
	for _ in cellworld.alloc_get_area_iterator(cell_pos, vector.add(cell_pos, structure_extent)) do
		--if any result, no space
		return false
	end
	return true
end

-- Returns an iterator function that iterates over all allocation entries in the given area, in raw format.
-- Iterator returns: x, y, z, cid
-- where cid can be decrypted by calling cellworld.alloc_resolve_cid(x,y,z,cid)
function cellworld.alloc_get_area_iterator(gp_min, gp_max)
	return cellworld.alloc_get_area_iterator_raw(gp_min.x, gp_min.y, gp_min.z, gp_max.x, gp_max.y, gp_max.z)
end
function cellworld.alloc_get_area_iterator_raw(lx, ly, lz, ox, oy, oz)
	local x, y, z = lx - 1, ly - 1, lz - 1
	local it_y, it_x
	return function()
		while y<=oy do
			if it_y then
				while x<=ox do
					if it_x then
						while z<oz do
							-- locating next z
							z=z+1
							if it_x[z] then
								--[[local realcid = gmaget(x,y,z)
								if realcid ~= it_x[z] then
									cellworld.log(x,y,z,"CIDs dont match real=",
										format_cid(x,y,z,realcid),"found=",
										format_cid(x,y,z,it_x[z]))
									cellworld.dump_allocation()
									error("CIDs dont match in iterator")
								end]]--
								return x, y, z, it_x[z]
							end
						end
						-- through with iterating it_x
						z=lz-1
					end
					-- locating next x
					x = x + 1
					it_x = it_y[x]
				end
				-- through with iterating it_y
				x=lx-1
				it_x = nil
			end
			-- locating next y
			y = y + 1
			it_y = gma_entries[y]
		end
		-- through with iterating everything
		return nil
	end
end


--[[
local TEST_table = {
	[1] = {
		[1] = {
			[1]="A",
			[4]="B",
			[5]="C",
		},
		[3] = {
			[2]="D",
		},
		[5] = {
		},
	},
	[2] = {
		[3] = {
			[2]="E",
		},
	},
	[4] = {
		[1] = {
			[1]="F",
			[4]="G",
		},	
	}
}
function cellworld.alloc_get_area_iterator_TEST(lx, ly, lz, ox, oy, oz)
	local x, y, z = lx - 1, ly - 1, lz - 1
	local it_y, it_x
	return function()
		while y<=oy do
			if it_y then
				while x<=ox do
					if it_x then
						while z<oz do
							-- locating next z
							z=z+1
							cellworld.log("next z",z)
							if it_x[z] then
								return x, y, z, it_x[z]
							end
						end
						-- through with iterating it_x
						z=lz-1
					end
					-- locating next x
					x = x + 1
					it_x = it_y[x]
					cellworld.log("next x",x,it_x~=nil)
				end
				-- through with iterating it_y
				x=lx-1
			end
			-- locating next y
			y = y + 1
			it_y = TEST_table[y]
			
			cellworld.log("next y",y,it_y~=nil)
		end
		-- through with iterating everything
		return nil
	end
end

for x,y,z,letter in cellworld.alloc_get_area_iterator_TEST(1,1,1,5,5,5) do
	cellworld.log(x,y,z,letter)
end
]]--

-- Checks efficiently whether no, some or all cells in the given area are allocated
-- returns:
-- 0 - no cells allocated
-- 1 - some cells, but not all, allocated
-- 2 - all cells allocated
function cellworld.alloc_check_some_cells_allocated(gp_min, gp_max)
	local have_skipped = false
	local have_any_cell = false
	for y=gp_min.y, gp_max.y do
		local ly = gma_entries[y]
		if ly then
			for x=gp_min.x, gp_max.x do
				local lx = ly[x]
				if lx then
					for z=gp_min.z, gp_max.z do
						if lx[z] then
							have_any_cell = true
						else have_skipped=true end
					end
				else have_skipped=true end
			end
		else have_skipped=true end
	end
	if not have_any_cell then return 0 end
	if have_skipped then return 1 end
	return 2
end
