function Test-TsfApprovalLedgerInvocationBinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Mission,
        [AllowEmptyString()][string]$ApprovalLedgerPath='',
        [Parameter(Mandatory)][string]$CanonicalLedgerPath
    )
    $required=@(Get-TsfKernelApprovalRequirements -Mission $Mission)
    if($required.Count-eq0){
        return [pscustomobject]@{approval_semantics='NO_APPROVAL_REQUIRED';include_approval_ledger=$false;approval_ledger_path='';approval_ledger_consumed=$false;required_count=0}
    }
    if([string]::IsNullOrWhiteSpace($ApprovalLedgerPath)){throw 'TIM_REQUIRED_APPROVAL_LEDGER_MISSING'}
    $actual=Get-TsfKernelFullPath $ApprovalLedgerPath
    $expected=Get-TsfKernelFullPath $CanonicalLedgerPath
    if(![string]::Equals($actual,$expected,[StringComparison]::OrdinalIgnoreCase)){throw 'NONCANONICAL_APPROVAL_LEDGER_PATH'}
    if(!(Test-Path -LiteralPath $actual -PathType Leaf)){throw 'TIM_REQUIRED_APPROVAL_LEDGER_MISSING'}
    if((Get-Item -LiteralPath $actual).Length-eq0){throw 'APPROVAL_LEDGER_EMPTY'}
    $ledger=Get-TsfKernelApprovalLedger $actual
    $matches=@(Find-TsfKernelApprovalMatches -Mission $Mission -Ledger $ledger -LedgerPath $actual -RequireCanonicalUsageBinding)
    if($matches.Count-ne$required.Count-or@($matches|Where-Object{!$_.satisfied}).Count){throw "TIM_REQUIRED_APPROVAL_LEDGER_MISMATCH: $(@($matches|Where-Object{!$_.satisfied}|ForEach-Object{$_.match_status})-join ', ')"}
    [pscustomobject]@{approval_semantics='APPROVAL_REQUIRED';include_approval_ledger=$true;approval_ledger_path=$actual;approval_ledger_consumed=$true;required_count=$required.Count}
}

function New-TsfLifecycleInvocationArgumentPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PowerShellPath,
        [Parameter(Mandatory)][string]$LifecycleEntryPoint,
        [Parameter(Mandatory)][string]$MissionPath,
        [Parameter(Mandatory)][string]$OutDirectory,
        [Parameter(Mandatory)][string]$OutFile,
        [Parameter(Mandatory)][string]$StateRoot,
        [Parameter(Mandatory)][string]$QueueMissionPath,
        [Parameter(Mandatory)][string]$QueueRoot,
        [Parameter(Mandatory)][string]$CanonicalQueueDocumentEvidencePath,
        [Parameter(Mandatory)][int]$WorkerTimeoutSeconds,
        [Parameter(Mandatory)][object]$ApprovalPlan,
        [switch]$RunCanonicalAppServerWorker,
        [switch]$ManageQueueTransitions,
        [switch]$TestOnlyAllowAlternateQueueRoot
    )
    $required=[ordered]@{MissionPath=$MissionPath;OutDirectory=$OutDirectory;OutFile=$OutFile;StateRoot=$StateRoot;QueueMissionPath=$QueueMissionPath;QueueRoot=$QueueRoot;CanonicalQueueDocumentEvidencePath=$CanonicalQueueDocumentEvidencePath;WorkerTimeoutSeconds=[string]$WorkerTimeoutSeconds}
    foreach($entry in $required.GetEnumerator()){if([string]::IsNullOrWhiteSpace([string]$entry.Value)){throw "REQUIRED_LIFECYCLE_ARGUMENT_MISSING: $($entry.Key)"}}
    if([string]::IsNullOrWhiteSpace($PowerShellPath)-or[string]::IsNullOrWhiteSpace($LifecycleEntryPoint)){throw 'REQUIRED_LIFECYCLE_ENTRY_POINT_MISSING'}
    $arguments=[Collections.Generic.List[string]]::new();foreach($value in @('-NoProfile','-ExecutionPolicy','Bypass','-File',$LifecycleEntryPoint)){$arguments.Add([string]$value)}
    $included=[Collections.Generic.List[string]]::new();foreach($entry in $required.GetEnumerator()){$arguments.Add("-$($entry.Key)");$arguments.Add([string]$entry.Value);$included.Add([string]$entry.Key)}
    $omitted=[Collections.Generic.List[string]]::new()
    if([bool]$ApprovalPlan.include_approval_ledger){
        if([string]::IsNullOrWhiteSpace([string]$ApprovalPlan.approval_ledger_path)){throw 'EMPTY_OPTIONAL_LIFECYCLE_ARGUMENT_REJECTED: ApprovalLedgerPath'}
        $arguments.Add('-ApprovalLedgerPath');$arguments.Add([string]$ApprovalPlan.approval_ledger_path);$included.Add('ApprovalLedgerPath')
    }else{$omitted.Add('ApprovalLedgerPath')}
    if($RunCanonicalAppServerWorker){$arguments.Add('-RunCanonicalAppServerWorker');$included.Add('RunCanonicalAppServerWorker')}else{$omitted.Add('RunCanonicalAppServerWorker')}
    if($ManageQueueTransitions){$arguments.Add('-ManageQueueTransitions');$included.Add('ManageQueueTransitions')}else{$omitted.Add('ManageQueueTransitions')}
    if($TestOnlyAllowAlternateQueueRoot){$arguments.Add('-TestOnlyAllowAlternateQueueRoot');$included.Add('TestOnlyAllowAlternateQueueRoot')}else{$omitted.Add('TestOnlyAllowAlternateQueueRoot')}
    [pscustomobject]@{powershell_path=$PowerShellPath;lifecycle_entry_point=$LifecycleEntryPoint;arguments=@($arguments);argument_names_included=@($included);optional_arguments_omitted=@($omitted);approval_semantics=[string]$ApprovalPlan.approval_semantics;approval_ledger_consumed=[bool]$ApprovalPlan.approval_ledger_consumed}
}
