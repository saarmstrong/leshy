# Emberwood project plan

Updated: 2026-10-18.

Build a minimal, beautiful woodland-horror card roguelike in Godot for portrait phones, with desktop and additional platform exports validated separately. The chosen motif is **Emberwood**: candlelit timber, aged parchment, original engraved animals, restrained amber light, and tactile, creepy card animation.

## Accepted product decisions

- Preserve a **4×4 grid**: enemy reserve, active enemy row, player front row, player back row.
- Both player rows accept creatures, including squirrels. Both rows attack the matching enemy lane; the front shields the back from enemy attacks. This is a deliberate extension of the original game's board.
- Separate main and squirrel piles. Open with three mixed main-deck species including a one-blood play, plus one squirrel. Choose one draw from either pile on later turns.
- Keep an unlimited hand in a minimized fan below the grid. Expand to select; collapse for placement. Draw, hand, and end-round actions favor the right thumb.
- Long-press placed creatures for inline offering information and mark/unmark. Only placement commits a sacrifice.
- Preserve reduced motion and make turn resolution readable.
- Target a full combat-and-map run: **branching map, map events, bones, sigils, items, and bosses**.
- **Exclude deathcards and cabin puzzles/exploration.** They are not completion requirements. Use original artwork and writing; no reproduction of later acts or ARG is planned.

## Current build

Godot sandbox with engraved creature assets, sacrifice/placement/attack/round animations, visible enemy intentions, two playable player rows, shuffled mixed opening deals, separate squirrel draw, deck inspection, discard tracking, long-press offerings, and five-point balance outcomes. Prototype stats and encounter scripts remain incomplete; the short run now has a title screen, branching map, creature rewards, safe campfire upgrades, deck-thinning shrine, local save/resume, and encounter-to-map transitions. Basic bones and three bone-cost undead creatures are now implemented, including starter decks and map rewards. Six targeting/defense sigils now function through the pure play/attack resolver. Remaining sigils, items, multi-phase bosses, and audio are outstanding.

## Implementation and delivery

Continue from the shared card definitions, pure play/attack rules, bones, first sigils, and persistent short run. Next extend sacrifice/survival sigils and trigger families, then remaining map events, item inventory, and boss encounters. Keep seeded randomness and versioned saves. Validate Android and desktop first, then other export targets. Check layout, safe areas, touch, performance, pause/resume, and accessibility on a physical phone.

The canonical feature checklist, priorities, completion gates, and source references are in [docs/FEATURE_ROADMAP.md](docs/FEATURE_ROADMAP.md). The README documents current controls; `tests/ritual_flow.gd` checks the current flow in both motion modes. Art prompts and assets are in `assets/art/`; visual iterations and rendered captures are in `docs/mockups/`.

## Draw presentation

Keep a visible normal-creature pile alongside the separate squirrel pile at the bottom, near the right thumb. The creature pile includes both blood and bone cards. Show remaining counts and an explicit Draw First gate. Require exactly one chosen draw on each later turn; lock both piles during/after the draw and prevent playing or ending the round beforehand. Opening deal is the existing exception. Preserve the 4×4 board and hand fan.

## Encounter endings and turn presentation

Add deployed-army wipeouts alongside scale outcomes: a player loses on a combat death that empties both player rows; the opponent loses when a combat death leaves both its active and queued rows empty. Opening emptiness and sacrifice-to-replacement gaps do not trigger defeat. Hand/draw cards do not protect a wiped-out deployed army. This is an intentional adaptation. Store an explicit win/loss outcome so map progression does not infer victory solely from the damage balance. Show a blocking result panel and continue to map/run defeat.

Turn changes now use 24 shuffled, non-repeating original lines, amber text reveal, etched-rule expansion, ember drift, and a dark-table fade. Provide a quiet full-text fade variant for reduced motion.

## Card-data foundation

Completed the next parity item: nine native Godot card-definition Resources and a shared catalog. Definitions contain stable identity, base stats/costs, tribe, sacrifice eligibility, sigil metadata, artwork, and role text. Map, battle, inspection, and save validation share this source. Runtime damage and temporary modifiers cannot alter the shared resource or permanent run upgrade data. Existing saves keep the same IDs. The initial ordered resolver and six sigil effects are now implemented, with later batches still pending.

## Rules and atmosphere checkpoint

Core play/attack rules now resolve synchronously into ordered events before animation playback. First sigil batch A is functioning, with card glyphs and inspector explanations. Added reactive skull eyes and header/edge-only ambient movement across title, map, events, and battle. Costs are restrained top-left symbols/numbers, following the latest feedback. Reduced motion quiets the scenery. Next is sacrifice/survival sigil batch B. See `docs/SIGIL_RULES.md` and the updated parity list.

### Living-card and balance checkpoint

Implemented portrait breathing/ink shimmer, irregular central-skull eye glimmer, and three right-skull hauntings. The right skull's growing teeth count rounds exactly (including round one), with extra ghost-jaw rows; all reset between encounters. Reduced motion leaves card portraits still. The 4×4 board and small top-left costs are preserved.

Added deterministic balance probes using shared production encounter/opening data and the rule resolver, full-round and face-damage checks for every undead card in both player rows, explicit zero-attack Stinky feedback, and a bounded full-suite runner. Tuned visible run openings and added escalating starvation pressure after both draw piles exhaust to resolve equal-damage stalemates. Baseline and limitations: `docs/BALANCE.md`; raw metrics: `reports/balance-latest.json`. Reward-deck/Carrion Hound affordability, physical phone playtests and full-run/boss balance remain outstanding.

### Survival and tools checkpoint

Batch B is implemented: Worthy Sacrifice, Many Lives, Unkillable, Bone King; four resource-defined reward variants, weighted blood UI, reusable-slot protection, return-to-hand preserving modifications, repeated-death accounting, and animated/trigger-reactive sigil icons. Their portraits currently reuse matching Emberwood animal art.

Added a three-pocket usable satchel, all six initial tools, native animated icons, confirmed targeting/cancellation, two-row hook placement, duration cleanup, inventory persistence, and a reachable backpack branch with one-tool choice/replacement. The original starter deck and six-item-free encounter balance benchmark remain comparable; new reward decks/items still need broader balance sampling. Next gameplay batch: multiple-strike and movement sigils, plus the pending sigil-transfer stones event. Details: `docs/ITEMS.md`, `docs/SIGIL_RULES.md`; checks: `tests/survival_items_rules.gd`, `tests/survival_items_flow.gd`.

### Permutation and randomized-test checkpoint

Added bounded exhaustive combat/payment/item/ownership matrices (105,514 cases), seeded mixed-deck battles with upgrades and combined sigils/items, full action-trace replay, and actual-scene randomized path/save testing. Shared contracts enforce ownership, unique live cards, board shape, stats, input/copy isolation, bone accounting, item conservation, return semantics and terminal ordering. Coverage manifests force explicit expected-effect updates for new sigils/items. The sweep exposed and fixed invalid hand/reserve/wrong-slot attacks and stale node reentry after defeat; its original attack case is a regression fixture and real-scene tests protect terminal run states.

The runner now reports as checks finish, stops early on script errors, supports quick/stress/seed/replay options, and writes machine-readable results. A 4,096-seed stress run passed 77,086 actions; default real-scene paths include all current event families and pending/committed save boundaries. See `docs/TESTING.md`. These checks do not replace item-aware difficulty tuning, real-device validation or tests for future unimplemented mechanics.
