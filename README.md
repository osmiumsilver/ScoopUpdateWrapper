# ScoopUpdateWrapper

## Overview
This script initially addressed the need for automatically updating Windows firewall rules when applications are upgraded using Scoop. Due to the way Scoop manages versioned installation directories, plus the limitations of Windows to recognize firewall rule application paths, the rules become outdated after each update and require manual intervention. This project automates the rule update process, reducing maintenance overhead.

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
   .\ScoopUpdateWrapper.ps1
   ```

## Features
- **Automated Rule Update**: Automatically updates Windows firewall rules based on versioned Scoop installations.
- **Dynamic Path Detection**: Identifies new application paths without manual reconfiguration.
- **More features are still in development...**

## Development History
This project was initially hosted on this [Gist](https://gist.github.com/osmiumsilver/4707fb236dca64e13a793da70532a668), where early versions were developed. The project has since migrated here to better facilitate versioning, enhancements, and community contributions. You can view the original version history there. 

## Notes
I am a beginner with PowerShell and created this script as an attempt to address an [issue](https://github.com/ScoopInstaller/Scoop/issues/5234) impacting many Scoop users. I will do my best to learn and address any problems as they arise, but please use this script at your own risk.

## Contributing
Contributions are welcome! Feel free to submit a PR or open an issue. Feedback and suggestions are greatly appreciated.
