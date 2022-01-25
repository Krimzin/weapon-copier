WeaponCopier = {}
WeaponCopier.selected_index = nil

function WeaponCopier.select(slot)
	local weapon = managers.blackmarket:get_crafted_category_slot(slot.category, slot.slot)
	local mods = WeaponCopier.get_mods(weapon)
	local missing_mods = WeaponCopier.get_missing_mods(mods)

	local cash_cost = WeaponCopier.get_cash_cost(weapon, mods)
	local coin_cost = WeaponCopier.get_coin_cost(missing_mods)

	local has_cash = cash_cost <= managers.money:total()
	local has_coins = coin_cost <= managers.custom_safehouse:coins()

	if has_cash and has_coins then
		WeaponCopier.selected_index = slot.slot

		managers.menu_component:reload_blackmarket_gui()
	else
		WeaponCopier.show_too_expensive(cash_cost, coin_cost)
	end
end

function WeaponCopier.cancel(slot)
	WeaponCopier.selected_index = nil

	managers.menu_component:reload_blackmarket_gui()
end

function WeaponCopier.show_confirmation(slot)
	local weapon = managers.blackmarket:get_crafted_category_slot(slot.category, WeaponCopier.selected_index)
	local mods = WeaponCopier.get_mods(weapon)
	local missing_mods = WeaponCopier.get_missing_mods(mods)

	local cash_cost = WeaponCopier.get_cash_cost(weapon, mods)
	local coin_cost = WeaponCopier.get_coin_cost(missing_mods)

	local texts = {}
	local cash_string = managers.experience:cash_string(cash_cost)
	local coin_string = managers.experience:cash_string(coin_cost, "")

	if cash_cost > 0 then
		if coin_cost > 0 then
			table.insert(texts, managers.localization:text("weapon_copier_cash_coin_cost", {
				cash = cash_string,
				coins = coin_string
			}))
		else
			table.insert(texts, managers.localization:text("weapon_copier_cash_cost", {
				cash = cash_string
			}))
		end
	elseif coin_cost > 0 then
		table.insert(texts, managers.localization:text("weapon_copier_coin_cost", {
			coins = coin_string
		}))
	end

	if managers.blackmarket:get_crafted_category_slot(slot.category, slot.slot) then
		local cash_value = managers.money:get_weapon_slot_sell_value(slot.category, slot.slot)
		local cash_string = managers.experience:cash_string(cash_value)

		table.insert(texts, managers.localization:text("weapon_copier_weapon_sold", {
			cash = cash_string
		}))
	end

	local text = table.concat(texts, "\n\n")

	managers.system_menu:show({
		title = managers.localization:to_upper_text("weapon_copier_confirmation"),
		text = text,
		button_list = {
			{
				text = managers.localization:text("dialog_yes"),
				callback_func = function () WeaponCopier.confirm(slot) end
			},
			{
				text = managers.localization:text("dialog_no"),
				cancel_button = true
			}
		}
	})
end

function WeaponCopier.confirm(slot)
	local weapon = managers.blackmarket:get_crafted_category_slot(slot.category, WeaponCopier.selected_index)
	local mods = WeaponCopier.get_mods(weapon)
	local missing_mods = WeaponCopier.get_missing_mods(mods)

	local cash_cost = WeaponCopier.get_cash_cost(weapon, mods)
	local coin_cost = WeaponCopier.get_coin_cost(missing_mods)

	local has_cash = cash_cost <= managers.money:total()
	local has_coins = coin_cost <= managers.custom_safehouse:coins()

	if has_cash and has_coins then
		WeaponCopier.copy(slot, weapon, mods, missing_mods)
	else
		WeaponCopier.show_too_expensive(cash_cost, coin_cost)
		WeaponCopier.cancel()
	end
end

function WeaponCopier.copy(slot, weapon, mods, missing_mods)
	if managers.blackmarket:get_crafted_category_slot(slot.category, slot.slot) then
		managers.blackmarket:on_sell_weapon(slot.category, slot.slot)
	end

	managers.blackmarket:on_buy_weapon_platform(slot.category, weapon.weapon_id, slot.slot)
	managers.mission:call_global_event(Message.OnWeaponBought)

	WeaponCopier.equip_cosmetics(slot, weapon.cosmetics)
	WeaponCopier.buy_missing_mods(missing_mods)
	WeaponCopier.equip_mods(slot, mods)

	local new_weapon = managers.blackmarket:get_crafted_category_slot(slot.category, slot.slot)
	new_weapon.blueprint = clone(weapon.blueprint) -- In case mods from the skin blueprint have been removed.

	if weapon.texture_switches then
		new_weapon.texture_switches = clone(weapon.texture_switches)
	end

	if weapon.custom_colors then
		new_weapon.custom_colors = clone(weapon.custom_colors)
	end

	WeaponCopier.selected_index = nil

	managers.menu_component:post_event("item_buy")
	managers.menu_component:reload_blackmarket_gui()
