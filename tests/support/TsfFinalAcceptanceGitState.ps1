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

function ConvertTo-TsfFinalAcceptanceOutputLines {
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    return @($Text -split "`r?`n" | Where-Object { $_ -ne '' })
}

function Get-TsfFinalAcceptanceWorktreeBindingState {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$GitExecutable
    )
    $commands = [ordered]@{
        status = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('status', '--porcelain=v2', '--untracked-files=all') -Stage 'WORKTREE_BINDING_STATUS'
        staged = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('diff', '--cached', '--name-only') -Stage 'WORKTREE_BINDING_STAGED'
        modified = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('diff', '--name-only') -Stage 'WORKTREE_BINDING_MODIFIED'
        untracked = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('ls-files', '--others', '--exclude-standard') -Stage 'WORKTREE_BINDING_UNTRACKED'
        branch = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('branch', '--show-current') -Stage 'WORKTREE_BINDING_BRANCH'
        head = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('rev-parse', 'HEAD') -Stage 'WORKTREE_BINDING_HEAD'
        tree = Invoke-TsfFinalAcceptanceGitCommand -RepositoryRoot $RepositoryRoot -GitExecutable $GitExecutable -Arguments @('rev-parse', 'HEAD^{tree}') -Stage 'WORKTREE_BINDING_TREE'
    }
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($name in $commands.Keys) {
        if (-not $commands[$name].success) { $errors.Add("$($name.ToUpperInvariant())_COMMAND_FAILED") | Out-Null }
    }
    $statusLines = @(ConvertTo-TsfFinalAcceptanceOutputLines $commands.status.stdout)
    $stagedPaths = @(ConvertTo-TsfFinalAcceptanceOutputLines $commands.staged.stdout | Sort-Object -Unique)
    $modifiedPaths = @(ConvertTo-TsfFinalAcceptanceOutputLines $commands.modified.stdout | Sort-Object -Unique)
    $untrackedPaths = @(ConvertTo-TsfFinalAcceptanceOutputLines $commands.untracked.stdout | Sort-Object -Unique)
    $dirtyPaths = @($modifiedPaths + $untrackedPaths | Sort-Object -Unique)
    $fileRows = [Collections.Generic.List[object]]::new()
    foreach ($relativePath in $dirtyPaths) {
        $absolutePath = Join-Path $RepositoryRoot ($relativePath -replace '/', '\')
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            $errors.Add("DIRTY_PATH_MISSING_OR_NONREGULAR:$relativePath") | Out-Null
            continue
        }
        $fileRows.Add([pscustomobject][ordered]@{
            path = $relativePath.Replace('\', '/')
            bytes = [long](Get-Item -LiteralPath $absolutePath).Length
            sha256 = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
            kind = if ($untrackedPaths -contains $relativePath) { 'UNTRACKED' } else { 'TRACKED_MODIFIED' }
        }) | Out-Null
    }
    $normalizedStatus = if ($statusLines.Count) { ($statusLines -join "`n") + "`n" } else { '' }
    $bindingLines = [Collections.Generic.List[string]]::new()
    $bindingLines.Add('TSF_AUTHORIZED_DIRTY_WORKTREE_BINDING_V1') | Out-Null
    $bindingLines.Add('STATUS') | Out-Null
    foreach ($line in $statusLines) { $bindingLines.Add($line) | Out-Null }
    $bindingLines.Add('FILES') | Out-Null
    foreach ($row in @($fileRows | Sort-Object path)) {
        $bindingLines.Add("$($row.kind)`t$($row.path)`t$($row.bytes)`t$($row.sha256)") | Out-Null
    }
    $bindingText = ($bindingLines -join "`n") + "`n"
    $branchLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $commands.branch.stdout -AllowEmpty
    $headLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $commands.head.stdout
    $treeLine = ConvertTo-TsfFinalAcceptanceSingleLine -Output $commands.tree.stdout
    if (-not $branchLine.valid) { $errors.Add("BRANCH_OUTPUT_INVALID:$($branchLine.disposition)") | Out-Null }
    if (-not $headLine.valid) { $errors.Add("HEAD_OUTPUT_INVALID:$($headLine.disposition)") | Out-Null }
    if (-not $treeLine.valid) { $errors.Add("TREE_OUTPUT_INVALID:$($treeLine.disposition)") | Out-Null }
    return [pscustomobject][ordered]@{
        schema_version = 'tsf_authorized_dirty_worktree_binding_state_v1'
        repository = [IO.Path]::GetFullPath($RepositoryRoot)
        branch = if ($branchLine.valid) { [string]$branchLine.value } else { $null }
        head = if ($headLine.valid) { [string]$headLine.value } else { $null }
        tree = if ($treeLine.valid) { [string]$treeLine.value } else { $null }
        status_lines = $statusLines
        status_sha256 = Get-TsfFinalAcceptanceTextSha256 $normalizedStatus
        staged_paths = $stagedPaths
        modified_paths = $modifiedPaths
        untracked_paths = $untrackedPaths
        dirty_paths = $dirtyPaths
        file_rows = @($fileRows | Sort-Object path)
        binding_sha256 = Get-TsfFinalAcceptanceTextSha256 $bindingText
        binding_text_sha256 = Get-TsfFinalAcceptanceTextSha256 $bindingText
        errors = @($errors)
        commands = @($commands.Keys | ForEach-Object {
            $row = $commands[$_]
            [pscustomobject][ordered]@{
                name = $_
                command = $row.command
                exit_code = $row.exit_code
                stdout_sha256 = $row.stdout_sha256
                stderr_sha256 = $row.stderr_sha256
            }
        })
    }
}

function Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding {
    param(
        [Parameter(Mandatory)][object]$State,
        [Parameter(Mandatory)][string]$ExpectedHead,
        [Parameter(Mandatory)][string]$ExpectedTree,
        [Parameter(Mandatory)][string]$ExpectedBranch,
        [Parameter(Mandatory)][string]$ExpectedBindingSha256,
        [Parameter(Mandatory)][string[]]$AllowedPathPatterns
    )
    $errors = [Collections.Generic.List[string]]::new()
    if ([string]$State.head -ne $ExpectedHead) { $errors.Add('HEAD_MISMATCH') | Out-Null }
    if ([string]$State.tree -ne $ExpectedTree) { $errors.Add('TREE_MISMATCH') | Out-Null }
    if ([string]$State.branch -ne $ExpectedBranch) { $errors.Add('BRANCH_MISMATCH') | Out-Null }
    if ($ExpectedBindingSha256 -notmatch '^[a-f0-9]{64}$') { $errors.Add('EXPECTED_BINDING_SHA256_INVALID') | Out-Null }
    if ([string]$State.binding_sha256 -ne $ExpectedBindingSha256) { $errors.Add('WORKTREE_BINDING_SHA256_MISMATCH') | Out-Null }
    if (@($State.errors).Count -ne 0) { $errors.Add('WORKTREE_STATE_CAPTURE_ERRORS') | Out-Null }
    if (@($State.staged_paths).Count -ne 0) { $errors.Add('INDEX_NOT_EMPTY') | Out-Null }
    if (@($State.dirty_paths).Count -eq 0) { $errors.Add('DIRTY_SCOPE_REQUIRED_BUT_EMPTY') | Out-Null }
    foreach ($relativePath in @($State.dirty_paths)) {
        $normalized = ([string]$relativePath).Replace('\', '/')
        $allowed = $false
        foreach ($pattern in $AllowedPathPatterns) {
            if ($normalized -match $pattern) { $allowed = $true; break }
        }
        if (-not $allowed) { $errors.Add("UNAUTHORIZED_DIRTY_PATH:$normalized") | Out-Null }
    }
    return [pscustomobject][ordered]@{
        valid = $errors.Count -eq 0
        errors = @($errors)
        expected_head = $ExpectedHead
        expected_tree = $ExpectedTree
        expected_branch = $ExpectedBranch
        expected_binding_sha256 = $ExpectedBindingSha256
        actual_binding_sha256 = [string]$State.binding_sha256
        staged_count = @($State.staged_paths).Count
        dirty_path_count = @($State.dirty_paths).Count
        dirty_paths = @($State.dirty_paths)
    }
}

function Test-TsfFinalAcceptanceAuthorizedDirtyDoctorBinding {
    param(
        [Parameter(Mandatory)][object]$Doctor,
        [Parameter(Mandatory)][object]$WorktreeBinding,
        [Parameter(Mandatory)][string]$ExpectedHead,
        [Parameter(Mandatory)][string]$ExpectedBranch
    )
    $errors = [Collections.Generic.List[string]]::new()
    if (-not $WorktreeBinding.valid) { $errors.Add('WORKTREE_BINDING_INVALID') | Out-Null }
    if ([string]$Doctor.overall_status -ne 'UNSAFE_TO_START') { $errors.Add('DOCTOR_STATUS_NOT_UNSAFE_TO_START') | Out-Null }
    if ([bool]$Doctor.safe_to_start) { $errors.Add('DOCTOR_UNEXPECTEDLY_SAFE') | Out-Null }
    if ([string]$Doctor.repository.head -ne $ExpectedHead) { $errors.Add('DOCTOR_HEAD_MISMATCH') | Out-Null }
    if ([string]$Doctor.repository.branch -ne $ExpectedBranch) { $errors.Add('DOCTOR_BRANCH_MISMATCH') | Out-Null }
    if ([bool]$Doctor.repository.clean) { $errors.Add('DOCTOR_UNEXPECTEDLY_CLEAN') | Out-Null }
    if ([string]$Doctor.process_owner.disposition -ne 'ABSENT') { $errors.Add('DOCTOR_OWNER_PRESENT') | Out-Null }
    if (@($Doctor.listener_state.listeners).Count -ne 0) { $errors.Add('DOCTOR_LISTENER_PRESENT') | Out-Null }
    if (@($Doctor.active_child).Count -ne 0) { $errors.Add('DOCTOR_OWNED_CHILD_PRESENT') | Out-Null }
    $unsafeChecks = @($Doctor.checks | Where-Object { [string]$_.status -eq 'UNSAFE_TO_START' } | ForEach-Object { [string]$_.id })
    if ($unsafeChecks.Count -ne 1 -or $unsafeChecks[0] -ne 'worktree_cleanliness') {
        $errors.Add("DOCTOR_UNSAFE_CHECK_SET_MISMATCH:$($unsafeChecks -join ',')") | Out-Null
    }
    return [pscustomobject][ordered]@{
        valid = $errors.Count -eq 0
        errors = @($errors)
        doctor_status = [string]$Doctor.overall_status
        safe_to_start = [bool]$Doctor.safe_to_start
        owner_disposition = [string]$Doctor.process_owner.disposition
        listener_count = @($Doctor.listener_state.listeners).Count
        owned_child_count = @($Doctor.active_child).Count
        unsafe_check_ids = $unsafeChecks
        worktree_binding_sha256 = [string]$WorktreeBinding.actual_binding_sha256
    }
}
