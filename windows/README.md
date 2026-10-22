# Windows DSC directory demo

Native PowerShell DSC ensures `C:\ArcDemo` exists with a protected DACL:

| Principal | Permission |
| --- | --- |
| SYSTEM | Full control |
| Built-in Administrators | Full control |
| Built-in Users | Read and execute |

Rules inherit to children; inheritance from the parent is disabled. This demo
manages the directory's DACL, not its owner or existing children's explicit ACLs.
Well-known SIDs avoid dependence on the Windows display language. A conflicting
file, junction, or symbolic link is rejected instead of replaced.

## Build and test

Use an elevated PowerShell 7 session on a Windows authoring/test host:

```powershell
Install-Module PSDesiredStateConfiguration -RequiredVersion 2.0.7 -Scope CurrentUser -Force
Install-Module GuestConfiguration -Scope CurrentUser -Force
./windows/tests/Test-Resource.ps1
./windows/build.ps1
Import-Module GuestConfiguration
Start-GuestConfigurationPackageRemediation -Path ./windows/out/ArcWindowsDirectoryDemo.zip -Verbose
Get-GuestConfigurationPackageComplianceStatus -Path ./windows/out/ArcWindowsDirectoryDemo.zip
Get-Acl C:\ArcDemo | Format-List
```

The resource tests use a temporary directory. Package remediation changes
`C:\ArcDemo` on the machine running the command. Use a disposable test host.
The GitHub Actions **Windows DSC demo** workflow builds and tests the package
on a disposable Windows runner and uploads the ZIP and SHA256 as artifacts.

## Assign to an Arc Windows node

Upload `windows/out/ArcWindowsDirectoryDemo.zip` to an accessible private blob
container using Microsoft Entra authentication. Grant the target Arc identity
Storage Blob Data Reader on that container. Its network must reach the blob URL,
including private DNS and routing when storage uses a private endpoint.

From the repository root, with Azure CLI signed in:

```powershell
$machineId = '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.HybridCompute/machines/<windows-arc-machine>'
$contentUri = 'https://<storage-account>.blob.core.windows.net/machineconfiguration/ArcWindowsDirectoryDemo-1.0.0.zip'
./assign.ps1 -MachineResourceId $machineId -ContentUri $contentUri -ContentHash (Get-Content ./windows/out/content-sha256.txt).Trim() -ConfigurationName ArcWindowsDirectoryDemo -UseSystemAssignedIdentity
```

The assignment uses `ApplyAndAutoCorrect`. The Arc agent includes the isolated
DSC runtime; the target does not need the authoring modules or Ansible installed.
The custom module travels inside the package. Check compliance in the node's
Machine Configuration page after agent processing.

For a drift demo, enable inheritance on `C:\ArcDemo` and wait for the next
configuration cycle to restore the protected DACL. To undo the demo, delete
the assignment first, then remove the directory only if it is no longer needed.

[Microsoft Windows package authoring guidance](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/develop-custom-package/2-create-package)
