# The Hollow — Emberwood

Portrait-first Godot card roguelike prototype. Open `project.godot` in Godot 4.7.2 and press **F5** for the title screen. **Begin a New Run** opens the branching map. Select the highlighted starting event, then follow connected paths.

The **4×4 layout remains**: enemy reserve, active enemies, your front row, and your back row. Both player rows are playable, including for squirrels. The hand fan sits below the board and overlays the near row only while expanded. The enemy stack remains visible for planning.

## Right-handed controls

- Tap **Hand** or the little bottom fan to expand it. Tap a card to select it and tuck the fan away. Additional cards are reachable using the fan's page arrows; there is no hand-size limit.
- **Main** and **Squirrel** are separate piles near your right thumb. On later turns, choose exactly one draw before playing or ending the round. The two piles cannot both be drawn from in one turn.
- Opening hand: three different shuffled main-deck species (including a one-blood creature) and one free squirrel; no extra first-turn draw. The player board starts empty. Play the squirrel, then sacrifice it for one blood toward a creature's cost.
- Mark your active creatures, then tap an empty or marked lane to commit. **Cancel Play** removes marks. **Card Info** lets you compare current stats and lane threats before committing.
- **End Round** stays at bottom right. Combat and reserve advancement resolve before the next draw choice. A five-point balance lead ends the battle.
- **Deck List** shows the main deck, side-pile count, discard, and larger card previews. Main and squirrel piles are finite and do not reshuffle. **Reduced motion** remains available above the board.

This pass follows Inscryption's core opening/draw/blood rules while retaining original artwork. Full mechanical parity remains future work: remaining card sigils, items, starvation, original encounter scripts, the exact original fair-hand algorithm, and run progression are not implemented. Existing animal stats remain prototype values. Sources for the draw rules: [Card Battle](https://inscryption.fandom.com/wiki/Card_Battle), [Cards](https://inscryption.fandom.com/wiki/Cards).

## Checks and art

Run `godot --headless --path . --script res://tests/ritual_flow.gd`. Checks cover the opening hand, independent squirrel count, one chosen draw, draw-before-play gating, blood sacrifice, visible reserve behavior, hands beyond four cards, paged selection, five-point victory, restart, and both motion modes.

Earlier hand-layout captures: `docs/mockups/14-thumb-collapsed.png`, `15-thumb-expanded.png`, and `16-draw-choice.png`. These captures predate the second playable player row; screenshots document visual iterations. Physical-phone ergonomics and export validation are still pending.

Generated art and exact prompts live in `assets/art/`. Noto Serif and its license live in `assets/fonts/`. See `PROJECT_PLAN.md` for project scope and design history.

## Inline offerings

Long-press your placed creature for 0.45 seconds to open a compact panel above the player row. It shows current stats, lane threats, and **Offer This Creature** / **Unmark Offering**. Select a blood-cost hand card first to enable marking. Each mark is reversible; choosing a destination still commits the sacrifice and placement. Tap outside the panel to dismiss it. Short taps keep the existing marking/placement behavior; moving more than 12 logical pixels cancels the hold. Holding never also triggers a short tap on release.

## Remaining features

The current scope and prioritized checklist live in [docs/FEATURE_ROADMAP.md](docs/FEATURE_ROADMAP.md): map, map events, bones, sigils, items, and bosses. Deathcards and cabin puzzles are explicitly out of scope. Both player rows can attack; a front-row creature takes enemy hits before a back-row creature in the same lane. Opening-hand diversity is guaranteed in addition to shuffling.

## Short run and map events

The main scene is now `scenes/run.tscn`: title → map → events/battles → run ending. The original `scenes/attack_preview.tscn` remains available as a standalone battle sandbox.

- **Creature reward:** choose one of three animals to add to your run deck.
- **Campfire:** choose one exact card, then give it +1 attack or +2 health. This first version is one safe warming with no survivor risk.
- **Hollow Shrine:** confirm permanent removal of one exact card, or leave. This is deck thinning, not sigil transfer.
- **Battles:** carry your run deck and individual upgrades into the 4×4 board. After the result, tap **Return to Map**. First encounters have a smaller, finite enemy supply. The Thicket is a stronger normal encounter, not a multi-phase boss yet.

