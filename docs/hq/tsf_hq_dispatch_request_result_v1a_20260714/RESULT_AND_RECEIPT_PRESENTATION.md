# Result and Receipt Presentation

The UI/API show mission/revision/run/result, route/model/effort/assurance, access/network, queue state, thread/turn when observed, worker verdict and touched/created paths, tests, mission/queue/durable/verifier/preservation hashes, verifier identity/verdict, preservation paths/status, admission verdict/reasons/caveats/receipt, replay facts, authority denials, and exact next action.

File hashes are calculated only for existing files contained by the TSF worktree. Arbitrary file contents, session tokens, stderr, prompts, credentials, and secret-like data are not rendered.

The 79-assertion HTTP/security/replay suite proves an admitted synthetic contract projection, canonical receipt-path and byte-hash projection, and separately proves that a worker-green result without an admission receipt remains `REJECTED`. The deterministic receipt identity is `b354a2a52164192d22988201bd0e0a400cf18e025d9138586321fe6bdb38d9a7`; the real receipt identity is `087259de6fc7205e171c78cfb87ca2a560ec73520c1417fd028d454a2a241beb`.
