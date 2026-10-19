# The Hollow — Emberwood

Portrait-first Godot card sandbox. Open `project.godot` in Godot 4.7.2 and press **F5**.

The **4×4 layout remains**: enemy reserve, active enemies, your active creatures, and the bottom hand area. The fourth row retains all four slot outlines while your hand appears as a collapsible fan, rather than four fixed card positions. The enemy stack remains visible for planning.

## Right-handed controls

- Tap **Hand** or the little bottom fan to expand it. Tap a card to select it and tuck the fan away. Additional cards are reachable using the fan's page arrows; there is no hand-size limit.
- **Main** and **Squirrel** are separate piles near your right thumb. On later turns, choose exactly one draw before playing or ending the round. The two piles cannot both be drawn from in one turn.
- Opening hand: three main-deck creatures and one free squirrel; no extra first-turn draw. The player board starts empty. Play the squirrel, then sacrifice it for one blood toward a creature's cost.
- Mark your active creatures, then tap an empty or marked lane to commit. **Cancel Play** removes marks. **Card Info** lets you compare current stats and lane threats before committing.
- **End Round** stays at bottom right. Combat and reserve advancement resolve before the next draw choice. A five-point balance lead ends the battle.
- **Deck List** shows the main deck, side-pile count, discard, and larger card previews. Main and squirrel piles are finite and do not reshuffle. **Reduced motion** remains available above the board.

This pass follows Inscryption's core opening/draw/blood rules while retaining original artwork. Full mechanical parity remains future work: card sigils and bone costs, items, starvation, original encounter scripts, fair-hand shuffling, and run progression are not implemented. Existing animal stats remain prototype values. Sources for the draw rules: [Card Battle](https://inscryption.fandom.com/wiki/Card_Battle), [Cards](https://inscryption.fandom.com/wiki/Cards).

## Checks and art

Run `godot --headless --path . --script res://tests/ritual_flow.gd`. Checks cover the opening hand, independent squirrel count, one chosen draw, draw-before-play gating, blood sacrifice, visible reserve behavior, hands beyond four cards, paged selection, five-point victory, restart, and both motion modes.

Current captures: `docs/mockups/14-thumb-collapsed.png`, `15-thumb-expanded.png`, and `16-draw-choice.png`. Earlier screenshots document earlier iterations. Physical-phone ergonomics and export validation are still pending.

Generated art and exact prompts live in `assets/art/`. Noto Serif and its license live in `assets/fonts/`. See `PROJECT_PLAN.md` for project scope and design history.

## Inline offerings

Long-press your placed creature for 0.45 seconds to open a compact panel above the player row. It shows current stats, lane threats, and **Offer This Creature** / **Unmark Offering**. Select a blood-cost hand card first to enable marking. Each mark is reversible; choosing a destination still commits the sacrifice and placement. Tap outside the panel to dismiss it. Short taps keep the existing marking/placement behavior; moving more than 12 logical pixels cancels the hold. Holding never also triggers a short tap on release.
