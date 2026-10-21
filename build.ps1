# Run on an Ubuntu authoring host with PowerShell 7.2.4+.
# Prerequisite installation commands are in README.md.
$ErrorActionPreference = 'Stop'
if (-not $IsLinux) { throw 'Build this Linux demo on Ubuntu, not macOS or Windows.' }
Import-Module PSDesiredStateConfiguration -RequiredVersion '3.0.0-beta1'
Import-Module GuestConfiguration
$env:PSModulePath = (Join-Path $PSScriptRoot 'modules') + [IO.Path]::PathSeparator + $env:PSModulePath
. (Join-Path $PSScriptRoot 'configuration.ps1')
$output = Join-Path $PSScriptRoot 'out'
$null = New-Item -ItemType Directory -Force -Path $output
ArcAnsibleDirectoryDemo -OutputPath $output
$mof = Join-Path $output 'ArcAnsibleDirectoryDemo.mof'
Move-Item (Join-Path $output 'localhost.mof') $mof -Force
$package = New-GuestConfigurationPackage -Name 'ArcAnsibleDirectoryDemo' `
    -Configuration $mof -Path $output -Type AuditAndSet -Force

# The playbook lives inside the resource module so it travels with the module.
$zip = [IO.Compression.ZipFile]::OpenRead($package.Path)
try {
    if (-not ($zip.Entries.FullName | Where-Object { $_ -match 'ArcAnsibleDemo[/\\].*ensure-directory\.yml$' })) {
        throw 'The generated package is missing the bundled Ansible playbook.'
    }
} finally { $zip.Dispose() }
$hash = (Get-FileHash -Path $package.Path -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $output 'content-sha256.txt') -Value $hash
Write-Host "Package: $($package.Path)"
Write-Host "Content SHA256: $hash"
