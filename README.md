# Aseprite Extension Updater

![icon](./screenshots/Extension%20Updater%20Icon.png)

#### An Aseprite extension
*current release: [v1.0.0](https://sudo-whoami.itch.io/extension-name-here)*

## Latest Changes
Initial release!

##
This Aseprite extension allows you to easily check for updates to participating[^1] Aseprite extensions for updates and download them.

[^1]: For information on how to add compatibility with the updater to your extension, please refer to [Adding Updater Compatibility to Your Extension](#adding-updater-compatibility-to-your-extension).

## Requirements

This extension has been tested on both Windows and Mac OS (specifically, Windows 11 and Mac OS Sonoma 14.3.1)

It should also work for Linux, but that hasn't been tested.

It is intended to run on Aseprite version 1.3 or later and requires API version 1.3-rc5 (as long as you have the latest version of Aseprite, you should be fine!)

## Permissions
When you run this plugin for the first time, you'll be aked to grant some permissions.

When prompted, select the "Give full trust to this script" checkbox and then click "Give Script Full Access" (you'll only need to do this once)

![security dialog](./screenshots/security%20dialog.png)

## Features & Usage
Once installed, you can find the updater in Aseprite's `File` menu.

![file menu](./screenshots/file%20menu.png)

Simply click on **Check for Extension Updates** to check for updates and download the latest versions of compatible installed extensions.

## For Extension Developers

### Adding Updater Compatibility to Your Extension
To add updater compatibility to your extension, you'll need to make a few changes to your `package.json` file and use **GitHub releases** for versioning.

>[!IMPORTANT]
> The updater understands and uses [Semantic Versioning](https://semver.org/) for version comparison. Prefixes like `version` or `v`, (e.g. `v1.2.3`), and affixes like `-alpha` (e.g. `v4.2.0-alpha`) are ignored. The updater only looks for the latest stable release (for now)

### Changes to `package.json`

Add the following to the root of your `package.json`:

```json
"asepriteExtensionUpdater": {
    "updateUrl": "https://api.github.com/repos/<your-github-username>/<your-extension-repo>/releases/latest"
}
```

`asepriteExtensionUpdater.updateUrl` is the URL that the updater extension checks for the latest release. This should point to the latest release API endpoint of your GitHub repository. Be sure to include `your-github-username` and `your-extension-repo` in the URL!

>[!TIP]
> You can add this JSON snippet anywhere between the opening and closing brackets `{}` in your extension's `package.json` file


### Using GitHub Releases

1. **Create a new release**: Go to your GitHub repository, click on "Releases" on the right sidebar, and then click "Draft a new release".
2. **Tag the release**: Set the tag version (e.g., `v1.0.0`) and ensure it matches the `version` field in your `package.json`.
3. **Release title and description**: Provide a title and description for your release. This can include details about the changes and new features.
4. **Attach files**: Upload the extension file (e.g., `<your extension>.aseprite-extension`) to the release.
5. **Publish the release**: Click "Publish release" to make it available.

By following these steps, your extension will be compatible with the Aseprite Extension Updater, allowing users to easily check for and download updates!

Once you've made the changes to your extension's `package.json`, you just need to create a GitHub release whenever you update your Aseprite extension.

>[!NOTE]
> For more detailed information on how to create and manage releases on GitHub, please refer to the [GitHub Releases documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

## Installation
You can download this extension from [itch.io](https://sudo-whoami.itch.io/extension-name-here) as a "pay what you want" tool

If you find this extension useful, please consider donating via itch.io to support further development! &hearts;

## TODO
- [ ] Support for other release sources, like GitLab or itch.io
