automata.chars = {
	{name = "zero",   desc = "Zero",   value = "0", main = true},
	{name = "one",    desc = "One",    value = "1"},
	{name = "a",      desc = "A",      value = "a"},
	{name = "b",      desc = "B",      value = "b"},
	{name = "c",      desc = "C",      value = "c"},
	{name = "dollar", desc = "Dollar", value = "$"},
	{name = "blank",  desc = "Blank",  value = "_"},
	{name = "gamma",  desc = "Gamma"},
	{name = "lambda", desc = "Lambda"}
}

automata.BASIC_CHARS = 2
automata.GAMMA_CHAR = 1
automata.ALL_CHARS = 0

automata.all_char_values = {}
for _, char in ipairs(automata.chars) do
	if char.value then
		char.values = {char.value}
		table.insert(automata.all_char_values, char.value)
	else
		char.values = automata.all_char_values
	end
end

local function build_letter_infos(base_info, variations)
	if base_info.uses_char then
		for i, char in ipairs(automata.chars) do
			local char_info = table.copy(base_info)

			char_info.node_name = "automata:" .. base_info.base_name .. "_" .. char.name
			char_info.texture = "automata_" .. base_info.base_name .. ".png"
			char_info.modifier = "^automata_char_" .. char.name .. ".png"
			char_info.desc = char.desc .. " " .. base_info.desc

			char_info.char = char.name
			char_info.value = char.value
			char_info.values = char.values

			-- Subtract off the extra characters we don't want from the number
			-- of characters in the list.
			local numc = #automata.chars - base_info.uses_char
			char_info.prev_char = ((i % numc) + numc - 2) % numc + 1
			char_info.next_char = (i % numc) + 1

			if not char.main then
				char_info.variation = true
			end

			table.insert(variations, char_info)
		end
	else
		local new_info = table.copy(base_info)
		new_info.node_name = "automata:" .. base_info.base_name
		new_info.texture = "automata_" .. base_info.base_name .. ".png"
		new_info.modifier = ""
		table.insert(variations, new_info)
	end
end

automata.colors = {
	{name = "red",    desc = "Red"},
	{name = "orange", desc = "Orange"},
	{name = "green",  desc = "Green"},
	{name = "cyan",   desc = "Cyan"},
	{name = "blue",   desc = "Blue"},
	{name = "violet", desc = "Violet"}
}

local function build_color_infos(variations)
	for _, gray_info in automata.ripairs(variations) do
		gray_info.prev_color = #automata.colors
		gray_info.next_color = 1

		for i, color in ipairs(automata.colors) do
			local color_info = table.copy(gray_info)

			color_info.node_name = gray_info.node_name .. "_" .. color.name
			color_info.modifier = color_info.modifier ..
					"^automata_color_" .. color.name .. ".png"
			color_info.desc = color.desc .. " " .. gray_info.desc

			color_info.color = color.name

			local numc = #automata.colors
			color_info.prev_color = (i + numc) % (numc + 1)
			color_info.next_color = (i + 1) % (numc + 1)

			color_info.variation = true

			table.insert(variations, color_info)
		end
	end
end

local function build_state_infos(variations)
	for _, off_info in automata.ripairs(variations) do
		off_info.off_name = off_info.node_name
		off_info.on_name = off_info.node_name .. "_on"

		local on_info = table.copy(off_info)

		on_info.node_name = off_info.on_name
		on_info.drop_name = off_info.off_name
		on_info.texture = "automata_" .. off_info.base_name .. "_on.png"
		on_info.desc = off_info.desc .. " On"

		off_info.is_on = false
		on_info.is_on = true

		on_info.variation = true

		table.insert(variations, on_info)
	end
end

automata.starts = {
	{name = "on",   desc = "On",   is_on = true},
	{name = "bad",  desc = "Bad",  is_on = false},
	{name = "good", desc = "Good", is_on = false},
	{name = "idle", desc = "Idle", is_on = false},
}

