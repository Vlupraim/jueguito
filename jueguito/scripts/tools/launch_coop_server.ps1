param([int]$QuitAfter = 0)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()
Set-Location -LiteralPath $PSScriptRoot
$program = Join-Path $PSScriptRoot 'JueguitoServidor.exe'
$config = Join-Path $PSScriptRoot 'server.cfg'
if (!(Test-Path -LiteralPath $program) -or !(Test-Path -LiteralPath $config)) {
    Write-Host 'Falta JueguitoServidor.exe o server.cfg. Extrae la carpeta completa.' -ForegroundColor Red
    exit 2
}
$port = 7777
$setting = Select-String -LiteralPath $config -Pattern '^port\s*=\s*(\d+)' | Select-Object -First 1
if ($setting) { $port = [int]$setting.Matches[0].Groups[1].Value }
foreach ($argument in $args) {
    if ($argument -match '^--port=(\d+)$') { $port = [int]$Matches[1] }
}
if ($port -lt 1 -or $port -gt 65535) {
    Write-Host 'El puerto configurado debe estar entre 1 y 65535.' -ForegroundColor Red
    exit 2
}
# A direct double-click of the dedicated EXE starts it silently. Detect that
# existing listener; never terminate a running server or another application.
$listeners = @(Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue)
if ($listeners.Count -gt 0) {
    $sameServer = $false
    foreach ($listener in $listeners) {
        $owner = Get-CimInstance Win32_Process -Filter ("ProcessId="+$listener.OwningProcess) -ErrorAction SilentlyContinue
        if ($owner -and $owner.ExecutablePath -and [string]::Equals($owner.ExecutablePath,$program,[StringComparison]::OrdinalIgnoreCase)) {
            $sameServer = $true
            Write-Host "El servidor ya esta activo en UDP $port (PID $($listener.OwningProcess))." -ForegroundColor Green
            Write-Host "Abre Jueguito.exe > Jugar en linea y conecta a 127.0.0.1, puerto $port, con la clave de server.cfg."
            Write-Host 'Para verlo en una consola nueva, cierra primero esa instancia desde el Administrador de tareas y vuelve a abrir IniciarServidor.bat.'
        } else {
            $ownerName = if ($owner) { $owner.Name } else { 'proceso no identificado' }
            Write-Host "UDP $port esta ocupado por $ownerName (PID $($listener.OwningProcess))." -ForegroundColor Yellow
        }
    }
    if ($sameServer) { exit 10 }
    Write-Host 'Cierra la otra aplicacion si corresponde, o elige otro puerto en server.cfg y en el cliente.'
    exit 4
}
$arguments = @('--headless')
if ($QuitAfter -gt 0) { $arguments += @('--quit-after',"$QuitAfter") }
$arguments += @('--','--server','--config=server.cfg') + $args
# Keep stderr readable: Windows PowerShell otherwise wraps every native error
# in a long NativeCommandError stack that obscures the actual Godot message.
& $program @arguments 2>&1 | ForEach-Object { Write-Host $_.ToString() }
exit $LASTEXITCODE
