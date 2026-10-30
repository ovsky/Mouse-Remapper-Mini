# --- MASTER BUILD SCRIPT WITH EMBEDDED SCRIPT ICON ---
$scriptName = "remapper.ps1"
$exeName = "MouseButtonRemapperMini.exe"

$currentDir = $PSScriptRoot
if (-not $currentDir) { $currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$scriptPath = Join-Path $currentDir $scriptName
$exePath = Join-Path $currentDir $exeName
$icoPath = Join-Path $currentDir "app_icon.ico"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   MOUSE BUTTON REMAPPER MINI - BUILD UTILITY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Check if source script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] Could not find '$scriptName' in: $currentDir" -ForegroundColor Red
    Pause
    exit
}

# --- GENERATE THE EXACT ICON FROM THE APP CODE ---
Write-Host "[INFO] Generating application icon..." -ForegroundColor Yellow
try {
    Add-Type -AssemblyName System.Drawing
    $bmp = [System.Drawing.Bitmap]::new(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(99, 102, 241))
    $g.FillEllipse($brush, 2, 2, 28, 28)

    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 2.5)
    $g.DrawLine($pen, 16, 8, 16, 24)
    $g.DrawLine($pen, 10, 14, 16, 8)
    $g.DrawLine($pen, 22, 14, 16, 8)

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)

    # Save icon stream to disk temporarily for the compiler
    $fs = [System.IO.FileStream]::new($icoPath, [System.IO.FileMode]::Create)
    $icon.Save($fs)
    $fs.Close()
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "[SUCCESS] Icon generated successfully!" -ForegroundColor Green
}
catch {
    Write-Host "[WARNING] Could not auto-generate icon, proceeding without custom icon: $_" -ForegroundColor Yellow
    $icoPath = $null
}

# Check and install ps2exe module if missing
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "[INFO] 'ps2exe' compiler module not found. Installing it automatically..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "[SUCCESS] ps2exe installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to install ps2exe module: $_" -ForegroundColor Red
        Pause
        exit
    }
}

Import-Module ps2exe -ErrorAction SilentlyContinue

Write-Host "[INFO] Compiling '$scriptName' into standalone executable..." -ForegroundColor Yellow

try {
    $ps2exeArgs = @{
        InputFile   = $scriptPath
        OutputFile  = $exePath
        NoConsole   = $true
        Title       = "Mouse Button Remapper Mini"
        Product     = "Mouse Button Remapper Mini"
        Company     = "OpenSource"
        Copyright   = "MIT"
        Version     = "1.0.0.0"
        ErrorAction = "Stop"
    }

    if ($icoPath -and (Test-Path $icoPath)) {
        $ps2exeArgs['IconFile'] = $icoPath
    }

    Invoke-PS2Exe @ps2exeArgs

    # Clean up temp icon file
    if ($icoPath -and (Test-Path $icoPath)) {
        Remove-Item $icoPath -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "   BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Your standalone app with the matching icon is ready here:" -ForegroundColor White
    Write-Host "$exePath" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host "[ERROR] Compilation failed: $_" -ForegroundColor Red
}

# Only pause if running interactively on a local machine
if (-not $env:CI) {
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}