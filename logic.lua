function automata.get_state_group(state_pos, found_states)
	local state_group = {}

	automata.recurse(state_pos, function(group_pos, group_info)
		if not group_info.state then
			return false
		end

		found_states[minetest.hash_node_position(group_pos)] = true
		table.insert(state_group, group_pos)

		return true
	end)

	return state_group
end

function automata.get_states(init_pos)
	local found_states = {}
	local states = {}

	automata.recurse(init_pos, function(state_pos, state_info)
		local state_hash = minetest.hash_node_position(state_pos)

		if state_info.state and not found_states[state_hash] then
			table.insert(states, automata.get_state_group(state_pos, found_states))
		end

		return true
	end)

	local starts = {}

	for _, state_group in ipairs(states) do
		for _, state_pos in ipairs(state_group) do
			if automata.get_node_info(state_pos).start then
				table.insert(starts, state_group)
				break
			end
		end
	end

	return states, starts
end

automata.start_meta = {
	"class",
	"nondet",
	"errors",

	"state",
	"pos",

	"input",
	"stack",
	"tape"
}

automata.type_map = {
	invalid = {"Invalid", "Invalid"},
	finite = {"DFA", "NFA"},
	pushdown = {"DPDA", "PDA"},
	turing = {"TM", "NTM"}
}

function automata.get_node_meta(auto_pos)
	local meta = minetest.get_meta(auto_pos)
	local data = {}

	data.class = meta:get("automata_class") or "invalid"
	data.nondet = meta:get_string("automata_nondet") == "true"
	data.errors = meta:get_string("automata_errors")

	data.state = meta:get_string("automata_state")
	data.pos = tonumber(meta:get_string("automata_pos")) or 1

	data.input = meta:get_string("automata_input")
	data.stack = meta:get_string("automata_stack")
	data.tape = meta:get_string("automata_tape")

	return data
end

function automata.get_meta(init_pos)
	local _, starts = automata.get_states(init_pos)

	for _, state_group in ipairs(starts) do
		for _, start_pos in ipairs(state_group) do
			-- Just like `automata.set_meta()`, we need to verify that this is,
			-- in fact, a start state, since only those have meta.
			local start_info = automata.get_node_info(start_pos)
			if start_info.start then
				return automata.get_node_meta(start_pos)
			end
		end
	end
end

function automata.update_infotext(init_pos)
	local infotext = {}

	local data = automata.get_meta(init_pos)
	local auto_type = automata.type_map[data.class][data.nondet and 2 or 1]

	table.insert(infotext, "Type: " .. auto_type)

	if data.class ~= "invalid" then
		local bar_input = data.input
		if data.class ~= "turing" then
			bar_input = data.input:sub(1, data.pos - 1) .. "|" .. data.input:sub(data.pos)
		end
		table.insert(infotext, "Input: " .. bar_input)

		if data.state ~= "idle" then
			if data.class == "pushdown" then
				table.insert(infotext, "Stack: " .. data.stack)
			elseif data.class == "turing" then
				local disp_tape = (data.tape == "") and "_" or data.tape
				local bar_tape = disp_tape:sub(1, data.pos - 1) .. "[" ..
						disp_tape:sub(data.pos, data.pos) .. "]" ..
						disp_tape:sub(data.pos + 1)
				table.insert(infotext, "Tape: " .. bar_tape)
			end
		end
	else
		table.insert(infotext, "Errors:\n" .. data.errors)
	end

	automata.recurse(init_pos, function(auto_pos, auto_info)
		local meta = minetest.get_meta(auto_pos)
		meta:set_string("infotext", table.concat(infotext, "\n"))
		return true
	end)
end

function automata.set_node_meta(auto_pos, items)
	local meta = minetest.get_meta(auto_pos)
	for _, key in ipairs(automata.start_meta) do
		-- If there is a value (including a value of false), set the meta.
		if items[key] ~= nil then
			meta:set_string("automata_" .. key, tostring(items[key]))
		end
	end
