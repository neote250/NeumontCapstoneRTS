# rts_base

A third-person, squad-based real-time strategy prototype in **Godot 4.7**.

You command a handful of *squads* on a large heightmap, spend a resource called **memory shards** to grow them, and fight roaming neutral squads. The camera rides on the squad you currently control, so it plays closer to a squad-commander game than to a top-down RTS — a *Total War* general's view rather than *StarCraft*. Orders come from a five-slot radial menu held open on right mouse, and move orders are issued through the minimap. It targets the **Mobile renderer** and touch input, deliberately.

It is a learning project and a systems skeleton: no win condition, no menu, no audio yet.

---

## Running it

Main scene is **`Map/test_map.tscn`**. `Global Scenes/main.tscn` looks like it should be the entry point but is an unused ProtoController sandbox.

| Input | Action | Effect |
|---|---|---|
| **Left mouse** | `target_command` | Raycast through the minimap onto terrain → sets the squad's destination and drops a move marker. Clicking a squad's collider targets it. |
| **Right mouse** (hold) | `input_wheel` | Opens the order wheel. Releasing commits the highlighted slot. |
| **Tab** / **Shift+Tab** | `next_squad` / `previous_squad` | Cycle the controlled squad; the camera cuts to its `CameraMount`. |
| **Backspace** | `stop_command` | Halt and forget the current target. |
| **Enter** | `debug_spawn_unit` | Free unit, bypassing the economy. Debug only. |

Physics layers: `1 units`, `2 terrain`, `3 squads`. Squads sit on layer 3 and scan layer 3; the move-order raycast filters to layer 2, so ground clicks never hit a unit.

---

## A round

*This is the design target. Most of it is not built yet — see the status table.*

A match is built around **3v3**. Other pairings work — solo against wild
squads, 1v1, 2v2 — and story mode is one to three players against AI, but 3v3
is what the balance is tuned for. Each player starts with **1–10 squads**,
spawned as a group on a base spot dealt at random from the map's array of them.
**Wild squads** — hostile to everyone, allied with nobody — are seeded around
the map as a neutral third party.

A standard round runs **ten minutes**. If nobody has been eliminated when the
clock expires, the team holding the most **crystal capture points** wins.
Crystals are worth more than the score: holding one grants a team-wide upgrade
choice — sometimes a player-only one — and losing it to the enemy takes that
back.

### Three roles a side

The intended rock-paper-scissors. Nothing in the engine knows a role exists —
a role is which upgrades you buy and which squads you end up managing:

| Role | Plays |
|---|---|
| **Base** | Base building, defence, and the heaviest gathering of the basic resource. |
| **Army** | The slow line — capturing points, holding ground, assembling and transporting siege equipment. |
| **Raid** | Fast troops, scouts and mages. Disrupting enemy bases, hit-and-run. Highest variance. |

Because roles specialise, **squads can be handed to a teammate at no cost** —
upgrades travel with the squad. A handover is a change of manager, not a trade.

### Growing

Squads come from buildings, not from a global build menu:

- **Buy a squad at a building** → it spawns next to that building, or at the
  far end of a **supply line** if the building has one.
- **Buy a building-squad prefab** → it spawns as a carryable object. A mobile
  squad picks it up and places it, either on a free **base spot** to expand, or
  on a **build spot** the map declares for turrets, walls and corridor traps.

The map is not a blank field. It publishes the places where things may be
built, and expansion means reaching them. Buildings are squads, and some of
them gather resources from the ground they sit on — which is why placement is
a real decision.

### Losing, and not losing

Running out of squads is **not** elimination. A player with no squads can
receive one from a teammate and keep playing, spectate while waiting, or
concede. A **team** is eliminated only when it has nothing left at all —
buildings included, since a team reduced to a base still has income and can
rebuild. The ten-minute clock is what resolves a stalemate, not a deadlock.

### The economy

One currency today (`memory_shards`). Planned: **three**.

| Currency | Gathered | Spendable |
|---|---|---|
| Basic | Anywhere, mostly by the base role | Pooled team-wide |
| Specialised ×2 | At specific sites | **Only where gathered**, until a squad physically carries it elsewhere |

Location-bound currency is the point: moving it is a job someone has to do, and
an enemy can disrupt or steal it in transit.

### Status

| Piece | State |
|---|---|
| One hardcoded player, squads placed in the map scene | working |
| Squad purchase at a building, spawned nearby | working |
| Wild squads | working — owned by a `NeutralController`, hostile to every team |
| Teams | working — each controller's **Team Id** in the inspector until `MatchConfig` exists; teammates never target each other. AI sides and friendly fire **not built** |
| Variable player count, dealt base spots | **not built** — the map authors the match |
| Crystal capture points, the ten-minute clock, win conditions | **not built** |
| Gifting, spectating, elimination | **not built** |
| Three currencies, transport, theft | **not built** — the purse still lives on the controller |
| Supply lines | **not designed** |
| Carryable building prefabs, build spots | **not built** |
| Player-scoped and team-scoped upgrades | **not built** — upgrades are squad-scoped today, and only that scope exists |
| QTE for special weapons, blocks and spells | **not built** — planned once the base game works, weighted toward the raid role |
| Menus, lobby, netcode | **TODO — not decided.** Everything above assumes a `MatchConfig` handed to the match at startup; where it comes from is deliberately unspecified |

