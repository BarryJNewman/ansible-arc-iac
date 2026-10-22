# Arc Machine Configuration + Ansible directory demo

For a native Windows DSC directory and permissions example, see
[the Windows demo](windows/README.md).

Ensures `/opt/arc-demo` is a directory owned by `root:root` with mode `0755`.
The DSC resource checks the actual directory type, numeric UID/GID and mode.
Its `Set()` method invokes the bundled Ansible playbook locally as root.
No SSH connection or Ansible controller is needed.

Azure Machine Configuration is a pull model: the assignment points the Arc
agent at a package ZIP; the agent downloads it, checks state, and applies changes.
`ApplyAndAutoCorrect` enables continued repair of drift. The existing audit
assignments in your screenshot are separate from this custom assignment.

## 1. Prepare the Arc node

Use an Arc-supported Linux distribution with a current Connected Machine agent
(the documented minimum for applying configurations is 1.10.0). Guest
Configuration must be enabled, and the node must reach the package's HTTPS URL.
The Arc agent includes the Machine Configuration component; do not install the
Azure VM Guest Configuration extension on an Arc server.

Install `ansible-core`, Python 3 and GNU coreutils using your distribution's
repositories. For an Ubuntu node:

```bash
sudo apt-get update
sudo apt-get install -y ansible-core python3 coreutils
```

On Azure Linux 3.0, the live demo uses an isolated Python environment because
`ansible-core` was not available in the configured RPM repositories:

```bash
sudo tdnf install -y python3-pip
sudo python3 -m venv /opt/arc-ansible-demo/venv
sudo /opt/arc-ansible-demo/venv/bin/python -m pip install ansible-core==2.21.5
# Only create this link when no Ansible executable is already installed there.
sudo ln -s /opt/arc-ansible-demo/venv/bin/ansible-playbook /usr/bin/ansible-playbook
```

Verify that these exact paths exist (the wrapper intentionally uses a fixed
executable path):

```bash
/usr/bin/ansible-playbook --version
/usr/bin/python3 --version
/usr/bin/stat --version
sudo azcmagent show
sudo azcmagent config get guestconfiguration.enabled
```

Ansible installation is a prerequisite for this demo; it is not installed by the
configuration. It needs no community collections. If `/opt/arc-demo` already
exists as a regular file or symlink, move it aside manually before the demo.
The package does not delete conflicting objects or change child permissions.

## 2. Build on Ubuntu

Copy this directory to an Ubuntu authoring machine with PowerShell 7.2.4+.
You can use the Arc node itself for a small demo. macOS is not a supported
Machine Configuration package test host.

In `pwsh`, from this directory:

```powershell
Install-Module GuestConfiguration -Scope CurrentUser
Install-Module PSDesiredStateConfiguration -RequiredVersion 3.0.0-beta1 -AllowPrerelease -Scope CurrentUser
./build.ps1
```

Outputs: `out/ArcAnsibleDirectoryDemo.zip` and `out/content-sha256.txt`.
The package uses `AuditAndSet`; the script also checks that the ZIP includes the
playbook alongside the DSC resource. Keep the ZIP unchanged after hashing.

Optional direct Ansible syntax check on the Linux host:

```bash
ansible-playbook -i 'localhost,' --syntax-check modules/ArcAnsibleDemo/ensure-directory.yml
```

The standalone DSC resource checks can run on the Arc node using its bundled
PowerShell runtime. Copy this repository to the node, then run from its root:

```bash
sudo /opt/GC_Service/GC/pwsh -NoProfile -File tests/Test-Resource.ps1
```

This checks temporary directories, permission drift, symlink rejection and the
demo's path restriction. It does not create or change `/opt/arc-demo`.

## 3. Test the package on a disposable Linux demo host

Run these commands in a **root PowerShell session** (`sudo pwsh`). The
GuestConfiguration module must be installed where root can import it; install
it in that session if needed. These commands create/change `/opt/arc-demo`.

```powershell
Import-Module GuestConfiguration
Get-GuestConfigurationPackageComplianceStatus -Path ./out/ArcAnsibleDirectoryDemo.zip
Start-GuestConfigurationPackageRemediation -Path ./out/ArcAnsibleDirectoryDemo.zip -Verbose
Get-GuestConfigurationPackageComplianceStatus -Path ./out/ArcAnsibleDirectoryDemo.zip
```

Expected: after remediation, `complianceStatus` is `True`. Run remediation again
to verify that an already compliant directory stays compliant.

## 4. Publish the ZIP

The following PowerShell commands use Azure CLI and an **existing storage
account**. The signed-in identity needs permission to upload blobs and generate
a user delegation SAS (for example, Storage Blob Data Contributor at the storage
account). The node needs network access to that account; a SAS does not bypass
storage firewalls. Set your own account name:

