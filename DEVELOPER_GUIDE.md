# AceThemeGenerator Developer Guide

## Architecture Overview

The `AceThemeGenerator` Godot plugin component was refactored from a single 3,187-line monolithic script into a clean, modular architecture following Godot paradigms:

- **Composition via `RefCounted` Helper Classes**: Pure business logic, I/O operations, UI building, and theme compilation are split into dedicated helper scripts that inherit from `RefCounted`.
- **Orchestrator Pattern**: `AceThemeGenerator.gd` remains attached to the `AceThemeGenerator.tscn` Control node. It manages `@onready` node references and delegates user interactions and business logic to lightweight helper instances created with `preload()`.
- **Dependency Injection**: Each helper script accepts a reference to `_owner` (the main `AceThemeGenerator` node) during `_init()`, allowing shared access to node references and state variables (`theme_parts`, `theme_variations`, configuration paths) without tight coupling or global singletons.

---

## File Structure

```
addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/
├── AceThemeGenerator.gd          # Main Scene Script / Orchestrator
├── AceThemeGenerator.tscn        # UI Layout Scene
└── Scripts/
    ├── DialogUtils.gd            # File/Directory picker dialogs & warning popups
    ├── StyleboxBuilder.gd        # Figma metadata-driven StyleBox Flat & Texture generation
    ├── SvgUtils.gd               # SVG directory scanning, filter cleaning, & DPI reimport
    ├── ThemeBuilder.gd           # Native Godot Theme object assembly
    ├── ThemeConfig.gd            # Config JSON load, save, migration, and import
    ├── ThemeExporter.gd          # .tres output, package bundling, path rewriting, preview scene export
    ├── ThemePartsManager.gd      # Parts tree CRUD, property options population, & input handlers
    └── ThemePreview.gd           # Live preview grid rendering, state nodes, & double-click inline editor
```

---

## File & Function Breakdown

### 1. `AceThemeGenerator.gd` (Orchestrator)
**Location:** [AceThemeGenerator.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/AceThemeGenerator.gd)  
**Inherits:** `Control` (`@tool`)  
**Responsibility:** Scene controller and UI signal router. Holds `@onready` references to all UI elements and delegates heavy lifting to helper modules.

#### Key Variables & Constants
- `CONFIG_FILE_PATH` / `OLD_CONFIG_FILE_PATH`: Constants pointing to working JSON configuration.
- `SECTION_MAP`: Dictionary mapping property types (`color`, `constant`, etc.) to theme dictionary keys.
- `theme_parts`, `theme_variations`, `preview_columns`, `preview_texts`: Core data model state.
- `_svg_utils`, `_dialog_utils`, `_config`, `_parts_manager`, `_builder`, `_preview`, `_stylebox_builder`, `_exporter`: Instantiated helper module references.

#### Shared Helper Methods
- `get_part_value(entry) -> Variant`: Safely unpacks entry value if wrapped in dictionary metadata.
- `get_part_id(entry) -> String`: Safely retrieves custom override ID from entry.
- `get_base_prop_name(name: String) -> String`: Strips internal `_copy` suffixes from property names.

#### Lifecycle & Wiring Methods
- `_ready()`: Instantiates helper objects, calls `setup_ui()`, loads configuration, builds parts tree, and initializes preview.
- `setup_ui()`: Connects all UI buttons, spinboxes, line edits, and option dropdowns to helper functions.
- `_apply_editor_scaling()`: Adjusts UI font sizes and minimum sizes dynamically based on Editor scale.

#### Signal Handlers (Thin Wrappers)
- `_on_select_control_type_pressed()`: Launches native Godot Node selection dialog.
- `_on_control_type_selected(type_name)`: Callback when Control type is chosen from node picker.
- `_on_custom_type_toggled(pressed)`: Enables/disables custom variation text input.
- `_on_images_edit_changed(new_text)`, `_on_fonts_edit_changed(new_text)`, `_on_metadata_edit_changed(new_text)`, `_on_output_edit_changed(new_text)`: Update path variables and trigger config saves.
- `_on_images_browse_pressed()`, `_on_fonts_browse_pressed()`, `_on_metadata_browse_pressed()`, `_on_output_browse_pressed()`: Open browse file/directory dialogs.
- `_on_settings_header_toggled(pressed)`, `_on_parts_builder_header_toggled(pressed)`: Toggle collapsible section visibility.
- `_on_preview_columns_changed(value)`, `_on_preview_item_width_changed(value)`, `_on_preview_font_size_changed(value)`: Update preview parameters and refresh layout.
- `_on_h_split_resized()`: Keeps split container proportions visually balanced.

---

