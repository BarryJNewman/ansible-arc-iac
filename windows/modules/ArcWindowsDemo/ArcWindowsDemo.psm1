[DscResource()]
class ArcWindowsDirectory {
    [DscProperty(Key)]
    [string] $Path

    [DscProperty(NotConfigurable)]
    [string] $CurrentState

    [System.Security.AccessControl.DirectorySecurity] DesiredAcl() {
        $acl = [System.Security.AccessControl.DirectorySecurity]::new()
        # Protected DACL; inheritable rules use well-known SIDs for all locales.
        # SYSTEM and Administrators: FullControl. Users: ReadAndExecute.
        $acl.SetSecurityDescriptorSddlForm(
            'D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)',
            [System.Security.AccessControl.AccessControlSections]::Access)
        return $acl
    }

    [string] ReadState() {
        if (-not (Test-Path -LiteralPath $this.Path)) { return 'Missing' }
        $item = Get-Item -LiteralPath $this.Path -Force
        if (-not $item.PSIsContainer -or
            ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            return 'Not a regular directory'
        }
        $acl = Get-Acl -LiteralPath $this.Path -ErrorAction Stop
        return $acl.GetSecurityDescriptorSddlForm(
            [System.Security.AccessControl.AccessControlSections]::Access)
    }

    [ArcWindowsDirectory] Get() {
        $result = [ArcWindowsDirectory]::new()
        $result.Path = $this.Path
        $result.CurrentState = $this.ReadState()
        return $result
    }

    [bool] Test() {
        $expected = $this.DesiredAcl().GetSecurityDescriptorSddlForm(
            [System.Security.AccessControl.AccessControlSections]::Access)
        $current = $this.ReadState()
        if (-not $current.StartsWith('D:')) { return $false }
        # Windows can add AI/AR bookkeeping flags when writing an ACL. They
        # do not change access rules; retain the protected-DACL flag itself.
        $descriptor = [System.Security.AccessControl.RawSecurityDescriptor]::new($current)
        $ignored = [System.Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited -bor
            [System.Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInheritRequired
        $descriptor.SetFlags($descriptor.ControlFlags -band (-bnot $ignored))
        return $descriptor.GetSddlForm(
            [System.Security.AccessControl.AccessControlSections]::Access) -ceq $expected
    }

    [void] Set() {
        if ($this.Path -cne 'C:\ArcDemo') { throw 'This demo only supports C:\ArcDemo.' }
        if (Test-Path -LiteralPath $this.Path) {
            $item = Get-Item -LiteralPath $this.Path -Force
            if (-not $item.PSIsContainer -or
                ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Move the conflicting file or reparse point aside before running this demo.'
            }
        } else {
            $null = New-Item -Path $this.Path -ItemType Directory -ErrorAction Stop
        }
        Set-Acl -LiteralPath $this.Path -AclObject $this.DesiredAcl() -ErrorAction Stop
        if (-not $this.Test()) { throw 'Directory permissions remain non-compliant.' }
    }
}
