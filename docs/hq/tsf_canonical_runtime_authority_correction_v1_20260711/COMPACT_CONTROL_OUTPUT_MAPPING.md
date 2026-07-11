# Compact Control Output Mapping

Queue-executor outputs use `rt/q/<mission-key>/<run-key>/`; lifecycle outputs use `rt/l/<mission-key>/<run-key>/`. Adapter and preservation evidence use the matching `a` and `p` identities. Fixed artifact names include `qe.json`, `lc.json`, `re.json`, `qd.json`, `m.json`, `pf.json`, `rp.json`, `wi.json`, `wr.json`, `ar.json`, `vr.json`, `ej.jsonl`, `u.json`, `q.txt`, `se.log`, `pp.json`, and `dr.json`.

The `q` and `l` trees are transient control workspaces. Admission-strength evidence is accepted only from the immutable `p` manifest and independently rehashed there.

Durable queue files are operational records under the existing queue root, not runtime artifacts. Their mission-oriented filenames remain part of the one existing queue authority and are validated by deterministic queue-document identity rather than the artifact-addressing budget.
