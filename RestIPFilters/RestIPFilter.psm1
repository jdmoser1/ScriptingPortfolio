#region Notes
<#
    Version: 2024.02.06
    This is the first release. Changes and bug fixes will be listed here.
    Known Issues
        * Procedural add/removal of multiple entries causes a failure. For now you must make one add and/or one
            remove at a time
        * Authtoken is not automatically refreshed. If you retain an Authtoken, it will expire after 10 minutes
        * INFO messages returned IPs on one line. I'd like them to have a new line per IP
        * No timer for verbose output
#>
#endregion Notes

#region Classes
# enum Method {
#     Get
#     Post
#     Put
# }

class VIFAuthRequest {
    [pscredential]$Credential
    [string]$Token
    # [timespan]$TokenAge
    VIFAuthRequest(){}
}

class VIFCustomer {
    [string]$IdCode
    [string]$Name
    [string]$Domain
    [guid]$Id
    VIFCustomer() {
    }
}

class VIFIPv4Address {
    [ipaddress]$IPv4Address
    [byte]$CIDR
    [string] ToCIDRNotation() {Return $this.IPv4Address.IPAddressToString + '/' + $this.CIDR}
    VIFIPv4Address() {}
    VIFIPv4Address($IPv4Address,$CIDR) {
        $this.IPv4Address = $IPv4Address
        $this.CIDR = $CIDR
    }
}

class VIFObject {
    [PSCustomObject]$Environment
    [VIFAuthRequest]$AuthRequest
    [VIFCustomer]$Customer
    [System.Collections.ArrayList]$IPAddressList
    VIFObject() {
        $this.AuthRequest   =   [VIFAuthRequest]@{}
        $this.Customer      =   [VIFCustomer]@{}
    }
    VIFObject($Environment,$IdCode,$Domain) {
        $this.Environment   =   $Environment
        $this.AuthRequest       =   [VIFAuthRequest]@{}
        $this.Customer          =   [VIFCustomer]@{IdCode=$IdCode;Domain=$Domain}
    }
}
#endregion Classes

#region Module Configurations
$Script:VIFModuleConfig = (
    Get-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath 'RestIPFilter.json') | Get-Content -Raw | 
        ConvertFrom-Json 
)
$Script:VIFLastParameters = @{}
$Script:ErrorActionPreference = 'Stop'
#endregion Module Configurations

#region Support Functions
function Write-VIFVerbose {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)][string]$Message
        , [Parameter(Position=1)][System.Diagnostics.Stopwatch]$Timer
    )
    begin {
        $ErrorActionPreference = 'Stop'
        if (-not $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.Get("VerbosePreference").Value
        }
    }
    # end {}
    process {
        try {
            if ($Timer) {
                $TimeString = [math]::Round(($Timer).Elapsed.TotalSeconds,2)
            }
            Write-Verbose -Message ((Get-PSCallStack)[1].Command + "`t" + $TimeString + "`t" + $Message)
        } catch {
            Write-VIFError -ErrorRecord $PSItem
        }
    }
}

function Write-VIFError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
        , $OutObject
    )
    # begin {}
    # end {}
    process {
        if ($ErrorRecord.Exception.GetType().FullName -eq 'System.Net.WebException') {
            switch -wildcard ($ErrorRecord.Exception.Message) {
                '*Unable to connect*' {  
                    Write-Warning -Message 'Unable to connect to server. Confirm Internet connection and VPN.'
                    $b=$true
                }
                '*(401) Unauthorized*' {  
                    Write-Warning -Message 'Received an authentication error. Possible causes:'
                    Write-Warning -Message "`t* Bad username or password"
                    Write-Warning -Message "`t* Authorization token timed out"
                    Write-Warning -Message "`t* Unauthorized to complete action"
                    Write-Warning -Message "`t* Token for one customer used for other customer"
                    $b=$true
                }
                '*(400) Bad Request*' {
                    Write-Warning -Message 'Received a response "Bad Request". Review your entries before trying again'
                    $b=$true
                }
                '*(404) Not Found*' {
                    Write-Warning -Message 'Received a response "Not Found". Does the customer exist on this environment?'
                    $b=$true
                }
                '*(500) Internal Server Error*' {
                    Write-Warning -Message 'Server returned "Internal Error." Try again. If the issue '
                    Write-Warning -Message "`tcontinues, contact the responsible parties for the server."
                    $b=$true
                }
                # Default {}
            }
        }
        if (-not $b) {
            Write-Host -ForegroundColor Red -Object ("ERROR:`t" + $ErrorRecord.Exception.Message)
            if ($ErrorRecord.TargetObject) {
                Write-Host -ForegroundColor Yellow -Object ("OBJECT:`t" + $ErrorRecord.TargetObject)
            }
            Write-Host -ForegroundColor Yellow -Object ("TRACE:`n" + $ErrorRecord.ScriptStackTrace)
            Write-Host -ForegroundColor Yellow -Object ("TYPE:`t" + $ErrorRecord.Exception.GetType().FullName)
            if ($OutObject) {
                Write-Verbose -Message 'Object detail:'
                Write-Verbose -Message ($OutObject | Format-Custom | Out-String)
            }
        }
    }
}

