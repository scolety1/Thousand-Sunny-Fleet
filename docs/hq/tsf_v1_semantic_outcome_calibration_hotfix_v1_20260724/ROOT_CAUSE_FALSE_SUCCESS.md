# Root cause: false success

The V1 structured worker claim did not separate the worker's own completion status from the answer body. `Get-TsfStructuredClaimContradictionDisposition` scanned `answer` with anchored lexical patterns. The list was inevitably incomplete: contractions, passive voice, and indirect incompletion could evade it while the worker reported `FULFILLED` and `completed_deliverables`.

The same classifier was reused by lifecycle result construction and admission. Worker-declared deliverable IDs were projected as observed before independent content verification. A successful transport plus a nonempty answer could therefore contribute to an incorrect fulfillment result.

Primary architecture classification:

`WORKER_CLAIM_AND_ANSWER_CONTENT_NOT_SEPARATED`

The correction does not expand the lexical list. It makes closed worker-own fields and verifier-observed deliverables the only semantic inputs. Answer prose cannot supply or contradict worker status.
