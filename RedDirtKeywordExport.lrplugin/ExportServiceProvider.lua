--[[
  ExportServiceProvider.lua
  Builds the plugin's panel in the Export dialog and sorts the exported
  files into one folder per keyword.
]]

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

-- Most keyword checkboxes the panel can show.
local MAX_KEYWORDS = 50

-- Log file: Documents\LrClassicLogs\RedDirtKeywordExport.log
local logger = LrLogger('RedDirtKeywordExport')
logger:enable('logfile')
logger:info('ExportServiceProvider loading')

local KeywordUtils = require 'KeywordUtils'

local provider = {}

--------------------------------------------------------------------------------
-- Dialog setup
--------------------------------------------------------------------------------

-- Hide Lightroom's own "Export Location" panel; our base folder replaces it.
-- With it hidden, Lightroom renders each photo to a temp folder and hands
-- us the file, and we copy it where it belongs.
-- "File Naming" is hidden too: the plugin names files itself
-- (keyword-1.jpg, keyword-2.jpg, ... numbered separately in each folder).
-- Video, Output Sharpening and Watermarking aren't used with this plugin.
provider.hideSections = {
	'exportLocation',
	'fileNaming',
	'video',
	'outputSharpening',
	'watermarking',
}

-- Photos only: Lightroom leaves any selected videos out of the export.
provider.canExportVideo = false

-- Called just before the export starts. A hidden panel still keeps its
-- settings, so anything switched on in an earlier export (renaming, a
-- watermark, sharpening) would quietly still apply. Switch them all off.
function provider.updateExportSettings(exportSettings)
	exportSettings.LR_renamingTokensOn = false
	exportSettings.LR_useWatermark = false
	exportSettings.LR_outputSharpeningOn = false
end

-- Settings saved with export presets.
--   rdke_baseFolder: the folder the keyword folders are created in
--   rdke_excluded:   keywords the user unticked, one per line
provider.exportPresetFields = {
	{ key = 'rdke_baseFolder', default = '' },
	{ key = 'rdke_excluded', default = '' },
}

-- Collect the keyword names on the currently selected photos, sorted A-Z.
local function keywordsOnSelectedPhotos()
	local catalog = LrApplication.activeCatalog()
	local names, seen = {}, {}
	for _, photo in ipairs(catalog:getTargetPhotos()) do
		for _, keyword in ipairs(photo:getRawMetadata('keywords') or {}) do
			local name = keyword:getName()
			if not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

-- Stop the Export button from working until a valid base folder is set.
local function updateExportStatus(propertyTable)
	local base = propertyTable.rdke_baseFolder
	if base == nil or base == '' then
		propertyTable.LR_cantExportBecause = 'Choose a base folder for Red Dirt Keyword Export.'
	elseif not LrFileUtils.exists(base) then
		propertyTable.LR_cantExportBecause = 'The base folder does not exist.'
	else
		propertyTable.LR_cantExportBecause = nil
	end
end

local buildSections  -- defined below

-- Lightroom only says "internal error" when this function fails, so we catch
-- the error ourselves, log it, and show the real message in the panel.
function provider.sectionsForTopOfDialog(f, propertyTable)
	local ok, result = pcall(buildSections, f, propertyTable)
	if ok then return result end

	logger:error('sectionsForTopOfDialog failed: ' .. tostring(result))
	return {
		{
			title = 'Red Dirt Keyword Export - error',
			f:static_text {
				title = 'Error: ' .. tostring(result),
				width_in_chars = 60,
				height_in_lines = 6,
			},
		},
	}
end