Choices close the other branch. A short path ends in The Thicket and a completion screen; losing ends the run. Deck copies have unique IDs so campfires affect only the chosen card. Battle sacrifices/deaths do not permanently delete cards from the run deck.

Runs autosave locally at map/event transitions. **Save & Title** and **Continue Into the Wood** resume the path and completed upgrades. A saved pending event reopens without granting its reward twice; a pending battle restarts that encounter rather than restoring mid-turn combat. Beginning a new run replaces the saved run.

Run `godot --headless --path . --script res://tests/run_flow.gd` for map reachability, one-time events, individual upgrades, finite early enemies, battle return, win/loss, and save/resume checks. Battle checks remain in `tests/ritual_flow.gd`. Current title/map/event captures are `docs/mockups/18-title.png` through `22-shrine.png`.

## Blood stacks and bones

Play two squirrels into either of your rows, select a wolf, then mark both squirrels (tap them or long-press and choose Offer). The counter shows **Blood 2/2** and valid destination slots glow. Tap a slot to commit; until then both squirrels remain alive and Cancel Play clears the marks. Blood is a payment for that play, not a resource carried between plays.

Each of your creatures that dies or is sacrificed grants one bone, shown in the battle counter and a +1 Bone pickup. Enemy deaths grant none. Bones accumulate during the battle, are spent on placement, and reset for the next encounter. Selecting a bone creature never consumes blood offerings.

| Creature | Attack / health | Cost |
| --- | --- | --- |
| Bone Stoat | 1 / 1 | 2 bones |
| Grave Raven | 2 / 2 | 4 bones |
| Carrion Hound | 3 / 3 | 6 bones |

These original skeletal creatures now have Sharp Quills, Waterborne, and Touch of Death respectively. Their art matches Emberwood's engraved parchment style. New runs include a Bone Stoat and Grave Raven; map rewards offer more bone creatures. Existing saves retain their existing decks. Start a new run to see the revised starter deck.

