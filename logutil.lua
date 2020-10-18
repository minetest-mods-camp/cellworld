-- Logutils - originally part of advtrains

local function dump(t, intend)
	local str
	if not t then
		str = "nil"
	elseif type(t)=="table" then
		if t.x and t.y and t.z then
			str=minetest.pos_to_string(t)
		else
			str="{"
			local intd = (intend or "") .. "  "
			for k,v in pairs(t) do
				str = str .. "\n" .. intd .. dump(k, intd) .. " = " ..dump(v, intd)
			end
			str = str .. "\n" .. (intend or "") .. "}"
		end
	elseif type(t)=="boolean" then
		if t then
			str="true"
		else
			str="false"
		end
	elseif type(t)=="function" then
		str="<function>"
	elseif type(t)=="userdata" then
		str="<userdata>"
	else
		str=""..t
	end
	return str
end

local function print_concat_table(tab)
	-- go through table and find max entry
	local maxe = 0
	for k, _ in pairs(tab) do
		maxe = math.max(maxe, k)
	end

	local t = {}
	for i=1,maxe do
		t[i] = dump(tab[i])
	end
	return table.concat(t, " ")
end

return print_concat_table, dump
