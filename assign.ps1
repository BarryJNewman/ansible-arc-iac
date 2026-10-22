param(
    [Parameter(Mandatory)] [string] $MachineResourceId,
    [Parameter(Mandatory)] [uri] $ContentUri,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string] $ContentHash,
    [switch] $UseSystemAssignedIdentity,
    [ValidateSet('ArcAnsibleDirectoryDemo', 'ArcWindowsDirectoryDemo')]
    [string] $ConfigurationName = 'ArcAnsibleDirectoryDemo'
)
$ErrorActionPreference = 'Stop'
if ($MachineResourceId -notmatch '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.HybridCompute/machines/[^/]+$') {
    throw 'Use the full resource ID of an Arc-enabled server (Microsoft.HybridCompute/machines).'
}
if ($ContentUri.Scheme -ne 'https') { throw 'ContentUri must use HTTPS.' }
$machineJson = & az resource show --ids $MachineResourceId --output json
if ($LASTEXITCODE -ne 0) { throw 'Unable to read the Arc machine. Check az login and the resource ID.' }
$machine = ($machineJson -join "`n") | ConvertFrom-Json
if ($ConfigurationName -eq 'ArcWindowsDirectoryDemo' -and $machine.properties.osType -ine 'windows') {
    throw 'The Windows demo requires a Windows Arc machine.'
}
$body = @{
    location = $machine.location
    properties = @{
        guestConfiguration = @{
            name = $ConfigurationName
            version = '1.0.0'
            contentUri = $ContentUri.AbsoluteUri
            contentHash = $ContentHash
            assignmentType = 'ApplyAndAutoCorrect'
        }
    }
}
if ($UseSystemAssignedIdentity) {
    $body.properties.guestConfiguration.contentManagedIdentity = 'system'
}
$temporaryFile = [IO.Path]::GetTempFileName()
try {
    $body | ConvertTo-Json -Depth 8 | Set-Content -Path $temporaryFile
    $url = "https://management.azure.com$MachineResourceId/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/${ConfigurationName}?api-version=2024-04-05"
    & az rest --method put --url $url --body "@$temporaryFile" --output json
    if ($LASTEXITCODE -ne 0) { throw 'Guest configuration assignment failed.' }
} finally {
    Remove-Item -LiteralPath $temporaryFile -Force
}
