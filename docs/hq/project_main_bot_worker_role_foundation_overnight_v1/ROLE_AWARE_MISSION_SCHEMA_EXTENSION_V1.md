# Role-Aware Mission Schema Extension V1

This extension keeps mission_schema_v1.json compatible by wrapping role metadata beside the existing mission packet rather than adding unknown fields to the existing schema.

Recommended draft shape:

`json
{
  "draft_schema": "project_main_bot_mission_draft_v1",
  "classification": "SAFE_LOCAL_MISSION",
  "mission_packet": { "...": "existing mission_schema_v1 payload" },
  "role_extension": { "...": "role-aware extension payload" }
}
`

The existing kernel can still validate mission_packet. The role-aware preflight checker validates ole_extension and permission profiles before worker handoff.

This avoids breaking existing V1 missions while making worker roles operationally visible.
