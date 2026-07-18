# M3 Validation Erratum V1

The accepted M3 `VALIDATION.json` is historical evidence and remains byte-unchanged. Its `adoption.hashes.status-porcelain-v2.txt` field recorded:

`c43ed4b42e4f6ea308732136199f90f9ba2d184044327841ef9820ca2734fb6a`

An independent SHA-256 of the preserved 2,024-byte file produced:

`c43ed4b42e4f4ea308732136199f90f9ba2d184044327841ef9820ca2734fb6a`

The preserved adoption bundle's own `HASHES.sha256` already contains the correct value. Its SHA-256 is `34e9079fd9e51441ed2748451bfc8351ccb0b9d79607219628b5121473fd7180`; the immutable `ADOPTION.json` SHA-256 is `d95dc30190805a59b35143811288ac0b06d5e795efcfd2f9875c7f722cb63c38`.

This is nonblocking because only a copied validation field is wrong. The adoption manifest, status bytes, archive, patches, classification, and accepted M3 source are not changed. The independent M4 Auditor rehashed the preserved bytes and immutable manifests and recorded `GREEN_NONBLOCKING` against candidate `e9d29bfb79e3b4a3da48b11887fa7a0bd8a9090e`. The machine-readable binding and disposition are in [M3_VALIDATION_ERRATA_V1.json](M3_VALIDATION_ERRATA_V1.json).