function Write-VIFCustomerInfo {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)][string]$IdCode
        , [Parameter(ValueFromPipelineByPropertyName)][string]$Name
        , [Parameter(ValueFromPipelineByPropertyName)][string]$Id
    )
    # begin {}
    # end {}    
    process {
        Write-Host -ForegroundColor Cyan -Object "INFO:`t$IdCode`t`t$Name`t`t$Id"
    }
}

function Read-VIFValue {
    [CmdletBinding()]
    param (
        [string]$Name
        , [System.Collections.ArrayList]$OptionList
    )
    # begin {}
    # end {}    
    process {
        try {
            if ($OptionList) {
                Write-Host -ForegroundColor Cyan -Object "INFO:`tOptions Available:`n`t  $OptionList"
            }
            Write-Host -ForegroundColor Cyan -NoNewline -Object "PROMPT:`tEnter value for $Name" 
            Read-Host -Prompt '?'
            Write-VIFVerbose -Message "Value for $Name from asking"
        } catch {
            Write-VIFError -ErrorRecord $PSItem
        }
    }
}

function Read-VIFEnvironment {
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}
    process {
        $VIFModuleConfig.Environments | Select-Object -Property Name | Out-GridView -PassThru
    }
}

function Read-VIFIPAddressList {
    [CmdletBinding()]
    param ()
    begin {
        Write-Host -ForegroundColor Cyan -Object (
            "INFO:`tA list of IPs is required for this command. Please enter them one line at at time." 
        )
    }
    # end {}    
    process {
        try {
            [System.Collections.ArrayList]$IpAddressList = @()
            $LastEntry = $true
            while ($LastEntry) {
                Write-Host -ForegroundColor Cyan -NoNewline -Object (
                    "PROMPT:`tEnter an IP Address, or IP with CIDR (e.g 10.0.0.0/24). Leave blank to end list" 
                )
                $LastEntry = Read-Host -Prompt '?'
                if ($LastEntry) {
                    $IpAddressList += $LastEntry
                }
            }
            $IpAddressList
        } catch {
            Write-VIFError -ErrorRecord $PSItem
        }
    }
}


function New-VIFIpObject {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)][string]$IPAddressString
    )
    # begin {}
    # end {}    
    process {
        try {
            New-Object -TypeName VIFIPv4Address -ArgumentList ($IPAddressString -split '/')
            Write-VIFVerbose -Message "Output IP object"
        }
        catch [System.Management.Automation.MethodException] {
            try {
                New-Object -TypeName VIFIPv4Address -ArgumentList ($IPAddressString,32)
                Write-VIFVerbose -Message "Output IP object"
            }
            catch [System.Management.Automation.MethodInvocationException] {
                Write-VIFVerbose -Message "IP seems to be missing. Skipping this entry"
            }
        }
        catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $IPAddressString
        }
    }
}

function Remove-VIFIpAddressEntry {
    [CmdletBinding()]
    param (
        [string[]]$IPRemoveList
        , [Parameter(ValueFromPipeline)]$VIFIPv4Address
    )
    # begin {}
    # end {}
    process {
        if (-not $IPRemoveList) {
            $VIFIPv4Address
            Write-VIFVerbose -Message 'Nothing in the remove list'
        } elseif ($IPRemoveList -notmatch '[0-9]{1}') {
            $VIFIPv4Address
            Write-Warning -Message 'Full wildcard deletion is not allowed. (e.g. "*", "*.*.*.*")'
        } else {
            $IPRemoveList | ForEach-Object -Process {
                $CurrentIP = ($_ -split '/')[0]
                if ($VIFIPv4Address.IPv4Address.IPAddressToString -like $CurrentIP) {
                    Write-VIFVerbose -Message (
                        $VIFIPv4Address.IPv4Address.IPAddressToString + ' matched, discarding'
                    )
                } else {
                    $VIFIPv4Address
                    Write-VIFVerbose -Message (
                        $VIFIPv4Address.IPv4Address.IPAddressToString + ' not matched, keeping'
                    )
                }
            }
        }
    }
}
#endregion Support Functions

#region Public Functions
function Enable-VIFVerbose {
    <#
    .DESCRIPTION
        Enable verbose messages for all RestIPFilters cmdlets during current module usage. These will provide 
        more detail, and may assist with troubleshooting.
    .NOTES
        Messages can be disabled by reloading the module with the -Force parameter
    .OUTPUTS
        Messages to the host
    .EXAMPLE
        PS> Enable-VIFVerbose
        Enable verbose messages
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}    
    process {
        $Script:VerbosePreference = 'Continue'
        Write-VIFVerbose -Message 'Enabled verbose output for this module'
    }
}
Set-Alias -Name evv -Value Enable-VIFVerbose

