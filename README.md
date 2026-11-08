# Xbox Cloud Gaming Installer & Updater for Batocera

*Created by DeLorean23* · [Deutsche Anleitung: LIESMICH.md](LIESMICH.md)

This installer adds **Xbox Cloud Gaming** to Batocera as its own system. Every cloud game from the Game Pass catalog becomes a normal entry in the game list, with name, cover and description. Pick a game and it starts **straight into the stream** in fullscreen, no menus, everything with the controller.

It runs on the open-source Xbox streaming client **Greenlight** (https://github.com/unknownskl/greenlight). The installer always downloads the newest Greenlight release from GitHub.

## Download

Get **Xbox Cloud Gaming Installer & Updater.zip** from the **[Releases](https://github.com/DeLorean23/Xbox-Cloud-Gaming-Installer-Updater-Batocera/releases/latest)** page.

## Requirements

- Batocera (x86_64 PC), run as root (the default when started from Ports)
- Internet connection
- A Microsoft account with **Xbox Game Pass Ultimate** (cloud gaming is part of Ultimate)
- A keyboard **once** for signing in, after that the controller is enough

## Installation

1. Extract the contents of the ZIP archive to `/userdata`. This places the installer and its cover image in `/userdata/roms/ports/`.
2. In Batocera, refresh the game list and launch **Xbox Cloud Gaming Installer & Updater** from **Ports**.
3. Read the warning and confirm with **y** or **A** on your controller.
4. The installer downloads the newest Greenlight build, sets up the system and builds the game list. Progress bars show what it is doing:
   - Step 1/3: list of all cloud games
   - Step 2/3: names and details (German store)
   - Step 3/3: covers
5. It asks "Sign in now?". Press **y / A**, Xbox Cloud Gaming opens in a window. Sign in with your Microsoft account (keyboard). When the start page appears, close the window with **Hotkey + Start** or **Alt + F4**.
6. At the end it asks "Reboot now?". Press **y / A** to restart Batocera. After the reboot the new system **Xbox Cloud Gaming** is in the system list.

You can skip the sign in and do it later: **F1 → Applications → Xbox Cloud Gaming**.

## How it works

- The game list comes from the **public Xbox Game Pass catalog** (`catalog.gamepass.com`), market Germany, German names. No sign in is needed for the list.
- Only games you can play with Game Pass are added. Titles that are only playable when you own them are left out.
- For every game the installer creates a small file `/userdata/roms/xboxcloud/<Name>.xcloud`. It contains only the xCloud title id of the game.
- Covers are saved in `/userdata/roms/xboxcloud/images/`, names, descriptions, publisher and genre in `gamelist.xml`.
- When you start a game, Batocera runs `/userdata/system/xboxcloud/launch.sh`. It reads the title id and starts Greenlight in fullscreen with `--connect=xcloud_<id>`, so the stream starts right away.
- **Hotkey + Start** (Select + Start, or Guide + Start) closes the stream and brings you back to the game list.

## What gets installed

- Greenlight in `/userdata/system/xboxcloud/XboxCloudGaming.AppImage` (helpers and logo in the same folder)
- System **Xbox Cloud Gaming** (`xboxcloud`): `/userdata/system/configs/emulationstation/es_systems_xboxcloud.cfg`
- Games folder: `/userdata/roms/xboxcloud/`
- **F1 → Applications → Xbox Cloud Gaming**: opens the program without a game, for signing in and settings
- System logo for every theme that can take it (themes in read-only folders are skipped and listed at the end)
- Cover image for the Ports entry

## Update

Simply launch the installer again from **Ports**:

- If a newer Greenlight version is available, it is installed after a y/n question. The previous version is kept in `/userdata/system/xboxcloud/backup`.
- The game list is **rebuilt every time**, so new Game Pass cloud games show up and removed ones disappear. Covers that are already there are not downloaded again.
- If the program is already the newest version, the installer shows "up to date".
- No reboot is required after an update.

## Notes

- This is an unofficial system. A future Batocera update may affect it.
- Greenlight is an unofficial client and not made by Microsoft. Cloud gaming may change at any time on Microsoft's side.
- The game list uses German names and the German store. Names of a few games may stay in English.
- This project does not provide any games or accounts. You need your own Game Pass Ultimate subscription.
- Xbox and Game Pass are trademarks of Microsoft. This project is not affiliated with Microsoft.
- Log files for troubleshooting: `/userdata/system/logs/xboxcloud-installer.log` and `/userdata/system/logs/xboxcloud.log`

## Building

`./build.sh` creates the ZIP in `dist/` from `src/installer.template.sh`, the helper scripts in `src/` and the images in `assets/`.

## License

The installer is released under the [MIT License](LICENSE). Greenlight is a separate project with its own license; this installer only downloads it from the official releases.