local function build_start_infos(variations)
	for _, off_info in automata.ripairs(variations) do
		off_info.off_name = off_info.node_name
		off_info.on_name = off_info.node_name .. "_on"
		off_info.bad_name = off_info.node_name .. "_bad"
		off_info.good_name = off_info.node_name .. "_good"
		off_info.idle_name = off_info.node_name .. "_idle"

		off_info.is_on = false

		for _, start in ipairs(automata.starts) do
			new_info = table.copy(off_info)

			new_info.node_name = off_info[start.name .. "_name"]
			new_info.drop_name = off_info.off_name
			new_info.texture = "automata_" .. off_info.base_name .. "_" .. start.name .. ".png"
			new_info.desc = off_info.desc .. " " .. start.desc

			new_info.is_on = start.is_on
			new_info.variation = true

			table.insert(variations, new_info)
		end
	end
end

local function build_info_variations(base_info)
	local variations = {}

	build_letter_infos(base_info, variations)

	if not base_info.state then
		build_color_infos(variations)
	end

	if base_info.start then
		build_start_infos(variations)
	else
		build_state_infos(variations)
	end

	return variations
end

local function build_info_conns(all_infos)
	local non_state_conns = {}
	local all_conns = {}
	local color_conns = {}

	for _, color in ipairs(automata.colors) do
		color_conns[color.name] = {}
	end

	for _, info in pairs(all_infos) do
		all_conns[info.node_name] = true

		if info.color then
			color_conns[info.color][info.node_name] = true
		else
			for _, color_conn in pairs(color_conns) do
				color_conn[info.node_name] = true
			end
		end
	end

	for _, info in pairs(all_infos) do
		if info.color then
			info.conns = color_conns[info.color]
		else
			info.conns = all_conns
		end
	end
end

local function build_infos(base_infos)
	local all_infos = {}

	for _, base_info in ipairs(base_infos) do
		local variations = build_info_variations(base_info)

		for _, info in ipairs(variations) do
			all_infos[info.node_name] = info
		end
	end

	build_info_conns(all_infos)

	return all_infos
end

local in_refresh = false

local function node_on_construct(pos)
	-- We have to be careful about calling `automata.refresh()` from inside the
	-- `on_construct` callback because it can call `minetest.swap_node()`, which
	-- will call `on_construct` again, leading to infinite recursion. So, don't
	-- call refresh again if we're already doing it.
	if not in_refresh then
		in_refresh = true

		automata.refresh(pos)

		in_refresh = false
	end
end

local function node_after_destruct(pos, old_node)
	-- The same logic about `automata.refresh()` that applies to `on_construct`
	-- also applies to `after_destruct`, so do the same here.
	if not in_refresh then
		in_refresh = true

		automata.around(pos, function(auto_pos, auto_info)
			automata.refresh(auto_pos)
		end, old_node)

		in_refresh = false
	end
end

local function start_on_construct(pos)
	node_on_construct(pos)

	local meta = minetest.get_meta(pos)
	meta:set_string("formspec", "field[input;Input;${automata_input}]")
end

local function start_on_receive_fields(pos, formname, fields, sender)
	if not sender:is_player() or not fields.input then
		return
	end

	if fields.input:match("^[01abc]*$") then
		automata.reset(pos)
		automata.set_meta(pos, {
			input = fields.input,
			tape = fields.input
		})
	else
		minetest.chat_send_player(sender:get_player_name(),
				"Error: Input must only contain zeros, ones, a's, b's, and c's")
	end
end

local function switch_tube(itemstack, user, switch_char)
	if not user or not user:is_player() then
		return nil
	end

	local info = automata.infos[itemstack:get_name()]
	local control = user:get_player_control()

	local char = info.char
	local color = info.color

	if switch_char then
		local index = control.sneak and info.prev_char or info.next_char
		char = automata.chars[index].name
	elseif info.next_color then
		local index = control.sneak and info.prev_color or info.next_color
		if index == 0 then
			color = nil
		else
			color = automata.colors[index].name
		end
	end

	local new_node = "automata:" .. info.base_name
	if char then
		new_node = new_node .. "_" .. char
	end
	if color then
		new_node = new_node .. "_" .. color
	end

	itemstack:set_name(new_node)
	return itemstack
