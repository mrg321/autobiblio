$ErrorActionPreference = 'Stop'

py -3.14 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt

# Keep Playwright's Chromium browser cache inside this venv.
$env:PLAYWRIGHT_BROWSERS_PATH = '0'
& .\.venv\Scripts\rfbrowser.exe init chromium