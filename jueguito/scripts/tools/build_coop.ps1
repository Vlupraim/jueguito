param(
    [Parameter(Mandatory=$true)][string]$Engine,
    [switch]$PackageOnly
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$repo = Split-Path $project -Parent
$distribution = Join-Path $repo 'dist'
$logs = Join-Path $project '.godot/build_coop'
New-Item -ItemType Directory -Force $logs,(Join-Path $distribution 'cliente'),(Join-Path $distribution 'servidor') | Out-Null
if (!$PackageOnly) {
    $version = & $Engine --version
    if ($version -notlike '4.7.stable*') { throw 'Use Godot 4.7 stable with matching export templates.' }
    $templates = Join-Path $project '.godot/export_runtime/templates'
    if (!(Test-Path (Join-Path $templates 'windows_release_x86_64.exe'))) { throw 'Missing Windows templates. See docs/technical/coast_coop.md.' }
    $env:APPDATA = Join-Path $logs 'appdata'
    & $Engine --headless --path $project --script res://scripts/tools/build_coop_catalog.gd *> (Join-Path $logs 'catalog.log')
    if ($LASTEXITCODE -ne 0) { throw 'Catalog generation failed; inspect catalog.log.' }
    foreach ($target in @('Client','Server')) {
        $log = Join-Path $logs "$target.log"
        & $Engine --headless --path $project --export-release "Windows $target" *> $log
        if ($LASTEXITCODE -ne 0 -or (Select-String -Path $log -Pattern "Can't open file.*project.binary|SCRIPT ERROR:|Failed to export|Unable to save export" -Quiet)) { throw "Export failed: $log" }
    }
}
$clientFolder = Join-Path $distribution 'cliente'
$serverFolder = Join-Path $distribution 'servidor'
foreach ($folder in @($clientFolder,$serverFolder)) {
    $executable = if ($folder -eq $clientFolder) { 'Jueguito' } else { 'JueguitoServidor' }
    foreach ($required in @("$executable.exe","$executable.pck",'libterrain.windows.release.x86_64.dll')) {
        if (!(Test-Path (Join-Path $folder $required))) { throw "Missing exported file: $folder/$required" }
    }
    Copy-Item -LiteralPath (Join-Path $project 'docs/technical/coast_coop.md') -Destination (Join-Path $folder 'LEEME.md')
}
$configPath = Join-Path $serverFolder 'server.cfg'
if (!(Test-Path $configPath)) {
    $roomKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(12)).ToLowerInvariant()
    @"
[server]
port=7777
bind="*"
room_key="$roomKey"
state_file="server_data/state.json"
"@ | Set-Content -LiteralPath $configPath -Encoding utf8
}
@'
@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0IniciarServidor.ps1"
echo.
echo Servidor cerrado. El estado esta en server_data/state.json.
pause
'@ | Set-Content -LiteralPath (Join-Path $serverFolder 'IniciarServidor.bat') -Encoding ascii
@'
param([int]$QuitAfter = 0)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()
Set-Location -LiteralPath $PSScriptRoot
# The main export binary works without the optional console-wrapper executable.
$arguments = @('--headless')
if ($QuitAfter -gt 0) { $arguments += @('--quit-after',"$QuitAfter") }
$arguments += @('--','--server','--config=server.cfg') + $args
& (Join-Path $PSScriptRoot 'JueguitoServidor.exe') @arguments 2>&1 | Out-Host
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath (Join-Path $serverFolder 'IniciarServidor.ps1') -Encoding utf8
@'
#Requires -RunAsAdministrator
param([int]$Port = 0)
$ErrorActionPreference = 'Stop'
if ($Port -eq 0) {
    $setting = Select-String -Path (Join-Path $PSScriptRoot 'server.cfg') -Pattern '^port\s*=\s*(\d+)'
    $Port = if ($setting) { [int]$setting.Matches[0].Groups[1].Value } else { 7777 }
}
if ($Port -lt 1 -or $Port -gt 65535) { throw 'Invalid UDP port' }
$program = (Resolve-Path (Join-Path $PSScriptRoot 'JueguitoServidor.exe')).Path
$rule = "Jueguito-Coast-UDP-$Port"
if (Get-NetFirewallRule -Name $rule -ErrorAction SilentlyContinue) {
    Set-NetFirewallRule -Name $rule -Direction Inbound -Action Allow -Program $program -Protocol UDP -LocalPort $Port -Profile Any
} else {
    New-NetFirewallRule -Name $rule -DisplayName "Jueguito costa UDP $Port" -Direction Inbound -Action Allow -Program $program -Protocol UDP -LocalPort $Port -Profile Any | Out-Null
}
Write-Host "Regla creada para JueguitoServidor.exe en UDP $Port."
'@ | Set-Content -LiteralPath (Join-Path $serverFolder 'AbrirFirewall.ps1') -Encoding utf8
@'
@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AbrirFirewall.ps1"
pause
'@ | Set-Content -LiteralPath (Join-Path $serverFolder 'AbrirFirewall.bat') -Encoding ascii
$catalog = Get-Content -LiteralPath (Join-Path $project 'data/network/coast_session_catalog.json') -Raw | ConvertFrom-Json
foreach ($folder in @($clientFolder,$serverFolder)) {
    $checksums = @{}
    foreach ($file in Get-ChildItem -LiteralPath $folder -File) {
        if ($file.Extension -in @('.exe','.dll','.pck')) { $checksums[$file.Name] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    @{ version='0.1.0'; godot='4.7.stable'; world_build=$catalog.build_id; protocol='coast-coop-v1'; files=$checksums } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $folder 'manifest.json') -Encoding utf8
}
# Exclude live server_data and logs from packages; updates preserve host saves.
foreach ($pair in @(@('cliente','Jueguito-Cliente-Windows.zip'),@('servidor','Jueguito-Servidor-Windows.zip'))) {
    $archive = Join-Path $distribution $pair[1]
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
    $source = Join-Path $distribution $pair[0]
    $zip = [IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $source -File) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,($pair[0]+'/'+$file.Name),[IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally { $zip.Dispose() }
    Get-Item -LiteralPath $archive | Select-Object Name,Length
}