function Get-VIFModuleConfig {
    <#
    .DESCRIPTION
        Output the RestIPFilter configuration object. This is the same information as the .json file that is 
        included with the module. Useful to see the configuration for troubleshooting
    .OUTPUTS
        Messages to the host
    .EXAMPLE
        PS> Get-VIFModuleConfig | Format-Custom
        Output the configuration object to the console
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}    
    process {
        Write-Host -ForegroundColor Cyan -Object "INFO:`tModule Config"
        $VIFModuleConfig
        Write-VIFVerbose -Message 'Output Config objects'
    }

}

function Get-VIFLastParameters {
    <#
    .DESCRIPTION
        Output the last parameters used by the web request action. Useful for troubleshooting
    .OUTPUTS
        Messages to the host
    .EXAMPLE
        PS> Get-VIFLastParameters | Format-Custom
        Output the parameters object to the console
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}    
    process {
        Write-Host -ForegroundColor Cyan -Object "INFO:`tLast Parameters"
        $VIFLastParameters
        Write-VIFVerbose -Message 'Output Config objects'
    }

}

function New-VIFObject {
    <#
    .SYNOPSIS
        Creates a new RestIPFilter object
    .DESCRIPTION
        New-VIFObject creates a new object that is specifically formated for use with other cmdlets in the 
        RestIPFilter module. Many cmdlets are able to accept input from the pipeline, but they require a
        VIFObject as an input.
    .NOTES
        When a VIFObject is created, an empty VIFAuthRequest object is added to the AuthRequest property, and an
        empty VIFCustomer object is added to the Customer property. The properties of these objects can then be 
        populated as the object moves through the pipe
    .OUTPUTS
        VIFObject
    .EXAMPLE
        PS> New-VIFObject -EnvironmentName Test -IdCode xzy  | New-VIFAuthToken -Credential $Credential
        Outputs the new VIFObject with the IdCode "xzy" metadata related to the environment "Test". The object
        is then used by the New-VIFAuthToken cmdlet to generate an authorization token
    #>
    [CmdletBinding()]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ValueFromPipelineByPropertyName,Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered, and you aren't using a reference, you will be 
        # prompted for it.
        [Parameter(ValueFromPipelineByPropertyName,Position=1)][string]$IdCode 
        , # Specifies that a reference IdCode be used from the module config file. This must only be used for
        # retrieving the list of customers (see Get-VIFCustomerList)
        [Parameter(Position=2)][switch]$UseReferenceIdCode
    )
    # begin {}
    # end {}
    process {
        try {
            if (-not $EnvironmentName) {
                $EnvironmentParameters = @{
                    Name        =   'EnvironmentName'
                    OptionList  =   $VIFModuleConfig.Environments.Name
                }
                $EnvironmentName = Read-VIFValue @EnvironmentParameters
            }
            $Environment = (
                $VIFModuleConfig.Environments | Where-Object -Property Name -EQ -Value $EnvironmentName |
                    Select-Object -First 1
            )
            if ($UseReferenceIdCode) {
                $IdCode = $Environment.ReferenceIdCode
            } elseif (-not $IdCode) {
                $IdCode = Read-VIFValue -Name IdCode
            }
            $CustomerDomain = $VIFModuleConfig.Defaults.DomainTemplate.Replace('DOMAIN',$Environment.Domain)
            $CustomerDomain = $CustomerDomain.Replace('IdCode',$IdCode)
            New-Object -TypeName VIFObject -ArgumentList $Environment,$IdCode,$CustomerDomain
            Write-VIFVerbose -Message "New VIFObject for $IdCode on $EnvironmentName"
        }
        catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $EnvironmentName,$IdCode
        }
    }
}
Set-Alias -Name nvo -Value New-VIFObject

