$script:TsfFinalAcceptanceGitStateStage = 'FINAL_ACCEPTANCE_GIT_STATE_PREFLIGHT'

function Get-TsfFinalAcceptanceTextSha256 {
    param([AllowNull()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($(if ($null -eq $Text) { '' } else { $Text }))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function ConvertTo-TsfFinalAcceptanceSingleLine {
    param([AllowNull()][object]$Output, [switch]$AllowEmpty)
    $nonEmpty = [Collections.Generic.List[string]]::new()
    foreach ($item in @($Output)) {
        if ($null -eq $item) { continue }
        foreach ($line in ([string]$item -split "`r?`n")) {
            $trimmed = $line.Trim()
            if ($trimmed) { $nonEmpty.Add($trimmed) | Out-Null }
        }
    }
    if ($nonEmpty.Count -gt 1) { return [pscustomobject][ordered]@{ valid=$false; value=$null; disposition='UNEXPECTED_MULTI_LINE_OUTPUT'; line_count=$nonEmpty.Count } }
    if ($nonEmpty.Count -eq 0) { return [pscustomobject][ordered]@{ valid=[bool]$AllowEmpty; value=$null; disposition=$(if($AllowEmpty){'EMPTY_OUTPUT_ACCEPTED'}else{'REQUIRED_OUTPUT_MISSING'}); line_count=0 } }
    return [pscustomobject][ordered]@{ valid=$true; value=$nonEmpty[0]; disposition='SINGLE_LINE_OUTPUT'; line_count=1 }
}

function ConvertTo-TsfFinalAcceptanceProcessArgument {
    param([Parameter(Mandatory)][string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-TsfFinalAcceptanceGitCommand {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$GitExecutable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$Stage = $script:TsfFinalAcceptanceGitStateStage
    )
    $allArguments = @('-C', $RepositoryRoot) + $Arguments
    $command = (@($GitExecutable) + $allArguments) -join ' '
    $started = [datetimeoffset]::UtcNow
    try {
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $GitExecutable
        $info.Arguments = ($allArguments | ForEach-Object { ConvertTo-TsfFinalAcceptanceProcessArgument ([string]$_) }) -join ' '
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $info
        if (!$process.Start()) { throw 'GIT_PROCESS_DID_NOT_START' }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = [int]$process.ExitCode
        $process.Dispose()
        $finished = [datetimeoffset]::UtcNow
        return [pscustomobject][ordered]@{ stage=$Stage; command=$command; repository=$RepositoryRoot; exit_code=$exitCode; success=$exitCode -eq 0; stdout=$stdout; stdout_sha256=Get-TsfFinalAcceptanceTextSha256 $stdout; stderr_sha256=Get-TsfFinalAcceptanceTextSha256 $stderr; error_classification=$(if($exitCode -eq 0){$null}else{'GIT_COMMAND_NONZERO_EXIT'}); started_utc=$started.ToString('o'); finished_utc=$finished.ToString('o') }
    } catch {
        $finished = [datetimeoffset]::UtcNow
        $errorText = $_.Exception.ToString()
        return [pscustomobject][ordered]@{ stage=$Stage; command=$command; repository=$RepositoryRoot; exit_code=-1; success=$false; stdout=''; stdout_sha256=Get-TsfFinalAcceptanceTextSha256 ''; stderr_sha256=Get-TsfFinalAcceptanceTextSha256 $errorText; error_classification='GIT_PROCESS_LAUNCH_FAILURE'; started_utc=$started.ToString('o'); finished_utc=$finished.ToString('o') }
    }
}

function Get-TsfFinalAcceptanceGitState {
    param([Parameter(Mandatory)][string]$RepositoryRoot, [Parameter(Mandatory)][string]$GitExecutable)
    if (!(Get-Command Get-TsfKernelGitState -ErrorAction SilentlyContinue)) { throw 'CANONICAL_GIT_STATE_AUTHORITY_UNAVAILABLE' }
    $canonical = Get-TsfKernelGitState -RepoPath $RepositoryRoot
    $branchCommand = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('branch','--show-current')
    $headCommand = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('rev-parse','HEAD')
    $treeCommand = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('rev-parse','HEAD^{tree}')
    $branchLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $branchCommand.stdout -AllowEmpty
    $headLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $headCommand.stdout
    $treeLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $treeCommand.stdout
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($pair in @([pscustomobject]@{name='branch';command=$branchCommand;line=$branchLine},[pscustomobject]@{name='head';command=$headCommand;line=$headLine},[pscustomobject]@{name='tree';command=$treeCommand;line=$treeLine})) {
        if (!$pair.command.success) { $errors.Add("$($pair.name.ToUpperInvariant())_COMMAND_FAILED") | Out-Null }
        if (!$pair.line.valid) { $errors.Add("$($pair.name.ToUpperInvariant())_OUTPUT_INVALID:$($pair.line.disposition)") | Out-Null }
    }
    if (![bool]$canonical.can_capture) { $errors.Add('CANONICAL_GIT_STATE_CAPTURE_FAILED') | Out-Null }
    if ($headLine.valid -and [string]$headLine.value -notmatch '^[a-f0-9]{40,64}$') { $errors.Add('HEAD_IDENTITY_INVALID') | Out-Null }
    if ($treeLine.valid -and [string]$treeLine.value -notmatch '^[a-f0-9]{40,64}$') { $errors.Add('TREE_IDENTITY_INVALID') | Out-Null }
    if ($headLine.valid -and [string]$canonical.head -ne [string]$headLine.value) { $errors.Add('CANONICAL_HEAD_MISMATCH') | Out-Null }
    $detached = $branchLine.valid -and [string]::IsNullOrWhiteSpace([string]$branchLine.value)
    if ($errors.Count -eq 0 -and $detached -and ![bool]$canonical.detached_head) { $errors.Add('CANONICAL_DETACHED_CLASSIFICATION_MISMATCH') | Out-Null }
    if ($errors.Count -eq 0 -and !$detached -and [string]$canonical.branch -ne [string]$branchLine.value) { $errors.Add('CANONICAL_ATTACHED_BRANCH_MISMATCH') | Out-Null }
    $classification = if($errors.Count){'UNKNOWN_OR_INVALID_GIT_STATE'}elseif($detached){'DETACHED_COMMIT_PINNED'}else{'ATTACHED_BRANCH'}
    $branch = if($classification -eq 'ATTACHED_BRANCH'){[string]$branchLine.value}else{$null}
    $disposition = switch($classification){'ATTACHED_BRANCH'{'ATTACHED_BRANCH_REQUIREMENTS_RETAINED'}'DETACHED_COMMIT_PINNED'{'DETACHED_READ_ONLY_ACCEPTANCE_PERMITTED_WRITES_REMAIN_DENIED'}default{'GIT_STATE_INVALID_FAIL_CLOSED'}}
    $evidence = [ordered]@{
        schema_version='tsf_final_acceptance_git_state_v1'; classification=$classification; repository=[IO.Path]::GetFullPath($RepositoryRoot); branch=$branch; detached=$classification -eq 'DETACHED_COMMIT_PINNED'; head=if($headLine.valid){[string]$headLine.value}else{$null}; tree=if($treeLine.valid){[string]$treeLine.value}else{$null}; branch_requirement_disposition=$disposition
        canonical_policy_state=[ordered]@{can_capture=[bool]$canonical.can_capture;branch=if([string]::IsNullOrWhiteSpace([string]$canonical.branch)){$null}else{[string]$canonical.branch};branch_identity_available=[bool]$canonical.branch_identity_available;detached_head=[bool]$canonical.detached_head;head=[string]$canonical.head;dirty=[bool]$canonical.dirty;error=[string]$canonical.error}
        commands=@($branchCommand,$headCommand,$treeCommand)|ForEach-Object{[ordered]@{stage=$_.stage;command=$_.command;repository=$_.repository;exit_code=$_.exit_code;success=$_.success;stdout_sha256=$_.stdout_sha256;stderr_sha256=$_.stderr_sha256;error_classification=$_.error_classification}}
        errors=@($errors)
    }
    $evidence.git_state_evidence_sha256 = Get-TsfFinalAcceptanceTextSha256 ($evidence|ConvertTo-Json -Depth 12 -Compress)
    return [pscustomobject]$evidence
}
