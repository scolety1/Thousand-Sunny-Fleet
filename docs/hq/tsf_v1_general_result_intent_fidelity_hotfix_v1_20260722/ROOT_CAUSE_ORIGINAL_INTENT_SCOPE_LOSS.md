# Root cause: original intent and scope loss

The operator request remained in `original_request`, but Project Main Bot classification omitted common edit/modify/commit authority and mission preparation replaced the operative goal with a fixed read-only policy-manifest task. No contract compared original operations with the proposed and actual mission operations. A read-only substitute could therefore queue and later be described as fulfillment of the write request.

The correction binds original request evidence before submission, compares it with the proposed read-only operation set, and refuses mission allocation or queue mutation unless the comparison is queueable. Write, commit, push, merge, delete, move, install, deploy, credential, plugin, network, process, and ambiguous modification intent remain visible. A denied authority operation produces `AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION`; a local-file request without `READ_FILE` authority produces `REQUEST_UNFULFILLABLE_UNDER_CURRENT_AUTHORITY`.

The original preview is never implicit confirmation of a different reduced mission. V1 returns `TIM_REQUIRED_NO_QUEUE`; it does not implement safe-alternative acceptance.
