# Writeset and Command Containment

An `APPROVED_WRITESET_V2` binds the registration, task binding, repository,
branch, predecessor commit, iteration, run, one exact source path, preimage and
replacement hashes, atomic operation, zero in-repository temporary files, and
the closed command-template set.

Paths must be canonical forward-slash repository-relative strings and exact
members of the task allowlist. Resolution, realpath, and component inspection
reject parent/sibling escape, case or separator bypass, absolute/UNC/device
paths, ADS, wildcards, control or encoded forms, short names, trailing dots or
spaces, reserved devices, direct `.git`, nested Git, symlink, junction, mount,
and reparse traversal.

Commands execute without a shell from an absolute, hash-checked executable,
exact working directory, and one of thirteen
`APPROVED_COMMAND_TEMPLATE_V2` records. Git and Node are never selected through
inherited `PATH`. The child environment is constructed from a closed allowlist:
`PATH` is empty, platform and temporary directories are fixed, Git prompting,
global configuration, and hooks are disabled, and credential-like parent
variables are not inherited.

Each proposed replacement must equal one of the exact content hashes pinned for
that task and iteration in the static authority. Registration validation also
requires the exact thirteen-key fixture file-hash map, preventing
shape-compatible file substitution.

Shell metacharacters, redirection, environment expansion, wildcards, package
commands, remote Git, push, destructive Git, alternate working directories, and
unlisted arguments fail before process launch.
