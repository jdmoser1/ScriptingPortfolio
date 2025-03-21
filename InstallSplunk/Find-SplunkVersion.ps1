[CmdletBinding()]
param (
    $SearchString = '*UniversalForwarder*'
)
process {
    [System.Collections.ArrayList]@(
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
    ) | Get-ChildItem -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction Stop |
        Where-Object -FilterScript {
            ($PSitem.PSChildName -like $SearchString) -or 
            ($PSitem.DisplayName -like $SearchString) 
        } | Select-Object -ExpandProperty DisplayVersion -First 1 | New-Variable -Name SplunkVersion
    [PSCustomObject]@{
        ComputerName    =   $env:COMPUTERNAME
        # Fqdn            =   ([System.Net.Dns]::GetHostByName(($env:computerName)).HostName)
        Fqdn            =   ($env:COMPUTERNAME + '.' + $env:USERDNSDOMAIN)
        SplunkInstalled =   [boolean]$SplunkVersion.count
        SplunkVersion   =   $SplunkVersion
    }
    Write-Verbose -Message "Completed search for $SearchString"
}
