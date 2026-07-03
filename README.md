# Anomaly Aces Theme Generator

Given a collection of assets and a JSON file with metadata, this project creates a Godot Theme that is ready for import in the game engine.

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
