param(
    [Parameter(Mandatory=$true)][string]$Engine,
    [string]$Client = "",
    [string]$Server = "",
    [int]$Port = 17777
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$qa = Join-Path $project '.godot/network_validation'
New-Item -ItemType Directory -Force $qa | Out-Null
$tag = if ($Client) { 'release' } else { 'source' }
$state = Join-Path $qa "$tag-state-$([DateTime]::Now.Ticks).json"
$started = @()
function Start-Probe([string]$label, [string]$binary, [string[]]$arguments) {
    $env:APPDATA = Join-Path $qa "$label-appdata"
    $process = Start-Process -FilePath $binary -WindowStyle Hidden -PassThru -ArgumentList $arguments -RedirectStandardOutput (Join-Path $qa "$tag-$label.log") -RedirectStandardError (Join-Path $qa "$tag-$label.err")
    return $process
}
$projectArgs = @('--headless','--path',('"'+$project+'"'))
try {
    $serverBinary = if ($Server) { $Server } else { $Engine }
    [string[]]$serverArgs = if ($Server) { @('--headless') } else { $projectArgs }
    $hostProcess = Start-Probe 'server' $serverBinary ($serverArgs+@('--','--server',"--port=$Port",'--key=testkey',('--state="'+$state+'"')))
    $started += $hostProcess
    Start-Sleep -Seconds 2
    if ($hostProcess.HasExited) { throw 'Server exited before clients started' }
    $clientBinary = if ($Client) { $Client } else { $Engine }
    [string[]]$clientArgs = if ($Client) { @('--headless') } else { $projectArgs }
    $alice = Start-Probe 'alice' $clientBinary ($clientArgs+@('--','--connect=127.0.0.1',"--port=$Port",'--name=Alice','--key=testkey','--network-test=alice'))
    $started += $alice
    $bob = Start-Probe 'bob' $clientBinary ($clientArgs+@('--','--connect=127.0.0.1',"--port=$Port",'--name=Bob','--key=testkey','--network-test=bob'))
    $started += $bob
    $deadline = (Get-Date).AddSeconds(55)
    while ((!$alice.HasExited -or !$bob.HasExited) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
    if (!$alice.HasExited -or !$bob.HasExited) { throw 'Client test timed out' }
    Get-Content (Join-Path $qa "$tag-alice.log"),(Join-Path $qa "$tag-alice.err"),(Join-Path $qa "$tag-bob.log"),(Join-Path $qa "$tag-bob.err") -Tail 35
    if ($alice.ExitCode -ne 0 -or $bob.ExitCode -ne 0) { throw 'Client assertion failed' }
    $rejected = Start-Probe 'reject' $clientBinary ($clientArgs+@('--','--connect=127.0.0.1',"--port=$Port",'--name=WrongKey','--key=incorrect','--network-test=reject'))
    $started += $rejected
    if (!$rejected.WaitForExit(20000) -or $rejected.ExitCode -ne 0) { throw 'Wrong-key assertion failed' }
    Get-Content (Join-Path $qa "$tag-reject.log") -Tail 5
    Get-Content (Join-Path $qa "$tag-server.log"),(Join-Path $qa "$tag-server.err") -Tail 20
    $hostProcess.Kill()
    $hostProcess.WaitForExit(5000) | Out-Null
    $restarted = Start-Probe 'restart' $serverBinary ($serverArgs+@('--','--server',"--port=$Port",'--key=testkey',('--state="'+$state+'"')))
    $started += $restarted
    Start-Sleep -Seconds 2
    $rejoin = Start-Probe 'rejoin' $clientBinary ($clientArgs+@('--','--connect=127.0.0.1',"--port=$Port",'--name=Alice','--key=testkey','--network-test=rejoin'))
    $started += $rejoin
    if (!$rejoin.WaitForExit(20000) -or $rejoin.ExitCode -ne 0) { throw 'Persistence assertion failed' }
    Get-Content (Join-Path $qa "$tag-rejoin.log") -Tail 5
    'COOP_MULTIPROCESS_PASS'
} finally {
    foreach ($process in $started) { if (!$process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null } }
}
