_addon.name = 'Slippery'
_addon.author = 'Kavendis@Asura'
_addon.version = '0.0.1'
_addon.command = 'slippery'

packets = require('packets')
slips = require('slips')
res = require('resources')

error_color = 123
debug_color = 158
debug_mode = true
error_mode = true

local inventory = nil

busy = false

valid_zones = {
	[245] = {menu=0}, -- Lower Jeuno
	[249] = {menu=338}, -- Mhaura
}

function debug_log( message )
	if debug_mode then
		windower.add_to_chat(debug_color, message)
	end
end

function error_log( message )
	if error_mode then
		windower.add_to_chat(error_color, message)
	end
end

function build_deposit_trade( porter_moogle, slip_number, items )
	debug_log("Building Deposit Trade for Slip " .. slip_number)
	
	local slip_index = get_slip_index_from_slip_number(slip_number)
	
	if not slip_index then
		windower.add_to_chat(error_color, "Slip " .. slip_number .. " not found.")	
	end

	local packet = packets.new('outgoing', 0x036)
	
    packet["Target"] = porter_moogle["Target ID"]
    packet["Target Index"] = porter_moogle["Target Index"]
    packet["Item Count 1"] = 1
    packet["Item Index 1"] = slipIndex

	--Build up all the things we're trading
	
    packet["Number of Items"] = 0
	
    --packets.inject(packet)
end

function build_withdraw_trade( porter_moogle, slip_number )
	debug_log("Building Withdraw Trade for Slip " .. slip_number)
	
	local slip_index = get_slip_index_from_slip_number(slip_number)
	
	if not slip_index then
		windower.add_to_chat(error_color, "Slip " .. slip_number .. " not found.")	
	end

    local packet = packets.new('outgoing', 0x036)
	
    packet["Target"] = porter_moogle["Target ID"]
    packet["Target Index"] = porter_moogle["Target Index"]
    packet["Item Count 1"] = 1
    packet["Item Index 1"] = slip_index

    packet["Number of Items"] = 1
	
    packets.inject(packet)
end

function retrieve_item_by_menu_index( porter_moogle, menu_index )
	local packet = packets.new('outgoing', 0x05B)
	packet["Target"] = porter_moogle["Target ID"]
	packet["Option Index"] = menu_index
	packet["_unknown1"] = 0
	packet["Target Index"] = porter_moogle["Target Index"]
	packet["Automated Message"] = true
	packet["_unknown2"] = 0
	packet["Zone"] = porter_moogle["Zone"]
	packet["Menu ID"] = porter_moogle["Menu ID"]
	
	packets.inject(packet)
end

function send_goodbye_packet( porter_moogle )
	local packet = packets.new('outgoing', 0x05B)
	packet["Target"] = porter_moogle["Target ID"]
	packet["Option Index"] = 0
	packet["_unknown1"] = 16384
	packet["Target Index"] = porter_moogle["Target Index"]
	packet["Automated Message"] = false
	packet["_unknown2"] = 0
	packet["Zone"] = porter_moogle["Zone"]
	packet["Menu ID"] = porter_moogle["Menu ID"]
	
	packets.inject(packet)	
end

function send_refresh_packet( porter_moogle )
	local packet = packets.new('outgoing', 0x016)
	packet["Target Index"] = porter_moogle["me"]
	
	packets.inject(packet)	
end

function check_close_to_porter_moogle()
	local zone = windower.ffxi.get_info()['zone']
	local distance = 100
	local result = {}
	
	if not valid_zones[zone] then
		windower.add_to_chat(error_color, "Not in a zone with a Porter Moogle.")
		return nil
	end
	
	result["Zone"] = zone
	result["Menu ID"] = valid_zones[zone].menu
	
	for i,v in pairs(windower.ffxi.get_mob_array()) do
		if v['name'] == windower.ffxi.get_player().name then
			result['me'] = i
			debug_log("Found me: " .. i)
		elseif v['name'] == "Porter Moogle" then
			result["Target Index"] = i
			result["Target ID"] = v['id']
			distance = windower.ffxi.get_mob_by_id(v['id']).distance
			debug_log("Found moogle: " .. i .. ' ' .. v['id'])
		end
	end
	
	if distance > 36 then
		windower.add_to_chat(error_color, "Too far from Porter Moogle")
		return nil
	end
	
	return result
end

function get_slip_index_from_slip_number(slip_number)
	local slip_item_id = slips.get_slip_id(slip_number)
	
	if not slip_item_id then
		windower.add_to_chat(error_color, "Invalid slip number: " .. slip_number)
		return
	end
	
	local slip_index = get_item_index(slip_item_id)
	
	if not slip_index then
		windower.add_to_chat(error_color, "Slip " .. slip_number .. " not in inventory.")
		return
	end	
	
	return slip_index