function New-VIFAuthToken {
    <#
    .SYNOPSIS
        Generates a new authorization token.
    .DESCRIPTION
        New-VIFAuthToken requests a new authorization token from the Rest API address. This has the same affect
        as completing a login and temporarily having access to view and change IP ACLs. The token will be 
        attached to a VIFObject, and then can be passed to other cmdlets from the RestIPFilter module to 
        complete various tasks. 
    .NOTES
        Guided mode is supported, meaning that this cmdlet doesn't reqiure a VIFOpbject to be piped in. 
    .OUTPUTS
        VIFObject
    .EXAMPLE
        PS> New-VIFObject -EnvironmentName Test -IdCode xzy  | New-VIFAuthToken -Credential $Credential
        Outputs the new VIFObject for the environment and IdCode, with an authorization token
    .EXAMPLE
        PS> New-VIFAuthToken -EnvironmentName Test -IdCode xzy -Credential $Credential
        Also outputs a VIFObject with a athorization token
    .EXAMPLE
        PS> New-VIFAuthToken
        Outputs a VIFObject, but you'll be asked to provide all required information
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Credential (username and password) for Rest. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(Position=2)][pscredential]$Credential 
        , # Specifies VIFObject objects representing Rest customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=3,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                $VIFObject = New-VIFObject -EnvironmentName $EnvironmentName -IdCode $IdCode
                Write-VIFVerbose -Message "Created VIF object"
            }
        }
        catch {
            Write-VIFError -ErrorRecord $PSItem
        }
    }
    # end {}
    process {
        try {
            if ($Credential) {
                $VIFObject.AuthRequest.Credential = $Credential
            }
            if (-not $VIFObject.AuthRequest.Credential) {
                $VIFObject.AuthRequest.Credential = Get-Credential -Message (
                    'Please enter your credentials for ' + $VIFObject.Customer.IdCode + 
                        ' on ' + $VIFObject.Environment.Name
                )
            }
            $BTSR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                $VIFObject.AuthRequest.Credential.Password
            )
            $BaseUri = $VIFModuleConfig.Auth.UriTemplate.Replace('DOMAIN',$VIFObject.Environment.Domain)
            Write-VIFVerbose -Message (
                'Prepared credentials for ' + $VIFObject.AuthRequest.Credential.UserName
            )
            $Script:VIFLastParameters = @{
                Uri     =   $BaseUri.Replace('IdCode',$VIFObject.Customer.IdCode)
                Method  =   $VIFModuleConfig.Auth.Method
                Body    =   @{
                    grant_type  =   $VIFModuleConfig.Auth.GrantType
                    client_id   =   $VIFModuleConfig.Auth.ClientId
                    username    =   $VIFObject.AuthRequest.Credential.UserName
                    password    =   [Runtime.InteropServices.Marshal]::PtrToStringAuto($BTSR)
                }
            }
            $VIFObject.AuthRequest.Token = (
                Invoke-WebRequest @VIFLastParameters | Select-Object -ExpandProperty Content | 
                    ConvertFrom-Json | Select-Object -ExpandProperty $VIFModuleConfig.Auth.ResultField
            )
            $VIFObject
            Write-VIFVerbose -Message (
                'Received authorization token for ' + $VIFObject.AuthRequest.Credential.UserName
            )
        } catch {
            $VIFLastParameters.Body.password = '(REDACTED)'
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
}
Set-Alias -Name nvat -Value New-VIFAuthToken

function Get-VIFCustomerList {
    <#
    .SYNOPSIS
        Gets a list of Rest customers 
    .DESCRIPTION
        Get-VIFCustomerList gets a list of Custom Software customers with names, IdCodes, and IDs from the requested
        environment. Optionally, a GUI window can be generated which allows the user to select one customer. 
    .NOTES
        Get-VIFCustomerList requires an authentication token against any IdCode in the Custom Software environment. 
        If ShowWindow is not specified, Get-VIFCustomerList sends the entire list to the host. If you need
        a CustomerID for a specific customer, use Find-VIFCustomerInfo
    .OUTPUTS
        Messages to the host or optional VIFObject
    .EXAMPLE
        PS> New-VIFObject -EnvironmentName Test -UseReferenceIdCode | New-VIFAuthToken -Credential $Credential | Get-VIFCustomerList -ShowWindow
        Get a list of all customers in the Test environment. This example uses pipelining, and 
        uses a reference IdCode that's known for the environment. The list will be presented in a new window.
    .EXAMPLE
        PS> Get-VIFCustomerList -EnvironmentName Test -IdCode xzy -Credential (Get-Credential)
        Get a list of all customers in the Test environment, like above. Customer "xzy" is used for reference
    .EXAMPLE
        PS> Get-VIFCustomerList
        Get a list of customers, but you'll be asked to provide all required information
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(ParameterSetName='Guided',Position=2)][pscredential]$Credential 
        , # Parameter help description
        [Parameter(Position=3)][switch]$ShowWindow
        , # Specifies VIFObject objects representing Custom Software customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=4,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                $AuthTokenParameters = @{
                    EnvironmentName =   $EnvironmentName 
                    IdCode        =   $IdCode
                    Credential      =   $Credential 
                }
                $VIFObject = New-VIFAuthToken @AuthTokenParameters
                Write-VIFVerbose -Message ('Created VIFObject and received Token')
            }
        }
        catch {
            Write-VIFError -ErrorRecord $PSItem
        }
    }
    # end {}
    process {
        try {
            $Script:VIFLastParameters = @{
                Uri = $VIFModuleConfig.CustomerList.UriTemplate.Replace('DOMAIN',$VIFObject.Environment.Domain)
                Method = $VIFModuleConfig.CustomerList.Method
                Headers = @{
                    accept                  =   $VIFModuleConfig.Defaults.Accept
                    'iii-customer-domain'   =   $VIFObject.Customer.Domain
                    'api-version'           =   $VIFModuleConfig.Defaults.Version
                    Authorization           =   'Bearer ' + $VIFObject.AuthRequest.Token
                }  
                Body = @{
                    page    =   $VIFModuleConfig.CustomerList.Page
                    size    =   $VIFModuleConfig.CustomerList.Size
                    sort    =   $VIFModuleConfig.CustomerList.Sort
                }
            }
            $CustomerList = (
                Invoke-RestMethod @VIFLastParameters | Select-Object -ExpandProperty items | 
                    Select-Object -Property IdCode,Name,Id | Sort-Object -Property IdCode
            )
            if ($ShowWindow) {
                $VIFObject.Customer = (
                    $CustomerList | Out-GridView -PassThru -Title 'Select one customer' | Select-Object -First 1
                )
                $VIFObject.Customer | Write-VIFCustomerInfo 
                $VIFObject
            } else {
                $CustomerList | Write-VIFCustomerInfo 
            }
            Write-VIFVerbose -Message ('Enumerated customer list for ' + $VIFObject.Environment.Name)
        } catch [System.Management.Automation.ParameterBindingException] {
            Write-Warning -Message 'No customer selected.'
        } catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
}
Set-Alias -Name gvcl -Value Get-VIFCustomerList

