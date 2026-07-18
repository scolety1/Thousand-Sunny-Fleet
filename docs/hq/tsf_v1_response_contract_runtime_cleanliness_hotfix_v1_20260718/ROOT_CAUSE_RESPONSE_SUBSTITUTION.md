# Root cause: response substitution

`tools/hq-dispatch/v1/New-TsfHqDispatchGovernedMission.ps1` was the authoritative substitution layer. It hardcoded the M2A compatibility fixture literal into every governed mission's `normalized_goal` and hardcoded the corresponding SHA-256 (`106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba`) into the required result test.

The downstream worker adapter, verifier, preservation, and admission components correctly enforced the mission they received. They therefore truthfully verified the substituted old literal instead of the operator's reviewed request. The fixed fixture behavior was not the defect; promoting its literal to an unrelated authoritative default was.

Correction: mission preparation now derives an exact result test only from a validated reviewed `EXACT_LITERAL_V1` contract. A request without an explicit exact literal receives `GENERAL_RESULT_V1`; it receives no fabricated M2A literal.
