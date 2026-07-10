# Research Pipeline Red-Team Regression V1

Historical verdict `GREEN_RESEARCH_PIPELINE_RED_TEAM_PASS` is superseded because the prior matrix included unconditional PASS rows and cases that were not executed.

Current status: EXECUTED_ASSERTIONS_ONLY. The corrected dedicated suite records every assertion with expected and observed results. PASS rows in this directory map to assertion IDs in `docs/hq/tsf_pr11_bounded_premerge_correction_v1_20260710/EXECUTED_TEST_COVERAGE.csv`. Unrun cases are `NOT_TESTED`; features outside report-file V1 are `DEFERRED`.

The corrected coverage includes strict export containment and identifier injection, import completeness/encoding/size checks, duplicate/wrong-project/unexpected-prompt/malicious filtering, content-derived output variation, source/report attribution, agreement/disagreement preservation, and advisory/no-approval semantics. Returned ZIP import is not implemented or claimed.
