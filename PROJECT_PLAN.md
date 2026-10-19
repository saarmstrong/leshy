# The Hollow — Emberwood

A portrait-first Godot woodland horror card sandbox with a four-by-four layout: visible enemy reserve, active enemy creatures, your creatures, and a four-slot hand. Open `project.godot` in Godot 4.7.2 and press **F5**.

## Play the ritual

1. Tap a card in your hand. Red dots beneath its name show how many creatures it costs.
2. Tap your creatures to mark offerings. No creatures are consumed until placement. **Cancel** clears the selection safely.
3. Tap a glowing empty lane to sacrifice the marked creatures and place your card. To replace a marked creature in its own slot, tap that slot again after marking enough offerings.
4. Tap **End round**. Your creatures attack, visible reserve creatures advance into empty active slots in the same lane and attack, then a new intention appears in reserve and you receive a card if your hand has room. Blocked reserve cards remain in place and never attack from reserve. The bottom row is your hand, not a second combat row. Unblocked damage moves the balance; reach +6 to win or −6 to lose. **New ritual** restarts.

Start with free hares and a fox on the table; the hand includes a raven, stag, hare, and wolf. Hares cost nothing; fox and raven cost one creature; stag and wolf cost two. Attack and health remain live Godot text. Five original engraved card faces share the Emberwood parchment style.

Sacrifice darkens and folds the card into drifting ash. Placement lifts and settles paper onto the wood. Attacks wind up, snap forward, recoil, and show damage. Round changes dim the candlelit scene around an unsettling message. **Reduced motion** removes lunges, card folding, drifting ash, and eye-light breathing while retaining slow fades and state feedback.

This is a small playable animation sandbox, not a complete deck-building run. Enemy reserve refill and draw order are fixed, there are no special abilities yet, and there is no save system or audio. Touch uses Godot's touch-to-mouse emulation; physical-phone testing is still pending.

## Validation

Run `godot --headless --path . --script res://tests/ritual_flow.gd` to check costs, cancellation, sacrificing into the same slot, free and paid placement, combat, enemy deployment, drawing, input locking, restart, and blocked/unblocked reserve advancement in both motion modes. Rendered screenshots of the current flow are under `docs/mockups/04-*` through `08-*`; earlier captures show previous iterations.

See `PROJECT_PLAN.md` for direction and scope. Art assets and exact generation prompts are in `assets/art/ART_DIRECTION.md`. The built-in image tool generated the artwork; Noto Serif and its license are bundled in `assets/fonts/`.

Latest four-row captures: `docs/mockups/09-visible-reserve.png` and `docs/mockups/10-reserve-next-turn.png`.

## Deck and offerings

The visible card-back pile and **Deck** button open a browser of remaining cards, live stats and costs, plus hand/table/discard counts. Tap a species for a larger card and role explanation. The opening four-card hand comes from a finite fourteen-card deck; three creatures also begin on the table. Draws remove actual cards from that deck, and player sacrifices or combat deaths go to discard. Draws pause when the four-card hand is full, and an empty deck does not reshuffle. The discard pile stays out of play for this battle.

Select a hand card, then tap **Card Info** to compare offerings. Tap creature rows to mark or unmark them; the guide shows current stats and active or queued threats in each lane. Return to the table and pick a glowing slot to commit. Only your active creatures supply offerings; there is no item inventory yet. **Offerings** opens the same guide without a selected card to explain the rules.

## Current interaction contract — supersedes earlier hand/deck assumptions

Preserve the 4×4 grid and visible opponent stack. The fourth row is the hand area, with sixteen slot outlines retained; cards now gather in a minimized fan until activated, rather than occupying four fixed hand slots. There is no hand-size limit. Larger hands use pages of five readable fan cards. Selecting a card collapses the fan so sacrifices and placement remain visible.

Put Main draw, Squirrel draw, hand activation/cancel, and End Round in the bottom control area, biased toward the right thumb. Opening hand is three main cards plus one squirrel from a ten-card side pile. Start with an empty player board. Later turns require exactly one chosen draw from either pile before playing or ending the turn. Squirrels are free 0/1 creatures that provide one blood when sacrificed from the active row. Replace the earlier automatic draw, four-card cap, free starter hares, and six-point scale assumptions. Victory uses a five-point balance lead.

Faithful first-act mechanics are the target. This iteration implements opening/draw/blood fundamentals; sigils, bone costs, items, starvation, fair-hand shuffling, encounter parity, and full run structure remain outstanding. The README describes the current executable behavior. Keep original art and worldbuilding. Source references: https://inscryption.fandom.com/wiki/Card_Battle and https://inscryption.fandom.com/wiki/Cards.

## Inline offering interaction

Placed player creatures now support a 0.45-second hold that opens a compact offering panel on the table. Show current power/health, lane threats, and a direct mark/unmark action. Preserve the 4×4 grid, right-thumb controls, and separate squirrel pile. No sacrifice is committed by holding; destination selection remains the commitment. Drag slop cancels the gesture, and hold release is consumed to prevent an accidental short-tap action. Tests cover both protections.
