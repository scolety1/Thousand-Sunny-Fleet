# Synthetic Repository Registration V2

`SYNTHETIC_REPOSITORY_REGISTRATION_V2` binds the exact root, Git top-level,
branch, baseline commit and tree, baseline subject, complete thirteen-file
inventory, per-file hashes, expiry, contract version, and zero-remotes fact.

The deterministic seeder accepts only an absent root or the exact empty root.
It rejects reparse roots, parent Git capture, inventory drift, a different
branch, a dirty state, and any remote. It creates the allowlisted files, runs
local `git init`, and makes one setup commit:

`chore: seed synthetic iteration pilot v2`

Setup is not a coding mission. It creates no remote and performs no network
operation. Duplicate or non-empty setup attempts fail rather than overwrite or
delete evidence.
