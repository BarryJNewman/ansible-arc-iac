using module ../modules/ArcAnsibleDemo/ArcAnsibleDemo.psm1

# Run with the Arc agent's PowerShell runtime as root on Linux.
$ErrorActionPreference = 'Stop'
if (-not $IsLinux -or ((& id -u) -ne '0')) { throw 'Run this check as root on Linux.' }
$env:PSModulePath = (Join-Path $PSScriptRoot '../modules') + [IO.Path]::PathSeparator + $env:PSModulePath
$module = Get-Module -ListAvailable -Name ArcAnsibleDemo | Select-Object -First 1
if (-not $module -or $module.ExportedDscResources -notcontains 'ArcDemoDirectory') {
    throw 'The module manifest must advertise ArcDemoDirectory for DSC discovery.'
}
$directory = Join-Path ([IO.Path]::GetTempPath()) ('arc-demo-test-' + [guid]::NewGuid())
$link = $directory + '-link'
$resource = [ArcDemoDirectory]::new()
$resource.Path = $directory
try {
    if ($resource.Test()) { throw 'A missing directory must be non-compliant.' }
    $null = New-Item -ItemType Directory -Path $directory
    & chmod 0755 -- $directory
    if (-not $resource.Test()) { throw 'A root-owned 0755 directory must be compliant.' }
    if ($resource.Get().CurrentState -cne 'directory|755|0|0') { throw 'Get returned incorrect state.' }
    & chmod 0700 -- $directory
    if ($resource.Test()) { throw 'Permission drift must be non-compliant.' }
    & chmod 0755 -- $directory
    & ln -s -- $directory $link
    $resource.Path = $link
    if ($resource.Test()) { throw 'A symbolic link must not satisfy the directory check.' }
    $resource.Path = $directory
    $rejected = $false
    try { $resource.Set() } catch {
        if ($_.Exception.Message -notlike '*only supports /opt/arc-demo*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Set must reject paths outside the demo.' }
    Write-Host 'PASS: DSC discovery, missing directory, compliant directory, Get state, permission drift, symlink rejection, and path restriction.'
} finally {
    if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Force }
}
