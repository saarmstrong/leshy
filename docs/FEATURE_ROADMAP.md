# Emberwood feature roadmap

Updated: 2026-10-18. This is the current scope and implementation checklist. It supersedes earlier suggestions to recreate every part of Act I.

## Target experience

A portrait-first Godot woodland card roguelike with Inscryption-style sacrifice combat, a branching map, map events, bones, sigils, and bosses. Preserve original Emberwood art, creepy animation, right-thumb controls, and the requested 4×4 board with **two playable player rows**.

**Explicitly out of scope:** deathcard creation/collection and cabin exploration/puzzles. Neither is required to call this project complete. Acts II/III, found-footage story recreation, the ARG, and Kaycee's Mod challenge progression are also outside the current Act I-inspired scope.

Status meanings: **Implemented** works in the sandbox; **Partial** exists but is incomplete or differs from the target; **Missing** has no implementation; **Adaptation** is a deliberate product choice rather than an outstanding parity bug. These are feature-level statuses, not a percentage-complete estimate.

## Current foundation

| Feature | Status | Current behavior / remaining gap |
| --- | --- | --- |
| Godot portrait project | Implemented | Compatibility renderer, mouse/touch emulation; phone exports still need testing. |
| Emberwood visual identity | Implemented | Candlelit wood, engraved parchment creatures, serif type. |
| 4×4 board | Adaptation | Enemy queue, enemy active row, player front row, player back row. Both player rows accept squirrels and paid creatures. |
| Two-row combat | Implemented adaptation | Both player rows attack the corresponding enemy lane. Enemy attacks hit the front creature first, then the back if the front is empty. No spillover through a killed front creature yet. |
| Hand fan | Implemented | Minimized until activated, collapses on selection, unlimited hand size with pages of five. |
| Opening deal | Implemented adaptation | Shuffle main deck; deal three distinct species including a one-blood creature, plus one squirrel. This diversity rule is not an exact recreation of the original hidden opening-hand algorithm. |
| Main / squirrel piles | Implemented | Visible thumb-accessible stacks and counts. Exactly one mandatory chosen draw on later turns, no extra opening draw, rapid-tap protection, and Draw First gating. |
| Blood costs | Partial | One blood per sacrificed player creature in either row. Sacrifice eligibility, three-blood offerings, and reusable offerings work; advanced generation/death chains remain. |
| Offerings and placement | Implemented | Long press a placed creature for inline information and mark/unmark; destination selection commits. Cancel and drag cancellation supported. |
| Direct damage and health | Partial | Basic lane attacks, card death, five-point balance lead. Airborne/reach/submerge targeting and first damage modifiers work. Overkill interactions and persistent excess-damage currency remain. |
| Enemy intentions | Partial | Visible persistent queue, blocked-lane waiting, animated advance. Encounter schedules and queue refill are still a simple repeating pattern. |
| Discard / run deck | Implemented | Battle deaths/sacrifices are tracked separately from the persistent run deck. Individual upgrades and permanent shrine removals persist across encounters and saves. |
| Animations / accessibility | Partial | Draw, settle, sacrifice ash, attacks, death, 24 ember-reveal whispers, result screens, reactive skull eyes, candle smoke, moth/edge-creature motion, and reduced motion. Audio/haptics and physical-phone review remain. |
| Card collection | Partial | Thirteen resource-defined creatures, including three undead bone cards, four survival variants, and legacy hare. Shared Emberwood art and prototype balance; ten functional sigils. Remaining abilities and a larger roster remain. |
| Bones | Implemented foundation | Player deaths/sacrifices award one; valid bone-card placement spends the bank; reset each encounter. Sigil/boon modifiers remain. |
| Encounter results | Implemented adaptation | Five-point scale or combat wipeout; queued enemies protect against premature victory. Empty setup and sacrifice replacement are exempt. Explicit results drive map return. |
| Title / map / events | Partial | New/Continue title, fixed branching map, creature rewards, safe campfire, deck-thinning shrine, local saves, encounter return, and short-run ending. Full event families and regions remain. |
| Card definitions | Implemented | Shared editor-facing Resources for IDs, stats, cost type, tribe, sacrifice eligibility, sigil metadata, artwork, and role. Runtime state is copied and separated from permanent/temporary upgrades. |

Implementation: `scripts/attack_preview.gd`, `scripts/ritual_card.gd`. Checks: `tests/ritual_flow.gd`. The latest checks exercise both rows, squirrel placement, cross-row sacrifice, front shielding, back-row attacks, long-press behavior, draw gating, large hands, and varied mixed deals in both motion modes.

