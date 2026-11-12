$ErrorActionPreference = 'Stop'

$pythonVersion = & python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
if ($LASTEXITCODE -ne 0) {
    throw "Python command failed. Install Python 3.14 and ensure 'python' is available on PATH."
}
if ($pythonVersion -ne '3.14') {
    throw "Python 3.14 is required, but 'python' resolved to Python $pythonVersion."
}

& python -m venv .venv
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to create the project virtual environment.'
}
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
    $maxAttempts = 5
    $downloadExitCode = 1

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host "Installing Pandoc $pandocVersion (attempt $attempt of $maxAttempts)..."

        & .\.venv\Scripts\python.exe -c "import pypandoc, sys; pypandoc.download_pandoc(version=sys.argv[1], targetfolder=sys.argv[2], delete_installer=True)" $pandocVersion $venvScripts
        $downloadExitCode = $LASTEXITCODE

        if ($downloadExitCode -eq 0) {
            break
        }

        if ($attempt -lt $maxAttempts) {
            $delaySeconds = [int][Math]::Pow(2, $attempt)
            Write-Warning "Pandoc download failed (exit code $downloadExitCode). Retrying in $delaySeconds seconds..."
            Start-Sleep -Seconds $delaySeconds
        }
    }

    if ($downloadExitCode -ne 0) {
        throw "Failed to install Pandoc $pandocVersion after $maxAttempts attempts."
    }
}

$pandocVersionOutput = & $pandocExe --version
if ($LASTEXITCODE -ne 0 -or $pandocVersionOutput[0] -notmatch "^pandoc\s+$([regex]::Escape($pandocVersion))$") {
    throw "Pandoc $pandocVersion is not available in the project virtual environment."
}

if ([string]::IsNullOrWhiteSpace($env:PLAYWRIGHT_BROWSERS_PATH)) {
    $env:PLAYWRIGHT_BROWSERS_PATH = '0'
}
& .\.venv\Scripts\rfbrowser.exe init chromium