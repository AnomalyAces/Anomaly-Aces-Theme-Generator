# AI Handoff - Anomaly Aces Theme Generator

This file contains the complete context, architectural choices, constraints, and current status of the Godot Theme Generator addon. It is designed to help another AI coding agent resume development on this repository on any machine.

---

## 1. Project Context & Purpose
The project is a Godot 4.x editor plugin/addon called **Anomaly Aces Theme Generator** located in `addons/anomalyAcesThemeGenerator/`. 
* **Input**: Figma metadata files (`metadata.json`), local image SVG resources, local fonts, and parts builder configurations.
* **Output**: A native Godot `Theme` resource (`.tres` or `.theme` file) that can be directly applied to control nodes within the engine, bundled with self-contained assets and exported `theme_preview.tscn` standalone preview scenes.

---

## 2. Recent Implementation & Completed Work

### A. Modular Refactoring of Monolithic Controller
* Refactored the monolithic 3,187-line `AceThemeGenerator.gd` into a clean **Orchestrator + RefCounted Composition Architecture**.
* Split business logic into **8 dedicated helper scripts** in `addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/`:
  - `DialogUtils.gd`: File/directory picker dialogs & warning popups.
  - `StyleboxBuilder.gd`: Figma metadata-driven `StyleBoxFlat` & `StyleBoxTexture` compilation.
  - `SvgUtils.gd`: SVG directory scanning, filter cleaning regex, and DPI texture reimporting.
  - `ThemeBuilder.gd`: Native Godot `Theme` object assembly in memory.
  - `ThemeConfig.gd`: `config.json` load, save, path migration, directory creation, and JSON import.
  - `ThemeExporter.gd`: Native `.tres` theme saving, package export, `res://` path rewriting, and standalone `theme_preview.tscn` export.
  - `ThemePartsManager.gd`: Theme parts CRUD, Tree view rendering, property option populating, and deduplication.
  - `ThemePreview.gd`: Live preview grid generation, state node freezing, component size resolution, and double-click inline text editing.
* Replaced monolithic controller with a slim (~280 line) orchestrator script `AceThemeGenerator.gd` that preloads and instantiates the 8 helper scripts during `_init(self)`.

### B. Project Documentation (`USER_GUIDE.md` & `DEVELOPER_GUIDE.md`)
* Created **`USER_GUIDE.md`** in project root: Step-by-step user guide covering installation, configuration, metadata stylebox building, theme overrides, custom type variations, live previews, in-place text editing, theme packaging, and troubleshooting.
* Created **`DEVELOPER_GUIDE.md`** in project root: Complete developer guide detailing the modular architecture, composition design patterns, file breakdown, key variables, and function signatures.

### C. Ground Truth SVG Aspect Ratio & Component Dimension Resolution
* **Figma Metadata Suffix Stripping**: Updated metadata lookups in `ThemePreview.gd` (`_lookup_metadata_dimensions`) with fuzzy suffix stripping (`_regular`, `_hover`, `_pressed`, `_disabled`, `_normal`) and word matching (e.g. `pressed_button` -> `Button_-_Pressed.svg`).
* **Texture Size Ground Truth**: Prioritized `StyleBoxTexture.texture.get_size()` minus `expand_margin` padding in `resolve_design_dimensions()` as primary ground truth for inner component body dimensions. This fixed aspect-ratio stretching on split toggle buttons (`ToggleGenderFemaleButton`, `ToggleGenderMaleButton`), maintaining their native 176×61 (2.885:1) SVG proportions.
* **Pixel-Perfect State Symmetry**: Compensated for `StyleBoxFlat` drop shadow margins and `StyleBoxTexture` expand margins. Buttons across all states (`Normal`, `Hover`, `Pressed`, `Disabled`) for `BackButton`, `ColorSelectButton`, `DecreaseButton`, `ForwardButton`, and `IncreaseButton` now share 100% pixel-identical inner component body sizes (e.g., `60×60` or `200×60`).

### D. Configuration Suffix Cleanup & Duplicate Pruning
* Grouped all theme parts keys by base name on load/save in `_cleanup_unique_properties()`.
* Automatically strips copy-suffixes (like `normal_copy` -> `normal`) from unique properties.
* Keeps the active copy during editing but automatically prunes stale/inactive duplicate override keys on configuration load/save.

### E. Metadata-Based StyleBox Builder (Opt-In Checkbox)
* Added a `"Build from Metadata"` checkbox dynamically positioned right under the `"Property Type"` dropdown in the Parts Builder.
* Visible only for `StyleBox` property types. When opted-in, displays a dropdown containing SVG elements from `metadata.json` and a `"Build..."` compilation button.
* Overwriting safety guards prevent accidental data loss if opt-in is unchecked.

### F. Self-Contained Theme Packaging & Preview Scene Export
* Compiling a theme automatically packages the theme file along with all referenced styleboxes, SVG textures, `.import` configuration files, and custom fonts into relative subfolders inside the output directory (`ResourceFiles/`, `Images/`, `Fonts/`). All internal `res://` paths are rewritten in-place.
* Automatically exports a self-contained `theme_preview.tscn` styled with your packaged theme, ready to be opened in Godot or loaded in the default Theme Editor preview pane.

---

## 3. Key Godot 4.x Constraints & Gotchas

* **@export_file Syntax**: Godot 4.x does not support multiple extensions passed as a comma-separated single string. Multiple file extensions must be passed as separate arguments:
  ```gdscript
  @export_file("*.tres", "*.theme") var output_file: String
  ```
* **Popup Node Dialog Type-Safety**: The editor node picker callback `EditorInterface.popup_create_dialog()` requires type-safe parameters. The `blocklist` argument must be strictly typed as `Array[StringName]`:
  ```gdscript
  var blocklist: Array[StringName] = []
  ```
* **StyleBox Expand Margin vs. Shadow Size Padding**:
  - `StyleBoxTexture` expand margins (`expand_margin_left/top/right/bottom`) expand the texture outward from the node rect.
  - `StyleBoxFlat` drop shadow sizes (`shadow_size` + `shadow_offset`) draw glow pixels outward from the node rect.
  - In theme preview sizing, expand margins must be subtracted from raw texture sizes (`tex_size - expand_margins`) to determine the true inner component body size.

---

## 4. File Map & Locations
* **Main Generator Orchestrator**: [AceThemeGenerator.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.gd)
* **Generator UI Scene**: [AceThemeGenerator.tscn](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.tscn)
* **Helper Scripts Directory**: [Scripts/](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts)
  - [DialogUtils.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/DialogUtils.gd)
  - [StyleboxBuilder.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/StyleboxBuilder.gd)
  - [SvgUtils.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/SvgUtils.gd)
  - [ThemeBuilder.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemeBuilder.gd)
  - [ThemeConfig.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemeConfig.gd)
  - [ThemeExporter.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemeExporter.gd)
  - [ThemePartsManager.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemePartsManager.gd)
  - [ThemePreview.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemePreview.gd)
* **User Guide Documentation**: [USER_GUIDE.md](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/USER_GUIDE.md)
* **Developer Guide Documentation**: [DEVELOPER_GUIDE.md](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/DEVELOPER_GUIDE.md)
* **Internal State config**: [config.json](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/working/config.json)
* **Plugin Manifest**: [plugin.cfg](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/plugin.cfg)

---

## 5. Next Steps for Next Session
* Extend preview layouts inside the generated `theme_preview.tscn` to include nested sub-scenes showing complete UI layouts (e.g. settings panels or character select menus).
* Parse layout margins and content padding parameters from Figma metadata to configure stylebox margins automatically.
