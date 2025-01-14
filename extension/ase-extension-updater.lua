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

local preferences = {} -- create a global table to store extension preferences

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

--- Determine which installed extensions are compatible with the updater.
---
--- This function will go through the list of installed extensions and check their package.json
--- files for repository information. If the repository information is found, the extension's
--- repository owner, name, and latest release verion added to the retuned table.
---
--- @return table | nil -- a table of info for compatible extensions, or nil if none are found
local function findCompatibleExtensions()
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
	local tempFilePath = app.fs.joinPath(app.fs.tempPath, update.name .. ".aseprite-extension")
	-- download the extension to a temporary file and open it in Aseprite
	if app.fs.isFile(tempFilePath) then
		-- remove the file if it already exists
		os.execute("rm " .. tempFilePath)
	end
	os.execute('curl -Ls "' .. update.downloadUrl .. '" -o "' .. tempFilePath .. '"')
	app.command.Options{ installExtension = tempFilePath }
end

local function compareVersions(currentVersion, releaseVersion)
	-- remove leading characters from the releaseVersion string
	releaseVersion = releaseVersion:match("%d+[%d%.]*")
	-- convert each version string to a Version object
	local current = Version(currentVersion)
	local release = Version(releaseVersion)
	-- compare the current and release versions
	if release.prereleaseLabel ~= "" then  -- TODO: allow for prerelease/unstable updates
		return false  -- disregard the releaseVersion if it's a prerelease
	elseif current >= release then
		return false  -- current version is up to date (or ahead) of the release version
	else
		return true  -- an update is available
	end
end

local function main(isStartup)
	-- check if the updater was called at startup (defaults to false)
	isStartup = isStartup or false
	-- check installed extensions for repository info / compatibility with updater
	local compatibleExtensions = findCompatibleExtensions()
	if compatibleExtensions == nil then
		return
	end

	local assetErr = false
	local availableUpdates = {}  -- table to store available update info

	-- iterate through the compatible extensions and check for updates
	for displayName, info in pairs(compatibleExtensions) do
		-- unpack the extension info
		local endpoint, extensionVersion, name = info[1], info[2], info[3]
		local releaseData = assert(
			getLatestReleaseData(endpoint),
			'Could not fetch release data for "' .. displayName .. '" from "' .. endpoint .. '"'
		)
		-- get the latest release version from the fetched data
		local tagVersion = releaseData.tag_name

		if releaseData.assets then
			for _, asset in ipairs(releaseData.assets) do
				-- find the aseprite-extension bundle in the release assets
				if asset.name:match("%.aseprite%-extension$") then
					local downloadUrl = asset.browser_download_url
					-- check the installed version against the release version
					local updateAvailable = compareVersions(extensionVersion, tagVersion)
					if updateAvailable then
						table.insert(
							availableUpdates,
							{
								extensionVersion = extensionVersion,
								name = name,
								displayName = displayName,
								tagVersion = tagVersion,
								downloadUrl = downloadUrl
							}
						)
					end
					break
				end
			end
		else
			assetErr = true
			app.alert{
				title="Extension Updater Error",
				text='No aseprite-extension bundle found for "' .. displayName .. '". Contact the extension\'s owner.'
			}
		end
	end

	local dlg = Dialog()
	if #availableUpdates > 0 then
		dlg:modify{ title="Extension Updates Available" }
		for _, update in ipairs(availableUpdates) do
			-- strip the tagVersion to just its numerical and '.' characters
			local sanitizedTagVersion = update.tagVersion:match("%d+[%d%.]*")
			dlg:label{
				text='"' .. update.displayName .. '" ' .. update.extensionVersion ..  ' >> ' .. sanitizedTagVersion,
				hexpand=false
			}
			:newrow()
			:button{
				text="Download",
				hexpand=true,
				onclick=function()
					-- open the default browser to download the file
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
				onclick=function()
					downloadAndInstall(update)
					dlg:close()
				end,
			}
			-- add separator between updates
			:separator()
		end
	elseif not isStartup and not assetErr then
		-- only show this alert if the user manually checks for updates
		dlg:modify{ title="No Extension Updates Available" }
		:label{ text="All qualified extensions are up to date!" }
	end

	if not assetErr then
		dlg:newrow()
		:check{
			id="checkAtStartup",
			text="Check for updates when Aseprite starts",
			selected=preferences.checkAtStartup or false,
			onclick=function()
				preferences.checkAtStartup = not preferences.checkAtStartup
			end
		}
		:separator()
		:button{
			id="refresh",


			text="Refresh",
			onclick=function()
				dlg:close()
				app.command.aseExtensionUpdater()
			end
		}
		:button{id="cancel", text="Cancel", focus=true }
		:show{ autoscrollbars=true }
	end
	if dlg.data["download_install"] then
		-- run the updater again to check for remaining updates
		app.command.aseExtensionUpdater()
	end
end

-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin)
	plugin:newCommand {
		id = "aseExtensionUpdater",
		title = "Check for Extension Updates...",
		group = "file_scripts",
		onclick = main
	}
	preferences = plugin.preferences -- load preferences
	if preferences.checkAtStartup == nil then
		preferences.checkAtStartup = false
	elseif preferences.checkAtStartup then
		main(true)
	end
end

---@diagnostic disable-next-line: lowercase-global
function exit(plugin)
	plugin.preferences = preferences -- save preferences
	return nil
end