function Find-VIFCustomerInfo {
    <#
    .SYNOPSIS
        Find the Custom Software ID for a customer
    .DESCRIPTION
        Find the Custom Software ID and name for a customer from the given environment. This information will be attached
        to a VIFObject
    .OUTPUTS
        VIFObject
    .EXAMPLE
        PS> New-VIFAuthToken -EnvironmentName Test -IdCode xzy -Credential $Credential | Find-VIFCustomerInfo
        Outputs a VIFObject with information for customer xzy, in pipeline mode
    .EXAMPLE
        PS> Find-VIFCustomerInfo -EnvironmentName Test -IdCode xzy -Credential (Get-Credential)
        Outputs a VIFObject with information for customer xzy like above. 
    .EXAMPLE
        PS> Find-VIFCustomerInfo
        Outputs a VIFObject, but you'll be asked to provide all required information
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(ParameterSetName='Guided',Position=2)][pscredential]$Credential 
        , # Specifies VIFObject objects representing Custom Software customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=3,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                $AuthTokenParameters = @{
                    EnvironmentName =   $EnvironmentName 
                    IdCode        =   $IdCode
                    Credential      =   $Credential 
                }
                $VIFObject = New-VIFAuthToken @AuthTokenParameters
                Write-VIFVerbose -Message ('Created VIFObject and received Token')
            }
        }
        catch {
            Write-CustomError -ErrorRecord $PSItem
        }
    }
    # end {}
    process {
        try {
            $Script:VIFLastParameters = @{
                Uri = $VIFModuleConfig.FindCustomer.UriTemplate.Replace('DOMAIN',$VIFObject.Environment.Domain)
                Method = $VIFModuleConfig.FindCustomer.Method
                Headers = @{
                    accept                  =   $VIFModuleConfig.Defaults.Accept
                    'iii-customer-domain'   =   $VIFObject.Customer.Domain
                    'api-version'           =   $VIFModuleConfig.Defaults.Version
                    Authorization           =   'Bearer ' + $VIFObject.AuthRequest.Token
                }
                Body = @{
                    IdCode = $VIFObject.Customer.IdCode
                }
            }
            $CurrentCustomer = Invoke-RestMethod @VIFLastParameters
            $VIFObject.Customer.IdCode = $CurrentCustomer.IdCode
            $VIFObject.Customer.Name = $CurrentCustomer.Name
            $VIFObject.Customer.Id = $CurrentCustomer.Id
            $VIFObject
            Write-VIFVerbose -Message ('Found details for Customer ' + $VIFObject.Customer.Name)
        } catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
}
New-Alias -Name Get-VIFCustomerInfo -Value Find-VIFCustomerInfo
New-Alias -Name Get-VIFCustomerInfo -Value fvci