end

function WeaponCopier.equip_cosmetics(slot, cosmetics)
	if cosmetics then
		if tweak_data.blackmarket.weapon_skins[cosmetics.id].is_a_color_skin then
			local update_weapon_unit = false

			managers.blackmarket:on_equip_weapon_color(slot.category, slot.slot, cosmetics, update_weapon_unit)
		else
			managers.blackmarket:on_equip_weapon_cosmetics(slot.category, slot.slot, cosmetics.instance_id)
		end
	end
end

function WeaponCopier.buy_missing_mods(missing_mods)
	local telemetry_prefix = TelemetryConst.economy_origin.purchase_weapon_mod

	for i = 1, #missing_mods do
		local part_id = missing_mods[i]
		local global_value = managers.blackmarket:get_global_value("weapon_mods", part_id)
		local not_new = true
		local coin_cost = BlackMarketGui:get_weapon_mod_coin_cost(part_id)

		managers.blackmarket:add_to_inventory(global_value, "weapon_mods", part_id, not_new)
		managers.custom_safehouse:deduct_coins(coin_cost, telemetry_prefix .. part_id)
	end
end

function WeaponCopier.equip_mods(slot, mods)
	local mods_tweak = tweak_data.blackmarket.weapon_mods

	for i = 1, #mods do
		local part_id = mods[i]
		local global_value = managers.blackmarket:get_global_value("weapon_mods", part_id)
		local free = false
		local no_consume = mods_tweak[part_id].is_a_unlockable

		managers.blackmarket:buy_and_modify_weapon(slot.category, slot.slot, global_value, part_id, free, no_consume)
	end
end

function WeaponCopier.get_mods(weapon)
	local mods = {}
	local blueprint = weapon.blueprint
	local mods_tweak = tweak_data.blackmarket.weapon_mods
	local skin_parts = WeaponCopier.get_skin_blueprint_set(weapon)

	for i = 1, #blueprint do
		local part_id = blueprint[i]

		if mods_tweak[part_id].pcs and not skin_parts[part_id] then
			table.insert(mods, part_id)
		end
	end

	return mods
end

function WeaponCopier.get_missing_mods(mods)
	local missing_mods = {}

	for i = 1, #mods do
		local part_id = mods[i]
		local global_value = managers.blackmarket:get_global_value("weapon_mods", part_id)

		if not managers.blackmarket:has_item(global_value, "weapon_mods", part_id) then
			table.insert(missing_mods, part_id)
		end
	end

	return missing_mods
end

function WeaponCopier.get_skin_blueprint_set(weapon)
	local skin_id = weapon.cosmetics and weapon.cosmetics.id
	local blueprint = skin_id and tweak_data.blackmarket.weapon_skins[skin_id].default_blueprint

	return blueprint and table.list_to_set(blueprint) or {}
end

function WeaponCopier.get_cash_cost(weapon, mods)
	local weapon_id = weapon.weapon_id
	local cost = managers.money:get_weapon_price_modified(weapon_id)

	for i = 1, #mods do
		local part_id = mods[i]
		local global_value = managers.blackmarket:get_global_value("weapon_mods", part_id)
		cost = cost + managers.money:get_weapon_modify_price(weapon_id, part_id, global_value)
	end

	return cost
end

function WeaponCopier.get_coin_cost(mods)
	local cost = 0

	for i = 1, #mods do
		cost = cost + BlackMarketGui:get_weapon_mod_coin_cost(mods[i])
	end

	return cost
end

function WeaponCopier.show_too_expensive(cash_cost, coin_cost)
	local text = ""
	local cash_string = managers.experience:cash_string(cash_cost)
	local coin_string = managers.experience:cash_string(coin_cost, "")

	if cash_cost > 0 then
		if coin_cost > 0 then
			text = managers.localization:text("weapon_copier_need_cash_coins", {
				cash = cash_string,
				coins = coin_string
			})
		else
			text = managers.localization:text("weapon_copier_need_cash", {
				cash = cash_string
			})
		end
	elseif coin_cost > 0 then
		text = managers.localization:text("weapon_copier_need_coins", {
			coins = coin_string
		})
	end

	managers.system_menu:show({
		title = managers.localization:to_upper_text("weapon_copier_too_expensive"),
		text = text,
		button_list = {
			{
				text = managers.localization:text("dialog_ok")
			}
		}
	})
end