buildSections = function(f, propertyTable)
	local bind = LrView.bind

	-- Start every export with all keywords ticked.
	propertyTable.rdke_excluded = ''

	-- Reading keywords from the catalog is only allowed inside a background
	-- task, but this function isn't one. So we draw MAX_KEYWORDS empty,
	-- hidden checkbox "slots" now, then fill them in from a background task.
	-- Each slot i is bound to three settings:
	--   rdke_kw_i      ticked or not
	--   rdke_kwName_i  the keyword shown as its label
	--   rdke_kwShow_i  whether the slot is visible
	local keywordNames = {}

	local function rebuildExcluded()
		local excluded = {}
		for i, name in ipairs(keywordNames) do
			if i <= MAX_KEYWORDS and not propertyTable['rdke_kw_' .. i] then
				excluded[#excluded + 1] = name
			end
		end
		propertyTable.rdke_excluded = KeywordUtils.joinList(excluded)
	end

	local checkboxes = {}
	for i = 1, MAX_KEYWORDS do
		propertyTable['rdke_kw_' .. i] = true
		propertyTable['rdke_kwName_' .. i] = ''
		propertyTable['rdke_kwShow_' .. i] = false
		propertyTable:addObserver('rdke_kw_' .. i, rebuildExcluded)
		checkboxes[#checkboxes + 1] = f:checkbox {
			title = bind('rdke_kwName_' .. i),
			value = bind('rdke_kw_' .. i),
			visible = bind('rdke_kwShow_' .. i),
			-- Fixed width: the label is blank when the panel is drawn, so
			-- without this Lightroom gives it no room for the name added later.
			width = 380,
		}
	end

	propertyTable.rdke_kwStatus = 'Loading keywords...'

	LrTasks.startAsyncTask(function()
		local ok, result = LrTasks.pcall(keywordsOnSelectedPhotos)
		if not ok then
			logger:error('Loading keywords failed: ' .. tostring(result))
			propertyTable.rdke_kwStatus = 'Could not load keywords: ' .. tostring(result)
			return
		end

		keywordNames = result
		for i, name in ipairs(keywordNames) do
			if i > MAX_KEYWORDS then break end
			propertyTable['rdke_kwName_' .. i] = name
			propertyTable['rdke_kwShow_' .. i] = true
		end

		if #keywordNames == 0 then
			propertyTable.rdke_kwStatus = 'No keywords on the selected photos. Everything will go into the base folder.'
		elseif #keywordNames > MAX_KEYWORDS then
			propertyTable.rdke_kwStatus = 'Showing the first ' .. MAX_KEYWORDS .. ' of '
				.. #keywordNames .. ' keywords. The rest are always used.'
		else
			propertyTable.rdke_kwStatus = 'Each ticked keyword becomes a folder. Photos with no ticked keyword go into the base folder.'
		end
	end)

	local keywordList = f:column {
		f:static_text {
			title = bind 'rdke_kwStatus',
			width_in_chars = 60,
		},
		f:scrolled_view {
			width = 420,
			height = 180,
			horizontal_scroller = false,
			f:column(checkboxes),
		},
	}

	propertyTable:addObserver('rdke_baseFolder', function() updateExportStatus(propertyTable) end)
	updateExportStatus(propertyTable)

	return {
		{
			title = 'Red Dirt Keyword Export',
			synopsis = bind { key = 'rdke_baseFolder', object = propertyTable },

			f:row {
				f:static_text {
					title = 'Base folder:',
					alignment = 'right',
					width = LrView.share 'rdke_label',
				},
				f:edit_field {
					value = bind 'rdke_baseFolder',
					width_in_chars = 40,
					immediate = true,
				},
				f:push_button {
					title = 'Choose...',
					action = function()
						local result = LrDialogs.runOpenPanel {
							title = 'Choose the base folder',
							canChooseFiles = false,
							canChooseDirectories = true,
							canCreateDirectories = true,
							allowsMultipleSelection = false,
						}
						if result and result[1] then
							propertyTable.rdke_baseFolder = result[1]
						end
					end,
				},
			},

			f:row {
				f:static_text {
					title = 'Keywords:',
					alignment = 'right',
					width = LrView.share 'rdke_label',
				},
				keywordList,
			},

			f:row {
				f:static_text {
					title = '',
					width = LrView.share 'rdke_label',
				},
				f:static_text {
					title = 'The list comes from the selected photos. If you change the selection, reopen the Export dialog.',
				},
			},
		},
	}
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

function provider.processRenderedPhotos(functionContext, exportContext)
	local settings = exportContext.propertyTable
	local base = settings.rdke_baseFolder
	local excluded = KeywordUtils.parseList(settings.rdke_excluded)
	local session = exportContext.exportSession
	local total = session:countRenditions()

	exportContext:configureProgress {
		title = total > 1
			and ('Exporting ' .. total .. ' photos by keyword')
			or 'Exporting 1 photo by keyword',
	}

	-- Next number to try in each keyword folder during this export, so we
	-- don't re-check carlos-1, carlos-2, ... from the start for every photo.
	local nextNumber = {}

	for _, rendition in exportContext:renditions { stopIfCanceled = true } do
		-- Wait for Lightroom to render the photo to its temp file.
		local success, pathOrMessage = rendition:waitForRender()

		if success then
			local tempPath = pathOrMessage
			local fileName = LrPathUtils.leafName(tempPath)
			local ext = LrPathUtils.extension(tempPath)
			ext = (ext and ext ~= '') and ('.' .. ext) or ''

			-- Which keyword folders does this photo belong in?
			local names = {}
			for _, keyword in ipairs(rendition.photo:getRawMetadata('keywords') or {}) do
				names[#names + 1] = keyword:getName()
			end
			local folderNames = KeywordUtils.folderNamesFor(names, excluded)

			-- Each target is a folder plus the file name to use there.
			local targets = {}
			for _, folderName in ipairs(folderNames) do
				local folder = LrPathUtils.child(base, folderName)
				local key = folder:lower()
				local newName, n = KeywordUtils.nextNumberedName(
					folderName, ext, nextNumber[key],
					function(name) return LrFileUtils.exists(LrPathUtils.child(folder, name)) end
				)
				nextNumber[key] = n + 1
				targets[#targets + 1] = { folder = folder, name = newName }
			end
			if #targets == 0 then
				-- No ticked keyword: loose in the base folder, original file name.
				targets = { { folder = base, name = fileName } }
			end

			-- Copy the rendered file into each target folder.
			local failures = {}
			for _, target in ipairs(targets) do
				LrFileUtils.createAllDirectories(target.folder)
				local dest = KeywordUtils.uniquePath(
					LrPathUtils.child(target.folder, target.name),
					LrFileUtils.exists
				)
				local ok = LrFileUtils.copy(tempPath, dest)
				if not ok then
					failures[#failures + 1] = dest
				end
			end

			LrFileUtils.delete(tempPath)

			if #failures > 0 then
				rendition:uploadFailed('Could not copy to: ' .. table.concat(failures, ', '))
			end
		else
			rendition:uploadFailed(pathOrMessage)
		end
	end
end

return provider
