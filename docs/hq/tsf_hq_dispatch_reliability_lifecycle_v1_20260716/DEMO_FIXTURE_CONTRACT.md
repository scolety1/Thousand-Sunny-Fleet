# Demo Fixture Contract

Demo uses only `.codex-local/fixtures/hq-dispatch-demo-v1` (and the committed HTTP test's sibling fixture root). It requires no product repository, plugin, credential, or network and launches no real app-server. UI and output label it fixture behavior.

It deterministically presents Milestone 1 preview, Milestone 2A request-to-result/admission projection, and Milestone 2B TIM_REQUIRED response/new-revision behavior. `-ResetFixture` is explicit and may remove only the exact demo root after containment validation; scenario 21 proves a sibling marker survives. Demo runs in the foreground, uses the same exact owner protocol and fixed loopback listener, and can be stopped only through verified Stop.
