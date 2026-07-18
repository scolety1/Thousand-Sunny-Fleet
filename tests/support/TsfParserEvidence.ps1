function New-TsfParserEvidenceRowV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Check,

        [Parameter(Mandatory)]
        [ValidateSet('POWERSHELL', 'JSON')]
        [string]$ParserKind,

        [AllowEmptyCollection()]
        [object[]]$ParserErrors = @(),

        [Parameter(Mandatory)]
        [string]$SuccessEvidence
    )

    $messages = @($ParserErrors | ForEach-Object {
        if ($_ -is [string]) { $_ }
        elseif ($null -ne $_.Exception -and -not [string]::IsNullOrWhiteSpace([string]$_.Exception.Message)) { [string]$_.Exception.Message }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$_.Message)) { [string]$_.Message }
        else { [string]$_ }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $failed = $messages.Count -gt 0
    $status = if ($failed) { 'FAIL' } else { 'PASS' }
    $exitCode = if ($failed) { 65 } else { 0 }
    $identity = '{0}_PARSER_{1}' -f $ParserKind, $(if ($failed) { 'FAILURE' } else { 'SUCCESS' })

    [pscustomobject][ordered]@{
        check = $Check
        status = $status
        exit_code = $exitCode
        parser_result_identity = $identity
        evidence = if ($failed) { $messages -join '; ' } else { $SuccessEvidence }
        stdout_path = $null
        stdout_sha256 = $null
        stderr = if ($failed) { $messages -join '; ' } else { '' }
        stderr_path = $null
        stderr_sha256 = $null
    }
}
