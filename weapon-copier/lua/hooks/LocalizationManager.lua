local localization_path = ModPath .. "localization/"

Hooks:Add("LocalizationManagerPostInit", "weapon_copier_localization", function (self)
	local files = file.GetFiles(localization_path)
	local key = SystemInfo:language():key()
	local file_name = "english.txt"

	for i = 1, #files do
		local name = files[i]

		if Idstring(name:match("^(.*).txt$")):key() == key then
			file_name = name
			
			break
		end
	end

	local path = localization_path .. file_name

	if io.file_is_readable(path) then
		self:load_localization_file(path)
	end
end)
