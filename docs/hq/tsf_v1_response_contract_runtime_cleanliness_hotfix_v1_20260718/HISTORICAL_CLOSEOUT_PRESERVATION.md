# Historical closeout preservation

The original and V2 closeout worktrees and external review packets were read only.

- Original packet: `C:\TSF_REVIEW\tsf_v1_post_merge_closeout_20260718`; 8 manifest files; inventory digest `7a834e21c32f396f80a25dc81d49b91b15f4bd26b01c18c0b158cc931daeac91`; `HASHES` SHA-256 `e88f413ff486dc69e1c8711902a446b7f2d414d886980bca9feef8fd7a89109b`.
- V2 packet: `C:\TSF_REVIEW\tsf_v1_post_merge_closeout_v2_20260718`; 9 total files, including the 8 rows listed by `HASHES.sha256`; preserved deterministic inventory TSV 878 bytes with SHA-256 `af4a89955bedfdb561b306fd7be1d0210143d678b81189db147027ecd9605a37`.
- V2 manifest: `C:\TSF_REVIEW\tsf_v1_post_merge_closeout_v2_20260718\HASHES.sha256`; 771 bytes; filesystem-byte SHA-256 `8b091ea39d16e5140f7a21c1885c4a35430bea3699271071768e05da37b331fe`; hash domain `FILESYSTEM_SHA256_V1`; recomputed at `2026-07-22T01:06:01.5731870+00:00` with `Get-FileHash -LiteralPath 'C:\TSF_REVIEW\tsf_v1_post_merge_closeout_v2_20260718\HASHES.sha256' -Algorithm SHA256`; all 8 listed rows rehashed successfully.
- Preserved V2 queue record: `C:\TSF_CLOSEOUT_V2\fleet\missions\complete_ready_for_gate\hq2-mrqnvg63-6f3cf5.r1.json`; state `complete_ready_for_gate`; mission `hq2-mrqnvg63-6f3cf5`; revision `1`; 27,245 filesystem bytes; SHA-256 `f5c94e80b3b1ebbab0444881639f286e0cbd6436fb4cc96fa2c957b10bd58d31`; recomputed at `2026-07-22T01:06:01.5731870+00:00` with `Get-FileHash -LiteralPath 'C:\TSF_CLOSEOUT_V2\fleet\missions\complete_ready_for_gate\hq2-mrqnvg63-6f3cf5.r1.json' -Algorithm SHA256`.
- The V2 queue document passed `Test-TsfCanonicalQueueDocument` with zero errors under its exact historical canonical authority, HEAD `7cceadcf6fa6a6c65000c72604023f87fc84f728`, tree `b6abd94055b60f77666b2f1ba807c6016537c1dd`; its canonical contract JSON SHA-256 was `bcde7f604aeff75550eb0d82105b8bdb7ca47fa410f6ffc50c5ef47bb961d2ce`. A newer hotfix translator reports deterministic-translation drift and is not used to relabel the immutable historical document.
- V2 Git status remained exactly the single preserved untracked record identified above; the original closeout remained clean.

No byte in `C:\TSF_CLOSEOUT`, `C:\TSF_CLOSEOUT_V2`, either external packet, the preserved mission/result/verifier/preservation/admission evidence, or its receipt was deleted, moved, relabeled, or rewritten.