Run `godot --headless --path . --script res://tests/bones_flow.gd` for stacked blood, bone earning/spending, unaffordable and occupied placement, undead sacrifice, and encounter reset checks in both motion modes. Artwork and exact built-in generation prompts are documented in `assets/art/ART_PROMPTS_BONES.md`. Bone behavior reference: [Bones](https://inscryption.fandom.com/wiki/Bones).

## Mandatory draw piles

The two card-back buttons at bottom right are **Creatures** (main deck, including blood- and bone-cost creatures) and **Squirrels** (side deck). Counts show how many remain. After the opening deal, each new turn requires one card from exactly one pile: neither playing nor ending the round is allowed first. Both piles lock as soon as a draw starts, so rapid taps cannot draw twice. An empty pile does not waive the required draw if the other still has cards. The initial three-creature-plus-squirrel deal already supplies the opening turn; it does not receive an extra draw. Both-pile exhaustion/starvation remains a separate roadmap item.

Checks: `godot --headless --path . --script res://tests/draw_phase.gd`. Screenshot: `docs/mockups/26-mandatory-draw-piles.png`.

## Wipeouts and whispered turns

A combat kill that removes your last deployed creature across both playable rows loses the encounter, even if your hand or draw pile still contains cards. Killing the final opposing creature wins when both the enemy active row and visible reserve are empty. Check this after combat deaths: the empty starting board is legal, and sacrificing your only creature to place a replacement does not lose midway through payment. Five-point scale wins/losses still apply. A dedicated result screen shows victory/defeat and its reason; Continue returns a run to the correct map or defeat screen.

Turn changes draw from 24 original sayings, split into twelve enemy-turn and twelve player-turn lines. Each pool is shuffled without repetition until used up, and avoids an immediate repeat when refreshed. Text emerges from amber ink with a character reveal, slow settling motion, growing etched rules, and drifting embers as the table darkens. Reduced motion uses full-text fades and static ornaments.

Checks: `tests/end_state.gd` covers combat wipeouts, reserve protection, sacrifice replacement, result idempotence, phrase variety, and animation cleanup in both modes. `tests/run_flow.gd` includes a zero-scale wipeout victory returning to the map. Captures: `docs/mockups/27-ember-whisper.png` and `28-wipeout-victory.png`.

## Editing creatures

Card definitions now live in `resources/cards/*.tres` and can be edited in Godot's Inspector. `scripts/creature_definition.gd` defines the fields; `scripts/card_catalog.gd` registers stable IDs and validates definitions. Battle cards, map events, deck inspection, and save validation all use the same catalog. Existing save IDs remain compatible.

Base resources are treated as read-only shared data. Each battle card copies its stats and sigil list; persistent run upgrades are separate from temporary battle bonuses and current damage. Sacrifice eligibility is enforced by both tap and inline offering paths. Tribes are metadata for future map/totem rules; six sigils now execute through the pure rule-event resolver. Check these boundaries with `godot --headless --path . --script res://tests/card_definitions.gd`.

## Sigils and living background

The first six sigils are active: Raven/Airborne, Stag/Mighty Leap, Grave Raven/Waterborne, Fox/Stinky, Bone Stoat/Sharp Quills, and Carrion Hound/Touch of Death. Card costs are small symbols and numbers at the top-left. Shared definitions, explanations, event order, and two-row targeting conventions are documented in [docs/SIGIL_RULES.md](docs/SIGIL_RULES.md).

Skull eyes now glow and react, candlelight breathes with smoke, a moth circles the flame, embers drift along the edges, and a crawling shadow occasionally crosses the margin. Reduced motion is available on the title and battle screens. The setting carries between them for the session.

## Living cards, round teeth, and balance checks

Card portraits now breathe subtly inside anchored frames, with an occasional ink shimmer. Reduced motion stops portrait animation. The main skull has an irregular ember glimmer. The right skull cycles between an ember eye, three pale eyes, and a red slit with creeping tears; it grows **one glowing tooth per round**, starting at one and adding ghost-jaw rows after eight. Reset returns it to the first tooth/form. Costs remain small at the top-left and the board remains 4×4.

Run `python tests/run_checks.py` for the complete bounded regression suite. The 1,200-game seeded probe writes `reports/balance-latest.json`; [docs/BALANCE.md](docs/BALANCE.md) explains the policies, current rates, tuning, bone-creature coverage, and limits. Stinky now explicitly shows why a 1-attack Bone Stoat cannot hit. Run openings were tuned to telegraph threats in reserve, and escalating starvation pressure resolves equal-damage races after both draw piles empty.

## Survival sigils and usable tools

Four new reward creatures bring **Worthy Sacrifice, Many Lives, Unkillable, and Bone King** into play. The first reward shows the new creatures; **Turn the Offerings** reveals the other set. Animated sigil badges glow when triggered; returning creatures keep their upgrades. See [docs/SIGIL_RULES.md](docs/SIGIL_RULES.md) for interactions and the custom wipeout rule.

Tap **Satchel** near the bottom when no card is selected. Three pockets hold single-use tools: bottled squirrel, pliers, scissors, hourglass, Bone Fan, and fish hook. New runs start with squirrel/pliers/hourglass; the **Old Satchel** map branch offers all six tools with inspect, confirm, and replacement when full. Use still requires the mandatory draw, and invalid targets/cancel never spend a tool. Inventory persists between battles and saves. [docs/ITEMS.md](docs/ITEMS.md) describes targeting, duration, and current save limitations.

## Permutation and randomized regression coverage

`python tests/run_checks.py` now runs all 16 suites, including **105,514 bounded permutation cases**, 512 seeded mixed-deck/item battles, and 32 real-scene randomized map/save paths. `--quick` runs the shorter subset; `--seeds 4096` expands the generated battle corpus. Failed cases record initial states, seeds and action traces under `reports/failures/`, and the runner supports exact battle-artifact replay. It stops promptly on Godot errors and records commands/results in `reports/test-suite-latest.json`.

See [docs/TESTING.md](docs/TESTING.md) for coverage, replay commands, stress results, and the checks required when adding new randomized mechanics. The sweep found and fixed attacks incorrectly accepted from hand/reserve/wrong slots and stale node commands reopening defeated runs; regression checks protect both boundaries.