end

function automata.set_meta(init_pos, items)
	local _, starts = automata.get_states(init_pos)

	for _, state_group in ipairs(starts) do
		for _, start_pos in ipairs(state_group) do
			-- If this automaton is invalid, there can be states in a start
			-- group that are not start states. Never set meta on these states.
			local start_info = automata.get_node_info(start_pos)
			if start_info.start then
				automata.set_node_meta(start_pos, items)
			end
		end
	end

	automata.update_infotext(init_pos)
end

function automata.turn_off(init_pos)
	automata.recurse(init_pos, function(auto_pos, auto_info)
		minetest.swap_node(auto_pos, {name = auto_info.off_name})
		return true
	end)
end

function automata.reset(init_pos)
	automata.turn_off(init_pos)

	local _, starts = automata.get_states(init_pos)
	for _, state_group in ipairs(starts) do
		for _, start_pos in ipairs(state_group) do
			local start_info = automata.get_node_info(start_pos)
			minetest.swap_node(start_pos, {name = start_info.idle_name})
		end
	end

	automata.set_meta(init_pos, {
		state = "idle",
		pos = 1,

		input = "",
		stack = "",
		tape = ""
	})
end

automata.transition_order = {
	read = 1,
	write = 2,
	move = 3,
	pop = 4,
	push = 5,
	conn = 6
}

function automata.follow_trans(read_pos)
	local specials = {}
	local conns = {read_pos}
	local states = {}

	local order = automata.transition_order
	local last_spec = order.read
	local found_states = {}

	local check_conn = function(next_pos, next_info)
		if next_info.state or next_info.read then
			return false
		end

		if last_spec == order.conn then
			if not next_info.conn then
				return false
			end
		else
			local this_spec
			if next_info.write then
				specials.write = next_info
				this_spec = order.write
			elseif next_info.move then
				specials.move = next_info
				this_spec = order.move
			elseif next_info.pop then
				specials.pop = next_info
				this_spec = order.pop
			elseif next_info.push then
				specials.push = next_info
				this_spec = order.push
			elseif next_info.conn then
				this_spec = order.conn
			end

			if last_spec >= this_spec and last_spec ~= order.conn then
				specials.invalid = true
			end
			last_spec = this_spec
		end

		table.insert(conns, next_pos)
		return true
	end

	automata.around(read_pos, function(conn_pos, conn_info)
		if conn_info.state then
			return
		end

		automata.recurse(conn_pos, function(next_pos, next_info)
			local next_hash = minetest.hash_node_position(next_pos)
			if next_info.state and not found_states[next_hash] then
				table.insert(states, automata.get_state_group(next_pos, found_states))
				return false
			end
			return check_conn(next_pos, next_info)
		end)
	end)

	return specials, conns, states
end