function Get-VIFIpAddressList {
    <#
    .SYNOPSIS
        Gets the IP address list for a customer
    .DESCRIPTION
        Gets the existing IP address list, in Custom Software, for a customer in a given environment. This is then added to
        a VIFObject
    .OUTPUTS
        VIFObject
    .EXAMPLE
        PS> New-VIFAuthToken -EnvironmentName Test -IdCode xzy -Credential $Credential | Find-VIFCustomerInfo | Get-VIFIpAddressList
        Outputs a VIFObject with IP address list customer xzy, using the pipeline
    .EXAMPLE
        PS> Get-VIFIpAddressList -EnvironmentName Test -IdCode xzy -Credential (Get-Credential)
        Outputs a VIFObject with information for customer xzy like above. 
    .EXAMPLE
        PS> Get-VIFIpAddressList
        Outputs a VIFObject, but you'll be asked to provide all required information
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specify the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specify the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Specify the Customer ID. It's generally better to let the cmdlet get this for you, but you may 
        # provide it if you have it, to improve efficiency slightly
        [Parameter(ParameterSetName='Guided',Position=2)][guid]$CustomerId = ('0'*32)
        , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(ParameterSetName='Guided',Position=3)][pscredential]$Credential 
        , # Write the IPList to the host window
        [Parameter(Position=4)][switch]$ShowIPList
        , # Specify VIFObject objects representing Custom Software customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=5,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                if ($CustomerId -ne ('0'*32)) {
                    $AuthTokenParameters = @{
                        EnvironmentName =   $EnvironmentName 
                        IdCode        =   $IdCode
                        Credential      =   $Credential 
                    }
                    $VIFObject = New-VIFAuthToken @AuthTokenParameters
                    $VIFObject.Customer.Id = $CustomerId
                } else { 
                    $VifObjectParameters = @{
                        EnvironmentName =   $EnvironmentName 
                        IdCode        =   $IdCode
                        Credential      =   $Credential 
                    }
                    $VIFObject = Find-VIFCustomerInfo @VifObjectParameters
                }
                Write-VIFVerbose -Message ('Created VIFObject and received CustomerInfo')
            }
        }
        catch {
            Write-CustomError -ErrorRecord $PSItem
        }
    }
    # end {}
    process {
        try {
            if ($VIFObject.Customer.Id -eq ('0'*32)) {
                $VIFObject = Find-VIFCustomerInfo -VIFObject $VIFObject
            }
            $BaseUri = $VIFModuleConfig.IpList.UriTemplate.Replace('DOMAIN',$VIFObject.Environment.Domain)
            $Script:VIFLastParameters = @{
                Uri = $BaseUri.Replace('CUSTID',$VIFObject.Customer.Id)
                Method = $VIFModuleConfig.IpList.Method
                Headers = @{
                    accept                  =   $VIFModuleConfig.Defaults.Accept
                    'iii-customer-domain'   =   $VIFObject.Customer.Domain
                    'api-version'           =   $VIFModuleConfig.Defaults.Version
                    Authorization           =   'Bearer ' + $VIFObject.AuthRequest.Token
                }
                Body = @{
                    IdCode = $VIFObject.Customer.IdCode
                }
            }
            $VIFObject.IPAddressList = [System.Collections.ArrayList]@()
            $VIFObject.IPAddressList += ((Invoke-RestMethod @VIFLastParameters).ips | New-VIFIpObject)
            if ($ShowIPList) {
                $WriteIPListParameters = @{
                    ForegroundColor =   'Cyan' 
                    Object          =   "INFO:`tCurrent IP List: " + $VIFObject.IPAddressList.ToCIDRNotation()
                }
                Write-Host @WriteIPListParameters
            }
            $VIFObject
            Write-VIFVerbose -Message ('Received received IP list for ' + $VIFObject.Customer.IdCode)
        } catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
}
Set-Alias -Name Get-VIFIpAddress -Value Get-VIFIpAddressList 
Set-Alias -Name gvil -Value Get-VIFIpAddressList 

