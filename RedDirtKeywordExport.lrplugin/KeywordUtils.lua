--[[
  KeywordUtils.lua
  Small helper functions in plain Lua, with no Lightroom calls, so they
  can be tested outside Lightroom.
]]

local KeywordUtils = {}

-- The separator used to store a list of keywords in a single text setting.
-- Keywords never contain line breaks, so a newline is safe.
local SEPARATOR = '\n'

-- Turn a keyword into a safe Windows folder name.
-- Removes  \ / : * ? " < > |  and control characters, trims spaces,
-- and drops trailing dots (Windows doesn't allow names ending in a dot).
function KeywordUtils.cleanFolderName(name)
	if type(name) ~= 'string' then return '' end
	local clean = name:gsub('[\\/:%*%?"<>|%c]', '')
	clean = clean:gsub('^%s+', ''):gsub('[%s%.]+$', '')
	return clean
end

-- Turn a list like { 'Name 1', 'Name 2' } into one string for saving.
function KeywordUtils.joinList(list)
	return table.concat(list, SEPARATOR)
end

-- Turn a saved string back into a lookup table: { ['Name 1'] = true, ... }
function KeywordUtils.parseList(text)
	local set = {}
	if type(text) ~= 'string' then return set end
	for item in text:gmatch('[^' .. SEPARATOR .. ']+') do
		set[item] = true
	end
	return set
end

-- Return a path that doesn't exist yet. If "photo.jpg" is taken, try
-- "photo-2.jpg", "photo-3.jpg", and so on.
-- `exists` is a function(path) -> true/false, passed in so this stays testable.
function KeywordUtils.uniquePath(path, exists)
	if not exists(path) then return path end

	-- Split "C:\out\photo.jpg" into "C:\out\photo" and ".jpg".
	local stem, ext = path:match('^(.*)(%.[^%.\\/]*)$')
	if not stem then
		stem, ext = path, ''
	end

	local n = 2
	while true do
		local candidate = stem .. '-' .. n .. ext
		if not exists(candidate) then return candidate end
		n = n + 1
	end
end

-- Find the first free numbered name: "carlos-1.jpg", "carlos-2.jpg", ...
-- name:    the keyword (already cleaned), e.g. "carlos"
-- ext:     the extension including the dot, e.g. ".jpg"
-- start:   number to start checking from (nil means 1)
-- isTaken: function(fileName) -> true if that file already exists
-- Returns the file name and the number used.
function KeywordUtils.nextNumberedName(name, ext, start, isTaken)
	local n = start or 1
	while isTaken(name .. '-' .. n .. ext) do
		n = n + 1
	end
	return name .. '-' .. n .. ext, n
end

-- Work out which folder names a photo should go into.
-- keywordNames: the photo's keyword names
-- excluded:     lookup table of keywords the user unticked
-- Returns a list of cleaned folder names, without duplicates (Windows folder
-- names ignore case, so "smith" and "Smith" count as the same folder).
function KeywordUtils.folderNamesFor(keywordNames, excluded)
	local folders, seen = {}, {}
	for _, name in ipairs(keywordNames) do
		if not excluded[name] then
			local clean = KeywordUtils.cleanFolderName(name)
			local key = clean:lower()
			if clean ~= '' and not seen[key] then
				seen[key] = true
				folders[#folders + 1] = clean
			end
		end
	end
	return folders
end

return KeywordUtils
