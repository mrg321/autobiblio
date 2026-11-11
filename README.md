# Autobiblio

Autobiblio is a Robot Framework browser-automation project for checking the
availability of configured newspapers in eBiblio Madrid. It checks the
current-day edition of each newspaper in the `@{PERIODICO}` list in
`book-loan.robot`; add other exact catalog titles as additional list values.
When an edition is available, the test attempts to borrow it; otherwise, it
attempts to place a reservation if that option is offered.
After each successful loan, the workflow downloads the offline-reading or
offline-listening file offered by eBiblio into `downloads/`, with a timestamped
filename. This supports both e-books and audiobooks. This folder is ignored by
Git so borrowed content is not committed. The files are available to later
steps in the same local run or GitHub Actions job.
The processing step converts decrypted PDFs to text and copies any decrypted
EPUBs unchanged to `results/epub`. If the decrypted folder contains neither
format, processing continues without failing. When converting a text file to
EPUB, the first page of a same-named PDF in `results/decrypted` is used as the
EPUB cover; text files without a matching PDF are converted without a cover.

## Project contents

- `book-loan.robot` — the Robot Framework test and browser workflow.
- `book-borrow-process.ps1` — runs the book-borrow, conversion, and Kindle-send
  suites in sequence.
- `.github/workflows/book-borrow.yml` — prepares the Windows runner and runs
  the book-borrow process daily.
- `credentials.resource` — local eBiblio login variables. This file is excluded
  from Git; create it locally and provide it securely when packaging the project.
- `requirements.txt` — pinned Python dependencies.
- `setup.ps1` — creates the Python virtual environment, installs dependencies,
  and initializes the Browser library with Chromium.
- `run.ps1` — runs the Robot Framework test.
- `text-to-articles.robot` — processes files in `results/txt` once, saving each
  input's articles separately under `results/cleaned_articles`.
- `send-to-kindle.robot` — sends EPUB files directly from `results/epub` to
  Kindle and records successful sends under `results/epub/.sent`.
- `book-loan-colab.ipynb` — prepares and runs the workflow in Google Colab.

## Prerequisites (Windows and Linux)

- Python 3.14 installed.
- Node.js and npm installed and available on `PATH`.
- Internet access for installing Python packages and downloading Chromium.

## Install

On Windows, open PowerShell in the project folder and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup.ps1
```

On Linux, open a shell in the project folder and run:

```sh
python3.14 -m venv .venv
. .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
PLAYWRIGHT_BROWSERS_PATH=0 rfbrowser init chromium
```

The Windows setup also installs the pinned Pandoc executable into `.venv`.
On Linux, install Pandoc separately and ensure `pandoc` is available on `PATH`
before running `text-to-epub.robot`.

The setup creates `.venv` in the project folder and installs Chromium into the
venv-local Playwright browser cache. You do not need to copy a pre-existing
`.venv` from another computer. The `setup.ps1` and `run.ps1` helpers are for
Windows; on Linux, activate `.venv` as shown above and run Robot Framework
directly.

Create `credentials.resource` in the project folder with your own eBiblio
credentials:

```robot
*** Variables ***
${USUARIO}     your_username
${PASSWORD}    your_password
```

Keep this file private; do not commit it or include it in a shared package.
Although it is listed in `.gitignore`, that rule does not stop Git tracking a
file that is already tracked.

## Run

From the project folder, run:

```powershell
.\run.ps1
```

On Linux, with `.venv` activated, run:

```sh
PLAYWRIGHT_BROWSERS_PATH=0 python -m robot book-loan.robot
```

The script sets `PLAYWRIGHT_BROWSERS_PATH=0` so Playwright uses the browser
cache installed with this venv, then runs the Robot tasks in sequence. It stops
on the first nonzero Robot exit code and displays a status and duration for
each task. Separate XML, log, and report files are saved under
`results/robot-reports/`. Successful loans also save the eBiblio download
under `downloads/` on both platforms. The provider may supply an offline-reader
file rather than a plain PDF; the automation saves the file as offered and
does not convert it.

The processing tasks can also be run individually. To send EPUB files directly
to Kindle, set these variables in the private
`credentials.resource` file:

```robot
*** Variables ***
${KINDLE_SENDER}          your_gmail_address
${KINDLE_APP_PASSWORD}    your_gmail_app_password
${KINDLE_TARGET_EMAIL}    first_kindle_email, second_kindle_email
```

Then run the task from the project root:

```powershell
.\.venv\Scripts\robot.exe --outputdir .\results\robot-reports .\send-to-kindle.robot
```

Separate multiple Kindle addresses with commas; surrounding whitespace is
ignored. The task sends each EPUB to each distinct address, marks each
file-recipient pair only after the sender reports success, and skips
file-recipient pairs with an existing marker. Existing `.sent/<filename>.sent`
markers from the single-recipient version are honored when exactly one address
is configured. Since those legacy markers do not identify their recipient,
they are ignored when multiple addresses are configured.
The timestamp prefix before the first underscore is removed from the Kindle
attachment name; the local EPUB filename is unchanged. The email subject starts
with `convert` followed by the book title derived from the EPUB filename.
To intentionally send a file again, remove its corresponding recipient marker
from `results/epub/.sent/`. The sender requests Amazon to convert the EPUB for
Kindle. Do not put credentials in the
Robot file or commit them. The task loads credentials from `credentials.resource`
and supplies them to the sender through its process environment. SMTP errors
identify the failing connection stage; for authentication errors, verify that
the Gmail app password in `credentials.resource` is current. Files are marked
only after Gmail confirms acceptance, and the sender does not require a
successful SMTP disconnect after that confirmation.

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

The workflow in `.github/workflows/book-loan.yml` runs only when manually
started from the **Actions** tab or triggered through GitHub's
`workflow_dispatch` API. The workflow in `.github/workflows/book-borrow.yml` runs
`book-borrow-process.ps1` on Windows, which borrows and downloads books, then
runs the transformation and Kindle-send tasks. The book-borrow and book-return
workflows can be started manually from the **Actions** tab or triggered
through GitHub's `workflow_dispatch` API. All three workflows run browsers
headlessly and upload Robot reports; browser workflows also include a
screenshot when the test fails.
The book-borrow workflow also uploads a `robot-diagnostics` artifact with its
Robot reports, failure screenshots and Playwright logs. Diagnostic artifacts
are retained for seven days.

Before enabling either workflow, add repository secrets named
`EBIBLIO_USERNAME` and `EBIBLIO_PASSWORD` under **Settings → Secrets and
variables → Actions**. The workflow creates `credentials.resource` at runtime
from those secrets; do not store credentials in the workflow or repository.
The book-borrow workflow also requires `KINDLE_SENDER`,
`KINDLE_APP_PASSWORD`, and `KINDLE_TARGET_EMAIL` secrets for its Kindle-send
step. Separate multiple Kindle addresses in `KINDLE_TARGET_EMAIL` with commas.

These are live workflows: they can submit a loan or reservation, return
available loans, and the book-borrow process can email EPUBs to Kindle. The
book-loan workflow can wait up to four hours for the newspaper to appear, so
a run may use significant runner time. Inspect run status and console output
in the repository's **Actions** tab.
