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
- `book-loan-colab.ipynb` — prepares and runs the workflow in Google Colab.

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

## Google Colab

Open [book-loan-colab.ipynb](./book-loan-colab.ipynb) in Google Colab and run
the cells in order. Upload `book-loan.robot` and your private
`credentials.resource` when prompted. The notebook installs the pinned
dependencies, initializes Chromium, and performs a Robot Framework dry run
before live execution. Live automation is disabled by default; explicitly
enable it in the notebook only when you are ready to allow a real loan or
reservation attempt. Do not share the notebook with credentials or saved
outputs.

## GitHub Actions

The workflow in `.github/workflows/book-loan.yml` runs the book-loan task daily
at 5 a.m. Madrid time. GitHub Actions schedules use UTC, so the workflow has
3:00 and 4:00 UTC triggers and proceeds only when it is 5 a.m. in Madrid.
Scheduled runs can be delayed during busy periods, so this is not an exact-time
guarantee. GitHub only runs scheduled workflows from the repository's default
branch. To start a run manually, open **Actions → Daily eBiblio book loan →
Run workflow**. Manual runs do not wait for the Madrid 5 a.m. schedule.

Before enabling the workflow, add repository secrets named
`EBIBLIO_USERNAME` and `EBIBLIO_PASSWORD` under **Settings → Secrets and
variables → Actions**. The workflow creates `credentials.resource` at runtime
from those secrets; do not store credentials in the workflow or repository.

This is a live run: it can submit a loan or reservation. The task can wait up
to four hours for the newspaper to appear, so a run may use significant runner
time. Inspect run status and console output in the repository's **Actions** tab.
