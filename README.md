# Autobiblio

Autobiblio is a Robot Framework browser-automation project for checking the
availability of the current day's *El País, edición Madrid* in eBiblio Madrid.
When the newspaper is available, the test attempts to borrow it; otherwise, it
attempts to place a reservation if that option is offered.

## Project contents

- `book-loan.robot` — the Robot Framework test and browser workflow.
- `credentials.resource` — local eBiblio login variables. This file is excluded
  from Git; create it locally and provide it securely when packaging the project.
- `requirements.txt` — pinned Python dependencies.
- `setup.ps1` — creates the Python virtual environment, installs dependencies,
  and initializes the Browser library with Chromium.
- `run.ps1` — runs the Robot Framework test.

## Prerequisites (Windows)

- Python 3.14 installed and available through the `py` launcher.
- Node.js and npm installed and available on `PATH`.
- Internet access for installing Python packages and downloading Chromium.

## Install

Place the project files in a folder, then open PowerShell in that folder and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1
```

The setup creates `.venv` in the project folder and installs Chromium into the
venv-local Playwright browser cache. You do not need to copy a pre-existing
`.venv` from another computer.

Create `credentials.resource` in the project folder with your own eBiblio
credentials:

```robot
*** Variables ***
${USUARIO}     your_username
${PASSWORD}    your_password
```

Keep this file private. It is gitignored; do not commit it or include it in a
shared package. Provide it separately and securely on the target computer.

## Run

From the project folder, run:

```powershell
.\run.ps1
```

The script sets `PLAYWRIGHT_BROWSERS_PATH=0` so Playwright uses the browser
cache installed with this venv, then runs `book-loan.robot`. Robot Framework
writes its run reports in the current project folder by default.

**Caution:** This is not a dry run. The test logs into eBiblio and can submit a
loan or reservation if available. To validate parsing and keyword resolution
without executing the browser actions, run:

```powershell
.\.venv\Scripts\robot.exe --dryrun --output NONE --log NONE --report NONE .\book-loan.robot
```
