#region Notes
<#
      ~,                            _    ___ ___ _____ ___ _  _ _ 
      ~~                           | |  |_ _/ __|_   _| __| \| | |
     :~~~                          | |__ | |\__ \ | | | _|| .` |_|
     :::~8                     /   |____|___|___/ |_| |___|_|\_(_)
     :,,::                    / __
      :,,,
        N,, :~=~,
         :+I7777$I+:                 =~~~~~:
        :?77I+++77$?~       O:::~~~~~~=~=~  
       ~I7?=:,,,:=I7I:,..........,,,,:
    ~~:~I7I=:,,,~+77I:   ....,.,,,,
    ~    =7$777777I=
          ~=?I7I?=:,:
         ~    :  I::::=
            ~    :?
                =:+

    Before deploying this template, complete these tasks
        [ ] Require any conditions that are needed for this module. For example:
                #Requires -RunAsAdministrator -Modules ActiveDirectory -Version 5.0
        [ ] Change names of preloaded classes and support functions to match module abbreviated name
        [ ] Delete Navi and this message
#>
<#
    Version: (Prerelease) (t2025-01-08)
    ToDo: 
        [ ] Template
        [ ] Validate and update all help text
        [ ] Clean Up
#>
#endregion Notes

#region Classes
# enum Method {
#     Get
#     Post
#     Put
# }

class TEMPLATEChecklistItem {
    [string]$Name
    [string]$Text
    [byte]$State
    TEMPLATEChecklistItem() {}
    TEMPLATEChecklistItem($Name,$Text) {
        $this.Name  =   $Name
        $this.Text  =   $Text
        $this.State =   0
    }
}

class TEMPLATEObject {
    [string]$Name
    [Int]$LineCount
    [System.IO.FileInfo]$FileInfo
    TEMPLATEObject() {}
    TEMPLATEObject($FileInfo) {
        $this.Name          =   $FileInfo.Name
        $this.FileInfo      =   $FileInfo
    }
}
#endregion Classes

#region Module Configurations
$Script:ErrorActionPreference = 'Stop'
$Script:TEMPLATEConfig=[PSCustomObject]@{
    Config = (
        Get-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Template.json') | Get-Content -Raw | 
            ConvertFrom-Json
    )
    Checklist=[System.Collections.ArrayList]@()
    Timer=[system.diagnostics.stopwatch]::new() 
}
#endregion Module Configurations

#region Support Functions
function Write-TEMPLATEVerbose {
    <#
    .DESCRIPTION
        Checks higher context for VerbosePreference, gives verbose output Standardized formatting. Able to 
        return a current timer value
    #>
    [CmdletBinding()]
    param (
        [string]$Message
    )
    begin {
        if (-not $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.Get("VerbosePreference").Value
        }
    }
    # end {}
    process {
        try {
            if ($TEMPLATEConfig.Timer.IsRunning) {
                $TimeString = [string][math]::Round($TEMPLATEConfig.Timer.Elapsed.TotalSeconds,2)+"s"
            }
            Write-Verbose -Message ((Get-PSCallStack)[1].Command + "  " + $TimeString + "  " + $Message)
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem
        }
    }
}

function Write-TEMPLATEError {
    <#
    .DESCRIPTION
        Verbose output Error output formatting, including detailed tracing. 
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
        , $OutObject
    )
    # begin {}
    # end {}
    process {
        Write-Host -ForegroundColor Red -Object ("ERROR:  " + $ErrorRecord.Exception.Message)
        if ($ErrorRecord.TargetObject) {
        Write-Host -ForegroundColor Yellow -Object ("  OBJECT:  " + $ErrorRecord.TargetObject)
        }
        Write-Host -ForegroundColor Yellow -Object ("  TRACE:`n" + $ErrorRecord.ScriptStackTrace)
        Write-Host -ForegroundColor Yellow -Object ("  TYPE:  " + $ErrorRecord.Exception.GetType().FullName)
        if ($OutObject) {
            Write-Verbose -Message "  OBJECT DETAIL:"
            Write-Verbose -Message ($OutObject | Format-Custom -Depth 1 | Out-String)
        }
    }
}

