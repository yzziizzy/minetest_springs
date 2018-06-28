
local pump_formspec =
	"size[10,8;]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"button[5,1;1,4;start;Start]" ..
	"list[current_player;main;0,3.85;8,1;]" ..
	"list[current_player;main;0,5.08;8,3;8]" ..
	"listring[context;main]" ..
	"listring[current_player;main]" ..
	default.get_hotbar_bg(0, 3.85)

local pump_formspec_on =
	"size[10,8;]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"button[5,1;1,4;stop;Stop]" ..
	"list[current_player;main;0,3.85;8,1;]" ..
	"list[current_player;main;0,5.08;8,3;8]" ..
	"listring[context;main]" ..
	"listring[current_player;main]" ..
	default.get_hotbar_bg(0, 3.85)




local function swap_node(pos, name)
	local node = minetest.get_node(pos)
	if node.name == name then
		return
	end
	node.name = name
	minetest.swap_node(pos, node)
end

minetest.register_node("springs:pump", {
	description = "Pump",
	drawtype = "normal",
	tiles = {"default_steel_block.png"},
	is_ground_content = false,
	paramtype2 = "facedir",
	groups = {cracky = 1, petroleum_fixture=1, oddly_breakable_by_hand = 3},
	sounds = default.node_sound_glass_defaults(),
	on_place = minetest.rotate_node,
	
	on_construct = function(pos) 
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", pump_formspec)
		
		--springs.pipes.on_construct(pos)
	end,
	
	--[[ not working, apparently due to an "undocumented feature" in the engine ;)
	on_receive_fields = function(pos, form, fields, player)
		local meta = minetest:get_meta(pos)
		local mf = meta:get_string("formspec")
		print(dump(mf).."\n")
		
		if fields.start then
			print("start")
			swap_node(pos, "springs:pump_on")
			
			-- refetch the meta after the node swap just to be sure
			local meta = minetest:get_meta(pos)
			meta:set_string("formspec", "") 
			meta:set_string("formspec", pump_formspec_on) 
			local mf = meta:get_string("formspec")
			print(dump(mf))
			
			minetest.show_formspec(player:get_player_name(), "", pump_formspec_on)
		end
	end,
	]]
	
	on_punch = function(pos)
		swap_node(pos, "springs:pump_on")
	end,
})




minetest.register_node("springs:pump_on", {
	description = "Pump (Active)",
	drawtype = "normal",
	tiles = {"default_tin_block.png"},
	is_ground_content = false,
	paramtype2 = "facedir",
	groups = {cracky = 1, petroleum_fixture=1, oddly_breakable_by_hand = 3, --[[not_in_creaetive_inventory=1]]},
	sounds = default.node_sound_glass_defaults(),
	on_place = minetest.rotate_node,
	drop = "springs:pump",
	
	on_construct = function(pos) 
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", pump_formspec_on)
		
		--springs.pipes.on_construct(pos)
	end,
	
	--[[ not working, apparently due to an "undocumented feature" in the engine ;)
	on_receive_fields = function(pos, form, fields, player)
		if fields.stop then
			print("stop")
			swap_node(pos, {name="springs:pump"})
			
			local meta = minetest:get_meta(pos)
			meta:set_string("formspec", pump_formspec)
			minetest.show_formspec(player:get_player_name(), "", pump_formspec)
		end
	end,
	]]
	
	on_punch = function(pos)
		swap_node(pos, "springs:pump")
	end,
})








minetest.register_abm({
	nodenames = {"springs:pump_on"},
	interval = 1,
	chance   = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local node   = minetest.get_node(pos)
		
		local back_dir = minetest.facedir_to_dir(node.param2)
		local backpos = vector.add(pos, back_dir) 
		local backnet = springs.pipes.get_net(backpos)
		if backnet == nil then
			print("pump no backnet at "..minetest.pos_to_string(backpos))
			return
		end
		
		local front_dir = vector.multiply(back_dir, -1)
		local frontpos = vector.add(pos, front_dir)
		local frontnet = springs.pipes.get_net(frontpos)
		if frontnet == nil then
			print("pump no frontnet at "..minetest.pos_to_string(frontpos))
			return
		end
		
-- 		if backnet.fluid ~= frontnet.fluid and backnet.fluid ~= "air" then
-- 			print("pump: bad_fluid")
-- 			return -- incompatible fluids
-- 		end
		
		local lift = 70
		print("fpos ".. minetest.pos_to_string(frontpos) .. " | bpos "..minetest.pos_to_string(backpos))
		print("fp ".. frontnet.in_pressure .. " | bp "..backnet.in_pressure)
		local taken, fluid = springs.pipes.take_fluid(frontpos, 10, 0, 2)
		local pushed = springs.pipes.push_fluid(backpos, fluid, taken, lift)
		print("pumped " ..taken .. " > "..pushed)
		
		if pushed < taken then
			print("pump leaked ".. (taken - pushed))
		end
		
		--print("")
	end
})



minetest.register_craft({
	output = "springs:pump 1",
	recipe = {
		{"", "", ""},
		{"springs:pipe", "default:furnace", "springs:pipe"},
		{"", "", ""},
	}
})
