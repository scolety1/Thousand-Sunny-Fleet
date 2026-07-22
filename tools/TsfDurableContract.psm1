$ErrorActionPreference = "Stop"

$script:TsfRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $script:TsfRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $script:TsfRoot "tools\TsfDurableContract.Canonical.ps1")

Export-ModuleMember -Function Get-TsfContractJsonHash, Test-TsfJsonContract, Get-TsfExactResponseLiteralSha256, Get-TsfExactResponseLiteralFromRequest, New-TsfExactResponseContract, Test-TsfExactResponseContract, Test-TsfMissionEnvelope, Test-TsfResultEnvelope, Resolve-TsfModelRouting, ConvertTo-TsfCanonicalEffortName, Get-TsfEffortEvidence, ConvertTo-TsfCanonicalExecutionArtifacts, Test-TsfCanonicalQueueDocument, Test-TsfCanonicalQueueRecordFile, Test-TsfCanonicalVerifierIdentity, ConvertTo-TsfDurableResultEnvelope, Get-TsfPolicyFingerprint, Get-TsfAdmissionDecision, Test-TsfAdmissionRelationship, Get-TsfRecoveryEnvelopeIdentity, New-TsfCanonicalRecoveryEnvelope, Test-TsfCanonicalRecoveryEnvelope, Write-TsfRecoveryConflictDiagnostic