function Read-TEMPLATEValue {
    <#
    .DESCRIPTION
        DO NOT USE THIS FUNCTION IN A NONINTERACTIVE, FULLY AUTOMATED CONTEXT
        Used to request information from user. May provide a list of options
    #>
    [CmdletBinding()]
    param (
        [string]$Name
        , [System.Collections.ArrayList]$OptionList
        , [string]$Default
    )
    # begin {}
    # end {}    
    process {
        try {
            if ($OptionList) {
                Write-Host -ForegroundColor Cyan -Object "INFO:  Options Available:`n    $OptionList"
            }
            if ($Default) {
                $DefaultText = "[$Default]"
            }
            Write-Host -ForegroundColor Cyan -NoNewline -Object "PROMPT:  Enter value for $Name $DefaultText" 
            Read-Host -Prompt '?'
            Write-TEMPLATEVerbose -Message "Value for $Name from asking"
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem
        }
    }
}

function New-TEMPLATEChecklistObject {
    <#
    .DESCRIPTION
        Used to create on item in a prodedure checklist. Outputs a checklist item.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)][PSCustomObject]$InputObject
    )
    begin {
        $i = 0
    }
    end {
        Write-TEMPLATEVerbose -Message "Objects evaluated: $i" 
    }  
    process {
        try {
            New-Object -TypeName TEMPLATEChecklistItem -ArgumentList $InputObject.Name,$InputObject.Text
            Write-TEMPLATEVerbose -Message ('Checklist item ' + $InputObject.Name + ' Added') 
            $i++
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem
        }
    }
}

function Write-TEMPLATEChecklistItem {
    <#
    .DESCRIPTION
        Writes the inputed checklist to the host. Output is color coded and includes a checkbox for easy 
        review of status
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$InputObject
    )
    begin {
        Write-Host -ForegroundColor Cyan -Object "Info:"
        Write-Host -ForegroundColor Cyan -Object "Info:  TEMPLATE Script Checklist"        
        $i = 0
    }
    end {
        if ($ChecklistAlert) {
            Write-Warning -Message 'Please review any errors and try again'
        }
        Write-Host -ForegroundColor Cyan -Object "Info:"
        Write-TEMPLATEVerbose -Message "Objects evaluated: $i"
    }  
    process {
        try {
            switch ($InputObject.State) {
                0 { 
                    $TextColor = $TEMPLATEConfig.Config.ChecklistColors[0] 
                    $Checkbox = "    [ ] "
                }
                1 { 
                    $TextColor = $TEMPLATEConfig.Config.ChecklistColors[1] 
                    $Checkbox = "    [!] "
                    $ChecklistAlert = $true
                }
                2 { 
                    $TextColor = $TEMPLATEConfig.Config.ChecklistColors[2] 
                    $Checkbox = "    [*] "
                }
                Default {
                    $TextColor = $TEMPLATEConfig.Config.ChecklistColors[1] 
                    $Checkbox = "    [?] "
                    $ChecklistAlert = $true
                }
            }
            Write-Host -ForegroundColor $TextColor -Object ($Checkbox + $InputObject.Text)
            $i++
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem -OutObject $TEMPLATEObject
        }
    }
}

function Update-TEMPLATEChecklistItem {
    <#
    .DESCRIPTION
        Increment the state on a named item in the inputed checklist. 0 is default and should indicate that 
        item is not started. 1 is "incomplete" or error status, and 2 is complete status
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$InputObject
        , [string]$ItemName
    )
    begin {
        $i = 0
    }
    end {
        if ($i) {
            Write-TEMPLATEVerbose -Message "Checklist item $ItemName updated" 
        }
    }  
    process {
        try {
            if ($InputObject.Name -eq $ItemName) {
                $InputObject.State++
            }
            $InputObject
            $i++
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem -OutObject $TEMPLATEObject
        }
    }
}

