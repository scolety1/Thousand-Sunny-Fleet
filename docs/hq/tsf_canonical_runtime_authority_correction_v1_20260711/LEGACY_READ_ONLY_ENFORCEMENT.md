# Legacy Read-Only Enforcement

`preservation_packet.json` is historical evidence only. Parsing, validation, inspection, and hashing remain supported. New durable results, admissions, transactions, conflicts, preservation artifacts, and queue mutations based directly on legacy storage are prohibited.

The receipt planner fails `LEGACY_PACKET_WRITE_PROHIBITED` before constructing a writable receipt root. Tests hash the complete legacy fixture directory before and after rejected operations and require byte-for-byte identity.
