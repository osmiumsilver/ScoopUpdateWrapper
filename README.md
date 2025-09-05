# ScoopUpdateWrapper

## Overview
This script initially addressed the need for automatically updating Windows firewall rules when applications are upgraded using Scoop. Due to the way Scoop manages versioned installation directories, plus the limitations of Windows to recognize firewall rule application paths, the rules become outdated after each update and require manual intervention [link](https://github.com/ScoopInstaller/Scoop/issues/5234). This project automates the rule update process.

## Features
- Automatically updates Windows firewall rules.
- Identifies and supports multiple installation of different versions.

## Installation and Usage
1. **Clone the repository**:
   ```powershell
   git clone https://github.com/osmiumsilver/ScoopUpdateWrapper.git
   cd ScoopUpdateWrapper
   ```
2. **Install dependencies**:
   ```powershell
   scoop install gsudo
   ```
3. **Run the project**:
   ```powershell
   Import-Module .\ScoopUpdateWrapper.psd1 -Force
   Invoke-ScoopUpdater
   ```
   
   Or invoke the function with params:
   ```powershell
   Invoke-ScoopUpdater -SkipScoopUpdate -Verbose
   ```


## Additional Parameters

- `-S`: Bypass the `scoop update` process to Skip Scoop Manifest Update. However, be cautious when using this option, as it may break the script if you haven't recently run `scoop update` to update the app manifest. Scoop attempts to automatically update the manifest before updating the app, and skipping this step may lead to issues.


## Development History
This project was initially hosted on this [Gist](https://gist.github.com/osmiumsilver/4707fb236dca64e13a793da70532a668), where early versions were developed. The project has since migrated here to better facilitate versioning, enhancements, and community contributions. You can view the original version history there. 

## Notes
Use the script at your own risk!

## Contributing
Contributions are welcome! Feel free to submit a PR or open an issue. Feedback and suggestions are greatly appreciated.
