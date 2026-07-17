function ConvertTo-TsfHqDispatchDoctorHumanLinesV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Report
    )

    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add(("TSF HQ Dispatch Doctor V1: {0}" -f $Report.overall_status)) | Out-Null
    $lines.Add(("Safe to start: {0}" -f $Report.safe_to_start)) | Out-Null
    $lines.Add(("Repository: {0}" -f $Report.repository.top)) | Out-Null
    $lines.Add(("Commit: {0}" -f $Report.repository.head)) | Out-Null
    $lines.Add(("Listener: {0}:{1} ({2} listener(s))" -f $Report.listener_state.host, $Report.listener_state.port, @($Report.listener_state.listeners).Count)) | Out-Null
    $lines.Add(("Process owner: {0}" -f $Report.process_owner.disposition)) | Out-Null
    $lines.Add(("Path budget: {0}/{1}" -f $Report.path_budget.maximum_path_length, $Report.path_budget.target_limit)) | Out-Null
    $lines.Add(("Pending TIM_REQUIRED: {0}; interrupted: {1}; replay conflicts: {2}" -f $Report.pending_tim_required_requests, $Report.interrupted_missions, $Report.duplicate_replay_conflicts)) | Out-Null

    foreach ($check in @($Report.checks)) {
        $identifier = [string]$check.id
        $status = [string]$check.status
        $nextAction = [string]$check.next_action
        if ([string]::IsNullOrWhiteSpace($identifier)) { throw 'TSF_HQ_DOCTOR_CHECK_LABEL_MISSING' }
        if ([string]::IsNullOrWhiteSpace($status)) { throw "TSF_HQ_DOCTOR_CHECK_STATUS_MISSING:$identifier" }
        if ([string]::IsNullOrWhiteSpace($nextAction)) { throw "TSF_HQ_DOCTOR_CHECK_NEXT_ACTION_MISSING:$identifier" }
        $lines.Add(("[{0}] {1}" -f $status, $identifier)) | Out-Null
        $lines.Add(("  Next: {0}" -f $nextAction)) | Out-Null
    }

    $lines.Add(("Exact next action: {0}" -f $Report.exact_next_action)) | Out-Null
    $lines.Add('Diagnostic output excludes the local stop capability and operator-session tokens.') | Out-Null
    return @($lines)
}
