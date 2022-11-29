function automata.debug(...)
	local to_print = {...}
	for i, val in ipairs(to_print) do
		to_print[i] = dump(val)
	end
	minetest.log("automata.debug(" .. table.concat(to_print, ", ") .. ")")
end

-- Same as ipairs, but iterates backwards. Useful for inserting or removing
-- elements during iteration at or after the current index.
local function ripairs_next(tab, i)
	i = i - 1
	if i == 0 then
		return nil
	end
	return i, tab[i]
end

function automata.ripairs(tab)
	return ripairs_next, tab, #tab + 1
end

function automata.get_node_info(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node then
		return nil
	end

	local info = automata.infos[node.name]
	if not info then
		return nil
	end

	return info
end

local neighbor_offsets = {
	vector.new(1, 0, 0),
	vector.new(-1, 0, 0),
	vector.new(0, 0, 1),
	vector.new(0, 0, -1),
	vector.new(0, 1, 0),
	vector.new(0, -1, 0)
}

function automata.around(init_pos, func, init_node)
	init_node = init_node or minetest.get_node(init_pos)

	for _, offset in ipairs(neighbor_offsets) do
		local pos = init_pos + offset
		local info = automata.get_node_info(pos)
		if info and info.conns[init_node.name] then
			func(pos, info)
		end
	end
end

function automata.recurse(init_pos, func)
	local found = {}
	local stack = {init_pos}

	while #stack ~= 0 do
		local pos = table.remove(stack)
		local info = automata.get_node_info(pos)
		local hash = minetest.hash_node_position(pos)

		if info and not found[hash] then
			found[hash] = true
			local continue = func(pos, info)

			-- Returning nil from the callback usually indicates a bug where an
			-- explicit return value was forgotten. Instead of blithely assuming
			-- false, explicitly require it.
			assert(continue ~= nil)

			if continue then
				automata.around(pos, function(offset_pos, offset_info)
					table.insert(stack, offset_pos)
				end)
			end
		end
	end
end

function automata.format_errors(errors)
	return "* " .. table.concat(errors, "\n* ")
end
