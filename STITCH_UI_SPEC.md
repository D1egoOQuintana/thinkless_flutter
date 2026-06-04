# ThinkLess — Stitch UI Spec

## Visual Direction
Warm Minimal Academic Productivity.

## Palette
Background: #fffaf6
Text/Dark: #302f35
Primary: #086779
Accent: #ea582a

## Rules
- No dark app.
- No black background.
- No gamer UI.
- No neon.
- No generic Material/Flutter look.
- Light warm academic interface.
- Primary actions use teal.
- Coral only for small accents/urgent cues.
- Cards are soft, rounded, warm, with subtle shadows.
- Typography: Plus Jakarta Sans for headings, Inter for body.

## Screens to implement
1. Home / Today
2. Empty Home
3. Calendar Month
4. Calendar Week
5. Calendar Day
6. Focus Start
7. Focus Running
8. Matrix
9. Profile
10. Scanner
11. Voice
12. Task Detail
13. Alerts
14. Priority Organizer
15. Quick Capture
16. Day Review
17. Task Edit

## Implementation Strategy
First update global theme and reusable UI components.
Then implement screens one by one.
Do not touch business logic.
Do not change TaskItem.
Do not change persistence.
Do not change GroqService.
Do not change callbacks.