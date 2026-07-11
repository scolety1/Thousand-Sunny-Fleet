$ErrorActionPreference = "Stop"

$script:TsfRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $script:TsfRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $script:TsfRoot "tools\TsfDurableContract.Canonical.ps1")

Export-ModuleMember -Function Get-TsfContractJsonHash, Test-TsfJsonContract, Test-TsfMissionEnvelope, Test-TsfResultEnvelope, Resolve-TsfModelRouting, ConvertTo-TsfCanonicalExecutionArtifacts, ConvertTo-TsfDurableResultEnvelope, Get-TsfPolicyFingerprint, Get-TsfAdmissionDecision
