<#
    This script converts image files from the source file, 
    given they are newer than time (default is 100 year ago)
    Conversion may be from BMP to JPEG of vice versa.
    The new file goes to the destionation folder    
#>
param(
    [Parameter(Mandatory=$True,Position=1)][String]$SourcePath
    , [Parameter(Position=2)][String]$DestinationPath = $SourcePath
    , [Parameter(Position=3)][DateTime]$OlderThan = (Get-Date)
    , [Parameter(Position=4)][DateTime]$NewerThan = (Get-Date -Date '01/01/1985')
    , [Switch]$BmpToJpg
    , [switch]$JpgToBmp
    , [switch]$RemoveOriginal 
)

# Initial configuration
# Load required assembly
[Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”) | Out-Null
# Set variables based on conversion flag
If ($BmpToJpg -and $JpgToBmp) {
    # Dump out of script 
    Write-Error -Message "One of these flags must be specified: -BmpToJpg or -JpgToBmp, but not both"
    Return
} ElseIf ($BmpToJpg) {
    $Filter = "*.bmp"
    $NewExtension = ".jpg"
    $NewFormat = ”jpeg”
} ElseIf ($JpgToBmp) {
    $Filter = "*.jpg"
    $NewExtension = ".bmp"
    $NewFormat = "bmp"
} Else {
    # Dump out of script if there's no flag
    Write-Error -Message "One of these flags must be specified: -BmpToJpg or -JpgToBmp"
    Return
} 
# Source path must by full path
$SourcePath = (Get-Item $SourcePath).FullName
# Staging path location
$StagePath = Join-Path -path $env:TEMP -ChildPath "ConvertImagesStaging"
# Reset counter
$I = 0
# Troubleshooting info
Write-Output -InputObject (Get-Item $MyInvocation.MyCommand.Path).BaseName
Write-Output -InputObject ("Time Start: " + (Get-Date).DateTime)
Write-Output -InputObject ("Converting images from: `n $SourcePath `n to $DestinationPath `n which matches the filter $Filter")
Write-Output -InputObject ("Older than " + $OlderThan.DateTime)
Write-Output -InputObject ("Newer than " + $NewerThan.DateTime)

# Check for the staging path. If it's not there, create it
If (-not (Test-Path $StagePath)) {
    New-Item -Path $StagePath -ItemType Directory -Force | Out-Null
}

# Get files in the Source folder that are of the specirfied file type
Get-ChildItem -Path $SourcePath -Filter $Filter -Attributes Normal,Archive -Recurse -File | `
    # Filter files which are newer than specificed date and time
    Where {(($_.LastWriteTime -ge $NewerThan) -or ($_.CreationTime -ge $NewerThan)) -and (($_.LastWriteTime -le $OlderThan) -or ($_.CreationTime -le $OlderThan))} | `
    # Process files that meet all the criteria
    Foreach-Object -Process { 
        # Paths for file pre/post conversion
        $CurrentFullName = Join-Path -Path $StagePath -ChildPath $_.Name
        $ConvertedName = $_.BaseName + $NewExtension
        $ConvertedFullName = Join-Path -Path $StagePath -ChildPath $ConvertedName
        $FinalPath = $_.Directory.ToString().Replace($SourcePath,$DestinationPath)
        $FinalFullName = Join-Path -Path $FinalPath -ChildPath $ConvertedName
        # Create any subfolders needed to preserve folder structure
        If (-not (Test-Path $FinalPath)) {
            New-Item -Path $FinalPath -ItemType Directory -Force | Out-Null
        }
        # Check first that the file doesn't already exist. Then, create the new file!
        If ((-not (Test-Path $FinalFullName)) -or ($_.LastWriteTime -gt (Get-Item $FinalFullName).LastWriteTime)) {
            # Enable for diagnostics
            #Write-Output -InputObject ("Converting " + $_.Fullname + " to $FinalFullName")
            # Move or copy file to staging on local computer
            If ($RemoveOriginal) {
                Move-Item -Path $_.FullName -Destination $StagePath
            } Else {
                Copy-Item -Path $_.FullName -Destination $StagePath
            }
            Try {
                # Convert between formats
                $TempFile = New-Object System.Drawing.Bitmap($CurrentFullName);
                $TempFile.Save($ConvertedFullName,$NewFormat);
                $TempFile.Dispose()
                # Delete old format file that we just copied
                #"FileDestName is $FileDestName"
                Move-Item -Path $ConvertedFullName -Destination $FinalPath
                # Remove the copy of the file in Staging
                Remove-Item -Path $CurrentFullName
            } Catch {
                Write-Output -InputObject ("Error processing " + $FinalFullName)
                Write-Error -Message ("Error processing " + $FinalFullName)
            }
            # Count number of loops
            $I++
        }
    }
# Troubleshooting info
Write-Output -InputObject ("Finished script run! Processed $I files. End time: " + (Get-Date).DateTime)