# Project Main Bot Mission Intake Adapter V1

	ools/New-TsfProjectMainBotMissionDraft.ps1 converts structured or semi-structured Tim-style requests into draft mission packets. It does not execute missions.

Classifications:

- SAFE_LOCAL_MISSION
- NEEDS_MAIN_BOT_REVIEW
- NEEDS_TIM_APPROVAL
- NEEDS_CHATGPT_HQ
- BLOCKED_UNSAFE

The output wraps the existing mission packet with a role-aware extension so the existing kernel path remains compatible.
