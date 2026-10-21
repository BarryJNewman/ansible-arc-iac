[DscResource()]
class ArcDemoDirectory {
    [DscProperty(Key)]
    [string] $Path

    [DscProperty(NotConfigurable)]
    [string] $CurrentState

    [string] ReadState() {
        # GNU stat does not follow symlinks by default. A symlink is not compliant.
        $output = & /usr/bin/stat -c '%f|%a|%u|%g' -- $this.Path 2>$null
        if ($LASTEXITCODE -ne 0) { return 'Missing or inaccessible' }
        $parts = (($output -join '').Trim()).Split('|')
        if ($parts.Count -ne 4) { throw 'Unexpected output from GNU stat.' }
        $type = [Convert]::ToInt32($parts[0], 16) -band 0xF000
        if ($type -ne 0x4000) { return 'Not a directory (or a symbolic link)' }
        return 'directory|' + ($parts[1..3] -join '|')
    }

    [ArcDemoDirectory] Get() {
        $result = [ArcDemoDirectory]::new()
        $result.Path = $this.Path
        $result.CurrentState = $this.ReadState()
        return $result
    }

    [bool] Test() {
        return $this.ReadState() -ceq 'directory|755|0|0'
    }

    [void] Set() {
        # This deliberately small demo manages only this one path.
        if ($this.Path -cne '/opt/arc-demo') {
            throw 'This demo only supports /opt/arc-demo.'
        }
        if (-not (Test-Path -LiteralPath '/usr/bin/ansible-playbook' -PathType Leaf)) {
            throw 'Install ansible-core on the Arc node; /usr/bin/ansible-playbook is required.'
        }
        $playbook = Join-Path $PSScriptRoot 'ensure-directory.yml'
        $output = & /usr/bin/ansible-playbook -i 'localhost,' -c local $playbook 2>&1
        $exitCode = $LASTEXITCODE
        Write-Verbose ($output -join "`n")
        if ($exitCode -ne 0) {
            throw "Ansible failed (exit $exitCode): $($output -join "`n")"
        }
        if (-not $this.Test()) {
            throw 'Ansible completed but the directory is still non-compliant.'
        }
    }
}
