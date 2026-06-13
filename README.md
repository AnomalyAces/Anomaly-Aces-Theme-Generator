# Anomaly Aces Theme Generator

Given a collection of assets and a JSON file with metadata, this project creates a Godot Theme that is ready for import in the game engine.

## Getting Started

### Prerequisites

This project utilizes the **Anomaly Aces Addon Manager** and its associated utilities.

#### Installation of Addon Manager

The addons were installed by adding all the subfolders in the `addons` folder from the GitHub repository:
[Anomaly-Aces-Addon-Manager](https://github.com/AnomalyAces/Anomaly-Aces-Addon-Manager)

The following addons are included in this project:
- `anomalyAcesAddonManager`: The core Addon Manager tool.
- `anomalyAcesLog`: Logger utility for Anomaly Aces projects.
- `anomalyAcesTable`: Table data structure and presentation utilities.
- `anomalyAcesUtil`: Common utilities and helpers.
- `anomalyAcesThemeGenerator`: The entry point for the Theme Generator itself.

> [!NOTE]
> In the near future, you will be able to install and update the **Anomaly Aces Addon Manager** directly from the **Godot Asset Library / Store**.

### Enabling the Addons

To use these tools:
1. Open the project in the Godot Editor.
2. Navigate to **Project -> Project Settings -> Plugins**.
3. Toggle the **Enable** checkbox for **Ace Theme Generator** and any of the **Anomaly Aces** addons you wish to use.
