# Windows Developer Tools Updater



A PowerShell 5.1 script that automatically checks for and installs updates to common PHP and JavaScript development tools on Windows.



## Supported Tools



- Laravel Installer â€” Composer global package

- GitHub CLI â€” Windows Package Manager (WinGet)

- PHP Installer for Extensions (PIE) â€” verified GitHub releases

- Node.js â€” latest LTS release using fnm

- npm â€” latest stable release



## Requirements



- Windows with PowerShell 5.1

- Composer and Laravel Installer

- WinGet

- GitHub CLI

- fnm (Fast Node Manager)

- PIE installed at `C:\tools\pie.exe`



Missing tools are skipped where supported.



## Usage



Run the updater using PowerShell:



```powershell

.\Update-DevTools.ps1

```



The script is designed to run as a regular user. It can also be automated through Windows Task Scheduler.



## Logging



The latest execution log is saved at:



`%LOCALAPPDATA%\DevToolsUpdater\updates.log`



The log is cleared at the beginning of each run.



## Notes



- Composer itself is updated separately with administrator privileges.

- PHP, Xdebug, and project dependencies are not updated.

- Some package updates may require administrator privileges depending on installation settings.

- The PIE replacement and rollback workflow has not yet been fully tested.

- Individual update failures are logged but may not cause the overall script to exit with an error code.




## Composer Self-Update

The repository also includes `Update-Composer.ps1`, a separate PowerShell script for updating Composer itself.

Unlike the main developer-tools updater, this script requires administrator privileges because Composer is installed system-wide.

### Requirements

- Windows PowerShell 5.1
- Administrator privileges
- Composer installed at `C:\ProgramData\ComposerSetup\bin\composer.bat`

### Usage

Open PowerShell as Administrator and run:

```powershell
.\Update-Composer.ps1
```

The script updates Composer to the latest stable release, verifies the installed version, and logs the results.

### Logging

The latest Composer update log is saved at:

`C:\ProgramData\DevToolsUpdater\composer.log`

The log is overwritten at the beginning of each run.

### Automation

Both scripts can be automated using Windows Task Scheduler.

The Composer updater should run as an administrator, while the main developer-tools updater can run as a regular user.

Before scheduling an elevated script, ensure its file, directory, and executable dependencies cannot be modified by unprivileged users.

Task Scheduler configurations are not included in this repository.



## License



MIT License.


