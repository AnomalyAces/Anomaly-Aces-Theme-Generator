# Anomaly Aces Theme Generator

Given a collection of assets and a JSON file with metadata, this project creates a Godot Theme that is ready for import in the game engine.

## Features

- **Metadata-Based StyleBox Builder**: Auto-compiles SVG assets and Figma shadow/blur effects into native Godot `StyleBoxFlat` or `StyleBoxTexture` resources.
- **Live Preview Panel**: Real-time rendering of compiled theme elements inside Godot. Features customizable columns and dynamic item width settings (including automatic 1:1 Figma design dimension matching).
- **Configurable Preview Font Sizes**: Includes a `Font Size` SpinBox in the preview header to scale preview text and group title headers dynamically.
- **In-Place Text Editing**: Double-click on any preview button, line edit, or label to type custom strings directly on top of the elements, persisting your text choices automatically.
- **DPI Layout & Text Clipping**: Integrates editor theme inheritance for high-DPI scaling and text clipping (`clip_text`) on constrained elements to prevent text-stretching.
- **SVG Filter Stripping**: Strips unsupported Figma `<filter>` attributes on import to bypass Godot's ThorVG rendering limitations, preserving custom shapes (like circles and arrow cutouts).
- **Automatic Expand Margins**: Matches Figma drop shadow boundaries to `StyleBoxTexture` expand margins, drawing glows outside the borders without shrinking or stretching the core shapes.
- **Self-Contained Theme Packaging**: Generating/compiling a theme automatically copies and packages the theme file along with all referenced styleboxes, SVG textures, `.import` configs, and fonts to subfolders relative to the output path, rewriting all `res://` paths in-place.
- **Standalone Preview Scene Export**: Automatically exports a standalone `theme_preview.tscn` styled with your packaged theme, ready to be opened in Godot or loaded in the default Theme Editor preview pane.

## Getting Started

### Prerequisites & Dependencies Installation

This project depends on the **Anomaly Aces Addon Manager** and its companion utilities (`anomalyAcesLog`, `anomalyAcesTable`, `anomalyAcesUtil`). Because these dependency folders are gitignored in this repository, you must install them before enabling the plugins in Godot.

To install the dependencies:
1. Ensure the `anomalyAcesAddonManager` folder is placed inside your `addons/` directory.
2. Follow the bootstrap and installation instructions inside [INSTALL.md](file:///c:/Users/Jerek/Documents/Anomaly%20Aces/Anomaly%20Aces%20Plugins/Anomaly-Aces-Theme-Generator/addons/anomalyAcesAddonManager/INSTALL.md) of the `anomalyAcesAddonManager` folder to download and install all companion addon dependencies automatically.

The dependencies managed by the addon manager are:
- `anomalyAcesLog`: Logger utility for Anomaly Aces projects.
- `anomalyAcesTable`: Table data structure and presentation utilities.
- `anomalyAcesUtil`: Common utilities and helpers.

> [!NOTE]
> In the near future, you will be able to install and update the **Anomaly Aces Addon Manager** directly from the **Godot Asset Library / Store**.

### Enabling the Addons

To use these tools:
1. Open the project in the Godot Editor.
2. Navigate to **Project -> Project Settings -> Plugins**.
3. Toggle the **Enable** checkbox for **Ace Theme Generator** and any of the **Anomaly Aces** addons you wish to use.