function Set-VIFIpAddressList {
    <#
    .SYNOPSIS
        Sets the IP address list for a customer
    .DESCRIPTION
        Sets the existing IP address list, in Custom Software, for a customer in a given environment. This can be then 
        added to a VIFObject if PassThru is specified
    .NOTES
        This will completely replace the current IP list for the customer. Take care not to lose data.
    .OUTPUTS
        Messages to the host or a VIFObject
    .EXAMPLE
        PS> New-VIFAuthToken -EnvironmentName Test -IdCode xzy -Credential $Credential | Set-VIFIpAddressList -IPAddressList 10.0.0.1
        Set the IP address list for customer xzy, using the pipeline
    .EXAMPLE
        PS> Set-VIFIpAddressList -EnvironmentName Test -IdCode xzy -Credential (Get-Credential) -IPAddressList 10.0.0.1
        Set the IP address list for customer xzy like above. 
    .EXAMPLE
        PS> Set-VIFIpAddressList
        You'll be asked to provide all required information, and set the IP address list for a customer
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Specify the Customer ID. It's generally better to let the cmdlet get this for you, but you may 
        # provide it if you have it, to improve efficiency slightly
        [Parameter(ParameterSetName='Guided',Position=2)][guid]$CustomerId = ('0'*32)
        , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(ParameterSetName='Guided',Position=3)][pscredential]$Credential 
        , # New list of IPs to set for the cutomer
        [Parameter(Position=4)][string[]]$IpAddressList
        , # Do not ask for confirmation
        [Parameter(Position=5)][switch]$Force
        , # Output the resultant VIFObject
        [Parameter(Position=6)][switch]$PassThru
        , # Specifies VIFObject objects representing Custom Software customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=7,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                $IpListParameters = @{
                    EnvironmentName =   $EnvironmentName 
                    IdCode        =   $IdCode 
                    CustomerId      =   $CustomerId
                    Credential      =   $Credential
                }
                $VIFObject = Get-VIFIpAddressList @IpListParameters
                if (-not $IpAddressList) {
                    $IpAddressList = Read-VIFIPAddressList
                }
                Write-VIFVerbose -Message ('Created VIFObject and received CustomerInfo')
            }
        }
        catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
    # end {}
    process {
        try {
            $BaseUri = $VIFModuleConfig.SetIpList.UriTemplate.Replace('DOMAIN',$VIFObject.Environment.Domain)
            if ($IpAddressList) {
                $VIFObject.IPAddressList = ($IpAddressList | New-VIFIpObject)
            } 
            $Script:VIFLastParameters = @{
                Uri = $BaseUri.Replace('CUSTID',$VIFObject.Customer.Id)
                Method = $VIFModuleConfig.SetIPList.Method
                Headers = @{
                    accept                  =   $VIFModuleConfig.Defaults.Accept
                    'iii-customer-domain'   =   $VIFObject.Customer.Domain
                    'api-version'           =   $VIFModuleConfig.Defaults.Version
                    'Content-Type'          =   $VIFModuleConfig.SetIPList.ContentType
                    Authorization           =   'Bearer ' + $VIFObject.AuthRequest.Token
                }
                Body = @{ips=$VIFObject.IPAddressList.ToCidrNotation()} | ConvertTo-Json
            }
            Write-Warning -Message ('This action will overwrite the IP list for '+$VIFObject.Customer.IdCode)
            if (-not $Force) {
                Write-Host -ForegroundColor Cyan -NoNewline -Object "PROMPT:`tContinue (y or n [default n])"
                $OverwriteResponse = Read-Host -Prompt '?'
            }
            if ($Force -or ($OverwriteResponse -like 'y*')) {
                Invoke-RestMethod @VIFLastParameters > $null
                Write-VIFVerbose -Message 'Sent IP filter update'
                $VIFObject = Get-VIFIpAddressList -VIFObject $VIFObject
                Write-VIFVerbose -Message 'Requested actual info from the server'
                Write-Host -ForegroundColor Cyan -Object (
                    "INFO:`tIP filter update sent for " + $VIFObject.Customer.Name + 
                    ' (' + $VIFObject.Environment.Name + " " + $VIFObject.Customer.IdCode  + 
                    "). New IP List:`n`t" + $VIFObject.IPAddressList.ToCidrNotation()
                )
                if ($PassThru) {
                    $VIFObject
                }             
            }
            Write-VIFVerbose -Message 'See any output above for result.'
        } catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
}
New-Alias -Name Set-VIFIpAddress -Value Set-VIFIpAddressList
New-Alias -Name svil -Value Set-VIFIpAddressList

function Add-VIFIpAddressList {
    <#
    .SYNOPSIS
        Adds an IP address list for a customer
    .DESCRIPTION
        Adds an IP address list to the existing IP address list, in Custom Software, for a customer in a given environment.
        This can be then added to a VIFObject if PassThru is specified
    .NOTES
        The IPs in the existing list will be saved.
    .OUTPUTS
        Messages to the host or a VIFObject
    .EXAMPLE
        PS> New-VIFAuthToken -EnvironmentName Test -IdCode xzy -Credential $Credential | Add-VIFIpAddressList -IPAddressList 10.0.0.1
        Add an IP address list for customer xzy, using the pipeline
    .EXAMPLE
        PS> Add-VIFIpAddressList -EnvironmentName Test -IdCode xzy -Credential (Get-Credential) -IPAddressList 10.0.0.1
        Add an IP address list for customer xzy like above. 
    .EXAMPLE
        PS> Add-VIFIpAddressList
        You'll be asked to provide all required information, and add an IP address list for a customer
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Specify the Customer ID. It's generally better to let the cmdlet get this for you, but you may 
        # provide it if you have it, to improve efficiency slightly
        [Parameter(ParameterSetName='Guided',Position=2)][guid]$CustomerId = ('0'*32)
        , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(ParameterSetName='Guided',Position=3)][pscredential]$Credential 
        , # New list of IPs to add for the cutomer
        [Parameter(Position=4)][string[]]$IpAddressList
        , # Output the resultant VIFObject
        [Parameter(Position=5)][switch]$PassThru
        , # Specifies VIFObject objects representing Custom Software customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=6,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                $IpListParameters = @{
                    EnvironmentName =   $EnvironmentName 
                    IdCode        =   $IdCode 
                    CustomerId      =   $CustomerId
                    Credential      =   $Credential
                }
                $VIFObject = Get-VIFIpAddressList @IpListParameters
                Write-VIFVerbose -Message ('Created VIFObject and received CustomerInfo')
            }
        }
        catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
    # end {}
    process {
        try {
            if (-not $VIFObject.IPAddressList) {
                $VIFObject = Get-VIFIpAddressList -VIFObject $VIFObject
            }
            if (-not $IpAddressList) {
                Write-Host -ForegroundColor Cyan -Object "INFO:`tIPs to *ADD* for the customer"
                $IpAddressList = Read-VIFIPAddressList
            }
            $VIFObject.IPAddressList += ($IpAddressList | New-VIFIpObject)
            Set-VIFIpAddressList -VIFObject $VIFObject -Force
            if ($PassThru) {
                $VIFObject
            }
            Write-VIFVerbose -Message ('Added IP(s) for ' + $VIFObject.Customer.IdCode)
        } catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        }
    }
}
New-Alias -Name Add-VIFIpAddress -Value Add-VIFIpAddressList
New-Alias -Name avil -Value Add-VIFIpAddressList


