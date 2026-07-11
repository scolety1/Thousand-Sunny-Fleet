# Queue Binding Evidence

| Fact | Read-only | Workspace-write |
|---|---|---|
| Mission | `synthetic-tsf-readonly-appserver-0001`, revision 1 | `synthetic-tsf-workspace-appserver-0001`, revision 1 |
| Canonical queue hash | `ff91ad0c02a64479ed83df7508287ecc5864421198fd95367a182fc74fe3ace6` | `2f679e09e297686017755930f0eaf8b385c456c8b62811e14fb85425a6d4acf1` |
| Development fingerprint | `2fcffeb0bdba3c01aacd2e88483eb561792c8e12cc856fd0f2618bf6ce67b87a` | Same |
| Runtime run/result ID | `canonical-result-synthetic-tsf-readonly-appserver-0001-1` | `canonical-result-synthetic-tsf-workspace-appserver-0001-1` |
| Final queue artifact hash | `54527a771bbfa2e5cc583ac665e723c080a76e7c0095020fad068853973bf442` | `66192a8162c34f3f35be2bbb0ff825310560a4d4875dee3fc08225921dcb8613` |
| Final state | `complete_ready_for_gate` | `complete_ready_for_gate` |

The translator deterministically generated the operational mission, role extension, and worker instruction. The existing queue and transition validator moved the same bound wrapper through every state. Executed swapped-mission and role-spoof assertions fail closed. No second queue or lifecycle was introduced.
