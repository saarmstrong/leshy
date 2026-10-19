# Testing Emberwood as the rules become randomized

Run from the project directory:

```sh
python tests/run_checks.py
```

The default suite runs 16 scripts: the existing rule, scene, draw, animation, inventory, save and balance checks, plus exhaustive permutations, 512 seeded mixed-deck battles, and 32 randomized real-scene map paths. Up to four scripts run concurrently. Godot script errors stop their process promptly, rather than leaving an assertion paused until timeout. Each script has a 180-second limit; the runner returns nonzero on failure and writes `reports/test-suite-latest.json` with exact commands, timing and captured output.

Useful alternatives:

```sh
# Fast rule/deck/draw/run checks, including permutations and mixed battles.
python tests/run_checks.py --quick

# Larger battle stress corpus, with the same invariant and replay checks.
python tests/run_checks.py --only rule_permutations,randomized_battles --seeds 4096

# Wider full suite, including more real-scene paths; allow longer per-script time.
python tests/run_checks.py --seeds 4096 --run-seeds 128 --timeout 300

# Reproduce one generated battle or one real-scene run.
python tests/run_checks.py --only randomized_battles --seed 37 --seeds 1
python tests/run_checks.py --only randomized_run_flow --seed 37 --run-seeds 1

# Replay a randomized-battle failure without needing its PRNG sequence.
python tests/run_checks.py --replay reports/failures/randomized-battles.json

# Exercise the saved replay sample after a passing corpus.
python tests/run_checks.py --replay reports/replay-sample.json
```

Keep a failing seed/artifact before a later passing invocation overwrites the latest report. Reports clear their own prior failure file on success. `tests/fixtures/invalid-hand-attack.json` is a permanent regression fixture for the illegal-attacker bug discovered by this sweep. Replay accepts battle artifacts; map failures are reproduced by seed, and permutation failures by rerunning their matrix/fixture.

## Coverage layers

| Layer | Current coverage |
| --- | --- |
| Exhaustive combat | 73,728 cases: offensive/defensive effect cross-products, all 1,024 subsets of ten sigils on either side, zero/low/high attacks, retaliation, death/return/bone combinations, both attack directions and player rows, and all four lanes with front/back shielding. |
| Exhaustive payment | 27,384 counted payment cases: both donors' 16 sacrifice/survival subsets, costs 0–6, offering subsets and ordering, empty/occupied/reusable destinations; bone banks 0–8 against costs 0–6 in all eight slots. Additional malformed/non-sacrificable offerings must fail atomically. |
| Item orders and targeting | 4,008 cases: all 216 three-pocket inventories from six tools, all six original-pocket use orders, duplicate timed-effect rejection, plus active-lane/empty-slot/out-of-range target boundaries. |
| Ownership chains | 384 cases: all 16 survival subsets on a stolen card, captured into each of eight slots, followed by sacrifice or combat death. Player bone/return/reusable triggers must follow the new ownership. |
| Invalid attackers | Saved regression plus invalid hand/reserve/wrong-slot/out-of-range sources. Cards cannot attack from hand or the waiting row. |
| Seeded mixed battles | Random 6–12-card decks, copied stat upgrades, added sigils, zero-to-three tools, varied enemy modifiers/lanes, both player rows, rejected actions, draws, reserve movement, skip/fan duration, starvation and terminal outcomes. Every completed trace is replayed from its initial state and must match exactly. |
| Real-scene randomized paths | Actual title/map/event/battle scenes, reachable branch choices, ordinary and survival rewards, individual upgrades/removal, satchel choices, one-time commitment, unique card IDs, inventory consumption, pending-event resume and committed-save reload. Battle outcomes are injected here to cover map boundaries; the mixed-battle probe separately tests combat. |
| Existing integration and balance | Real card placement/attack/return/sacrifice animations, mandatory draw and rapid-repeat guards, all undead attacks, item targets/expiration, outcomes/whispers, plus the existing 1,200-game starter-deck difficulty benchmark. |

The permutation suite currently totals **105,514 cases** and over **1.9 million contract checks**. This is exhaustive for the explicitly bounded matrices, not every possible game state or arbitrarily long action history.

## What the contracts assert

`tests/support/contracts.gd` checks input immutability, deterministic action replay, representative nested-copy isolation, exact board dimensions, unique tokens across the draw pile and live zones, valid ownership, positive bounded live health, nonnegative bones, inventory capacity and pocket conservation. It also checks event references, one death per actor per action, correct one/four-bone awards, death-prevention semantics, one full-health Unkillable return with preserved modifications, exact bone payment, and final-position terminal events.

Combat and payment matrices calculate expected damage, bypass, retaliation, blood funding, survival, resource totals and slot acceptance independently from the production resolver. They do not simply compare two calls to the same implementation. The roster manifest deliberately fails when the supported sigil/item set changes: new mechanics must extend their expected-effect coverage before the test suite is green.

The random probe uses the production card catalog, opening-selection/encounter data and action resolver. Test-only draw/advance/spawn orchestration is in `tests/support/sequence_actions.gd`; it is not a second production turn engine. Existing live-scene tests cover the real controller's timing, input and mandatory-draw gates. Whole-number JSON values are normalized for comparisons because saved integers can reload as floats.

## Latest stress evidence

The 4,096-seed mixed-deck run completed **77,086 actions** and **3,630,815 contracts**, replaying every trace exactly, with 133 representative traces also round-tripped through JSON. All thirteen creatures were played, all ten sigils triggered and all six items were used. There were 2,025 deliberately rejected/invalid attempts and no invariant failures or 80-round timeouts. The largest battle lasted 19 rounds. Raw evidence is preserved in `reports/randomized-battles-stress.json`.

A passing full-suite record is preserved in `reports/test-suite-full.json`; `reports/test-suite-latest.json` always reflects the most recent runner invocation, including focused runs. `reports/replay-sample.json` contains a generated battle with its expected final state and can be replayed even when no failure is present.

The 32-path real-scene corpus performed 148 pending-event save/restores and visited every current event family. Its latest detailed metrics are in `reports/randomized-run-flow.json`; permutation metrics are in `reports/rule-permutations.json`.

These stress bots are intentionally erratic and use synthetic upgrades/sigil combinations, including combinations the current map cannot yet generate. Their win rates are not difficulty targets. Keep balance decisions tied to `docs/BALANCE.md`, representative deck policies and human playtests.

## Regression fixes found by these tests

The first matrix accepted a hand card as an attacker; validation now requires the correct active slot, owner and lane bounds. The saved fixture checks that hand/reserve/wrong-slot sources stay rejected.

The randomized real-scene probe also found that a stale node command could reopen a battle after defeat. Node selection now requires an active run, and both the explicit run-flow test and the seeded path corpus protect terminal screens against reentry.

## Adding randomized features safely

1. Extend the manifest and independent expected-effect matrix for the new sigil, item or trigger family. Include negative cases and both player rows.
2. Add the feature to random generation and assert that it is actually exercised, rather than merely included in a pool.
3. Cover its ownership, resource, return/death, duration and serialization interactions. Add a real-scene case when input/animation/turn ordering changes.
4. Preserve discovered failures as small regression fixtures, fix the rules, and rerun both the relevant probe and the full suite.
5. Update the realistic balance cohorts separately. New mechanics need new balance measurements, not looser correctness checks.

Remaining test work includes physical touch/device behavior, exports, visual/audio regressions, production randomized map generation and saved RNG state, full mid-battle restoration, and future bosses/items/sigils. Automated coverage cannot establish that every future mechanic is correct or that the game feels fair on a phone.
