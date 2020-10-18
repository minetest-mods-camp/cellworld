--[[
CellWorld - Random grid-like underground structures
(c) 2020 orwell96

	This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

]]--

local DEBUG = true

cellworld = {}

-- global constants
--     N [+z]
-- W [-x]    [+x] E
--     S [-z]

cellworld.NORTH = 0
cellworld.EAST  = 1
cellworld.SOUTH = 2
cellworld.WEST  = 3
cellworld.UP    = 4
cellworld.DOWN  = 5

cellworld.dirrev = {[0]="NORTH", "EAST", "SOUTH", "WEST", "UP", "DOWN"}


local loadt1 = os.clock()

local modpath = minetest.get_modpath(minetest.get_current_modname())
-- load log utils
local print_concat_table, dump = dofile(modpath..DIR_DELIM.."logutil.lua")

cellworld.log = function(...)
	minetest.log("action", "[cellworld] "..print_concat_table({...}))
end
cellworld.chat = function(...)
	minetest.chat_send_all("[cellworld] "..print_concat_table({...}))
end
cellworld.warn = function(...)
	local t = print_concat_table({...})
	minetest.log("warning", "[cellworld] -!- "..t)
	minetest.chat_send_all("[cellworld] -!- "..t)
end

if DEBUG then
	cellworld.debug = function(...)
		local t = print_concat_table({...})
		minetest.log("action", "[cellworld] "..t)
		minetest.chat_send_all("[cellworld] "..t)
	end
else
	cellworld.debug = function() end
end

dofile(modpath..DIR_DELIM.."utils.lua")
dofile(modpath..DIR_DELIM.."allocation.lua")
dofile(modpath..DIR_DELIM.."gridgen.lua")
dofile(modpath..DIR_DELIM.."mapgen.lua")
dofile(modpath..DIR_DELIM.."struct_register.lua")
dofile(modpath..DIR_DELIM.."structures.lua")

local stcnt = 0
for stname,_ in pairs(cellworld.structures) do
	--cellworld.debug("Streg:",stname)
	stcnt = stcnt + 1
end

--cellworld.load_allocation()

-- TODO make this a on_shutdown
minetest.register_chatcommand("sa",
	{
        params = "", 
        description = "Cellworld Save Allocation Map To File", 
        privs = {server=true},
        func = function(name, param)
			cellworld.save_allocation()
			return true, "OK"
        end,
})

cellworld.load_allocation()

minetest.register_on_shutdown(function()
	cellworld.save_allocation()
end)

cellworld.log("Loaded, active structure set is",cellworld.structure_set.name,", registered",stcnt,"structures.")