end

function get_item_index(item_id)
	inventory = windower.ffxi.get_items(0) --TODO: Better track inventory, lock with each request

    for itemIndex, item in pairs(inventory) do
        if item.id == item_id then
            return itemIndex
        end
    end
	
	return nil
end

--[[Interactive Stuff (Commands)]]
windower.register_event('addon command', function(...)

	local item_names = {"Warrior's Lorica", "Arasy Sword", "Warrior's Calligae", "Warrior's Cuisses", "Warrior's Codpiece", "Melee Crown"}

	debug_log("Ooh... Slippery!")
	if arg[1] == "test" then
		debug_log("Beginning Test")

		local moogle = check_close_to_porter_moogle()
		if not moogle then
			error_log("Couldn't find a Porter Moogle")
			return
		end
		
		local item_ids = {}
		
		for _, name in ipairs(item_names) do
			local potential_match = res.items:with('name', name)
			if potential_match then
				table.insert(item_ids, potential_match.id)
			else
				error_log("Item %s does not exist.":format(name))
			end
		end
		
		debug_log(dump(item_ids))
		
		local slips_to_use = {}
		
		for _, item_id in ipairs(item_ids) do
			local potential_slip = slips.get_slip_id_by_item_id(item_id)
			if not potential_slip then
				error_log("Item id %d (%s) is not on any slip.":format(item_id, res.items[item_id].name))
			elseif not slips.player_has_item(item_id) then
				error_log("You don't own Item id %d (%s).":format(item_id, res.items[item_id].name))
			else
				if not slips_to_use[potential_slip] then
					slips_to_use[potential_slip] = T{}
				end
				
				slips_to_use[potential_slip]:append(item_id)
			end	
		end
		
		debug_log(dump(slips_to_use))
		
		local slipped_items = slips.get_player_items()
		
		local menu_indices_per_slip = T{}
		
		for slip_id, item_ids in pairs(slips_to_use) do
			local offset_tracker = 1
			for i, slipped_item_id in ipairs(slipped_items[slip_id]) do
				local slip_number = slips.get_slip_number_by_id(slip_id)
				if item_ids:contains(slipped_item_id) then
					if not menu_indices_per_slip[slip_number] then menu_indices_per_slip[slip_number] = T{} end
					menu_indices_per_slip[slip_number]:append(i - offset_tracker)
					offset_tracker = offset_tracker + 1
				end
			end
		end
		
		debug_log(dump(menu_indices_per_slip))
			
		for slip_number, menu_indices in pairs(menu_indices_per_slip) do
			
			event_id = windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
				if id ~= 0x034 then return end
				
				local packet = packets.parse('incoming', data)
				if packet["Menu ID"] == moogle["Menu ID"] then
					
					for _, menu_index in ipairs(menu_indices) do 
						retrieve_item_by_menu_index(moogle, menu_index)
					end
					
					send_goodbye_packet(moogle)
					send_refresh_packet(moogle)
				
					windower.unregister_event(moogle["Event ID"])
					return true
				end
			end)
			
			moogle["Event ID"] = event_id
			
			build_withdraw_trade( moogle, slip_number )		
		end
	end
	
end)

--[[Test Stuff (Debug)]]
-- windower.register_event('outgoing chunk', function(id, data)
	-- if id == 0x036 then -- outgoing trade
		-- local packet = packets.parse('outgoing', data)
		-- debug_log("Item Count 1: " .. packet["Item Count 1"])
		-- debug_log("Item Index 1: " .. packet["Item Index 1"])
	-- end
-- end)

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function print_menu_packet(id, data, modified, injected, blocked)
	if id ~= 0x032 and id ~= 0x033 and id ~= 0x034 then return end
	
	local packet = packets.parse('incoming', data)
	debug_log("Incoming Packet ID: " ..  '0x%03x':format(id))
	debug_log("Menu ID: " .. packet["Menu ID"])
	
	if id == 0x034 then
		debug_log("Menu Parameters: %s":format(tostring(packet["Menu Parameters"])))
	end
end

function print_outgoing_packet(id, data, modified, injected, blocked)
	if id == 0x015 then return end
	
	local packet = packets.parse('outgoing', data)
	debug_log("Outgoing Packet ID: " ..  '0x%03x':format(id))
	
	if id == 0x05B or id == 0x03A then
		debug_log("Option Index: " .. packet["Option Index"])
		debug_log("   _unknown1: " .. packet["_unknown1"])
		debug_log("   _unknown2: " .. packet["_unknown2"])
		debug_log("   Automated: " .. tostring(packet["Automated Message"]))
		debug_log("Option Index: " .. packet["Option Index"])
	end
end

--windower.register_event('incoming chunk', print_menu_packet)
--windower.register_event('outgoing chunk', print_outgoing_packet)