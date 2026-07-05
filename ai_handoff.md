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

### G. UI Scaling and Layout Improvements
* **Editor Theme Inheritance**: Assigned the main theme generator instance's `theme` property to the editor's base control theme, letting the plugin inherit native styling, fonts, and DPI scaling automatically.
* **Dynamic Override Font Scaling**: Implemented dynamic scaling of hardcoded font size overrides and tree heights in `AceThemeGenerator.gd` using `EditorInterface.get_editor_scale()`.
* **Configured Overrides Expansion**: Enabled vertical size flags (`size_flags_vertical = 3`) on `PartsBuilderPanel`, its nested `VBox`/`PartsBuilderContent` containers, and `PartsTree` itself to stretch it to fill the remaining height of the left panel.

### H. Override Form Preservation & Safe Duplicate Keys
* Fixed a bug where creating a **New Override** overwrote active properties by automatically generating unique copy keys (e.g. `normal_copy`).
* Preserved user form inputs (Property Type, Property Name, Override Name/ID) and the **Build from Metadata** checkbox when switching categories or adding overrides.

### I. Dynamic Preview Width & Uniform Columns
* Added an **Item Width** SpinBox. When `width > 0`, constraints are applied to all elements uniformly in the grid columns, preventing Godot from stretching columns unevenly.
* Configured the grid's horizontal flag to `SIZE_SHRINK_CENTER` to keep the layout snug and clean.

### J. In-Place Double-Click Text Editing
* Left double-clicks on preview controls spawn a borderless overlay LineEdit that inherits the control's font family, color, and size.
* The customized string is automatically saved in `config.json` mapping `ctrl_type + "_" + state` to values, and restored upon preview redrawing.
* Supported typing empty strings `""` to preview textless panels, and special keywords like `default` or `reset` to clear configs.

### K. 1:1 Figma Design Size Alignment
* Loaded figma metadata dimension parameters. If Item Width is `0` (Auto), controls automatically size themselves to their 1:1 designed dimensions (e.g., 200x60, 60x60).
* Enabled text clipping (`clip_text`) on constrained elements to prevent long text strings (e.g. `"BackButton (Button) (Disabled)"`) from stretching small icon buttons out of shape.
* Traces resource stylebox paths back to their source SVG filenames to resolve metadata lookups even if custom override IDs or suffix-copies are present.

### L. Automatic State Sizing Fallback
* Standardized button dimensions across all states: if a state fails to trace a design size (such as the pressed flat StyleBox), it automatically adopts a fallback from another state of the same control type (e.g., matching the normal state's 200x60 scale).

### M. Custom Shape Safety & SVG Filter Stripping
* Prevented custom shapes (arrows, knobs, toggles, sliders) with drop shadows from being compiled as flat rectangles, forcing them to remain as `StyleBoxTexture` resources.
* Automatically strips unsupported SVG `filter="url(#...)"` properties on import, bypassing Godot's ThorVG renderer bugs and restoring full rendering of hidden circle and arrow vector shapes.
* Calculates Figma shadow border padding and applies it to the `StyleBoxTexture`'s `expand_margin` properties, drawing glows outside the button bounds while keeping the core button exactly at its designed 1:1 size.

### N. Preview Node Visual Freeze Overrides
* Applied local theme overrides to preview controls, mapping the resolved state asset (and font colors) to all variant slots (`normal`, `hover`, `pressed`, `disabled`, `focus`, and `hover_pressed`).
* This freezes their visual appearances, keeping the elements completely interactive for double-click text editing while preventing Godot from dynamically shifting styleboxes or font colors upon mouse hover or focus.
* **Normal State Exemption**: Excluded elements representing the `"normal"` state from this freeze, allowing them to remain fully interactive and show transitions to hover and pressed states when hovered/clicked in the preview.
* **Focus Preview State**: Added support to recognized and display `"focus"` overrides as their own dedicated preview nodes in the grid columns.
* **childFills Fallback Support**: Programmed the stylebox compiler to read child vector node fills (`childFills`) as a fallback if frame-level fills (`fills`) are empty, preventing background color loss for components styled with nested shapes (like text input fields).
* **SVG Corner Radius Parsing**: Configured the `StyleBoxFlat` builder to search the raw SVG file text for a `<rect>` node's `rx` attribute, matching the flat stylebox corner radius exactly to the original Figma design radius (e.g. `12px` for input boxes) instead of defaulting to a pill shape.
* **Text Layer Fills Exclusion**: Filtered out vector nodes named `"Text"` (case-insensitive) inside the `childFills` loop to prevent text label colors from overriding the component's true background fill.
* **Stale Background Rect Cleanups**: Implemented dynamic background-rect stripping in the texture compiler to clean previous `figma_bg_inject` rect tags from target SVG files. If the design has no solid fill metadata, the old background rect is completely stripped to restore the component's transparency.
* **Immediate SVG Re-Importing**: Triggered `EditorInterface.get_resource_filesystem().reimport_files()` after any compilation modification (injecting background, cleaning filters, or stripping rects) so Godot immediately flushes texture cache and reloads files in-editor.
* **Grouped Section Layouts**: Structured `%PreviewGrid`'s columns count to `1` (VBox mode) and grouped each control variation/type into individual sub-grid sections styled with custom colored headers and separation padding. This aligns cells cleanly and prevents wider components from stretching adjacent controls.

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
* **Main Generator Logic**: [AceThemeGenerator.gd](file:///c:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.gd)
* **Generator Scene UI**: [AceThemeGenerator.tscn](file:///c:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.tscn)
* **Internal State config**: [config.json](file:///c:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/working/config.json)
* **Plugin Configuration**: [plugin.cfg](file:///c:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/plugin.cfg)

---

## 5. Next Steps for Next Session
* Verify and compile all other custom SVG shapes (like slider knobs, toggles, and right arrows) using the new filter stripping and expand margin system.
* Check with the user if they want to integrate automated parsing of Figma layout constraints or font properties from the JSON metadata file (`Metadata/metadata.json`).
* Extend preview layouts with mock themes so that style changes can be tested inside complex layouts (e.g. nested lists, checkboxes, and sliders).