The wiring plan for getting from the first rows to the rest is in
**Wiring the Match** — staged so the game runs after every step.

---

## The three levels

Almost everything makes sense once you have this:

| Level | Class | Owns |
|---|---|---|
| **Squad** | `Squad` (CharacterBody3D) | Identity and orchestration. Holds four components and a state machine. This is what the player commands. |
| **Unit** | `Unit` (Node3D) | Nothing. A mesh plus components. **A building is a squad of size 1** whose "unit" is a gravestone. |
| **Component** | `HealthComponent`, `WeaponComponent`, `Attack` | One stat block each. |
| **Rules** | `Teams`, `Combat` | Static, no nodes. `Teams` keeps one lookup — player → team — which the match fills at startup. `Teams.is_hostile()` answers *may A attack B*; `Combat.resolve()` answers *how much does it hurt*. |

A squad is a physics body carrying its units as children. Move the squad and the units follow — units have no movement code at all. That reuse is why your home base and your infantry share one targeting, damage and upgrade path.

---

## Squad's four components

`Squad` went from 499 lines to 185 (79 of them actual code). Everything it used to do lives in a component:

| Component | Owns |
|---|---|
| `RosterComponent` | Who is in the squad, formation slots, spawning and removing units, per-unit ground clamping. |
| `TargetingComponent` | The current target, weapon range (horizontal only — see below), nearest-hostile acquisition. |
| `MovementComponent` | Navigation and steering for the body. Owns velocity x/z; y belongs to gravity and `Ground.snap()`. |
| `EconomyComponent` | What this squad can buy, what it costs, whether the player may start it. |

**The rule for what stays on `Squad`:** a method lives there only if it makes a decision spanning more than one component. `engage_nearest()` asks Targeting and tells Roster; `stop_movement()` halts Movement and clears Targeting. Anything that merely forwards belongs on the component it forwards to — so callers write `squad.roster.add_unit()`, not a pass-through on `Squad`.

Tuning numbers live in a **`SquadStats` resource** (`Resources/SquadStats/*.tres`), one per squad type. The resource is the *type*, the node is the *instance* — anything that changes during a match belongs on the node. See `RosterComponent.size_bonus` for the pattern: the resource holds the base, the node holds what upgrades granted.

> ⚠️ A `Resource` is one object shared by every squad using it. Writing to `stats.speed` at runtime changes every squad on that `.tres` **and saves to disk**. Treat stats as read-only.

---

## How a frame runs

`Squad._physics_process()` orders four things, and the order matters:

```gdscript
state_machine.state_machine_physics_process(delta)   # 1. body moves x/z
if not state_machine.current_state.controls_weapons():
    _passive_fire(delta)                             #    stance-driven self-defence
movement.snap_to_ground()                            # 2. body y, exact
roster.align_to_slots(delta)                         # 3. units close on slots (local space)
roster.snap_to_ground()                              # 4. unit y from terrain
```

Swapping 3 and 4 makes units chase a slot that is still moving.

A state returning a `State` from `state_physics_update()` is how a transition is *asked for*; the machine never needs to know what any state means.

**`controls_weapons()`** is the split between orders that aim for themselves (Target, Turret, Warpath) and everything else, which falls through to `_passive_fire()` and the squad's **stance** — `HOLD_FIRE`, `RETURN_FIRE`, `WEAPONS_FREE`. That is what stops a squad in the build slot from looking broken.

---

## The order wheel

The wheel does **not** pick a state. It picks a **slot**, and each squad scene maps its slots to different states — so the same wedge means *chase this target* on infantry and *overcharge production* on a building. That indirection is what lets one wheel serve every squad type.

| Slot | `squad.tscn` | `building_squad.tscn` |
|---|---|---|
| 0 `DEFAULT` | ReadyState | BuildState |
| 1 `AGGRESSIVE` | WarpathState | TurretState |
| 2 `FOCUS` | AttackTargetState | OverchargeState |
| 3 `MOVE` | MarchState | SupplyState |
| 4 `ECONOMY` | BuildState | *(unmapped)* |

Wheel options are `.tres` files in `Resources/WheelOptions/`, each carrying the slot it commits to. Giving buildings their own icon set is just a different array.