## Priority 1 — complete the combat rules

- [x] **Basic bones:** one bone per player death/sacrifice, visible bank and pickup, costs paid on valid placement, no enemy-death rewards, and reset per encounter. Added Bone Stoat (2), Grave Raven (4), and Carrion Hound (6), starter/reward integration, and insufficient-resource feedback. Sigil/boon modifiers remain with their respective systems.
- [x] **Card definitions:** thirteen editor-facing `.tres` resources with IDs, base stats, blood/bone costs, tribes, sacrifice eligibility, sigil lists, artwork, and role text. Shared catalog used by battle/map/inspectors/save validation. Permanent run bonuses, temporary battle bonuses, current damage, and copied sigil lists remain isolated. Ten supported sigils execute through the rule resolver; remaining batches are pending.
- [x] **Core rule events:** pure synchronous play/attack resolvers return ordered payment, sacrifice, damage, retaliation, death, bone, and outcome events. Animation presents an already-resolved action. Draw, spawn, and reserve movement are journaled; return-to-hand works for player Unkillable cards; advanced generation/movement trigger families remain.
- [ ] **Sigil engine:** first ten effects work through the rule resolver, including combined targeting/retaliation and modifier ordering. Remaining sigil batches, generated-card effects, movement, resurrection, and broader hooks remain.
- [ ] **Combat edge cases:** overkill into the enemy queue, blocked and direct attacks, death-trigger chains, invalid targets, resource exceptions, simultaneous outcomes, and multiple-strike sequencing.
- [x] **Exhausted piles:** escalating starvation pressure resolves exhausted-pile stalemates. Deliberate adaptation: direct balance damage rather than a growing Starvation creature; see `docs/BALANCE.md`.
- [ ] **Balance rewards:** excess damage becomes spendable teeth; distinguish a battle ending from a run ending.
- [ ] **Battle setup:** load encounters and run deck state, apply starting boons/items, seed randomness, and restore health/resources appropriately between fights.

### Sigil rollout

| Batch | Effects to support | Acceptance example |
| --- | --- | --- |
| A: targeting and defense — implemented | Airborne, Mighty Leap, Waterborne, Stinky, Sharp Quills, Touch of Death | A flying attacker bypasses an ordinary blocker but is caught by a reach blocker; submerged cards behave differently on their owner's attack turn. |
| B: sacrifice and survival — implemented | Worthy Sacrifice, Many Lives, Unkillable, Bone King | A three-blood offering funds a high-cost card; a reusable offering remains; returning cards preserve the right modifications. |
| C: strikes and movement | Bifurcated / Trifurcated Strike, Sprinter, Hefty, Guardian, Burrower | Each strike resolves in order and movement respects board occupancy. |
| D: generation and scaling | Fledgling, Rabbit Hole, Ant Spawner / ant power, Bees Within, Dam Builder, Bellist, Fecundity, Hoarder, Trinket Bearer | Generated cards enter the correct zone and scaling power updates after a board change. |
| E: remaining target roster | Inventory remaining Act I sigils and special card rules against the chosen card list | Every shipped card has functioning rules, inspector text, animations, and interaction checks. |

This is a rollout list, not a claim that every original sigil is listed. Confirm exact effect behavior when implementing each batch. The two player rows need explicit targeting/movement decisions for every sigil; mark those adaptations in the card rules.

## Priority 2 — playable branching run

- [ ] Run state: persistent deck, upgrades, teeth, items, lives/candles, current region/node, random seed, encounter history.
- [x] Short portrait branching map with reachable choices, persistent path closure, event screens, deck inspection, and confirmation of permanent shrine removal. Larger maps, event symbols, and procedural generation remain future work.
- [ ] Regions and encounter pacing: authored encounter pools, difficulty curves, normal/totem battles, boss at each region end, final encounter.
- [ ] Card rewards after eligible battles, including ordinary/rare pools and meaningful choices.
- [ ] Save/resume: versioned local map/event autosave and title-screen Continue are implemented. Pending battles restart the encounter. Mid-battle restore and physical-phone background/resume validation remain.
- [x] Defeat/restart flow **without deathcards**: result → run defeat → title → fresh run. Both scale and wipeout defeats are routed correctly. Persistent unlocks are not yet implemented.

### Required map events

