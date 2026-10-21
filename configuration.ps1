Configuration ArcAnsibleDirectoryDemo {
    Import-DscResource -ModuleName ArcAnsibleDemo -ModuleVersion '1.0.0'
    Node localhost {
        ArcDemoDirectory DemoDirectory {
            Path = '/opt/arc-demo'
        }
    }
}