### 2. `Scripts/ThemeConfig.gd`
**Location:** [ThemeConfig.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemeConfig.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Configuration file I/O operations, path fallbacks, data migration, and JSON import.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `ensure_config_loaded()`: Lazy-loads configuration if not already loaded.
- `ensure_dir_exists(path: String)`: Recursively creates missing directories.
- `save_config()`: Serializes current paths, `theme_parts`, `theme_variations`, and preview settings to JSON (`config.json`).
- `load_config()`: Reads JSON config, performs automatic migration from old path location, enforces directory creation, applies fallback paths, cleans up orphaned keys, and triggers SVG reimport.
- `import_config_from_file(file_path: String)`: Imports external `config.json` file into current workspace and refreshes UI.
- `on_import_config_pressed()`: Opens file dialog to select a configuration JSON file to import.

---

### 3. `Scripts/ThemePartsManager.gd`
**Location:** [ThemePartsManager.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemePartsManager.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Theme parts dictionary CRUD operations, Tree view rendering, dynamic input control creation, property option populating, and deduplication.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `cleanup_unique_properties()`: Scans `theme_parts` dictionary and merges/deduplicates properties sharing the same base name.
- `update_property_types()`: Populates the Property Type dropdown (`Color`, `Constant`, `Font`, `Font Size`, `Icon`, `StyleBox`) based on selected Control class defaults.
- `update_property_names()`: Queries `ThemeDB.get_default_theme()` for available default property names for the chosen Control class and category.
- `update_value_input_control()`: Dynamically instantiates appropriate input control (`ColorPickerButton`, `SpinBox`, `EditorResourcePicker`) in the value container based on property type.
- `on_new_override_pressed()`: Clears active selection and resets input controls for creating a new property override.
- `on_duplicate_override_pressed()`: Duplicates selected tree item with a copy suffix.
- `on_delete_override_pressed()`: Removes selected override entry from `theme_parts` data structure and updates tree/preview.
- `on_add_part_pressed()`: Reads input widget values and commits/updates property override in `theme_parts`.
- `refresh_parts_tree()`: Rebuilds tree hierarchy representing configured theme overrides grouped by Control type.
- `on_tree_item_selected()`: Syncs input fields and dropdowns when a user clicks an entry in the Tree view.
- `on_override_name_changed(new_text)`: Updates entry ID/alias when text is modified in line edit.
- `on_color_picker_changed(color)`, `on_spin_box_changed(value)`, `on_resource_picker_changed(res)`: Event callbacks updating entry value when user alters input control.
- `on_prop_type_selected(index)`, `on_prop_name_selected(index)`: Event callbacks when user alters Property Type or Property Name dropdowns.
- `on_erp_resource_changed(res)`, `on_erp_resource_selected(res, inspect)`: Handles resource selection and opens resource in Inspector if in editor.

---

### 4. `Scripts/ThemeBuilder.gd`
**Location:** [ThemeBuilder.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemeBuilder.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Constructs a native Godot `Theme` resource object in memory from the `theme_parts` and `theme_variations` dictionaries.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `build_theme() -> Theme`: Instantiates new `Theme` object, configures type variations, and sets all colors, constants, fonts, font sizes, icons, and styleboxes defined in `theme_parts`.

---

### 5. `Scripts/ThemePreview.gd`
**Location:** [ThemePreview.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemePreview.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Live preview grid generation, control state node instantiation, Figma metadata size lookups, inner design body resolution, state visual freezing, and double-click inline text editing.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `get_configured_states(ctrl_type) -> Array[String]`: Inspects configured properties for a control type and returns array of active state names (`normal`, `disabled`, `pressed`, `read_only`, `focus`).
- `instantiate_class_by_name(p_class) -> Control`: Safely instantiates standard engine Control class or custom global script class.
- `setup_preview_node(inst, display_name, theme_ref)`: Prepares label/text fields, fits content, and applies font size overrides.
- `apply_preview()`: Builds native theme, clears preview grid, instantiates section containers and sub-grids for each Control type, sets state flags, freezes visual appearances for state preview nodes, applies metadata dimensions, and connects double-click handlers.
- `on_preview_item_gui_input(event, inst)`: Listens for double-click mouse input on preview controls and spawns inline `LineEdit` overlay to customize sample text.
- `_resolve_svg_key(record, val_path) -> String`: Resolves target SVG filename from stylebox record or resource path.
- `_lookup_metadata_dimensions(svg_key, metadata) -> Vector2`: Extracts width/height from metadata JSON for a given SVG key with fuzzy suffix stripping and word matching.
- `resolve_design_dimensions(active_stylebox, record, val_path, metadata) -> Vector2`: Resolves true inner component body dimensions (subtracting expand margins for `StyleBoxTexture`) with fallbacks to metadata JSON and stylebox minimum sizes.
- `apply_node_preview_sizing(inst, active_stylebox, design_width, design_height, item_width)`: Applies node minimum size and alignment while preserving aspect ratio and visual sizing symmetry across states.
- `_find_common_design_size(ctrl_type, states, metadata) -> Vector2`: Fallback helper to discover common design width/height across control states.
- `_load_metadata() -> Dictionary`: Reads and parses metadata JSON file into dictionary.

---

### 6. `Scripts/ThemeExporter.gd`
**Location:** [ThemeExporter.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/ThemeExporter.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Compiles native `Theme` resource to disk (`.tres`), packages resources (`ResourceFiles/`, `Images/`, `Fonts/`), updates path references inside packaged files, and generates a standalone `theme_preview.tscn` scene.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `on_compile_pressed()`: Builds native `Theme` resource, saves it to output path via `ResourceSaver.save()`, and triggers packaging export.
- `export_theme_package(target_dir)`: Copies all referenced styleboxes, textures, fonts, config JSON, and metadata into packaged target directory structure and rewrites internal `res://` path strings inside `.tres`, `.theme`, `.import`, and `.json` files.
- `_export_preview_scene(target_dir, packaged_theme_path)`: Constructs complete node hierarchy of the preview grid using the packaged theme, packs scene into `PackedScene`, and saves `theme_preview.tscn`.
- `_set_owner_recursive(node, owner_node)`: Recursively assigns node ownership required for `PackedScene.pack()`.

---

### 7. `Scripts/StyleboxBuilder.gd`
**Location:** [StyleboxBuilder.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/StyleboxBuilder.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Parses Figma metadata to generate `StyleBoxFlat` (with corner radii, neon borders, and drop shadows) or `StyleBoxTexture` (with background fill SVG injection, padding expansion, and filter cleanup). Manages metadata build UI controls.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `on_metadata_build_check_toggled(pressed)`: Displays/hides SVG selection dropdown and build controls.
- `refresh_metadata_dropdown()`: Scans metadata JSON keys for `.svg` entries and populates the OptionButton.
- `ensure_metadata_controls()`: Dynamically injects metadata build UI controls into the property grid if missing.
- `on_build_stylebox_pressed(dropdown)`: Opens file dialog asking user where to save generated `StyleBox` resource `.tres`.
- `_on_stylebox_save_path_selected(save_path, svg_key, dialog)`: Main generation handler; parses metadata entry, evaluates drop shadow presence and shape type, calls flat or texture builder, saves `.tres` file, and assigns it to property editor.
- `_build_stylebox_flat(entry, shadow_effect, svg_key) -> StyleBoxFlat`: Generates procedural `StyleBoxFlat` with corner radius, border width, neon color, and shadow parameters parsed from Figma metadata.
- `_build_stylebox_texture(entry, svg_key) -> StyleBoxTexture`: Generates `StyleBoxTexture`, injects solid background fills directly into SVG `<rect>`, cleans unsupported SVG filters, reimports texture, and applies expand margins.
- `_find_solid_fill(fills) -> Variant`: Utility function extracting solid fill dict from Figma metadata fills array.

---

### 8. `Scripts/SvgUtils.gd`
**Location:** [SvgUtils.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/SvgUtils.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** SVG file scanning, filter cleanup (removing unsupported SVG filters), and automatic reimporting of SVGs as Godot `DPITexture`.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `scan_for_svgs(dir_path, out_files)`: Recursively traverses directory tree collecting paths of `.svg` files.
- `reimport_svgs_as_dpi_textures(dir_path)`: Scans SVG directory, cleans unsupported filters, checks `.import` files, updates import settings to importer `svg` and type `DPITexture`, and calls `EditorInterface.get_resource_filesystem().reimport_files()`.
- `on_process_frame_reimport()`: Deferred frame callback ensuring files are reimported safely on the main thread.
- `clean_svg_filters(file_path)`: Uses regular expressions to strip unsupported `filter="url(#...)"` attributes from SVG XML files to avoid Godot rendering artifacts.

---

### 9. `Scripts/DialogUtils.gd`
**Location:** [DialogUtils.gd](file:///d:/Anomaly%20Aces%20Files/Anomaly%20Aces%20Projects/Godot%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesThemeGenerator/Scenes/AceThemeGenerator/Scripts/DialogUtils.gd)  
**Inherits:** `RefCounted` (`@tool`)  
**Responsibility:** Spawns directory and file picker dialogs (`EditorFileDialog` when in Editor mode, `FileDialog` in standalone mode) and warning dialog popups.

#### Functions
- `_init(owner)`: Binds orchestrator instance.
- `show_warning_dialog(message)`: Pops up centered `AcceptDialog` displaying warning message.
- `browse_dir(line_edit, title)`: Opens directory selection dialog and populates target `LineEdit` upon confirmation.
- `browse_file(line_edit, filter, title, is_save)`: Opens file selection/save dialog with extension filter and updates target `LineEdit`.
- `_on_browse_path_selected(path, line_edit, dialog)`: Internal callback emitting `text_changed` on line edit and freeing dialog node.

---

## Best Practices & Integration Notes

1. **Adding New Functionality**:
   - Determine which helper domain the feature belongs to (e.g., export logic → `ThemeExporter.gd`, UI interaction → `ThemePartsManager.gd`).
   - Add method to helper script using `_owner` to access shared state.
   - If UI signal connection is required, route through a thin handler method on `AceThemeGenerator.gd`.

2. **Accessing UI Nodes**:
   - UI `@onready` nodes live on `_owner`. Use `_owner.override_name_edit`, `_owner.parts_tree`, etc. from within helper scripts.

3. **Editor Scale Handling**:
   - All helper script dialogs and dynamic widgets automatically respect `EditorInterface.get_editor_scale()` through `_owner._apply_editor_scaling()`.