- [ ] Card rewards: basic three-creature choice now adds one card permanently. Cost/tribe selection and larger reward pools remain.
- [ ] Sacrifice stones: remove a donor and transfer permitted sigils to a recipient.
- [ ] Campfire: one safe +1 attack / +2 health upgrade to an individual run card is implemented. Survivor risk and repeat warming rules remain.
- [x] Initial backpack event: three-pocket inventory, inspect/confirm, one chosen tool, full-inventory replacement, and leave handling. Complete empty-slot refill and broader resupply pools remain.
- [ ] Trapper and Trader: teeth purchases, pelts, and card exchanges.
- [ ] Woodcarver: tribe/sigil totem pieces, assembly, persistence, and application in battle.
- [ ] Mycologists: merge eligible duplicates, carrying appropriate stats/sigils forward.
- [ ] Cave trial: explicit deck test, pass/fail resolution, and reward.
- [ ] Bone Lord: permanent card removal in exchange for a run boon; implement any special-case rewards deliberately.

Reference event families: [Events](https://inscryption.fandom.com/wiki/Events), [Campfire](https://inscryption.fandom.com/wiki/Campfire), [Mycologists](https://inscryption.fandom.com/wiki/The_Mycologists), [Woodcarver](https://inscryption.fandom.com/wiki/The_Woodcarver). Cabin unlock requirements should become direct map/run unlocks where needed, because puzzles are excluded.

## Priority 3 — items and bosses

### Items

- [x] Thumb-accessible three-pocket inventory, inspect/target/use/cancel, and consumption only on valid use; carried through battles and saves.
- [x] Initial useful set: bottled squirrel, pliers, scissors, hourglass, Bone Fan, and fish hook. Remaining Act I item audit is pending.
- [ ] Duration, generated squirrel, stolen ownership and both-row targeting are tested. Boss restrictions, the broader item pool and item-aware full-run balance remain.

Items are combat tools, not blood offerings by default. Reference inventory: [Items](https://inscryption.fandom.com/wiki/Category%3AItems).

### Boss encounters

- [ ] **Prospector:** authored phases, board conversion to gold, pack-mule reward, recovery pacing.
- [ ] **Angler:** telegraphed card theft, bait buckets / sharks, phase changes.
- [ ] **Trapper / Trader:** traps and pelts followed by the trading phase and resulting battle.
- [ ] **Final opponent:** multi-phase mask mechanics, deathcard-free replacement encounter roster, final large-board threat analogous to the Moon, and completion screen.
- [ ] Boss life/candle rules, transitions, rewards, difficulty tuning, encounter-specific dialogue, and distinct sound/animation cues.

Use original visual identities and writing. Reproduce the strategic purpose of each boss while adapting all board-wide and targeting effects to two player rows. Deathcards will not be generated or collected, even where an original boss would use them. Reference phase overview: [Leshy](https://inscryption.fandom.com/wiki/Leshy).

## Presentation and delivery work

- [ ] Original card art for the chosen roster, sigil icons, map/event art, items, boss portraits/masks, and encounter environments.
- [ ] Sound effects, creature impacts, sacrifice audio, ambient room tone, music, and independent volume controls.
- [ ] Rulebook / sigil glossary, onboarding, readable costs, active-effect inspection, and clear feedback during locked animations.
- [ ] Device safe areas, responsive layout, large-hand navigation, real touch testing, battery/performance profiling, and export presets.
- [ ] Android and desktop builds first; validate additional platform toolchains independently.
- [ ] Encounter/resource/sigil regression tests, seeded run playtests, full-run completion, interrupted save/resume, and accessibility review.

## Suggested build order and completion gates

1. **Combat vertical slice:** bones + data-driven cards + sigil batches A/B + edge-case rules. Gate: one meaningful encounter with mixed blood/bone cards and reproducible rule checks.
2. **Short run:** branching map + persistent deck + rewards + sacrifice stones + campfire + save/resume. Gate: a complete small run with decisions that affect later encounters.
3. **Strategic variety:** remaining map events + items + totems + sigil batches C/D. Gate: several distinct viable deck strategies across a run.
4. **Boss campaign:** three regional bosses and final opponent, remaining card/sigil audit, tuned progression. Gate: start-to-finish campaign with no deathcard or puzzle dependency.
5. **Phone release pass:** art/audio completeness, performance, safe areas, exports, and balance. Gate: a full run on a physical phone with reliable one-handed input and resume.

Do not declare original-game parity solely because basic card placement works. Completion means the agreed combat-and-map scope above works as a complete run. Optional cabin/story/deathcard content is not a blocker.

## Current checkpoint and next work

**Completed foundations:** title and short branching run; safe card events with individual persistent upgrades; visible main/squirrel piles and mandatory draw; 4×4 / two-player-row combat; stacked blood payments; basic bones and undead cards; inline long-press offerings; explicit scale/wipeout endings; 24 varied animated transitions; and shared card Resources. The shrine still only thins the deck, and The Thicket is a normal encounter rather than a multi-phase boss.

**Next:** sacrifice stones for sigil transfer, then sigil batch C (multiple strikes and movement). Batches A and B, animated sigil badges, four survival reward variants, a three-pocket usable satchel with six initial tools, and an optional backpack map branch are implemented. See `docs/SIGIL_RULES.md` and `docs/ITEMS.md`.

**Deliberate adaptations:** two playable player rows, shuffled three-species opening guarantee, combat wipeouts, and no deathcards/cabin puzzles. These remain product decisions rather than original-game parity claims.

**Checks:** `tests/battle_rules.gd` (pure events and six sigils), `tests/sigil_playback.gd` (animation/model integration), `tests/card_definitions.gd` (catalog/schema, modifier isolation, sacrifice eligibility), `tests/ritual_flow.gd` (board/hand/draw/hold), `tests/bones_flow.gd` (blood/bone economy), `tests/draw_phase.gd` (mandatory draw), `tests/end_state.gd` (results/whispers), `tests/run_flow.gd` (map/events/save/return).

### Animation and balance checkpoint

- [x] Living engraved portraits with reduced-motion support; irregular main-skull eye glimmer; three right-skull hauntings and growing teeth as the round counter.
- [x] All undead attack through complete rounds and deal face damage from either player row. Explicit Stinky/zero-attack feedback.
- [x] Shared encounter/opening setup, 1,200 seeded encounter probes, reproducible losing seeds, per-creature play/attack metrics, broad difficulty alarms, and a bounded full-suite runner.
- [x] Exhausted-pile stalemate protection: escalating direct starvation pressure, a deliberate adaptation rather than the original growing creature.
- [ ] Rewarded/upgraded deck cohorts, six-bone Carrion Hound affordability, full-run/boss simulations, human difficulty calibration and physical-phone playtests.

See `docs/BALANCE.md` and `reports/balance-latest.json`. These probes do not establish full-game balance or original-game parity. The next gameplay feature is sigil-transfer stones, followed by strike/movement batch C.


### Survival sigils and item checkpoint

- [x] Worthy Sacrifice, Many Lives, Unkillable, Bone King; weighted blood payments, retained occupied slots, preserved return-to-hand modifications, and repeated death rewards.
- [x] Animated idle and triggered sigil glyphs with reduced-motion behavior; four reward-card variants using matching existing creature portraits.
- [x] Six usable tools, three-pocket satchel, inspect/target/cancel, per-round effect cleanup, generated squirrels, and hooks into either player row.
- [x] Optional Old Satchel map branch, one-tool choice, full-inventory replacement, and persistent consumption.
- [ ] Item-aware / new-reward-deck balance cohorts, full mid-battle restoration, enemy-hand survival-sigil AI, additional items and boss restrictions.

New checks: `tests/survival_items_rules.gd`, `tests/survival_items_flow.gd`. Full suite: `python tests/run_checks.py`. Captures: `35-survival-sigils.png` through `40-animated-sigils-satchel.gif` in `docs/mockups/`.

### Permutation and randomized testing checkpoint

- [x] 105,514 bounded combat/payment/item/ownership cases with independent expected-effect checks.
- [x] Seeded mixed-deck/stat/sigil/item battles, invariant accounting, exact action-trace replay, and saved failure seeds/artifacts.
- [x] Real-scene randomized reachable paths, reward/upgrade/removal/backpack commitment, card UID checks and save/resume boundaries.
- [x] Prompt-error/timeout test runner, quick/stress/seed/replay commands and machine-readable results.
- [x] Roster coverage manifests require extending tests for new supported sigils/items; illegal hand/reserve/wrong-slot attacks fixed and fixture-protected.
- [ ] Production randomized map/RNG persistence, full mid-battle saves, future boss/trigger coverage, realistic item-aware balance cohorts and physical-device tests.

Full details: `docs/TESTING.md`. Default suite: 16 scripts; existing starter balance probes remain separate from synthetic randomized correctness stress tests.
