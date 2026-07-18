# Root cause: runtime dirtiness

The established canonical queue authority writes durable mission-revision records under tracked state directories in `fleet/missions`. Those generated records had no narrow Git policy. A normal admitted mission consequently left `fleet/missions/complete_ready_for_gate/<mission>.r<revision>.json` as an untracked source file.

Doctor consumed the truthful raw Git status and therefore marked the worktree unsafe. Stop did not cause the dirtiness and correctly refused to delete evidence. The defect was the missing generated-record classification for the already-established local queue root, not the queue authority or Doctor's source checks.

Correction: state-specific ignore rules cover only `fleet/missions/<known-state>/*.r*.json`. No second queue, external state store, record move, or evidence deletion was introduced.