end

local function tube_on_secondary_use(itemstack, user, pointed_thing)
	return switch_tube(itemstack, user, false)
end

local function tube_on_use(itemstack, user, pointed_thing)
	return switch_tube(itemstack, user, true)
end

local function register_node(info)
	local def = {
		description = info.desc,
		tiles = {info.texture .. info.modifier},
		use_texture_alpha = "clip",

		drop = info.drop_name or info.node_name,
		groups = {choppy = 3, oddly_breakable_by_hand = 3},
		is_ground_content = false
	}

	if info.variation then
		def.groups.not_in_creative_inventory = 1
	end

	if info.start then
		def.on_construct = start_on_construct
		def.on_receive_fields = start_on_receive_fields
	else
		def.on_construct = node_on_construct
	end
	def.after_destruct = node_after_destruct

	if not info.state then
		def.inventory_image = def.tiles[1]

		def.drawtype = "nodebox"
		def.node_box = {
			type = "connected",
			fixed = {-3/16, -3/16, -3/16, 3/16, 3/16, 3/16},
			connect_top = {-3/16, -3/16, -3/16, 3/16, 1/2, 3/16},
			connect_bottom = {-3/16, -1/2, -3/16, 3/16, 3/16, 3/16},
			connect_front = {-3/16, -3/16, -1/2, 3/16, 3/16, 3/16},
			connect_back = {-3/16, -3/16, -3/16, 3/16, 3/16, 1/2},
			connect_left = {-1/2, -3/16, -3/16, 3/16, 3/16, 3/16},
			connect_right = {-3/16, -3/16, -3/16, 1/2, 3/16, 3/16}
		}

		def.paramtype = "light"
		def.sunlight_propagates = true

		def.connects_to = {}
		for conn in pairs(info.conns) do
			table.insert(def.connects_to, conn)
		end

		def.on_secondary_use = tube_on_secondary_use
		if info.char then
			def.on_use = tube_on_use
		end
	end

	minetest.register_node(info.node_name, def)
end

automata.infos = build_infos({
	{
		base_name = "state",
		desc = "State",
		state = true
	},
	{
		base_name = "state_accept",
		desc = "Accept State",
		state = true,
		accept = true
	},
	{
		base_name = "state_start",
		desc = "Start State",
		state = true,
		start = true
	},
	{
		base_name = "state_start_accept",
		desc = "Start Accept State",
		state = true,
		start = true,
		accept = true
	},

	{
		base_name = "conn",
		desc = "Connect",
		conn = true
	},

	{
		base_name = "read",
		desc = "Read",
		uses_char = automata.ALL_CHARS,
		read = true
	},
	{
		base_name = "write",
		desc = "Write",
		uses_char = automata.BASIC_CHARS,
		write = true
	},

	{
		base_name = "left",
		desc = "Tape Left",
		move = true,
		left = true
	},
	{
		base_name = "right",
		desc = "Tape Right",
		move = true,
		right = true
	},

	{
		base_name = "pop",
		desc = "Pop",
		uses_char = automata.GAMMA_CHAR,
		pop = true
	},
	{
		base_name = "push",
		desc = "Push",
		uses_char = automata.BASIC_CHARS,
		push = true
	}
})

for _, info in pairs(automata.infos) do
	register_node(info)
end

