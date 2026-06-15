# AI Handoff - Anomaly Aces Theme Generator

This file contains the complete context, architectural choices, constraints, and current status of the Godot Theme Generator addon. It is designed to help another AI coding agent resume development on this repository on any machine.

---

## 1. Project Context & Purpose
The project is a Godot 4.x editor plugin/addon called **Anomaly Aces Theme Generator** located in `addons/anomalyAcesThemeGenerator/`. 
* **Input**: Figma metadata files, local image resources, local fonts, and parts builder configurations.
* **Output**: A native Godot `Theme` resource (`.tres` or `.theme` file) that can be directly applied to control nodes within the engine (instead of plain JSON outputs).

---

## 2. Recent Implementation & Completed Work

### A. Configuration Staging Relocation
* Moved the plugin's internal configuration state file from the addon root path `res://addons/anomalyAcesThemeGenerator/config.json` to a dedicated subfolder: `res://addons/anomalyAcesThemeGenerator/working/config.json`.
* Implemented automatic configuration migration: if an old config is found on startup, it is copied to the new `working/` folder and the old one is deleted.
* **Constraint**: The `working/` folder is **not** added to `.gitignore` so users can share their settings/stage data across multiple PCs.

### B. Default Export Settings & Auto-Directory Creation
* Created appropriately named subfolders inside the `working/` directory for default export settings:
  * **Images**: `res://addons/anomalyAcesThemeGenerator/working/Images`
  * **Fonts**: `res://addons/anomalyAcesThemeGenerator/working/Fonts`
  * **Metadata**: `res://addons/anomalyAcesThemeGenerator/working/Metadata/metadata.json`
  * **Themes**: `res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres`
* On startup, the `load_config()` script automatically checks if these settings are empty or missing. If so, it falls back to these defaults and recursively creates the directories on disk via `DirAccess.make_dir_recursive_absolute()` to prevent reference errors.

### C. Live Property Auto-Saving
* Removed the need for manual save buttons. Edits to colors, values, resource paths, or overrides in the UI automatically trigger signals (`color_changed`, `value_changed`, `resource_changed`, `text_changed`) which instantly serialize updates to `working/config.json`.

### D. State-Specific Live Preview Nodes
* Created a helper function `_get_configured_states(ctrl_type)` that scans the configured override properties for any given control type.
* In the live preview panel (`_on_apply_preview_pressed()`), we instantiate separate preview controls side-by-side or stacked for each state configured by the user:
  * **Normal**: Default state button.
  * **Disabled**: Enforces `disabled = true` if disabled theme properties (e.g. `disabled` StyleBox or `font_disabled_color`) are configured.
  * **Pressed**: Enforces `button_pressed = true` (and activates `toggle_mode = true` so the button stays pressed) if pressed theme properties are configured.
  * **Read-Only**: Enforces `editable = false` / `read_only = true` on text inputs.
* This allows users to inspect exactly how hover/normal, pressed, and disabled states will look concurrently.

### E. Visual Warning Dialogs (`AcceptDialog`)
* Implemented an on-the-fly warning dialog popup (`_show_warning_dialog(message)`) to catch issues interactively in the Godot Editor.
* Dialog triggers:
  1. If a user clicks `Add Part` without choosing a base control type.
  2. If a user tries to assign/use an in-memory resource that has not been saved to a file on disk first (which has an empty `resource_path`). This is checked in both the `Add Part` button click and the real-time resource-changed signal handler.

---

## 3. Key Godot 4.6 Constraints & Gotchas

* **@export_file Syntax**: Godot 4.6 does not support multiple extensions passed as a comma-separated single string. Multiple file extensions must be passed as separate arguments:
  ```gdscript
  @export_file("*.tres", "*.theme") var output_file: String
  ```
* **Popup Node Dialog Type-Safety**: The editor node picker callback `EditorInterface.popup_create_dialog()` requires type-safe parameters in Godot 4.6. The `blocklist` argument must be strictly typed as `Array[StringName]` rather than `PackedStringArray`, otherwise it will throw a type mismatch warning/error:
  ```gdscript
  var blocklist: Array[StringName] = []
  ```

---

## 4. File Map & Locations
* **Main Generator Logic**: [AceThemeGenerator.gd](file:///C:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.gd)
* **Generator Scene UI**: [AceThemeGenerator.tscn](file:///C:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.tscn)
* **Internal State config**: `addons/anomalyAcesThemeGenerator/working/config.json`
* **Plugin Configuration**: `addons/anomalyAcesThemeGenerator/plugin.cfg`

---

## 5. Next Steps for Next Session
* Check with the user if they want to integrate automated parsing of Figma layout constraints or font properties from the JSON metadata file (`Metadata/metadata.json`).
* Extend preview layouts with mock themes so that style changes can be tested inside complex layouts (e.g. nested lists, checkboxes, and sliders).