function Set-TEMPLATEIncrementChecklistItem {
    <#
    .DESCRIPTION
        Used to increment ChecklistItem in procedural script. This is required when module doesn't have an 
        internal method to determin success
    #>
    [CmdletBinding()]
    param (
        [string]$ItemName
    )
    # begin {}
    # end {}    
    process {
        try {
            $TEMPLATEConfig.Checklist = $TEMPLATEConfig.Checklist | Update-TEMPLATEChecklistItem -ItemName $ItemName
            Write-TEMPLATEVerbose -Message "Updated Item $ItemName"
        }
        catch {
            Write-TEMPLATEError -ErrorRecord $PSItem
        }
    }
}
#endregion Support Functions

#region Public Functions
function Enable-TEMPLATEVerbose {
    <#
    .DESCRIPTION
        Enable verbose messages for all TEMPLATE cmdlets during current module usage. These will provide 
        more detail, and may assist with troubleshooting.
    .NOTES
        Messages can be disabled by reloading the module with the -Force parameter
    .OUTPUTS
        Messages to the host
    .EXAMPLE
        PS> Enable-TEMPLATEVerbose 
        Enable verbose messages
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}    
    process {
        $Script:VerbosePreference = 'Continue'
        Write-TEMPLATEVerbose -Message 'Enabled verbose output for this module'
    }
}

function Start-TEMPLATETimer {
    <#
    .DESCRIPTION
        Starts the internal timer for the Template module. This is used to indicate, through verbose messaging,
        when a segment of code was executed relative to the start of the timer start time. 
    .NOTES
        For timer to be exposed to other module commands, use the $TEMPLATEConfig.Timer object
    .EXAMPLE
        PS> Start-TEMPLATETimer
        Enable timer
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}    
    process {
        $Script:TEMPLATEConfig.Timer.Start()
        Write-TEMPLATEVerbose -Message 'Enabled timer for this module'
    }
}

function Clear-TEMPLATETimer {
    <#
    .DESCRIPTION
        Clears the timer for the Template module
    .NOTES
        See Start-TEMPLATETimer
    .EXAMPLE
        PS> Clear-TEMPLATETimer
        Stop and reset timer
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}    
    process {
        $Script:TEMPLATEConfig.Timer.Stop()
        $Script:TEMPLATEConfig.Timer.Reset()
        Write-TEMPLATEVerbose -Message 'Cleared timer for this module'
    }
}

function Enable-TEMPLATEChecklist {
    <#
    .SYNOPSIS
        Enables the internal checklist for the Template module. 
    .DESCRIPTION
        A checklist is created using information from the Template.json file. The checklist will start with 
        all status being "incomplete ([ ])" 
    .EXAMPLE
        PS C:\> Enable-TEMPLATEChecklist
        Enables the checklist
    .NOTES
        The checklist object can be accessed using Write-TEMPLATEChecklist and Update-TEMPLATEChecklistItem. 
        The checklist is contained in the $TEMPLATEConfig.Checklist object. To access this object directly, you
        will have to make changes to this module. 
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}
    process {
        try {
            $TEMPLATEConfig.Checklist = $TEMPLATEConfig.Config.Checklist | New-TEMPLATEChecklistObject
            Write-TEMPLATEVerbose -Message 'Built new checklist object'
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem 
        }
    }
}

function Write-TEMPLATEChecklist {
    <#
    .SYNOPSIS
        Writes the Template checklist to the host
    .DESCRIPTION
        When the Temlcate checklist enabled, the checklist will be output to the host, with current status for 
        each item in the checklist. 
    .EXAMPLE
        PS> Write-TEMPLATEChecklist
    .NOTES
        Put Write-TEMPLATEChecklist at the beginning and end of procedural code. Commands in the Template module
        will increment the status of checklist items as they are invoked.
    #>
    [CmdletBinding()]
    param ()
    # begin {}
    # end {}
    process {
        try {
            $TEMPLATEConfig.Checklist | Write-TEMPLATEChecklistItem
            Write-TEMPLATEVerbose -Message 'Wrote checklist to console'
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem 
        }
    }
}

