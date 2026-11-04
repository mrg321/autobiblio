$ErrorActionPreference = 'Stop'

$robotExe = Join-Path $PSScriptRoot '.venv\Scripts\robot.exe'
$pandocExe = Join-Path $PSScriptRoot '.venv\Scripts\pandoc.exe'
$resultsDir = Join-Path $PSScriptRoot 'results'
$reportDir = Join-Path $resultsDir 'robot-reports'
$suites = @(
    'book-borrow.robot'
    'transform-book.robot'
    'pdf-to-text.robot'
    'text-to-epub.robot'
    'send-to-kindle.robot'
)

if (-not (Test-Path -LiteralPath $robotExe -PathType Leaf)) {
    Write-Error "Robot Framework executable not found: $robotExe. Run setup.ps1 first."
    exit 1
}

if (-not (Test-Path -LiteralPath $pandocExe -PathType Leaf)) {
    Write-Error "Pandoc executable not found: $pandocExe. Run setup.ps1 first."
    exit 1
}

$pandocVersionOutput = & $pandocExe --version
if ($LASTEXITCODE -ne 0 -or $pandocVersionOutput[0] -notmatch '^pandoc\s+') {
    Write-Error "Pandoc executable could not be run: $pandocExe"
    exit 1
}
$env:PYPANDOC_PANDOC = $pandocExe

$missingSuites = @(
    $suites | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $_) -PathType Leaf)
    }
)
if ($missingSuites.Count -gt 0) {
    Write-Error "Robot suite(s) not found: $($missingSuites -join ', ')"
    exit 1
}

New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$env:PLAYWRIGHT_BROWSERS_PATH = '0'
$runResults = @()

Push-Location $PSScriptRoot
try {
    foreach ($suite in $suites) {
        $suiteName = [IO.Path]::GetFileNameWithoutExtension($suite)
        $reportFile = Join-Path $reportDir "$suiteName-report.html"
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()

        Write-Host "`n=== Running $suite ==="
        & $robotExe `
            --outputdir $reportDir `
            --output "$suiteName-output.xml" `
            --log "$suiteName-log.html" `
            --report "$suiteName-report.html" `
            --removekeywords 'name:Fill Text' `
            --variable 'HEADLESS:True' `
            $suite
        $exitCode = $LASTEXITCODE

        $stopwatch.Stop()
        $status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
        $runResults += [PSCustomObject]@{
            Suite = $suite
            Status = $status
            ExitCode = $exitCode
            Duration = $stopwatch.Elapsed
        }

        Write-Host ("{0}: {1} (exit code {2}, {3:N1}s)" -f `
            $status, $suite, $exitCode, $stopwatch.Elapsed.TotalSeconds)
        Write-Host "Reports: $reportFile"

        if ($exitCode -ne 0) {
            Write-Host "`nRun summary:"
            $runResults | Format-Table Suite, Status, ExitCode, Duration -AutoSize
            Write-Host "Stopping after '$suite' failed with exit code $exitCode."
            exit $exitCode
        }
    }
}
finally {
    Pop-Location
}

Write-Host "`nRun summary:"
$runResults | Format-Table Suite, Status, ExitCode, Duration -AutoSize
Write-Host "All Robot tasks completed successfully."
