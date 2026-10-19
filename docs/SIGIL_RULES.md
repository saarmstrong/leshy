# Rule events, first sigils, and haunted scenery

## Resolved actions

`scripts/battle_rules.gd` takes value-only snapshots (IDs, arrays, stats, resources), copies them, and returns a new state plus ordered events. It never accesses a Node, Tween, renderer, clock, or random generator. Identical snapshots and actions produce identical results.

- Play: validate destination and full payment → payment → each sacrifice/death/bone gain → place the new creature. No wipeout is evaluated midway through payment.
- Attack: validate attacker → opposing Stinky modifier → attack or zero-power block → targeting sigils → damage → quills retaliation → return presentation marker → deaths and bone gains → terminal outcome.
- The scene commits the resolved state once, then presents the events. Displayed health updates at the impact event; death animation does not award resources again.
- Draws, queue spawns, and reserve advances are also logged in the scene's ordered journal. Their controller operations remain separate from the pure play/attack resolver. Player Unkillable return-to-hand is supported; generated-card and movement chains remain for later batches.
- `event_log` retains the latest 256 events with increasing sequence numbers. It is a diagnostic journal, not a saved mid-battle replay format yet.

## First six functioning sigils

| Sigil | Current creature | Effect |
| --- | --- | --- |
| Airborne | Raven | Attacks directly over an ordinary opposing creature. |
| Mighty Leap | Stag | Catches Airborne attacks instead of allowing direct damage. |
| Waterborne | Grave Raven | Submerges during opposing attacks, which hit the balance instead. It still attacks normally on its own turn. |
| Stinky | Fox | Lowers opposing attack power in its lane by one, to a minimum of zero. |
| Sharp Quills | Bone Stoat | Retaliates for one damage even if the incoming hit is lethal. |
| Touch of Death | Carrion Hound | Any positive creature damage it deals is lethal. It does not instantly win on direct balance damage. |

Sigils can combine. Quills plus Touch of Death makes the retaliatory wound lethal; Airborne is caught by Mighty Leap; Waterborne avoids the attack rather than retaliating. Definitions and inspector descriptions live in `scripts/sigil_library.gd`; card resources select their sigils. Small native-drawn glyphs appear above the stat line. Costs are a restrained symbol and number at the top-left, with the name alongside them.

Reference behavior: [Sigils](https://inscryption.fandom.com/wiki/Sigils), [Mighty Leap](https://inscryption.fandom.com/wiki/Mighty_Leap). The roster, costs, and two-row interactions are this project's adaptations, not exact original card statistics.

## Two-row conventions

Both player rows attack the matching enemy lane. On an enemy attack the front creature is the initial defender, or the back creature if the front is empty. Airborne and Waterborne bypass that defender to the balance; they do not then seek a second creature behind it. Stinky is evaluated on the initial opposing creature before bypass rules. A zero-power attack stops before damage or quills. Simultaneous quills deaths resolve together, then wipeouts: if both armies are wiped out, the player loses. Visible enemy reserve still prevents a premature enemy wipeout.

## Living table

`scripts/haunted_table.gd` adds artwork-aligned skull-eye glow, breathing candlelight, flame sway, smoke, a circling moth, marginal dust/embers, and a rare crawling silhouette. Deaths, sigils, plays, and turn changes can intensify the eyes. Effects remain in the header/margins and never move controls. The same layer is used on title/map/event screens and the battle scene; the parent layer is hidden during battle to prevent doubling.

Reduced motion keeps static low-level eyes/candle glow and removes smoke, drift, moth/creature movement, and reactive pulses. The title-screen toggle carries into battle; changing the battle toggle carries back to the map for the session. There is no new audio in this pass.

## Checks

- `tests/battle_rules.gd`: pure input preservation, targeting, all six effects, combined retaliation, payments, sacrifice eligibility, death/bone order, and two-row targeting.
- `tests/card_definitions.gd`: valid sigil-bearing resources and isolation of shared/permanent/temporary data.
- Existing ritual, bone, draw, end-state, and run suites verify scene integration.

Captures: `29-haunted-title.png`, `30-small-costs-sigils.png`, `31-top-left-cost.png`, and `32-reach-resolved.png` in `docs/mockups/`.

## Sacrifice and survival batch B

Four additional sigils now run through the same synchronous action pipeline:

| Sigil | New creature | Rule |
| --- | --- | --- |
| Worthy Sacrifice | Ashen Stag — 0/2, 1 blood | Offering contributes 3 blood. Overpayment is allowed; excess is lost. |
| Many Lives | Ember Fox — 0/2, 1 blood | Offering survives. No death, bones, or Unkillable return triggers. Its slot remains occupied. |
| Unkillable | Revenant — 1/1, 2 bones | Player creature returns to hand at full maximum health after combat death or sacrifice, retaining stats and sigils. |
| Bone King | Ossuary Hound — 3/3, 3 blood | Player creature death/sacrifice awards 4 bones instead of 1. |

Worthy Sacrifice + Many Lives combine: a reusable offering supplies three blood each play, but cannot supply its own occupied slot. Bone King + Unkillable award four bones each actual death and return the card. Many Lives prevents both effects on sacrifice because it prevents death, but does not protect against combat damage. Duplicate marks remain invalid. Existing combat-wipeout rules still end the battle when the last deployed creature dies, even if Unkillable returns it to hand.

Before death presentation, death sigils flare on the card; the scene then folds/ashes it, displays the exact bone gain, and returns an Unkillable card to the hand without freeing its Node. Damage events retain impact health separately from the restored state. Hand return does not permanently remove or duplicate the card in the run deck. Player-owned return/death bonuses are supported; the current enemy schedule does not use these new sigils and has no enemy-hand/replay AI yet.

All ten sigil badges now have a slow orbiting ember and soft pulse. Triggered badges brighten with a short halo. Reduced motion keeps glyphs stationary and uses a color fade. Frames, costs, and stats stay anchored. The four variants reuse the matching existing engraved animal art; new portrait art is still future presentation work.

New run rewards show the survival creatures first. **Turn the Offerings** switches between the two three-card sets; only one creature may be taken. The second reward also offers Ossuary Hound. The original six-card starter deck remains unchanged so its existing balance benchmark stays comparable.

Checks: `tests/survival_items_rules.gd` and `tests/survival_items_flow.gd`. Reference semantics: [Sigils](https://inscryption.fandom.com/wiki/Sigils), [Bone King](https://inscryption.fandom.com/wiki/Bone_King).