function New-TEMPLATEObject {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        # Parameter help description
        [Alias('Path')][Parameter(ValueFromPipelineByPropertyName,Position=0)][string[]]$FullName
    )
    begin {
        $i = 0
    }
    end {
        if (-not $i) {
            Write-Warning -Message 'No files found in the current path.'
        }
        Write-TEMPLATEVerbose -Message "Objects evaluated: $i" 
    }
    process {
        try {
            if (-not $FullName) {
                $FullName = Read-TEMPLATEValue -Name 'Path' 
            }
            $ObjectParameters = @{
                TypeName = 'TEMPLATEObject' 
                ArgumentList = Get-Item -Path $FullName
            }
            New-Object @ObjectParameters
            Write-TEMPLATEVerbose -Message ('New Object for ' + $FullName) 
            $i++
        } catch [System.Management.Automation.MethodException] {
            Write-Warning -Message 'FullName (Path) must be a file'
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem -OutObject $Fullname,$ObjectParameters
        }
    }
}

function Get-TEMPLATELineCount {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Position=0,ParameterSetName='Guided')][string]$Path
        , # Parameter help description
        [Parameter(ValueFromPipeline,Position=1,ParameterSetName='InputObject')]$TEMPLATEObject
        , [parameter(DontShow)][string]$ChecklistItemName = 'LineCount'
    )
    begin {
        Write-TEMPLATEVerbose -Message ('Selected ParameterSetName is ' + $PSCmdlet.ParameterSetName)
        if ($PSCmdlet.ParameterSetName -eq 'Guided') {
            $TEMPLATEObject = New-TEMPLATEObject -FullName $Path 
            Write-TEMPLATEVerbose -Message "Created TEMPLATE object"
        }
        Set-TEMPLATEIncrementChecklistItem -ItemName $ChecklistItemName
        $i = 0
    }
    end {
        if (-not $LineCountError) {
            Set-TEMPLATEIncrementChecklistItem -ItemName $ChecklistItemName
        }
        Write-TEMPLATEVerbose -Message "Objects evaluated: $i" 
    }
    process {
        try {
            if ($TEMPLATEObject.FileInfo.Extension -in $TEMPLATEConfig.Config.TextFilter) {
                $TEMPLATEObject.LineCount = (Get-Content -Path $TEMPLATEObject.FileInfo.FullName | Measure-Object).Count
                Write-TEMPLATEVerbose -Message (
                    'Enumerated lines for ' + $TEMPLATEObject.Name + ' got ' + $TEMPLATEObject.LineCount
                )
                $TEMPLATEObject
                $i++
            }
        } catch {
            Write-TEMPLATEError -ErrorRecord $PSItem -OutObject $TEMPLATEObject
            $LineCountError = $true
        }
    }
}

function Get-TEMPLATEFileCount {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    param (
        # Parameter help description
        [Parameter(Position=0,Mandatory)][string]$Path
        , [parameter(DontShow)][string]$ChecklistItemName = 'FileCount'
    )
    # begin {}
    # end {}
    process {
        try {
            Set-TEMPLATEIncrementChecklistItem -ItemName $ChecklistItemName
            Write-Host -ForegroundColor Cyan -Object (
                'INFO:  File Count:' + (Get-ChildItem -Path $Path -File | Measure-Object).Count
            )
            Set-TEMPLATEIncrementChecklistItem -ItemName $ChecklistItemName
            Write-TEMPLATEVerbose -Message 'Output File Count' 
        }
        catch {
            Write-TEMPLATEError -ErrorRecord $PSItem -OutObject $Path
        }
    }
}

#endregion Public Functions