function Remove-VIFIpAddressList {
    <#
    .SYNOPSIS
        Remove an IP address list for a customer
    .DESCRIPTION
        Remove an IP address list to the existing IP address list, in Custom Software, for a customer in a given environment.
        This can be then added to a VIFObject if PassThru is specified
    .NOTES
        This will remove IPs from the address list. Take care not to lose data
    .OUTPUTS
        Messages to the host or a VIFObject
    .EXAMPLE
        PS> New-VIFAuthToken -EnvironmentName Test -IdCode xzy -Credential $Credential | Remove-VIFIpAddressList -IPAddressList 10.0.0.1
        Remove an IP address list for customer xzy, using the pipeline
    .EXAMPLE
        PS> Remove-VIFIpAddressList -EnvironmentName Test -IdCode xzy -Credential (Get-Credential) -IPAddressList 10.0.0.1
        Remove an IP address list for customer xzy like above. 
    .EXAMPLE
        PS> Remove-VIFIpAddressList
        You'll be asked to provide all required information, and remove an IP address list for a customer
    #>
    [CmdletBinding(DefaultParameterSetName='Guided')]
    param (
        # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
        # entered, you will be prompted for it.
        [Parameter(ParameterSetName='Guided',Position=0)][string]$EnvironmentName 
        , # Specifies the customer IdCode. If not entered you will be prompted for it
        [Parameter(ParameterSetName='Guided',Position=1)][string]$IdCode 
        , # Specify the Customer ID. It's generally better to let the cmdlet get this for you, but you may 
        # provide it if you have it, to improve efficiency slightly
        [Parameter(ParameterSetName='Guided',Position=2)][guid]$CustomerId = ('0'*32)
        , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
        # Clarivate credentials. If not entered you will be prompted for them.
        [Parameter(ParameterSetName='Guided',Position=3)][pscredential]$Credential 
        , # New list of IPs to remove from the cutomer. 
        [Parameter(Position=4)][string[]]$IpAddressList
        , # Do not ask for confirmation
        [Parameter(Position=5)][switch]$Force
        , # Output the resultant VIFObject
        [Parameter(Position=6)][switch]$PassThru
        , # Specifies VIFObject objects representing Custom Software customers. Enter a variable that contains the objects, 
        # or type a command or expression that gets the objects. You can pipe a VIFobject to this cmdlet.
        [Parameter(ParameterSetName='InputObject',Position=7,ValueFromPipeline)]$VIFObject
    )
    begin {
        try {
            Write-VIFVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
            if ($PSCmdlet.ParameterSetName -eq 'Guided') {
                $IpListParameters = @{
                    EnvironmentName =   $EnvironmentName 
                    IdCode        =   $IdCode 
                    CustomerId      =   $CustomerId
                    Credential      =   $Credential
                }
                $VIFObject = Get-VIFIpAddressList @IpListParameters
                Write-VIFVerbose -Message ('Created VIFObject and received CustomerInfo')
            }
        }
        catch {
            Write-CustomError -ErrorRecord $PSItem
        }
    }
    # end {}
    process {
        try {
            if (-not $VIFObject.IPAddressList) {
                $VIFObject = Get-VIFIpAddressList -VIFObject $VIFObject
            }
            if (-not $IpAddressList) {
                Write-Host -ForegroundColor Cyan -Object "INFO:`tIPs to *REMOVE* for the customer"
                $IpAddressList = Read-VIFIPAddressList
            }
            $VIFObject.IPAddressList = (
                $VIFObject.IPAddressList | Remove-VIFIpAddressEntry -IPRemoveList $IpAddressList 
            )
            Set-VIFIpAddress -VIFObject $VIFObject -Force:$Force
            if ($PassThru) {
                $VIFObject
            }
            Write-VIFVerbose -Message ('Added IP(s) for ' + $VIFObject.Customer.IdCode)
        } catch {
            Write-VIFError -ErrorRecord $PSItem -OutObject $VIFLastParameters
        } 
    }
}
New-Alias -Name  Remove-VIFIpAddress -Value Remove-VIFIpAddressList
New-Alias -Name  rvil -Value Remove-VIFIpAddressList
#endregion Public Functions