**When remapping arrives**, split the enum in two: `STATE_ROLE` for what a squad does (which code keys on, and which never moves) and `WHEEL_SLOT` for where the thumb goes, with a per-player `Dictionary[WHEEL_SLOT, STATE_ROLE]` between them. Keeping them separate makes remapping rewrite only the lookup table.

---

## The damage chain

Nothing talks to its target directly:

```
WeaponComponent.damage_target()   cooldown elapsed → emits its Attack
  ↓ signal deal_damage
Squad.on_damage_dealt()           attaches self as attacker, targeting.target as victim
  ↓ signal damage_dealt
GameManager.damage()              validity + Teams.is_hostile(). The one place a hit is
                                  observable — score, kill feed and damage numbers hook in here
  ↓
Squad.take_damage()               picks a random surviving unit
  ↓
Combat.resolve()                  damage type × armour type. Pure function
  ↓
HealthComponent.apply_damage()    subtract, update the bar, announce death
  ↓ signal died
RosterComponent.remove_unit()     → emits `emptied` when the last one goes
  ↓
Squad._on_emptied()               → signal squad_terminated → GameManager
```

**Range is measured horizontally, ignoring y — deliberately.** A squad on a hill 15 m up should still be in weapon range; true 3D distance would let elevation silently eat the range budget and make combat unpredictable on slopes.

---

## Buying things: three layers

Three distinct questions, three owners. Getting this wrong is where every build-economy bug came from:

| Layer | Question | Owns |
|---|---|---|
| `EconomyComponent.buy_…()` | *Should this happen?* | Costs, caps, tech gates. Refuses with a `PurchaseResult` the UI turns into words. |
| `Build` (a node) | *Is it happening yet?* | Progress, per-frame spend, cancellation. |
| `RosterComponent.add_…()` | *Can this exist? Make it.* | Preconditions and instantiation. Knows nothing about money. |

The middle layer is a **node, not a method**, because construction holds state — how far along, whether it is running, what multipliers apply. Functions do not hold state; nodes do. That is why there is no `build_unit()`.

`Build` nodes live under the squad's `Economy` node, one per purchasable thing, configured in the inspector.

---

## Adding things

**A new squad type** — duplicate a `.tres` in `Resources/SquadStats/`, change the numbers, assign it to a squad scene's `Stats` and to its `Roster`, `Movement` and `Economy` components. No new scene needed unless the node layout differs.

**A new order** — write a `State` subclass, add it as a child of `StateMachine`, set its `parent` NodePath to the squad, and map it to a slot in the scene's `states` dictionary. Override `controls_weapons()` if it aims for itself.

**A new purchasable** — add a `UPGRADE_TYPE`, a `Build` node under `Economy`, a gate in `EconomyComponent.request_build()` if it needs one, and an arm in `Build.complete()` calling the component that makes the thing exist.

---

## Script conventions

Every script follows one layout. `#region` blocks in this order:

```
signals → constants → configuration (@export) → node references (@onready)
→ state → lifecycle → one region per concern
```

Region headers are decorated so they read at a glance and still fold in Godot's editor:

```gdscript
#region ───────────────────────────  build panel  ────────────────────────────
```

Below the lifecycle callbacks, group by **concern**, not by public/private — a handler sits with the thing it updates. Use `@export_group(...)` to organise the inspector; close with `@export_group("")` if ungrouped exports follow.

Two habits worth keeping:

- **Fail loud.** A fallback that guesses (`if the export is empty, go find something that looks right`) hides setup mistakes for weeks. Prefer a null reference on frame one that names the node.
- **Never store what something else already knows.** The nav agent knows your destination; the marker array knows your squad cap; a valid reference answers "do I have a target". Every duplicate pair in this codebase started in agreement and drifted.

---

## Where to look next

- **RTS Base Teardown** — the standing architecture review, with a backlog of unbuilt systems and an order-of-attack list.
- **Unbundling squad.gd** — the refactor plan that produced the component split, with the placeholders that still need wiring.
- **Wiring the Match** — the staged plan for getting from one hardcoded player to 3v3: collapsing the six ownership records, teams, match setup, and win conditions.

## Known issues

- **Terrain3D 1.0.1 on Godot 4.7** emits two startup messages — a `get_texture_slice_view` mipmap error on the Mobile renderer and an `instance_reset_physics_interpolation` deprecation. Neither is fatal; both come from the addon, which officially covers 4.4–4.6. Minimal repro: a camera plus a Terrain3D node on Mobile.
- **`state_update()` never runs** — nothing calls `state_machine_process()`, so any logic there is dead. Relevant to `ai_idle_state`.
- **`last_squad_index` is never written**, so quick-swap-to-previous has no history yet.
- **`State.move_speed` and `State.animation_name` are unread** — hooks waiting on the per-state speed cap and an `AnimationPlayer`.
- **`display_builds_progress` is a fixed pool of widgets**; a squad with more upgrades than slots silently loses the extras.
