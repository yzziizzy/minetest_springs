


local networks = {}
local net_members = {}
local netname = 1

local mod_storage = minetest.get_mod_storage()


	
networks = minetest.deserialize(mod_storage:get_string("networks")) or {}
net_members = minetest.deserialize(mod_storage:get_string("net_members")) or {}
netname = mod_storage:get_int("netname") or 1


local function save_data() 
	--print("saving")
	
	mod_storage:set_string("networks", minetest.serialize(networks))
	mod_storage:set_string("net_members", minetest.serialize(net_members))
	mod_storage:set_int("netname", netname)
end


-- centralized network creation for consistency
local function new_network(pos) 
	local hash = minetest.hash_node_position(pos)
	print("new network: hash: ".. hash .." name: " ..netname); 
	
	networks[hash] = {
		hash = hash,
		pos = {x=pos.x, y=pos.y, z=pos.z},
		fluid = 'air',
		name = netname,
		count = 1,
		inputs = {
			[hash] = 1,
		},
		outputs = {},
		buffer = 0,
		in_pressure = -32000,
	}
	
	net_members[hash] = hash
	
	netname = netname + 1
	
	return networks[hash], hash
end


-- check nearby nodes for existing networks
local function check_merge(pos) 
	local hash = minetest.hash_node_position(pos)
	
	local merge_list = {}
	local current_net = nil
	local found_net = 0
	
	local check_net = function(npos)
		local nhash = minetest.hash_node_position(npos)
		local nphash = net_members[nhash] 
		if nphash ~= nil then
			local pnet = networks[nphash]
			
			if nil == current_net then
				print("joining existing network: ".. pnet.name)
				net_members[hash] = nphash
				current_net = nphash
				pnet.count = pnet.count + 1
				pnet.inputs[hash] = 1
				table.insert(merge_list, pnet)
			elseif current_net == nphash then
				print("alternate connection to existing network")
			else
				print("found seconday network: "..pnet.name)
				table.insert(merge_list, pnet)
			end
			
			found_net = 1
		end
	end
	
	check_net({x=pos.x, y=pos.y - 1, z=pos.z})
	check_net({x=pos.x, y=pos.y + 1, z=pos.z})
	check_net({x=pos.x + 1, y=pos.y, z=pos.z})
	check_net({x=pos.x - 1, y=pos.y, z=pos.z})
	check_net({x=pos.x, y=pos.y, z=pos.z + 1})
	check_net({x=pos.x, y=pos.y, z=pos.z - 1})
	
	return found_net, merge_list
end

