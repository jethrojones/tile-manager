# Tile Manager

Name Hyprland workspaces and keep assigned apps launching there from the Omarchy Quattro bar.

The built-in `omarchy.workspaces` widget only shows workspace numbers. Tile Manager adds saved names, app assignments, and follow-on-launch so communication apps can live on workspace 1, editors on 2, and launching Slack takes you there.

## Install

```sh
omarchy plugin add https://github.com/jethrojones/tile-manager.git --enable
```

For a local checkout:

```sh
omarchy plugin add /home/jethro/projects/tile-manager --enable
```

While Tile Manager is enabled it hides Omarchy's numbered `1–0` widget. Turn that widget back on from the cog panel, or after removal:

```sh
omarchy plugin enable omarchy.workspaces --section left --before io.github.jethrojones.tile-manager
```

## Usage

- Click a workspace name in the bar to switch to it.
- Middle-click a name to launch its assigned apps.
- Right-click a name, or click the cog, to manage names and app assignments.
- **Assign open windows** parks each unique app on the workspace it is already using. Apps that roam, like terminals, are skipped.
- **Keep apps there** moves assigned apps back if they leave that workspace.
- Press Escape to close the panel.

Assigned apps open on their workspace through generated Hyprland window rules. With **Follow launches** on (the default), Hyprland also switches you to that workspace. `omarchy-launch-or-focus` is used when an assigned app is already running.

## Configure

Assignments are stored in `~/.config/omarchy/tile-manager.json`. Window rules are generated to `~/.local/state/omarchy/toggles/hypr/tile-manager.lua`, the same auto-loaded Hyprland toggle directory Omarchy already watches. The plugin does not edit `~/.config/hypr/hyprland.lua`.

## Remove

```sh
omarchy plugin remove io.github.jethrojones.tile-manager
```

Optional cleanup:

```sh
rm -f ~/.config/omarchy/tile-manager.json ~/.local/state/omarchy/toggles/hypr/tile-manager.lua
```

Restore the numbered workspace widget if it does not come back on its own:

```sh
omarchy plugin enable omarchy.workspaces --section left
```

## Develop

```sh
omarchy plugin validate .
node tests/model.test.js
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml Service.qml
```

## License

MIT
