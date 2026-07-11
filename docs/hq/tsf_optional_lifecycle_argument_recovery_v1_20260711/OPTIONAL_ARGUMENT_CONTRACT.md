# Optional lifecycle argument contract

For no-approval missions:

- `ApprovalLedgerPath` is omitted from native lifecycle arguments.
- preflight and lifecycle evidence state `NO_APPROVAL_REQUIRED`;
- `approval_ledger_consumed` is false;
- no empty or synthetic ledger is created.

For approval-required missions:

- the canonical compact `al.json` path is required;
- the file must exist, be non-empty, parse against the approval schema, match mission/action/lane/repository/path scope, and carry canonical usage binding;
- missing, empty, malformed, noncanonical, mismatched, inactive, expired, exhausted, or fixture-only approval fails closed before lifecycle or worker start;
- caller-selected paths cannot replace the canonical policy path.

The argument plan records `argument_names_included` and `optional_arguments_omitted`. It never records argument values in executor invocation-failure evidence.
