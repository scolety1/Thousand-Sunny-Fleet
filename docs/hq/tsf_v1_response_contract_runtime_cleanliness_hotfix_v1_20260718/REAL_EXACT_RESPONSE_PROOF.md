# Real exact-response proof

Command:

`node tests/run-tsf-hq-dispatch-real-readonly-v1.mjs`

Bounded real app-server rerun (isolated test queue, foreground-owned child, no product repository, plugin, credential, worker-tool network, or write authority):

- UTC terminal time: `2026-07-18T04:49:06.756Z`
- exit: `0`
- stdout SHA-256: `f0a82964d7046cc116cf636ea5c6e3833ddb398bc6e9e3db8c82bb3f44bbcfb8`
- stderr SHA-256: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- submission: `hq-submission-1dfc57f1-a0c1-4b24-9bc1-dbc3232e1719`
- preview: `hq-preview-49897e94c41c49ed9558c938a09d933b`
- preview SHA-256: `26f1f7b2e3fcbd6b4a31f18a61f025dc1730013c4d07af2ad65cde8facf9f70e`
- mission/revision: `hq2-mrpvzbh8-65793b` / `1`
- run/result: `canonical-result-hq2-mrpvzbh8-65793b-1`
- app-server PID: `48492` (exited; no orphan)
- thread: `019f738e-177c-71a0-99cf-30c0b16821d5`
- turn: `019f738e-2cc6-7892-90f4-5fdcbc003b41`
- expected and observed SHA-256: `192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627`
- semantic contract SHA-256: `62a009c3ed144b9687575881de2dd0aee1dc5d34536692357148d00835035b65`
- verifier: GREEN; result SHA-256 `29a7e4b185b7936446dc554c80969ec064c16a231060dfdac30f37079dc72ee3`
- preservation: PRESERVED; packet SHA-256 `e51301241476f63467b113de2ed6105fe7904e85219bf8d1bbd8295c7a1b0c51`; manifest SHA-256 `1b924569b0ba1bcdef499013ef480d8c5fbf2f384dac963daebde09a95f77e71`
- admission: ADMITTED_WITH_CAVEATS; receipt `admission-ivqcehclmmy5vkpkgtk5o7gn`; receipt SHA-256 `4baf9d0e24c8bbcf0955157290aa62dcca5c73c6d35386511a597bf348f8e447`

This run proves the corrected implementation path but precedes the single commit, so its reported Git HEAD/tree are the required baseline while the hotfix files are working-tree inputs. To avoid a prohibited amend or second commit, final candidate identity is self-bound by the committed production harness:

`node tests/run-tsf-hq-dispatch-production-hotfix-proof-v1.mjs`

That command must run from the newly authorized clean detached `C:\TSF_HOTFIX2_PROOF_FINAL` after the single amend and before independent review/publication. It prints final HEAD/tree, Doctor/Start/Stop identities, canonical queue path/hash, mission/result, app-server PID, thread/turn, verifier, preservation, admission receipt, sentinel detection, and final owner/listener/child/Git state. Earlier proof worktrees remain historical and are not overwritten.