```powershell
az login
$storageAccount = '<storage-account-name>'
$container = 'machineconfiguration'
$blob = 'ArcAnsibleDirectoryDemo-1.0.0.zip'
az storage container create --account-name $storageAccount --name $container --auth-mode login
az storage blob upload --account-name $storageAccount --container-name $container --name $blob --file ./out/ArcAnsibleDirectoryDemo.zip --auth-mode login --overwrite
# Stop and resolve any Azure CLI errors before continuing.
$expiry = (Get-Date).ToUniversalTime().AddHours(4).ToString('yyyy-MM-ddTHH:mmZ')
$sas = az storage blob generate-sas --account-name $storageAccount --container-name $container --name $blob --permissions r --expiry $expiry --auth-mode login --as-user --https-only --output tsv
$contentUri = "https://$storageAccount.blob.core.windows.net/$container/${blob}?$sas"
```

This read-only SAS lasts four hours for the demo. Renew the assignment URL before
expiry if keeping it longer, because future package downloads require access.
Treat the SAS as a credential; do not commit it. Rebuilding a package requires
uploading the new ZIP and updating its hash in the assignment.

## 5. Assign to the Arc machine

The Azure identity also needs read access to the machine and permission to write
guest configuration assignments at its scope. Register the
`Microsoft.GuestConfiguration` resource provider in the subscription if needed.
In the same PowerShell session:

```powershell
$machineId = '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.HybridCompute/machines/<arc-machine-name>'
./assign.ps1 -MachineResourceId $machineId -ContentUri $contentUri -ContentHash (Get-Content ./out/content-sha256.txt).Trim()
```

The script reads the machine's Azure location and creates a direct assignment
named `ArcAnsibleDirectoryDemo` with `ApplyAndAutoCorrect`. This does not require
creating an Azure Policy definition. In the portal, open your Arc server's
**Machine Configuration** page and refresh to find the manual assignment.
Agent processing and compliance reporting are asynchronous.

### Managed identity alternative (used by the live Azure Linux demo)

If storage policy disables shared-key access, use Microsoft Entra authentication
to upload (`--auth-mode login`) and grant the Arc machine's system-assigned
identity **Storage Blob Data Reader** on the package container. The build/upload
identity needs **Storage Blob Data Contributor** on that container. Uploads and
downloads also need network access to storage, such as a private endpoint with
private DNS for both hosts.

Use a plain blob URL without a SAS, then enable identity-based package access:

```powershell
$contentUri = "https://$storageAccount.blob.core.windows.net/$container/$blob"
./assign.ps1 -MachineResourceId $machineId -ContentUri $contentUri -ContentHash (Get-Content ./out/content-sha256.txt).Trim() -UseSystemAssignedIdentity
```

This sets `contentManagedIdentity` to `system`; there is no SAS expiration to
renew. Allow time for new Azure role assignments to propagate.

## 6. Show drift and repair

On the Arc node, first confirm the applied state:

```bash
sudo stat -c '%F %a %U:%G %n' /opt/arc-demo
# Expected: directory 755 root:root /opt/arc-demo
sudo chmod 0700 /opt/arc-demo
sudo stat -c '%F %a %U:%G %n' /opt/arc-demo
```

Wait for an agent evaluation cycle, then repeat `stat`: the mode should return
to `755`. The portal may not show the brief non-compliant state before repair.
Inspect the assignment's latest report or `/var/lib/GuestConfig/` logs if it does
not converge. Do not use a fixed short wait as proof of success.

## Cleanup

Remove the assignment first so it cannot recreate or repair the directory:

```powershell
$assignmentId = "$machineId/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/ArcAnsibleDirectoryDemo"
az rest --method delete --url "https://management.azure.com${assignmentId}?api-version=2022-01-25"
```

After confirming deletion, optionally run `sudo rmdir /opt/arc-demo` on the node.
`rmdir` leaves a nonempty directory alone. Delete the uploaded demo blob when no
longer needed. Removing an assignment does not undo previously applied settings.

## References and validation status

- [Microsoft: custom packages and third-party tool integration](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/develop-custom-package/2-create-package)
- [Microsoft: Ubuntu authoring prerequisites](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/develop-custom-package/1-set-up-authoring-environment)
- [Microsoft: package testing and remediation](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/develop-custom-package/3-test-package)
- [Microsoft: assignments for Arc resources](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to/assign-configuration/rest-api)
- [Microsoft: Connected Machine agent components](https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview)

Validated on October 21, 2026:

- MOF compilation and `AuditAndSet` ZIP generation on Ubuntu 24.04 with PowerShell
  7.6.7, PSDesiredStateConfiguration 3.0.0-beta1, and GuestConfiguration.
- ZIP inspection confirmed the Ansible playbook is bundled with its module.
- DSC discovery and resource checks passed using the Arc agent's bundled
  PowerShell on Azure Linux 3.0: missing directory, correct mode/ownership,
  permission drift, symlink rejection, and rejection of unrelated paths.
- Package publication succeeded over a private endpoint using managed identity.
- The live `ApplyAndAutoCorrect` assignment on an Azure Linux 3.0 Arc node
  completed its first configuration run and reported **Compliant** to Azure.

These checks are separate from the live agent's compliance report; check the
assignment and on-disk state before presenting the live demo.
