\# Windows Developer Tools Updater



A PowerShell 5.1 script that automatically checks for and installs updates to common PHP and JavaScript development tools on Windows.



\## Supported Tools



\- Laravel Installer — Composer global package

\- GitHub CLI — Windows Package Manager (WinGet)

\- PHP Installer for Extensions (PIE) — verified GitHub releases

\- Node.js — latest LTS release using fnm

\- npm — latest stable release



\## Requirements



\- Windows with PowerShell 5.1

\- Composer and Laravel Installer

\- WinGet

\- GitHub CLI

\- fnm (Fast Node Manager)

\- PIE installed at `C:\\tools\\pie.exe`



Missing tools are skipped where supported.



\## Usage



Run the updater using PowerShell:



```powershell

.\\Update-DevTools.ps1

```



The script is designed to run as a regular user. It can also be automated through Windows Task Scheduler.



\## Logging



The latest execution log is saved at:



`%LOCALAPPDATA%\\DevToolsUpdater\\updates.log`



The log is cleared at the beginning of each run.



\## Notes



\- Composer itself is updated separately with administrator privileges.

\- PHP, Xdebug, and project dependencies are not updated.

\- Some package updates may require administrator privileges depending on installation settings.

\- The PIE replacement and rollback workflow has not yet been fully tested.

\- Individual update failures are logged but may not cause the overall script to exit with an error code.



\## License



MIT License.

