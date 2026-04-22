# Build Pinnacle release artifacts and copy them into the user's Downloads folder.
# Run from anywhere:  pwsh -File scripts\build_to_downloads.ps1
# Or from repo root:  .\scripts\build_to_downloads.ps1
#
# Outputs:
#   %USERPROFILE%\Downloads\Pinnacle-release.apk
#   %USERPROFILE%\Downloads\Pinnacle-Windows-Release\   (full Flutter bundle — run Pinnacle.exe here)
#   %USERPROFILE%\Downloads\Pinnacle-Windows-x64.zip  (same bundle, zipped for sharing)

$ErrorActionPreference = 'Stop'
$projRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projRoot

$flutter = if (Test-Path "$env:USERPROFILE\flutter\bin\flutter.bat") {
    "$env:USERPROFILE\flutter\bin\flutter.bat"
} elseif (Test-Path 'C:\src\flutter\bin\flutter.bat') {
    'C:\src\flutter\bin\flutter.bat'
} else {
    'flutter'
}

$downloads = [Environment]::GetFolderPath('UserProfile') + '\Downloads'
if (-not (Test-Path $downloads)) {
    New-Item -ItemType Directory -Path $downloads -Force | Out-Null
}

Write-Host "==> Android APK (release)..." -ForegroundColor Cyan
& $flutter build apk --release
$apkSrc = Join-Path $projRoot 'build\app\outputs\flutter-apk\app-release.apk'
$apkDst = Join-Path $downloads 'Pinnacle-release.apk'
Copy-Item -LiteralPath $apkSrc -Destination $apkDst -Force
Write-Host "    $apkDst" -ForegroundColor Green

Write-Host "==> Windows (release)..." -ForegroundColor Cyan
Get-Process -Name Pinnacle -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400
& $flutter build windows --release

$releaseSrc = Join-Path $projRoot 'build\windows\x64\runner\Release'
$releaseDst = Join-Path $downloads 'Pinnacle-Windows-Release'
if (Test-Path $releaseDst) {
    Remove-Item -LiteralPath $releaseDst -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDst -Force | Out-Null
Copy-Item -Path (Join-Path $releaseSrc '*') -Destination $releaseDst -Recurse -Force
Write-Host "    $releaseDst\Pinnacle.exe" -ForegroundColor Green

$zipPath = Join-Path $downloads 'Pinnacle-Windows-x64.zip'
if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $releaseDst '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host "    $zipPath" -ForegroundColor Green

Write-Host "`nDone. Open Downloads and run Pinnacle.exe inside Pinnacle-Windows-Release." -ForegroundColor Cyan
