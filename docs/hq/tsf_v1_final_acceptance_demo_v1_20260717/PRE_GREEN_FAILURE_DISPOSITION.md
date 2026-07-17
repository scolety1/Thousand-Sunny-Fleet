# Pre-GREEN Run Disposition

The acceptance record retains both pre-GREEN runs. Neither is presented as a successful proof, and neither was erased.

## Run `20260717T213454796Z-31348`

- Tested commit: `ee9112884bcb19f78fe78b9ca56692337ff567e8`.
- Summary SHA-256: `cd66606286e0ce3567185c2ca08a56a01d2c5499e026daf0d0cdd168a0ffbcb4`.
- Disposition: `FAIL`, preserved.
- The real interruption barrier did not become ready inside an outer 90-second test wait after the preceding governed preparation work consumed most of that interval. The bounded test wait was raised to 240 seconds, still inside the existing worker and executor hard bounds; no runtime timeout or mission behavior changed.
- The HQ chokepoint test wrote generated validation bytes into tracked fixture paths. Its generated output was redirected to the run evidence root, and the tracked fixtures were restored byte-for-byte from the candidate index.
- The final Doctor and cleanup rows were downstream failures; the run retained its evidence and terminated without an orphan process or listener.

## Run `20260717T215248491Z-32112`

- Tested commit: `19f275f6fdcc1319d181f54867d6e645b157cd9f`.
- Summary SHA-256: `43239d7b50bcb6c7868ad4e65d32bb7a12680f506ee40b79a1dfab33d4fe022f`.
- Disposition: `FAIL`, preserved.
- Static integrity looked only at uncommitted changes and therefore could not discover corrections after they were committed. It now evaluates the committed `origin/main...HEAD` candidate diff plus any working-tree changes.
- Reusing fixed synthetic mission identities across independent canonical matrix runs caused the preserved artifacts to be classified, correctly, as conflicting replays. Every matrix run now uses a nonce-bound synthetic identity. Two consecutive 149-assertion runs then ended with zero replay conflicts.
- The blocked real proof and final Doctor rows were downstream of the static gate and preserved fixture conflicts; no real proof was started in this run.

## Preservation before the GREEN run

All 1,375 pre-GREEN canonical runtime fixture files were moved, not deleted, into an ignored M4 evidence archive. `ARCHIVE_MANIFEST.json` records every relative path, byte count, and SHA-256. `ARCHIVE_VALIDATION.json` confirms the before/after file counts and hashes are identical. The manifest and validation hashes are bound by `ACCEPTANCE_SEAL.json`.

The final all-up run on `b2ea672031b610bb82065fb571189b09689cf3d7` passed 21 of 21 gates, including 83 real app-server assertions and final cooperative cleanup.