function automata.refresh(init_pos)
	automata.reset(init_pos)

	local errors = {}

	local states, starts = automata.get_states(init_pos)
	if #starts ~= 1 then
		table.insert(errors, "Multiple start states")
	end

	for _, state_group in ipairs(states) do
		local first_info = automata.get_node_info(state_group[1])

		for _, state_pos in ipairs(state_group) do
			local state_info = automata.get_node_info(state_pos)
			if state_info.start ~= first_info.start or
					state_info.accept ~= first_info.accept then
				table.insert(errors, "Mismatched state group")
				break
			end
		end
	end

	local pushdown = false
	local turing = false

	automata.recurse(init_pos, function(auto_pos, auto_info)
		if auto_info.push or auto_info.pop then
			pushdown = true
		elseif auto_info.write or auto_info.left or auto_info.right then
			turing = true
		end

		return true
	end)

	local auto_class
	if pushdown and turing then
		table.insert(errors, "Mixed tape and stack operations")
		auto_class = "invalid"
	elseif pushdown then
		auto_class = "pushdown"
	elseif turing then
		auto_class = "turing"
	else
		auto_class = "finite"
	end

	local auto_nondet = false

	for _, state_group in ipairs(states) do
		for _, state_pos in ipairs(state_group) do
			local found_trans = {}

			automata.around(state_pos, function(read_pos, read_info)
				if not read_info.read then
					return
				end

				local specials, conns, dest_states = automata.follow_trans(read_pos)
				local pop_values = specials.pop and specials.pop.values or automata.all_char_values

				for _, rc in ipairs(read_info.values) do
					for _, pc in ipairs(pop_values) do
						local rpc = rc .. pc
						found_trans[rpc] = (found_trans[rpc] or 0) + 1
					end
				end

				if specials.invalid then
					table.insert(errors, "Transition has invalid number or order of actions")
				end

				if #dest_states == 0 then
					table.insert(errors, "Transition doesn't end in a state")
				elseif #dest_states >= 2 then
					table.insert(errors, "Transition ends in multiple states")
				end
			end)

			for _, num_trans in pairs(found_trans) do
				if num_trans > 1 then
					auto_nondet = true
					break
				end
			end
		end
	end

	local auto_errors = ""

	if #errors ~= 0 then
		auto_class = "invalid"
		auto_nondet = false
		auto_errors = "* " .. table.concat(errors, "\n* ")
	end

	automata.set_meta(init_pos, {
		class = auto_class,
		nondet = auto_nondet,
		errors = auto_errors
	})
end

function automata.can_trans(read_pos)
	local data = automata.get_meta(read_pos)

	local read_info = automata.get_node_info(read_pos)
	local specials, conns, states = automata.follow_trans(read_pos)

	local tape_char = data.tape:sub(data.pos, data.pos)
	if tape_char == "" then
		tape_char = "_"
	end

	if read_info.value ~= tape_char and
			read_info.char ~= "gamma" and read_info.char ~= "lambda" then
		return false
	end

	if data.class == "pushdown" and specials.pop then
		local stack_char = data.stack:sub(#data.stack, #data.stack)
		if specials.pop.value ~= stack_char and specials.pop.char ~= "gamma" then
			return false
		end
	end

	return true
end

function automata.run_trans(read_pos)
	local data = automata.get_meta(read_pos)

	local read_info = automata.get_node_info(read_pos)
	local specials, conns, states = automata.follow_trans(read_pos)

	local new_tape = data.tape
	if specials.write then
		new_tape = new_tape:sub(1, data.pos - 1) ..
				specials.write.value .. new_tape:sub(data.pos + 1)
	end

	local new_pos = data.pos
	if data.class == "turing" then
		if specials.move then
			if specials.move.left then
				new_pos = new_pos - 1
			else
				new_pos = new_pos + 1
			end
		end
	elseif read_info.char ~= "lambda" then
		new_pos = new_pos + 1
	end

	if new_pos < 1 then
		new_tape = string.rep("_", 1 - new_pos) .. new_tape
		new_pos = 1
	elseif new_pos > #new_tape then
		new_tape = new_tape .. string.rep("_", new_pos - #new_tape)
	end

	local new_stack = data.stack
	if specials.pop then
		new_stack = new_stack:sub(1, #new_stack - 1)
	end
	if specials.push then
		new_stack = new_stack .. specials.push.value
	end

	automata.set_meta(read_pos, {
		pos = new_pos,
		stack = new_stack,
		tape = new_tape
	})

	for _, conn_pos in ipairs(conns) do
		local conn_info = automata.get_node_info(conn_pos)
		minetest.swap_node(conn_pos, {name = conn_info.on_name})
	end
	for _, state_pos in ipairs(states[1]) do
		local state_info = automata.get_node_info(state_pos)
		minetest.swap_node(state_pos, {name = state_info.on_name})
	end
end

function automata.no_trans(init_pos)
	local data = automata.get_meta(init_pos)

	if data.class ~= "turing" then
		automata.set_meta(init_pos, {
			pos = data.pos + 1
		})
	end
end
