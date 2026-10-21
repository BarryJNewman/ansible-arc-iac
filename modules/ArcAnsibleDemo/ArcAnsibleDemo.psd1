@{
    RootModule = 'ArcAnsibleDemo.psm1'
    ModuleVersion = '1.0.0'
    GUID = '609aa180-5995-4806-a237-62f414adef6b'
    Author = 'Arc demo'
    PowerShellVersion = '7.2'
    DscResourcesToExport = @('ArcDemoDirectory')
    # Force module analysis so Get-Module -ListAvailable discovers the DSC class.
    # This module defines no functions, so the wildcard exports no functions.
    FunctionsToExport = @('*')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
