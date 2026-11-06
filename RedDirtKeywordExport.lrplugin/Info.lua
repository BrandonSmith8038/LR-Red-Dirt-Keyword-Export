--[[
  Info.lua
  Lightroom reads this file first to learn what the plugin is called
  and which file provides the export service.
]]

return {
	LrSdkVersion = 10.0,
	LrSdkMinimumVersion = 6.0,

	-- Unique ID for the plugin (reverse-domain style).
	LrToolkitIdentifier = 'photos.reddirt.keywordexport',
	LrPluginName = 'Red Dirt Keyword Export',

	-- Adds "Red Dirt Keyword Export" to the Export dialog's "Export To" dropdown.
	LrExportServiceProvider = {
		title = 'Red Dirt Keyword Export',
		file = 'ExportServiceProvider.lua',
	},

	VERSION = { major = 1, minor = 0, revision = 0, build = 1 },
}
