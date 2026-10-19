# Balance probes and current tuning

Run the whole suite with `python tests/run_checks.py` from the project directory. The runner checks Godot exit status and script errors, imposes a 150-second timeout per script, and runs up to four independent scripts at once. Run only the balance probe with:

```sh
godot --headless --path . --script res://tests/balance_simulation.gd
```

This writes `reports/balance-latest.json`, including exact losing/stalled seeds, per-card plays, bone attack and blocked-attack counts, early defeats, and encounter length. Rerun one case from a Godot script with `preload("res://scripts/battle_simulation.gd").new().run_seed(39, 2, true)`; the arguments are seed, encounter level, and lookahead policy enabled.

## What is measured

The probe runs seeds 0–199 for each of three encounters under two policies: a one-round lookahead lane selector and a random lane selector. Both use the same simple draw/payment policy. They play the six-card starter deck, without map rewards or campfire upgrades. Each game is capped at 40 rounds. This is an encounter regression benchmark, not a human win-rate estimate or a full-run simulation.

Production battle and simulation share `battle_setup.gd` for starter cards, opening selection, reserve roster, reinforcement sequence index and budget; all play, attack, sigil, bone and starvation actions use `battle_rules.gd`. Live-scene tests check that the three encounter setups match. The seeded simulator has its own turn orchestration, with draw choice, player attacks from all eight slots, reserve advance, enemy attacks, and refill in production order. The post-selection hand shuffle is omitted because this policy ignores hand order. There are no Node animations in the simulation.

Current baseline, 200 samples per cell:

| Encounter | Lookahead win rate | Random lanes win rate | Lookahead mean rounds |
| --- | ---: | ---: | ---: |
| Opening | 96.5% | 92.5% | 4.10 |
| Second | 65.5% | 19.5% | 4.51 |
| Thicket | 63.0% | 14.5% | 7.22 |

No simulations time out. The opening intentionally teaches payment and bones; the next two encounters reward lane planning. These figures are a starting point. Physical-phone playtests, rewarded/upgraded decks, deck archetypes, item interactions, and bosses still need separate balance coverage.

The broad regression bands allow a 60–99% lookahead opening win rate, 25–90% later win rates, and at least a 15-point later advantage over random placement. Later lookahead early defeats must stay at or below 40/200. Both wins and losses must occur, no games may time out, seed replay must be exact, and starter bone creatures must actually produce attack events. These are alarms for this bot and corpus; inspect the report before changing them for an intentional redesign.

## Changes prompted by the probe

Previously, the opening had only one queued Raven and was easily swept, while later encounters opened with an active Wolf plus queued threats. The first naive policy won 99% of openings, 2.5% of second encounters, and none of the final encounters. Those figures exposed both poor bot decisions and uneven pressure; they are not directly comparable to the stronger final bot.

Run encounters now begin with visible reserve intentions. The opening queues a Raven and Bone Stoat; the second queues a Raven and Wolf; the Thicket adds a Bone Stoat instead of the opening Fox. Reinforcement budgets remain 1 / 2 / 3. The standalone sandbox retains its original tougher opening and endless refill, so it is not the measured run campaign.

Equal direct damage could otherwise leave a battle repeating forever after both piles emptied. **Starvation now takes 1, then 2, then 3… balance away from the player at the beginning of each subsequent player round when both piles are empty.** This is a direct-pressure adaptation rather than the original game's growing Starvation creature. It does not trigger when either pile still has a card. Pressure resets between encounters and uses the same pure rules in production and simulations.

## Bone creatures

All three undead pass live full-round tests from both player rows, plus face-damage tests in both motion modes. Bone payment happens only on placement, not again when attacking. Waterborne makes Grave Raven avoid incoming hits; it still deals its own attack normally. Carrion Hound's death touch kills a surviving defender; Bone Stoat's Quills retaliate even on a lethal hit.

**Bone Stoat has 1 attack. Opposing Stinky reduces that to zero.** This is intentional, not a failure of bone-cost cards. A blocked strike now displays `0 ATK · STINKY` beside the creature. Tests verify that it produces a blocked event and causes no damage.

The lookahead starter-deck cohorts produced Bone Stoat attack events 590 / 196 / 1,334 times and Grave Raven events 43 / 51 / 289 times by encounter level. Carrion Hound is a reward card, absent from this starter benchmark; its mechanics are verified by the live tests, but its six-bone affordability and reward-deck win impact still need longer-run sampling. No bone stats or costs were changed merely to make tests pass.

`tests/living_table.gd` covers full-round creature damage, death touch, Quills retaliation, return positions, portrait motion, reduced motion, tooth counts, three skull hauntings, and reset. `tests/starvation_and_bone_damage.gd` covers undead face damage, no repeated payment, exhaustion, pure-input preservation, reset, and shared encounter setup. Existing blood/bone payment, draw, outcome, resource, and run/save tests remain in the suite.

## Survival/item checkpoint

The full suite now has 13 scripts, including pure and live-scene checks for batch B and the six initial tools. The original six-card starter deck remains unchanged and the 1,200-case starter benchmark still passes after these additions. The standalone sandbox includes the four extra survival variants; its deck-count checks derive the count from its actual roster. New reward-deck synergies and item-aware policies are not measured by the starter benchmark and still require targeted balance sampling. Catalog tests explicitly protect all six original sigil assignments as well as validating the thirteen resources.

## Correctness stress versus difficulty

`docs/TESTING.md` documents the new permutation and random-state coverage, including a successful 4,096-seed mixed-deck/item stress run. Those policies intentionally make erratic choices and generate synthetic modifications; their win/loss ratio is not a human difficulty estimate. Use their traces and resource invariants to find correctness regressions, then evaluate tuning using representative balance cohorts and playtests. The default runner now includes 16 scripts.
