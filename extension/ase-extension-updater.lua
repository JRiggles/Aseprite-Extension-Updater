--[[
MIT LICENSE
Copyright © 2025 John Riggles [sudo_whoami]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- stop complaining about unknown Aseprite API methods
---@diagnostic disable: undefined-global
-- ignore dialogs which are defined with local names for readablity, but may be unused
---@diagnostic disable: unused-local

-- local preferences = {} -- create a global table to store extension preferences

--- Fetch the latest release data from a specified GitHub repository.
--- @param endpoint string -- the URL to fetch the latest release data from
--- @return table | nil -- JSON data for the latest release or nil if an error occurred
local function getLatestReleaseData(endpoint)
	local command = 'curl -Ls "' .. endpoint .. '"'

	if app.os.windows then -- fetch data via curl using io.popen
		local handle = assert(io.popen(command), "curl error - could not connect to " .. url)
		local result = handle:read("*a")
		assert(handle:close(), "curl error - could not close connection")
		return result
	else -- assume a non-Windows OS, use os.execute instead of io.popen
		local tempFilePath = app.fs.joinPath(app.fs.tempPath, "releasedata.tmp")
		-- execute curl, redirect output to a temporary file
		os.execute(command .. " > " .. tempFilePath)
		local file = io.open(tempFilePath, "r")
		if file then
			local result = file:read("*a")
			file:close()
			-- os.remove(tempFilePath) -- NOTE: os.remove is not currently available in Aseprite
			os.execute("rm " .. tempFilePath) -- remove temporary file
			return json.decode(result)
		else
			app.alert {title = "Error Loading Release Data", text = "Could not open temp file"}
			return
		end
	end
end

--- Check for updates to the installed extensions.
--- This function will go through the list of installed extensions and check their package.json
--- files for repository information. If the repository information is found, the extension's
--- repository owner, name, and latest release verion added to the retuned table.
---
--- @return table | nil -- a table of info for compatible extensions, or nil if none are found
local function checkExtensions()
	local extensionsDir = app.fs.joinPath(app.fs.userConfigPath, "extensions")
	local allExtensions = app.fs.listFiles(extensionsDir)
	local compatibleExtensions = {}
	for _, extensionSubDir in ipairs(allExtensions) do
		-- check each extension's package.json file for release info used by the updater
		local packageJsonPath = app.fs.joinPath(extensionsDir, extensionSubDir, "package.json")
		local packageFile = io.open(packageJsonPath, "r")
		if packageFile then
			local packageContent = packageFile:read("*a")
			packageFile:close()
			local packageData = json.decode(packageContent)
			-- if the package.json file exists and has been modified for compatiblity with this
			-- extension, add it to the list of extensions to check for updates
			if packageData and packageData.asepriteExtensionUpdater then
				local extensionVersion = packageData.version
				local displayName = packageData.displayName
				local name = packageData.name
				local endpoint = packageData.asepriteExtensionUpdater.updateUrl
				compatibleExtensions[displayName] = {endpoint, extensionVersion, name}
				return compatibleExtensions
			end
		end
	end
end

local function downloadAndInstall(update)
	local tempFilePath = app.fs.joinPath(app.fs.userDocsPath, update.name .. ".aseprite-extension")
	-- download the extension to a temporary file and open it in Aseprite
	if app.fs.isFile(tempFilePath) then
		-- remove the file if it already exists
		os.execute("rm " .. tempFilePath)
	end
	os.execute('curl -Ls "' .. update.downloadUrl .. '" -o "' .. tempFilePath .. '"')
	if app.os.windows then
		os.execute('start "" "' .. tempFilePath .. '"')
	else
		os.execute('open "' .. tempFilePath .. '"')
	end
end

local function compareVersions(currentVersion, releaseVersion)
	local function splitVersion(version)
		local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)$")
		return tonumber(major), tonumber(minor), tonumber(patch)
	end

	local major1, minor1, patch1 = splitVersion(currentVersion)
	local major2, minor2, patch2 = splitVersion(releaseVersion)

	if major2 > major1 then
		return true
	elseif minor2 > minor1 then
		return true
	elseif patch2 > patch1 then
		return true
	end
	return false -- current version is up to date (or ahead) of the release version
end

local function main()
	-- check installed extensions for repository info / compatibility with updater
	local compatibleExtensions = checkExtensions()
	if compatibleExtensions == nil then
		return
	end

	local availableUpdates = {}
	for displayName, info in pairs(compatibleExtensions) do
		local endpoint, extensionVersion, name = info[1], info[2], info[3]
		local releaseData = getLatestReleaseData(endpoint)
		if releaseData == nil then
			app.alert{
				title="Extension Updater Error",
				text='Could not fetch release data for "' .. displayName .. '" from "' .. endpoint .. '"'
			}
			return
		end
		-- get the latest release version from the fetched data
		local tagVersion = releaseData.tag_name

		if releaseData.assets then
			for _, asset in ipairs(releaseData.assets) do
				if asset.name:match("%.aseprite%-extension$") then
					local downloadUrl = asset.browser_download_url
					local updateAvailable = compareVersions(extensionVersion, tagVersion)
					if updateAvailable then
						table.insert(availableUpdates, {
							extensionVersion = extensionVersion,
							name = name,
							displayName = displayName,
							tagVersion = tagVersion,
							downloadUrl = downloadUrl
						})
					end
					break
				end
			end
		else
			app.alert{
				title="Extension Updater Error",
				text='No aseprite-extension bundle found for "' .. displayName .. '". Contact the extension\'s owner.'
			}
		end
	end

	if #availableUpdates > 0 then
		local dlg = Dialog{ title="Updates Available" }
		for _, update in ipairs(availableUpdates) do
			-- strip the tagVersion to just its numerical and '.' characters
			local sanitizedTagVersion = update.tagVersion:gsub("[^%d%.]", "")
			dlg:label{
				text='"' .. update.displayName .. '" ' .. update.extensionVersion ..  ' >> ' .. sanitizedTagVersion,
				hexpand=false
			}
			:newrow()
			:button{
				text="Download",
				hexpand=true,
				onclick=function()
					if app.os.windows then
						os.execute('start "" "' .. update.downloadUrl .. '"')
					else
						os.execute('open "' .. update.downloadUrl .. '"')
					end
				end,
			}
			:button{
				id="download_install",
				text="Download + Install",
				hexpand=true,
				focused=true,
				onclick=function()
					downloadAndInstall(update)
					dlg:close()
				end,
			}
			:separator()
		end
		dlg:newrow()
		-- :button{
		-- 	id="download_all",
		-- 	text="Download All",
		-- 	onclick=function()
		-- 		for _, update in ipairs(availableUpdates) do
		-- 			local tempFilePath = app.fs.joinPath(app.fs.userDocsPath, update.name .. ".aseprite-extension")
		-- 			if app.fs.isFile(tempFilePath) then
		-- 				os.execute("rm " .. tempFilePath)
		-- 			end
		-- 			os.execute('curl -Ls "' .. update.downloadUrl .. '" -o "' .. tempFilePath .. '"')
		-- 		end
		-- 		dlg:close()
		-- 	end
		-- }
		:button{id="cancel", text="Cancel", onclick=function() dlg:close() end}
		:show()
		-- TODO: run the updater again to check for remaining updates
		if dlg.data["download_install"] then
			-- run the updater again to check for remaining updates
			-- app.command.aseExtensionUpdater()
		end
	else
		app.alert{title="No Updates Available", text="All qualified extensions are up to date!"}
	end
end

-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin)
	-- preferences = plugin.preferences -- load preferences
	plugin:newCommand {
		id = "aseExtensionUpdater",
		title = "Check for Extension Updates",
		group = "file_scripts",
		onclick = main
	}
end

---@diagnostic disable-next-line: lowercase-global
function exit(plugin)
	-- plugin.preferences = preferences -- save preferences
	return nil
end