minetest.register_tool("automata:stepper", {
	description = "Stepper",
	inventory_image = "automata_stepper.png",

	on_place = function(itemstack, placer, pointed_thing)
		if not placer:is_player() then
			return nil
		end
		local player = placer:get_player_name()

		local pos = pointed_thing.under
		if pointed_thing.type ~= "node" or not automata.get_node_info(pos) then
			minetest.chat_send_player(player, "Error: The stepper must be used on an automaton node")
			return nil
		end

		local data = automata.get_meta(pos)
		automata.reset(pos)
		automata.set_meta(pos, {
			input = data.input,
			tape = data.input
		})
	end,

	on_use = function(itemstack, user, pointed_thing)
		if not user:is_player() then
			return nil
		end
		local player = user:get_player_name()

		local pos = pointed_thing.under
		if pointed_thing.type ~= "node" or not automata.get_node_info(pos) then
			minetest.chat_send_player(player, "Error: The stepper must be used on an automaton node")
			return nil
		end

		local data = automata.get_meta(pos)
		if data.class == "invalid" then
			minetest.chat_send_player(player, "Error: The automaton is not valid")
			return nil
		end

		local all_states, starts = automata.get_states(pos)

		if data.state == "idle" then
			for _, start_pos in ipairs(starts[1]) do
				local start_info = automata.get_node_info(start_pos)
				minetest.swap_node(start_pos, {name = start_info.on_name})
			end

			automata.set_meta(pos, {
				state = "run"
			})
		elseif data.state == "accept" or data.state == "reject" then
			return nil
		else
			local on_states = {}
			for _, state_group in ipairs(all_states) do
				if automata.get_node_info(state_group[1]).is_on then
					table.insert(on_states, state_group)
				end
			end

			local can_trans = {}
			for _, state_group in ipairs(on_states) do
				for _, state_pos in ipairs(state_group) do
					automata.around(state_pos, function(read_pos, read_info)
						if read_info.read and automata.can_trans(read_pos) then
							table.insert(can_trans, read_pos)
						end
					end)
				end
			end

			if #can_trans == 0 then
				automata.turn_off(pos)
				automata.no_trans(pos)
			elseif #can_trans == 1 then
				automata.turn_off(pos)
				automata.run_trans(can_trans[1])
			else
				local info = automata.get_node_info(pos)
				if info.read then
					local valid = false

					for _, read_pos in ipairs(can_trans) do
						if read_pos == pos then
							valid = true
							automata.turn_off(pos)
							automata.run_trans(read_pos)
							break
						end
					end

					if not valid then
						minetest.chat_send_player(player, "Error: This nondeterministic " ..
								"transition cannot be applied")
					end
				else
					minetest.chat_send_player(player, "Error: Nondeterministic transition: " ..
							"explicitly choose the transition to follow")
				end
			end
		end

		data = automata.get_meta(pos)

		local has_on = false
		local has_accept = false
		local has_lambda = false

		for _, state_group in ipairs(all_states) do
			local state_info = automata.get_node_info(state_group[1])

			if state_info.is_on then
				has_on = true

				if state_info.accept then
					has_accept = true
				end

				for _, state_pos in ipairs(state_group) do
					automata.around(state_pos, function(read_pos, read_info)
						if read_info.read and read_info.char == "lambda" and
								automata.can_trans(read_pos) then
							has_lambda = true
						end
					end)
				end
			end
		end

		local new_state = "run"
		if data.class == "turing" then
			if has_accept then
				new_state = "accept"
			elseif not has_on then
				new_state = "reject"
			end
		elseif has_accept or not has_lambda then
			if data.pos == #data.input + 1 then
				new_state = has_accept and "accept" or "reject"
			end
		end

		if new_state ~= "run" then
			automata.set_meta(pos, {
				state = new_state
			})

			if new_state == "accept" then
				for _, state_group in ipairs(starts) do
					for _, start_pos in ipairs(state_group) do
						local start_info = automata.get_node_info(start_pos)
						minetest.swap_node(start_pos, {name = start_info.good_name})
					end
				end
			else
				for _, state_group in ipairs(starts) do
					for _, start_pos in ipairs(state_group) do
						local start_info = automata.get_node_info(start_pos)
						minetest.swap_node(start_pos, {name = start_info.bad_name})
					end
				end
			end
		end

		return nil
	end
})
