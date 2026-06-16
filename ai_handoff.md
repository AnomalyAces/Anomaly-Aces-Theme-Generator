# AI Handoff - Anomaly Aces Theme Generator

This file contains the complete context, architectural choices, constraints, and current status of the Godot Theme Generator addon. It is designed to help another AI coding agent resume development on this repository on any machine.

---

## 1. Project Context & Purpose
The project is a Godot 4.x editor plugin/addon called **Anomaly Aces Theme Generator** located in `addons/anomalyAcesThemeGenerator/`. 
* **Input**: Figma metadata files (`metadata.json`), local image SVG resources, local fonts, and parts builder configurations.
* **Output**: A native Godot `Theme` resource (`.tres` or `.theme` file) that can be directly applied to control nodes within the engine.

---

## 2. Recent Implementation & Completed Work

### A. Configuration Suffix Cleanup & Duplicate Pruning
* Grouped all theme parts keys by base name on load/save in `_cleanup_unique_properties()`.
* Automatically strips copy-suffixes (like `normal_copy` -> `normal`) from unique properties.
* Keeps the active copy during editing but automatically prunes stale/inactive duplicate override keys on configuration load/save, resolving duplicate configuration bloat.

### B. Metadata-Based StyleBox Builder (Opt-In Checkbox)
* Added a `"Build from Metadata"` checkbox dynamically positioned right under the `"Property Type"` dropdown in the Parts Builder.
* Visible only for `StyleBox` property types. When opted-in, displays a dropdown containing SVG elements from `metadata.json` and a `"Build..."` compilation button.
* **Overwriting Safety Guard**: Aborts and prevents overwriting of values if the build checkbox is not checked.
* **StyleBox Auto-Generation**:
  * **With Drop Shadow**: If the SVG entry in `metadata.json` has a `DROP_SHADOW` effect, builds a programmatically styled `StyleBoxFlat` with capsule corners (half of SVG height), border width of 2, a solid background color parsed from Figma fills (with fallback to semi-transparent dark charcoal), a neon border/shadow color, and a dynamically scaled shadow opacity based on Figma blur radius:
    $$\text{Alpha Scale} = \text{clamp}\left(\frac{12.0}{\text{Figma Radius}}, 0.15, 1.0\right)$$
    This formula mathematically converts Figma's diffuse web blurs to Godot's shadow falloff gradient.
  * **Standard Vector**: If no drop shadow is present, builds a `StyleBoxTexture` utilizing the SVG directly.
  * Enforces standard button margins (`L=6, R=6, T=4, B=4`).

### C. In-Memory Cache Invalidation
* Programmed the stylebox builder to reload generated resource files utilizing Godot's `ResourceLoader.CACHE_MODE_REPLACE` mode. This invalidates the cached resource in memory, allowing changes (e.g. converting a stylebox from texture to flat, or changing shadow size/radius) to propagate instantly inside the Godot editor viewport without reloading the project.

### D. Parent Panel Container Live Preview
* Reverted wrapping individual preview controls in cards. The preview controls are added directly to the preview grid container.
* Restructured `PreviewArea` (which is a `PanelContainer` styled by the theme currently being compiled) to hold a `VBoxContainer` with a subtle `"Panel Container"` Label at the top and the ScrollContainer below (with 15px separation).
* Wrapped the inner `PreviewGrid` inside a `MarginContainer` with **60px margins on all sides** so neon glows and shadow offsets do not get clipped by the ScrollContainer boundaries.

### E. Headless & Non-Editor Test Fallbacks
* Replaced direct editor-only `EditorResourcePicker` instantiations with a conditional fallback to `Button` when running headlessly or outside the editor, preventing crashes during automated CI/CD testing.

### F. Workspace Test Safety
* Implemented `config.json` backup and restore logic inside `test_stylebox_builder.gd` to prevent automated tests from permanently polluting or corrupting local workspace settings.

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
* **Main Generator Logic**: [AceThemeGenerator.gd](file:///c:/Anomaly Aces/Plugins/4.x/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.gd)
* **Generator Scene UI**: [AceThemeGenerator.tscn](file:///c:/Anomaly Aces/Plugins/4.x/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.tscn)
* **Internal State config**: [config.json](file:///c:/Anomaly Aces/Plugins/4.x/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/working/config.json)
* **Plugin Configuration**: [plugin.cfg](file:///c:/Anomaly Aces/Plugins/4.x/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/plugin.cfg)

---

## 5. Next Steps for Next Session
* Check with the user if they want to integrate automated parsing of Figma layout constraints or font properties from the JSON metadata file (`Metadata/metadata.json`).
* Extend preview layouts with mock themes so that style changes can be tested inside complex layouts (e.g. nested lists, checkboxes, and sliders).
