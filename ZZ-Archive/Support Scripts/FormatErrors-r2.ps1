<#
    This script gets error details from $Error system variable,
    and returns an array 
#>
$I = 0
$ProcedureErrors = [System.Collections.ArrayList]@()
$Error | Sort-Object | Select-Object -First 32 | Where-Object -FilterScript { $_.Exception.Message -notmatch 'used by another process' } | `
    ForEach-Object -Process {
        If ($I -eq 0) {
            $ProcedureErrors.Add('**** Last detected errors ****') | Out-Null
        }
        $ProcedureErrors.Add(
            "** EID: `t" + $I + "** `n" +
            "Script Name: `t" + $_.InvocationInfo.ScriptName + "`n" +
            "Line #: `t" + $_.InvocationInfo.ScriptLineNumber + "`n" +
            "Line Content: `t" + $_.InvocationInfo.Line.Trim() + "`n" +
            "Target Object: `t" + $_.TargetObject + "`n" +
            "Exception: `t" +$_.Exception.Message+ "`n"
        ) > $Null
        $I++
    }
# $Error lists last error first, so reverse the order
Return $ProcedureErrors