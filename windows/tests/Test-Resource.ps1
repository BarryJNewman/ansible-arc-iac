using module ../modules/ArcWindowsDemo/ArcWindowsDemo.psm1

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Run this check on Windows.' }
$path = Join-Path $env:TEMP ('arc-windows-test-' + [guid]::NewGuid())
$r = [ArcWindowsDirectory]::new()
$r.Path = $path
try {
    if ($r.Test()) { throw 'A missing directory must not be compliant.' }
    $null = New-Item -Path $path -ItemType Directory
    Set-Acl -LiteralPath $path -AclObject $r.DesiredAcl()
    if (-not $r.Test()) {
        $expected = $r.DesiredAcl().GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::Access)
        throw "The desired ACL must be compliant. Expected: $expected Actual: $($r.ReadState())"
    }
    if ($r.Get().CurrentState -cne $r.ReadState()) { throw 'Get returned incorrect state.' }
    $acl = Get-Acl -LiteralPath $path
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        [System.Security.Principal.SecurityIdentifier]::new('S-1-1-0'),
        [System.Security.AccessControl.FileSystemRights]::Write,
        [System.Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $path -AclObject $acl
    if ($r.Test()) { throw 'An additional write permission must be detected as drift.' }
    $rejected = $false
    try { $r.Set() } catch {
        if ($_.Exception.Message -notlike '*only supports C:\ArcDemo*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Set must reject unrelated paths.' }
    Write-Host 'PASS: missing directory, desired ACL, Get state, permission drift, and path restriction.'
} finally {
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
