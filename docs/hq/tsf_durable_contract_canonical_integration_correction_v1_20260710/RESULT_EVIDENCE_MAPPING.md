# Result Evidence Mapping

`ConvertTo-TsfDurableResultEnvelope` maps existing runtime evidence into `tsf_result_envelope_v1`.

Artifact hashes are recomputed from canonical repository paths. Git and repository facts come from the kernel Git observer. Test records are kernel-observed, verifier results are verifier-observed, and model claims remain unverified unless adapter/native evidence supplies a stronger assurance. Agent narrative is retained only as reported action text and never proves files, hashes, tests, approvals, or authority.

Evidence classes are `NATIVE_OBSERVED`, `ADAPTER_OBSERVED`, `KERNEL_OBSERVED`, `FILESYSTEM_OBSERVED`, `VERIFIER_OBSERVED`, `AGENT_REPORTED`, and `UNVERIFIED`.
