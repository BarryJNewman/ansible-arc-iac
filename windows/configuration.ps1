Configuration ArcWindowsDirectoryDemo {
    Import-DscResource -ModuleName ArcWindowsDemo -ModuleVersion '1.0.0'
    Node localhost {
        ArcWindowsDirectory DemoDirectory {
            Path = 'C:\ArcDemo'
        }
    }
}
