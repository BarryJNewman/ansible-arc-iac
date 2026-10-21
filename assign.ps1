param(
    [Parameter(Mandatory)] [string] $MachineResourceId,
    [Parameter(Mandatory)] [uri] $ContentUri,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string] $ContentHash
)
$ErrorActionPreference = 'Stop'
if ($MachineResourceId -notmatch '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.HybridCompute/machines/[^/]+$') {
    throw 'Use the full resource ID of an Arc-enabled server (Microsoft.HybridCompute/machines).'
}
if ($ContentUri.Scheme -ne 'https') { throw 'ContentUri must use HTTPS.' }
$machineJson = & az resource show --ids $MachineResourceId --output json
if ($LASTEXITCODE -ne 0) { throw 'Unable to read the Arc machine. Check az login and the resource ID.' }
$machine = ($machineJson -join "`n") | ConvertFrom-Json
$body = @{
    location = $machine.location
    properties = @{
        guestConfiguration = @{
            name = 'ArcAnsibleDirectoryDemo'
            version = '1.0.0'
            contentUri = $ContentUri.AbsoluteUri
            contentHash = $ContentHash
            assignmentType = 'ApplyAndAutoCorrect'
        }
    }
}
$temporaryFile = [IO.Path]::GetTempFileName()
try {
    $body | ConvertTo-Json -Depth 8 | Set-Content -Path $temporaryFile
    $url = "https://management.azure.com$MachineResourceId/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/ArcAnsibleDirectoryDemo?api-version=2022-01-25"
    & az rest --method put --url $url --body "@$temporaryFile" --output json
    if ($LASTEXITCODE -ne 0) { throw 'Guest configuration assignment failed.' }
} finally {
    Remove-Item -LiteralPath $temporaryFile -Force
}
