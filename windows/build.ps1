$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Build this package in PowerShell 7 on Windows.' }
Import-Module PSDesiredStateConfiguration -RequiredVersion '2.0.7'
Import-Module GuestConfiguration
$env:PSModulePath = (Join-Path $PSScriptRoot 'modules') + [IO.Path]::PathSeparator + $env:PSModulePath
. (Join-Path $PSScriptRoot 'configuration.ps1')
$output = Join-Path $PSScriptRoot 'out'
$null = New-Item -ItemType Directory -Force -Path $output
ArcWindowsDirectoryDemo -OutputPath $output
$mof = Join-Path $output 'ArcWindowsDirectoryDemo.mof'
Move-Item (Join-Path $output 'localhost.mof') $mof -Force
$package = New-GuestConfigurationPackage -Name 'ArcWindowsDirectoryDemo' `
    -Configuration $mof -Path $output -Type AuditAndSet -Force
$hash = (Get-FileHash -Path $package.Path -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $output 'content-sha256.txt') -Value $hash
Write-Host "Package: $($package.Path)"
Write-Host "Content SHA256: $hash"
