dofile(ModPath .. "lua/WeaponCopier.lua")

Hooks:PostHook(BlackMarketGui, "_setup", "weapon_copier_init_buttons", function (self)
	local buttons = {
		weapon_copier_select = {
			name = "weapon_copier_select",
			btn = "BTN_A",
			prio = 5,
			callback = WeaponCopier.select
		},
		weapon_copier_cancel = {
			name = "weapon_copier_cancel",
			btn = "BTN_X",
			prio = 2,
			callback = WeaponCopier.cancel
		},
		weapon_copier_place = {
			name = "weapon_copier_place",
			btn = "BTN_A",
			prio = 1,
			callback = WeaponCopier.show_confirmation
		}
	}
	local text_x = 10

	for name, config in pairs(buttons) do
		config.callback = callback(self, self, "overridable_callback", {
			button = name,
			callback = config.callback
		})
		self._btns[name] = BlackMarketGuiButtonItem:new(self._buttons, config, text_x)
	end

	self:show_btns(self._selected_slot)
end)

Hooks:PostHook(BlackMarketGui, "close", "weapon_copier_clear_selection", function (self)
	WeaponCopier.selected_index = nil
end)

Hooks:PostHook(BlackMarketGui, "populate_weapon_category_new", "weapon_copier_populate_page", function (self, page)
	if managers.blackmarket:get_hold_crafted_item() then return end

	local selected_index = WeaponCopier.selected_index

	if selected_index then
		for i = 1, #page do
			local slot = page[i]
			local buttons = {}

			if slot.slot == selected_index then
				slot.equipped_text = managers.localization:to_upper_text("weapon_copier_copying")
				slot.invalid_double_click = true
			elseif slot.locked_slot then
				table.insert(buttons, "ew_unlock")
			else
				table.insert(buttons, "weapon_copier_place")

				slot.selected_text = managers.localization:to_upper_text("weapon_copier_place")

				if slot.empty_slot then
					slot.mid_text.selected_text = slot.mid_text.noselected_text
				end
			end

			table.insert(buttons, "weapon_copier_cancel")

			slot.buttons = buttons
		end
	else
		for i = 1, #page do
			local slot = page[i]

			if not slot.empty_slot and slot.unlocked then
				table.insert(slot, "weapon_copier_select")
			end
		end
	end
end)

Hooks:PostHook(BlackMarketGuiSlotItem, "init", "weapon_copier_init_slot", function (self)
	if WeaponCopier.selected_index and (self._data.slot == WeaponCopier.selected_index) then
		BoxGuiObject:new(self._panel, {
			name = "weapon_copier_box",
			sides = {2, 2, 2, 2}
		})

		if not self._data.equipped then
			local equipped_text = self._panel:child("equipped_text")

			if equipped_text then
				equipped_text:set_text(self._data.equipped_text)
			end
		end
	end
end)

Hooks:PostHook(BlackMarketGuiSlotItem, "select", "weapon_copier_select_slot", function (self)
	if WeaponCopier.selected_index then
		if self._data.slot == WeaponCopier.selected_index then
			local box = self._panel:child("weapon_copier_box")

			if box then
				box:hide()
			end
		elseif self._data.equipped then
			local equipped_text = self._panel:child("equipped_text")

			if equipped_text then
				equipped_text:set_text(self._data.selected_text)
			end
		end
	end
end)

Hooks:PostHook(BlackMarketGuiSlotItem, "deselect", "weapon_copier_deselect_slot", function (self)
	if WeaponCopier.selected_index then
		if self._data.slot == WeaponCopier.selected_index then
			local box = self._panel:child("weapon_copier_box")

			if box then
				box:show()
			end
		elseif self._data.equipped then
			local equipped_text = self._panel:child("equipped_text")

			if equipped_text then
				equipped_text:set_text(self._data.equipped_text or managers.localization:to_upper_text("bm_menu_equipped"))
			end
		end
	end
end)