-- merge a list if networks, if the are multiple nets in the list
local function try_merge(merge_list)
	if #merge_list > 1 then 
		print("\n merging "..#merge_list.." networks")
		
		local biggest = {count = 0}
		local mlookup = {}
		
		for _,n in ipairs(merge_list) do
			mlookup[n.hash] = 1 
			if n.count > biggest.count then
				biggest = n
			end
		end
		
		mlookup[biggest.hash] = 0
		
		for k,v in pairs(net_members) do
			if mlookup[v] == 1 then
				net_members[k] = biggest.hash
			end
		end
		
		
		for _,n in ipairs(merge_list) do
			if n.hash ~= biggest.hash then
				biggest.count = biggest.count + n.count
				networks[n.hash] = nil -- delete old networks
			end
		end
		
		return biggest
	end
	
	return merge_list[1]
end



local function pnet_for(pos)
	local hash = minetest.hash_node_position(pos)
	local ph = net_members[hash]
	if ph == nil then
		return nil, hash
	end
	
	return networks[ph], hash
end

local function walk_net(opos)
	local members = {}
	local count = 0
	
	local opnet = pnet_for(opos)
	if opnet == nil then
		return nil, 0, nil
	end
		
	local stack = {}
	table.insert(stack, opos)
	
	
	while #stack > 0 do
	
		local pos = table.remove(stack)
		local pnet, hash = pnet_for(pos)
		if pnet ~= nil and members[hash] == nil then
			
			-- only count members of the original node's network
			if pnet.name == opnet.name then
				members[hash] = pos
				count = count + 1
				
		--		print(" found net node: " .. minetest.pos_to_string(pos))
				
				table.insert(stack, {x=pos.x-1, y=pos.y, z=pos.z})
				table.insert(stack, {x=pos.x+1, y=pos.y, z=pos.z})
				table.insert(stack, {x=pos.x, y=pos.y-1, z=pos.z})
				table.insert(stack, {x=pos.x, y=pos.y+1, z=pos.z})
				table.insert(stack, {x=pos.x, y=pos.y, z=pos.z-1})
				table.insert(stack, {x=pos.x, y=pos.y, z=pos.z+1})
			end
		end
	end
	
	return members, count, opnet
end


-- crawls the network and assigns found nodes to the new network
local function rebase_network(pos) 
	
	local net, phash, hash = springs.pipes.get_net(pos)
--	print(dump(pos))
	if hash == phash then
		print("trying to rebase network to the same spot")
		return {name = 9999999}
	end
	
	local pipes = walk_net(pos)
--	print(dump(pipes))
	
	local new_net, new_phash = new_network(pos)
	
	-- switch all the members
	for h,p in pairs(pipes) do
		--print("reassigning " .. minetest.pos_to_string(p))
		net_members[h] = new_phash
		new_net.count = new_net.count + 1
	end
	
	return new_net, new_phash
end




springs.pipes = {}


-- used by external machines to connect to a network in their on_construct callback
springs.pipes.on_construct = function(pos) 
	local found_net, merge_list = check_merge(pos)
	
	if found_net == 0 then 
		local hash = minetest.hash_node_position(pos)
		local net = new_network(pos)
	end
	
	local pnet = try_merge(merge_list)
	--pnet.count = pnet.count + 1 -- TODO: this might be implicit somewhere else
	
	save_data()
end


springs.pipes.after_destruct = function(pos)

	local hash = minetest.hash_node_position(pos)
	local phash = net_members[hash]
	if phash == nil then
		print("wtf: pipe has no network in after_destruct")
		return
	end
	local pnet = networks[phash]
	if pnet == nil then
		print("wtf: no network in after_destruct for pipe")
		return
	end
	
	-- remove this node from the network
	net_members[hash] = nil
	pnet.count = pnet.count - 1
	
	-- neighboring nodes
	local check_pos = {
		{x=pos.x+1, y=pos.y, z=pos.z},
		{x=pos.x-1, y=pos.y, z=pos.z},
		{x=pos.x, y=pos.y+1, z=pos.z},
		{x=pos.x, y=pos.y-1, z=pos.z},
		{x=pos.x, y=pos.y, z=pos.z+1},
		{x=pos.x, y=pos.y, z=pos.z-1},
	}
	
	local stack = {}
	local found = 0
	-- check neighbors for network membership
	for _,p in ipairs(check_pos) do
		local h = minetest.hash_node_position(p)
		
		local lphash = net_members[h]
		if lphash ~= nil then
			local lpnet = networks[lphash]
			
			-- only process pipes/fixtures on the same network as the destroyed pipe
			if lpnet and lpnet.name == pnet.name then
				stack[h] = vector.new(p)
				found = found + 1
				--print("check stack: "..p.x..","..p.y..","..p.z)
			else 
				print("no lpnet")
			end
		else
			print("no lphash "..p.x..","..p.y..","..p.z)
		end
	end
	
	-- don't need to split the network if this was just on the end
	if found > 1 then
		--print("check to split the network")
		for h,p in pairs(stack) do
			print(dump(p))
			print(dump(h))
		-- BUG: spouts and intakes can be counted as pipes when walking the network
			
			-- just rename the net
			local new_pnet = rebase_network(p)
		--	print("split off pnet ".. new_pnet.name .. " at " .. minetest.pos_to_string(p))
			-- all fluid is lost in the network atm
			-- some networks might get orphaned, for example, the first
			--   net to be rebased in a loop
		end
		
		
	end
	
	save_data()
end


-- used by external machines to find the network for a node
springs.pipes.get_net = function(pos)
	local hash = minetest.hash_node_position(pos)
	local phash = net_members[hash]
	if phash == nil then
		return nil, nil, hash
	end
	
	return networks[phash], phash, hash
end


-- used by external machines to add fluid into the pipe network
-- returns amount of fluid successfully pushed into the network
springs.pipes.push_fluid = function(pos, fluid, amount, extra_pressure)
	local hash = minetest.hash_node_position(pos)
		
	local phash = net_members[hash]
	if phash == nil then 
		print("no network to push to")
		return 0 -- no network
	end
	local pnet = networks[phash]
	
-- 	if pnet.fluid == 'air' or pnet.buffer == 0 then
-- 		if minetest.registered_nodes[fluid] 
-- 			and minetest.registered_nodes[fluid].groups.petroleum ~= nil then
-- 			-- BUG: check for "full" nodes
-- 			pnet.fluid = fluid
-- 		else
-- 			print("here "..fluid.." ".. dump(minetest.registered_nodes[fluid]))
-- 			return 0 -- no available liquids
-- 		end
-- 	else -- only suck in existing fluid
-- 		if fluid ~= pnet.fluid and fluid ~= pnet.fluid.."_full" then
-- 			print("wrong fluid")
-- 			return 0
-- 		end
-- 	end
	
	if amount < 0 then
		print("!!!!!!!!!!!! push amount less than zero?")
		return 0
	end
	
	local input_pres = pos.y + extra_pressure
	
	pnet.in_pressure = pnet.in_pressure or -32000
	
	if pnet.in_pressure > input_pres then
		print("backflow at intake: " .. pnet.in_pressure.. " > " ..input_pres )
		return 0
	end
	
	pnet.in_pressure = math.max(pnet.in_pressure, input_pres)
	print("net pressure: ".. pnet.in_pressure)
	local rate = amount --math.max(1, math.ceil(ulevel / 2))
	
	local cap = 64
	local take = math.max(0, math.min(amount, cap - pnet.buffer))
	pnet.buffer = pnet.buffer + take

	return take
end

-- used by external machines to remove fluid from the pipe network
-- returns amount and fluid type
springs.pipes.take_fluid = function(pos, max_amount, backpressure, suction)
	local hash = minetest.hash_node_position(pos)
	local phash = net_members[hash]
	if phash == nil then 
		return 0, "air" -- no network
	end
	local pnet = networks[phash]
	
	if pnet.buffer <= 0 then
		--print("spout: no water in pipe")
		return 0, "air" -- no water in the pipe
	end
	
	-- hack
	pnet.in_pressure = pnet.in_pressure or -32000
	
	if pnet.in_pressure + (suction or 0) <= pos.y then
		print("insufficient pressure at spout: ".. pnet.in_pressure .. " < " ..pos.y )
		return 0, "air"
	end
	
	local take =  math.min(pnet.buffer, max_amount)
	pnet.buffer = pnet.buffer - take
	
	if pnet.buffer == 0 then
-- 		print("pipe drained " .. pnet.name) -- BUG: there might be a bug where a low pressure input can add fluid to the network with a higher spout, then a higher intake with low flow can raise the pressure of the previous fluid to the level of the comparatively lower spout
		pnet.in_pressure = backpressure or pos.y
	end
	
	return take, pnet.fluid
end


-- take or push into the network, based on given pressure
-- returns change in fluid and fluid type
-- negative if fluid was pushed into the network
-- positive if fluid was taken from the network
springs.pipes.buffer = function(pos, fluid, my_pres, avail_push, cap_take, can_change_fluid)
	local hash = minetest.hash_node_position(pos)
	local phash = net_members[hash]
	if phash == nil then 
		print("no net")
		return 0, "air" -- no network
	end
	local pnet = networks[phash]
	
-- 	print("pressure ["..pnet.name.."] ".. pnet.in_pressure .. " - " .. my_pres)
	if pnet.in_pressure <= my_pres then
		-- push into the network
-- 		print("push")
		return -springs.pipes.push_fluid(pos, fluid, avail_push, my_pres), fluid
	else
-- 		print("take") 
		if pnet.fluid == fluid or can_change_fluid then 
-- 			print("can take " .. cap_take)
			return springs.pipes.take_fluid(pos, cap_take, my_pres)
		else
-- 			print("wrong type ".. pnet.fluid .. " - ".. fluid)
			return 0, "air" -- wrong fluid type
		end
	end
	
end











minetest.register_node("springs:intake", {
	description = "Intake",
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = {{-.1, -.1, -.1, .1, .1, .1}},
		-- connect_bottom =
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
		connect_bottom = {{ -.1, -.5, -.1,  .1, .1,  .1}},
	},
	connects_to = { "group:water_pipe", "group:water_fixture" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_tin_block.png" },
	walkable = true,
	groups = { cracky = 3, water_fixture = 1, },
	on_construct = function(pos) 
		print("\nintake placed at "..pos.x..","..pos.y..","..pos.z)
		
		local found_net, merge_list = check_merge(pos)
		
		if found_net == 0 then 
			local hash = minetest.hash_node_position(pos)
			local net = new_network(pos)
			net.in_pressure = pos.y
			net.inputs[hash] = 1
		end
		
		try_merge(merge_list)
		
		save_data()
	end,
	after_destruct = springs.pipes.after_destruct,
})
		
minetest.register_abm({
	nodenames = {"springs:intake"},
	neighbors = {"group:fresh_water"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local hash = minetest.hash_node_position(pos)
		
		pos.y = pos.y + 1
		local unode = minetest.get_node(pos)
		if unode.name ~= "springs:water" and unode.name ~= "springs:water_full" then
			print("no water near intake")
			return
		end
		
		local ulevel = minetest.get_node_level(pos)
		if ulevel < 1 then
			print("!!!!!!!!!!!! intake level less than one?")
			return
		end
		
		local phash = net_members[hash]
		local pnet = networks[phash]
		
		
		pnet.in_pressure = pnet.in_pressure or -32000
		
		if pnet.in_pressure > pos.y - 1 then
			print("backflow at intake: " .. pnet.in_pressure.. " > " ..(pos.y - 1) )
			return
		end
		
		pnet.in_pressure = math.max(pnet.in_pressure, pos.y - 1)
		
		local rate = math.max(1, math.ceil(ulevel / 2))
		
		local cap = 64
		local take = math.max(0, math.min(ulevel, cap - pnet.buffer))
		pnet.buffer = pnet.buffer + take
		--print("intake took "..take.. " water")
		if ulevel - rate > 0 then
			minetest.set_node_level(pos, ulevel - take)
		else
			minetest.set_node(pos, {name = "air"})
		end
	end
})



minetest.register_node("springs:spout", {
	description = "Spout",
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = {{-.1, -.1, -.1, .1, .1, .1}},
		-- connect_bottom =
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
		connect_top = {{ -.1, -.1, -.1,  .1, .5,  .1}},
	},
	connects_to = { "group:water_pipe", "group:water_fixture" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_copper_block.png" },
	walkable = true,
	groups = { cracky = 3, water_fixture = 1, },
	on_construct = function(pos) 
		print("\nspout placed at "..pos.x..","..pos.y..","..pos.z)
		
		local found_net, merge_list = check_merge(pos)
		
		if found_net == 0 then 
			local hash = minetest.hash_node_position(pos)
			local pnet = new_network(pos)
			pnet.outputs[hash] = 1
		end
		
		try_merge(merge_list)
		
		save_data()
	end,
	after_destruct = springs.pipes.after_destruct,
})
		
		
minetest.register_abm({
	nodenames = {"springs:spout"},
-- 	neighbors = {"group:fresh_water"},
	interval = 1,
	chance = 1,
	action = function(pos)
		local hash = minetest.hash_node_position(pos)
		local phash = net_members[hash]
		local pnet = networks[phash]
		
		if pnet.buffer <= 0 then
			--print("spout: no water in pipe")
			return -- no water in the pipe
		end
		
		-- hack
		pnet.in_pressure = pnet.in_pressure or -32000
		
		if pnet.in_pressure <= pos.y then
			print("insufficient pressure at spout: ".. pnet.in_pressure .. " < " ..pos.y )
			return
		end
		
		
		pos.y = pos.y - 1
		
		local bnode = minetest.get_node(pos)
		local avail =  10 -- pnet.buffer / #pnet.outputs
		if bnode.name == "springs:water" then
			local blevel = minetest.get_node_level(pos)
			local cap = 64 - blevel
			local out = math.min(cap, math.min(avail, cap))
			--print("cap: ".. cap .." avail: ".. avail .. " out: "..out) 
			pnet.buffer = pnet.buffer - out
			minetest.set_node_level(pos, blevel + out)
		elseif bnode.name == "air" then
			local out = math.min(64, math.max(0, avail))
			pnet.buffer = pnet.buffer - out
			minetest.set_node(pos, {name = "springs:water"})
			minetest.set_node_level(pos, out)
		end
		
	
	end
})





minetest.register_node("springs:pipe", {
	description = "water pipe",
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = {{-.1, -.1, -.1, .1, .1, .1}},
		-- connect_bottom =
		connect_front = {{-.1, -.1, -.5,  .1, .1, .1}},
		connect_left = {{-.5, -.1, -.1, -.1, .1,  .1}},
		connect_back = {{-.1, -.1,  .1,  .1, .1,  .5}},
		connect_right = {{ .1, -.1, -.1,  .5, .1,  .1}},
		connect_top = {{ -.1, -.1, -.1,  .1, .5,  .1}},
		connect_bottom = {{ -.1, -.5, -.1,  .1, .1,  .1}},
	},
	connects_to = { "group:water_pipe", "group:water_fixture" },
	paramtype = "light",
	is_ground_content = false,
	tiles = { "default_steel_block.png" },
	walkable = true,
	groups = { cracky = 3, water_pipe = 1, },
	
	on_construct = function(pos) 
		print("\npipe placed at "..pos.x..","..pos.y..","..pos.z)
		
		local found_net, merge_list = check_merge(pos)
		
		if found_net == 0 then 
			local net = new_network(pos)
		end
		
		try_merge(merge_list)
		
		save_data()
	end,
	
	after_destruct = springs.pipes.after_destruct,
})


minetest.register_craft({
	output = "springs:pipe 3",
	recipe = {
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "", "default:steel_ingot"},
	}
})

minetest.register_craft({
	output = "springs:intake 1",
	type = "shapeless",
	recipe = {"springs:pipe", "default:tin_ingot"},
})

minetest.register_craft({
	output = "springs:spout 1",
	type = "shapeless",
	recipe = {"springs:pipe", "default:copper_ingot"},
})


