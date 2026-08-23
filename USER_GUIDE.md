# Anomaly Aces Theme Generator — Godot User Guide

Welcome to the **Anomaly Aces Theme Generator** user guide! This Godot 4 plugin provides a visual suite for crafting, previewing, and packaging game UI themes directly within Godot. Whether you are generating native Godot themes from Figma SVG assets or manually building control overrides and type variations, this guide will walk you through every step.

---

## Table of Contents
1. [Overview](#overview)
2. [Installation & Setup](#installation--setup)
3. [Interface Layout](#interface-layout)
4. [Step-by-Step Workflow](#step-by-step-workflow)
   - [1. Export Settings & Directory Configuration](#1-export-settings--directory-configuration)
   - [2. Building StyleBoxes from Figma Metadata & SVGs](#2-building-styleboxes-from-figma-metadata--svgs)
   - [3. Managing Theme Parts & Overrides](#3-managing-theme-parts--overrides)
   - [4. Creating Custom Type Variations](#4-creating-custom-type-variations)
   - [5. Using Live Theme Preview & In-Place Text Editing](#5-using-live-theme-preview--in-place-text-editing)
   - [6. Compiling & Packaging the Final Theme](#6-compiling--packaging-the-final-theme)
5. [Applying the Packaged Theme in Your Game](#applying-the-packaged-theme-in-your-game)
6. [Importing & Exporting Config Files](#importing--exporting-config-files)
7. [Troubleshooting & Tips](#troubleshooting--tips)

---

## Overview

Godot UI themes can be complex to assemble and maintain. **Ace Theme Generator** simplifies this process by providing:
- **Visual Theme Parts Builder**: Easily override colors, constants, fonts, font sizes, icons, and styleboxes for any `Control` node.
- **Figma Metadata StyleBox Compiler**: Automatically translates Figma `metadata.json` properties and SVG graphics into native Godot `StyleBoxFlat` or `StyleBoxTexture` resources, preserving corner radii, solid fills, and drop-shadow glows.
- **Live Interactive Preview Pane**: Renders live UI components across all interactive states (`Normal`, `Hover`, `Pressed`, `Disabled`, `Read Only`, `Focus`) with live font size scaling and double-click sample text editing.
- **Self-Contained Theme Packaging**: Compiles and bundles your final `.tres` theme alongside all required stylebox resources, textures, fonts, and an exported standalone `theme_preview.tscn` scene.

---

## Installation & Setup

### Prerequisites
Make sure your project includes the **Anomaly Aces** core plugin structure:
- `addons/anomalyAcesThemeGenerator/`

### Enabling the Plugin
1. In Godot 4, open **Project Settings** (`Project -> Project Settings`).
2. Go to the **Plugins** tab.
3. Check **Enable** next to **Ace Theme Generator**.
4. The **AceThemeGenerator** dock or main panel tab will appear in your editor layout.

---

## Interface Layout

The Ace Theme Generator is divided into two main panels:

```
+--------------------------------------------------+--------------------------------------------------+
| LEFT PANEL (Control Panel)                       | RIGHT PANEL (Live Theme Preview)                 |
| - Title & Version Header                         | - Preview Header & State Controls               |
| - ▼ Export Settings (Collapsible)               |   - Columns Count SpinBox                        |
|   - Images Folder / Fonts Folder / Metadata File  |   - Item Width SpinBox                           |
|   - Output Theme Path / Import Config Button     |   - Font Size SpinBox                            |
| - ▼ Theme Parts Builder (Collapsible)            | - PanelContainer Preview Workspace               |
|   - Name / ID, Base Control Type                 |   - Live stacked Control sections                |
|   - Custom Type Variation Checkbox               |   - State sub-grids (Normal, Pressed, etc.)      |
|   - Property Type & Name Dropdowns               |   - Dynamic Property Value Widget                |
|   - Build Stylebox from Metadata Option          |                                                  |
|   - Action Buttons (New, Update, Dup, Delete)    |                                                  |
|   - Configured Theme Overrides Tree View         |                                                  |
| - Action Bar                                     |                                                  |
|   - [Apply & Preview Theme]  [Generate Theme]    |                                                  |
+--------------------------------------------------+--------------------------------------------------+
```

---

## Step-by-Step Workflow

### 1. Export Settings & Directory Configuration

Expand the **Export Settings** collapsible header in the Left Panel to configure your working environment:

- **Images Folder**: Directory where your project's UI SVG graphics and textures are stored (Default: `res://addons/anomalyAcesThemeGenerator/working/Images`).
- **Fonts Folder**: Directory containing TTF/OTF font files (Default: `res://addons/anomalyAcesThemeGenerator/working/Fonts`).
- **Metadata File**: Path to your exported Figma `metadata.json` file (Default: `res://addons/anomalyAcesThemeGenerator/working/Metadata/metadata.json`).
- **Output Theme File**: Output path for your compiled `.tres` theme (Default: `res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres`).

> Click the **Browse...** button next to any path to pick directories or files visually. Any changes are automatically saved to your local `config.json`.

---

### 2. Building StyleBoxes from Figma Metadata & SVGs

The generator can automatically craft Godot `StyleBox` resources using Figma design tokens and SVG assets:

1. Select **StyleBox** as the **Property Type** in the Parts Builder.
2. Check **Build from Metadata**.
3. Select your target SVG from the **Metadata SVG** dropdown (populated directly from your `metadata.json`).
4. Click **Build...**.
5. Choose where to save the generated `.tres` stylebox (e.g. inside `working/ResourceFiles/`).
6. The generator will inspect the Figma design tokens:
   - **Vector Shapes / Drop Shadows**: Produces a `StyleBoxFlat` with corner radii, solid bg fill, border thickness, and glow size.
   - **Custom Texture Shapes / Icons**: Produces a `StyleBoxTexture` with auto-injected solid fill colors and expand margins so drop-shadow padding doesn't clip.
7. The new StyleBox resource is automatically assigned to your active property override!

---

### 3. Providing Icons to the Theme Generator (Slider Grabbers, CheckBoxes, Arrows)

For `Icon` properties (such as `HSlider` -> `grabber`, `grabber_highlight`, `grabber_disabled`, `CheckBox` -> `checked`, or `OptionButton` -> `arrow`), you can provide icons using **either of two methods**:

#### Method A: Procedural Metadata Building (Recommended for Knobs with Drop Shadows)
1. Select **Icon** as the **Property Type** in the Parts Builder (e.g. Control = `HSlider`, Property = `grabber`).
2. Check **Build from Metadata**.
3. Select your SVG (e.g. `Red_Slider_Knob_Pressed.svg`) from the **Metadata SVG** dropdown.
4. Click **Build...**.
5. Choose where to save the generated `.tres` Texture2D resource (inside `ResourceFiles/`).
6. The generator creates a native `Texture2D` resource in memory with solid background fills, circular corner radii, and glowing drop shadows directly from your `metadata.json` properties, saves the `.tres` file, and automatically assigns & commits the resource to your active property override!

#### Method B: File Resource Picker
1. Select **Icon** as the **Property Type** in the Parts Builder.
2. In the **Value** Resource Picker control, click **Quick Load** (or **Load**).
3. Select your `.svg` or `.png` texture file directly from your project's `Images/` folder (e.g. `res://addons/anomalyAcesThemeGenerator/working/Themes/CoTO/Images/Red_Slider_Knob.svg`).
4. Click **Add/Update Override**.

---

### 3. Managing Theme Parts & Overrides

To add or modify individual theme overrides (e.g., setting a button's font color or panel stylebox):

1. **Select Base / Control Type**: Click **Select...** to pick any Godot Control class (`Button`, `LineEdit`, `Label`, `PanelContainer`, etc.) using Godot's built-in Node creation picker.
2. **Select Property Type**: Choose `Color`, `Constant`, `Font`, `Font Size`, `Icon`, or `StyleBox`.
3. **Select Property Name**: Select from default engine property names for that Control class (e.g. `font_color`, `font_hover_color`, `normal`, `pressed`).
4. **Set Property Value**:
   - **Color**: Click the ColorPicker button to choose a color.
   - **Constant / Font Size**: Adjust the SpinBox value.
   - **Font / Icon / StyleBox**: Drag-and-drop a resource file or pick one using the Resource Picker.
5. **Set Name / ID (Optional)**: Give your override a descriptive ID tag (e.g. `primary_btn_hover`).
6. Click **Update Override** (or **New Override**).

#### Tree View Controls
The **Configured Theme Overrides Tree** displays all your overrides grouped by Control type:
- **Click an entry** to inspect and edit its values.
- Click **Duplicate Override** to clone an existing override.
- Click **Delete Override** to remove an override.

---

### 4. Creating Custom Type Variations

Godot allows controls to inherit base styles while using custom variation names (e.g. making a `PrimaryButton` or `HeaderLabel` without creating custom GDScript nodes).

1. Select the base control class (e.g. `Button`).
2. Check the **Custom Type?** checkbox.
3. Enter your custom class name in **Custom Name** (e.g. `PrimaryButton`).
4. Add property overrides as usual.
5. In your game scenes, any `Button` node can switch its `theme_type_variation` property to `PrimaryButton` to receive these unique styles!

---

### 5. Using Live Theme Preview & In-Place Text Editing

Click **Apply & Preview Theme** to render your theme live in the Right Panel:

- **State Verification**: The preview displays sub-grids showing how controls render across interactive states (`Normal`, `Disabled`, `Pressed`, `Read Only`, `Focus`).
- **Interactive Header Settings**:
  - **Columns**: Adjust the number of state columns per row (1–6).
  - **Item Width**: Set fixed width for preview elements, or set to `0` for auto-fill.
  - **Font Size**: Dynamically scale font size across all preview items.
- **In-Place Text Editing**:
  - **Double-click** on any preview element (e.g. a button or line edit).
  - Type custom sample text (e.g. *"Submit Order"* or *"Enter username..."*) and press Enter.
  - Your sample text persists automatically in your theme settings!
  - Type `default` or `reset` to return to standard element labels.

---

### 6. Compiling & Packaging the Final Theme

When you are satisfied with your theme design, click **Generate Godot Theme**:

1. **Native Resource Generation**: Saves the compiled `Theme` (`.tres`) to your configured **Output Theme File** path.
2. **Self-Contained Packaging**: Automatically creates subdirectories in your output location:
   - `ResourceFiles/` — Contains all `.tres` StyleBox files.
   - `Images/` — Contains all referenced SVG and texture assets.
   - `Fonts/` — Contains all font files.
   - `config.json` — Saved workspace configuration for round-trippable editing.
3. **In-Place Path Rewriting**: Automatically updates all internal `res://` resource dependency strings across your packaged files so the export folder can be safely moved or distributed anywhere in your project!
4. **Standalone Preview Scene**: Generates a runnable `theme_preview.tscn` file in your output directory, allowing team members or artists to test the full theme in isolation.

---

## Applying the Packaged Theme in Your Game

Once generated, applying your theme in Godot takes seconds:

### Method A: Project-Wide Default Theme
1. Go to **Project -> Project Settings -> Display -> Window**.
2. Scroll to **GUI / Theme**.
3. Set **Custom Theme** to your compiled `.tres` theme file (e.g. `res://addons/anomalyAcesThemeGenerator/working/Themes/theme.tres`).

### Method B: Scene / Container Specific Theme
1. Select any root node in your UI scene (e.g. a `Control`, `CanvasLayer`, or `MarginContainer`).
2. In the Inspector, locate the **Theme** property.
3. Drag and drop your compiled `.tres` theme into the slot.

---

## Importing & Exporting Config Files

- **Automatic Persistence**: All workspace settings are automatically saved to `res://addons/anomalyAcesThemeGenerator/working/config.json`.
- **Sharing Configurations**: To share theme setups across team members or projects:
  1. Click **Import Theme Configuration...** in the Export Settings panel.
  2. Select any valid `config.json` file.
  3. The editor will import all theme parts, variations, paths, and preview text overrides instantly.

---

## Troubleshooting & Tips

- **"Resource must be saved to a file first" Error**:
  Godot requires resources assigned to theme overrides to be saved as `.tres` files on disk. Click the dropdown arrow on the resource picker and select **Save** before updating the override.

- **SVG Filtering Artifacts**:
  SVGs exported from Figma may contain `<filter>` tags for blurs/shadows that ThorVG (Godot's SVG renderer) does not support. The generator automatically cleans unsupported SVG filters on import and configures SVGs as high-DPI `DPITexture` assets.

- **DPI & High-Res Displays**:
  The plugin interface automatically queries `EditorInterface.get_editor_scale()` to scale tree views, spinboxes, headers, and spacing according to your editor scaling preferences (100%, 125%, 150%, 200%).
