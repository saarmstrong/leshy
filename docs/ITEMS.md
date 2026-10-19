# Usable tools and satchel

A battle has three inventory pockets. Tap **Satchel** at the bottom of the screen when no card is selected. If a card is selected, that button shows Card Info; cancel the card selection to open the satchel. Tools have engraved native icons, subtle glints, and a short use animation. Reduced motion keeps the icon still and fades it.

New runs start with Bottled Squirrel, Pliers, and Hourglass. Old version-1 saves receive the starter tools only if the inventory field is absent; an explicitly empty inventory stays empty. Used tools persist immediately in the run save. Later battles receive the remaining inventory; starting a fresh run replenishes the starter set. The standalone sandbox resets its starter inventory on New Ritual.

| Tool | Effect / valid target |
| --- | --- |
| Bottled Squirrel | Creates a free squirrel in hand; does not remove one from the squirrel pile or replace the mandatory draw. |
| Pliers | Adds 1 to the player's balance and may win by tipping the scale. |
| Scissors | Removes one active enemy creature; reserve cards cannot be targeted. Death processing and terminal checks still execute. Enemy deaths award no player bones. |
| Hourglass | Skips the next entire enemy phase: reserve advance, attacks, and refill. It expires at the next player round. Cannot stack another while pending. |
| Bone Fan | Gives all current/new player creatures Airborne for this round's attacks, visibly adding the temporary badge. Mighty Leap still blocks them. Expires at the next player round. |
| Fish Hook | Steals one active enemy into an empty player slot in either row, preserving health and sigils. Choose enemy, then destination. A stolen creature becomes player-owned for future sacrifice, bone and return effects. |

Tools can be inspected before drawing, but use is gated by the mandatory draw. Opening, cancelling, invalid targets, occupied destinations and duplicate pending effects do not spend an item. A valid resolver action consumes exactly one inventory entry before presentation. Animations lock input to prevent double spending. Capturing or cutting the last enemy also honors this project's custom opponent-wipeout victory rule.

## Backpack map stop

**Old Satchel** is an alternative branch alongside Hollow Shrine and Last Embers, before the Thicket. Choose one of all six tools; inspect it, then confirm Take This Tool. With three full pockets, choose which tool to replace first. With space, the choice fills a pocket. Leaving consumes the event without changing inventory. This first event supplies one chosen tool, not a complete refill of every empty pocket.

Inventory changes save immediately. Existing save behavior still restarts a pending battle rather than restoring it mid-turn; already spent tools remain spent on restart. Full mid-battle state restoration, boss-specific item restrictions, additional Act I items, sound/haptics, and item-aware full-run balance probes remain future work.

Rules: `scripts/battle_rules.gd`; definitions: `scripts/item_library.gd`; icons: `scripts/item_icon.gd`. Pure rule and live-scene checks cover all six effects, cancellation/draw guards, hooked ownership, full-phase skipping, expiration, capacity, backpack reachability, one-time commitment and save/resume. Run `python tests/run_checks.py`.

Reference effects: [Consumable Items](https://inscryption.fandom.com/wiki/Consumable_Items). Original names/presentation and two-row targeting are adapted to Emberwood.
