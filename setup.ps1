$ErrorActionPreference = 'Stop'

py -3.14 -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt

$pandocVersion = '3.9.0.2'
$venvScripts = Join-Path $PSScriptRoot '.venv\Scripts'
$pandocExe = Join-Path $venvScripts 'pandoc.exe'
$installedPandocVersion = $null
if (Test-Path -LiteralPath $pandocExe) {
    $pandocVersionOutput = & $pandocExe --version
    if ($LASTEXITCODE -eq 0 -and $pandocVersionOutput[0] -match '^pandoc\s+(.+)$') {
        $installedPandocVersion = $Matches[1]
    }
}

if ($installedPandocVersion -ne $pandocVersion) {
    & .\.venv\Scripts\python.exe -c "import pypandoc, sys; pypandoc.download_pandoc(version=sys.argv[1], targetfolder=sys.argv[2], delete_installer=True)" $pandocVersion $venvScripts
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Pandoc $pandocVersion."
    }
}

$pandocVersionOutput = & $pandocExe --version
if ($LASTEXITCODE -ne 0 -or $pandocVersionOutput[0] -notmatch "^pandoc\s+$([regex]::Escape($pandocVersion))$") {
    throw "Pandoc $pandocVersion is not available in the project virtual environment."
}

# Keep Playwright's Chromium browser cache inside this venv.
$env:PLAYWRIGHT_BROWSERS_PATH = '0'
& .\.venv\Scripts\rfbrowser.exe init chromium