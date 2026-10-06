# ANTITHESIS — Game Design Pitch

> **Every loadout has an answer.**
> A first-person 1v1 and 2v2 round-based arena shooter for Roblox. After each round, the winner locks in their loadout and it is shown to the loser. The loser then picks a loadout to counter it.

Units: studs and seconds. All numbers are launch values and live in one tuning module (`src/shared/Config.luau`) so they can be patched without touching game code.

---

## 0. Summary & Locked Decisions

| Decision | Choice |
|---|---|
| **Name** | Antithesis |
| **Core hook** | **Counter-Pick**: round winner locks first and their loadout is revealed; the loser picks after seeing it |
| **Loadouts** | Chosen before every round from weapons the player has unlocked |
| **Unlocks** | Weapons cost **Coins**. Coins are earned from battles only and can never be bought with Robux |
| **Camera** | First-person only |
| **Modes at launch** | 1v1 and 2v2 |
| **Platform priority** | PC-first competitive. Mobile and console are supported but secondary |
| **Art** | "Contrast" low-poly: matte white/graphite with cyan vs orange |
| **Monetization** | Cosmetic only. No loot boxes, no paid Coins, no stat items |
| **Team** | Solo dev, new to Studio. Claude writes the Luau, synced with **Rojo** |
| **Timeline** | As soon as possible, so this doc is scoped to a lean MVP. Everything else is marked **Later** |

---

## 1. Core Hook & Differentiator

### 1.1 Elevator Pitch
*A one-life-per-round duel shooter. Each round you either hold your ground or find the counter. Lose a round and you see exactly what beat you, then pick the answer.*

### 1.2 Counter-Pick (the Thesis → Antithesis rule)
1. **Round 1:** both sides pick blind and at the same time.
2. **Every round after:**
   - The round winner's loadout is the **Thesis**. Its default is "Keep", so a winner who does nothing locks in automatically.
   - Once it locks, a full-screen **reveal card** shows it to the loser.
   - The loser then builds the **Antithesis**: any loadout from their own unlocks.
3. **2v2:** the winning team's loadouts are both revealed, and the losing team picks after seeing them.
4. **Draw:** both sides pick blind again.
5. **Counter hints:** after the reveal, the pick screen highlights 1–2 suggested counters, so new players learn the matchups (see §2.4).

Why it works:
- **Built-in comeback.** The loser always has more information than the winner.
- **The meta can't settle.** Any comfort weapon gets countered as soon as you win with it.
- **Easy to learn.** No economy, no heroes, no abilities. It's "see their weapon, pick the answer."
- **Clip moment.** The reveal card followed by an instant counter-kill reads clearly in a 10-second Short.

### 1.3 Versus the Market

| | *Rivals*-style loadout duels | *Arsenal*-style gun game | **Antithesis** |
|---|---|---|---|
| Loadout | Picked once, often one comfort weapon | Random forced cycling | **Re-picked every round, with information** |
| Comeback mechanic | None | None | Loser counter-picks |
| Unlock path | Mixed | Play-based | Coins from battles only, never sold |

### 1.4 Aesthetic: "Contrast"
- **Surfaces:** matte low-poly in two neutrals, off-white `#E8E6E1` and graphite `#2B2D31`. Everything uses part color + SmoothPlastic, with almost no textures. This is the cheapest style to build alone and the fastest to render.
- **Arenas:** 180° rotationally symmetric, with a light half and a dark half. That gives instant orientation, and the symmetry means no side swaps.
- **Colors are perspective-relative:** your side is always **Cyan `#22D3EE`** and enemies are always **Orange `#FB923C`**. The pair is colorblind-safe.
- **Enemy rim:** a `Highlight` outline (FillTransparency 1, OutlineTransparency 0.4) on enemies, so dark avatar outfits can't camouflage.
- **No gore:** eliminated players shatter into low-poly shards in their team color.
- **Skins:** because weapons are built from colored parts, **a skin is just a palette swap**. New skins are nearly free to produce.

---

## 2. Core Gameplay Loop & Mechanics

### 2.1 Movement

| Mechanic | Spec | Ship |
|---|---|---|
| Base speed | 18 studs/s, always running | MVP |
| Accel / stop | 0 → 18 in 0.06s, 18 → 0 in 0.05s | MVP |
| Counter-strafe | Perfect first-shot accuracy below 4 studs/s | MVP |
| Weapon speed mult | Knife 1.10, SMG 1.05, AR/Burst 1.00, Shotgun 0.97, Sniper 0.92. ADS ×0.65 | MVP |
| Jump | 7.0 stud apex. Coyote time 100 ms, jump buffer 120 ms | MVP |
| Crouch | 9 studs/s. Eye height drops 2.5 studs in 0.08s (crouch-peek) | MVP |
| **Slide** | Crouch at ≥ 14 studs/s → enter at 30, decays to 12 over 0.75s. 1.0s cooldown | MVP |
| **Slide-jump** | Keeps horizontal velocity, capped at 32 studs/s | MVP |
| **Dash** | 1 charge, 4.0s recharge. 20 studs over 0.18s, in the input direction, usable in air. Can't fire during it | MVP |
| **Wall-bounce** | Airborne within 1.5 studs of a wall + Jump → reflect × 0.9 + 38 up. Max 2 per airtime | Later (v1.2) |
| Fall damage | None | MVP |
| Swap time | 0.35s. To secondary 0.20s, to melee 0.15s | MVP |

### 2.2 Gunplay
- **HP:** 100. No shields, no regen within a round.
- **Hit multipliers:** Head ×2.0, Torso ×1.0, Limbs ×0.85 (weapons can override).
- **Ammo:** infinite reserve, magazines only.
- **Recoil:** a learnable pattern for the first 6 shots plus ±10% random. First shot is perfectly accurate when ADS or stationary.
- **Hitscan only at MVP.** Projectile weapons come later, since they need more netcode.
- **Hitbox parity:** avatars are **R6**, which has one fixed body size. Accessories are excluded from hit detection (§6.3).

### 2.3 Launch Weapon Roster (11 items)

Loadout = **1 Primary + 1 Secondary + 1 Melee + 1 Utility**.

**Primaries**

| Name | Type | Body / Head | Fire rate | Mag / Reload | Falloff | TTK body / head | Cost |
|---|---|---|---|---|---|---|---|
| **Paragon** | Assault Rifle | 24 / 48 | 600 RPM | 30 / 2.0s | 70→140 to 75% | 0.40s / 0.20s | Starter |
| **Breaker** | Pump Shotgun | 10 pellets × 12 (head ×1.5) | 0.83s | 6 / 0.45s per shell | Full ≤10, 30% at 30 | One-shot ≤ ~9 studs | Starter |
| **Hornet** | SMG | 17 / 30 | 900 RPM | 34 / 1.7s | 25→60 to 55% | 0.33s / 0.20s | 150 |
| **Triad** | Burst Rifle (3) | 30 / 60 | 0.32s between bursts | 24 / 2.1s | 80→160 to 80% | 0.43s / 1 burst | 400 |
| **Meridian** | Bolt Sniper | 95 / 250 (limbs 80) | 1.4s cycle | 5 / 2.6s | None | Head one-tap | 600 |

**Secondaries**

| Name | Type | Body / Head | Fire rate | Mag / Reload | Cost |
|---|---|---|---|---|---|
| **Ward** | Pistol | 22 / 50 | 400 RPM cap | 12 / 1.3s | Starter |
| **Verdict** | Revolver | 50 / 110 | 0.46s | 6 / 2.2s | 300 |

**Melee**

| Name | Damage | Swing | Special | Cost |
|---|---|---|---|---|
| **Edge** | 45 | 0.40s | Backstab (within 60° of the target's back) = 100 | Starter |

**Utility** (charges per round)

| Name | Charges | Spec | Cost |
|---|---|---|---|
| **Glare** (Flash) | 2 | Pops 1.2s after throw. 2.0s blind if within 50° of view, 0.8s peripheral | Starter |
| **Veil** (Smoke) | 1 | 11-stud sphere for 7s | 250 |
| **Crack** (Frag) | 1 | 2.4s fuse. 100 within 3 studs → 25 at 10 studs. Self-damage on | 400 |

**Total unlock cost: 2,100 Coins, about 5 hours of play.** The starter set covers close and mid range, so counter-picking works from the first match.

**Later:** Quarrel (crossbow) and Kickback (rocket launcher), which are projectile weapons; Vow (katana lunge); Flicker (machine pistol); Spring (jump pad).

### 2.4 Counter Matrix (drives the pick-screen hints)

| Thesis (winner) carries | Suggested Antithesis | Why |
|---|---|---|
| Meridian | Veil + Hornet or Breaker | Smoke kills the sightline; the sniper moves slowly and loses up close |
| Breaker | Paragon or Triad + Crack | Out-range it; the frag flushes the corners it holds |
| Hornet | Triad or Meridian + Glare | Hornet falls to 55% damage beyond 60 studs |
| Paragon | Triad (mid) or Breaker (close) | Specialists beat the generalist at their own range |
| Triad | Hornet (close) or Meridian (long) | A burst rifle only wins at mid range |
| Any + Veil | Glare or Crack | Pressure the smoke instead of waiting it out |

Arenas mix **one long lane, one mid lane and one close-quarters route**, so every primary has a place it wins.

### 2.5 Match Flow

**Round timeline**

| Phase | 1v1 | 2v2 |
|---|---|---|
| Pick, Round 1 (blind, simultaneous) | 12s | 12s |
| Pick, later rounds | Thesis lock **5s** → reveal → Antithesis **7s** | Same |
| Countdown (frozen, can look) | 3s | 3s |
| Live | **60s** | **75s** |
| Collapse (overtime) | 15s: ring shrinks to an 8-stud radius at center, 20 HP/s outside | Same |
| Round end | 3s | 3s |

If a winner presses Ready or keeps their loadout, the Thesis phase ends early.

**Round resolution**
1. The last side with a living player wins.
2. If both sides survive Collapse, higher total HP wins.
3. An exact tie is a **Draw**: the round is replayed with blind picks.

**Formats**

| Mode | Win condition | Avg. length | Ship |
|---|---|---|---|
| **Duel 1v1** (casual) | First to 3 | ~3 min | MVP |
| **Doubles 2v2** (casual, solo or duo queue) | First to 3 | ~4 min | MVP |
| **Call-Out** (challenge a lobby player) | First to 3 / 5 / 7 | — | MVP |
| **Ranked 1v1** | First to 5 | ~5 min | Later (v1.1) |

**Ranked unlocks once a player owns every weapon (~5 hours)**, so nobody in Ranked is missing counter options.

**Arenas at launch (2)**

| Arena | Size | Identity |
|---|---|---|
| **Fulcrum** | ~90 × 60 | Three clear lanes (long / mid / close), central bridge. Teaches counter-picking |
| **Mirrorline** | ~120 × 90, 2 floors | Vertical mid-range. Slide routes and stair peeks |

### 2.6 Audio & Visual Feedback

| Event | Visual | Audio | Ship |
|---|---|---|---|
| Body hit | White X, 120 ms + damage number | Soft tick | MVP |
| Headshot | Large yellow X, 160 ms | **"Crunch"**: metal tink over a low thump | MVP |
| Kill | Red X. Victim **shatters** into 8 pooled shards | "Ding" that rises **+2 semitones per kill** in a round | MVP |
| Headshot kill | 2° FOV punch for 80 ms | Crunch + ding | MVP |
| Taking damage | Directional edge flash, 0.5s | Muffled impact | MVP |
| Low HP (< 30) | 40% desaturation | Heartbeat | MVP |
| **Thesis reveal** | Full-screen card slam showing the winner's loadout | Heavy "lock" stamp | MVP |
| Round win | Center banner | 1.2s stinger | MVP |
| **Final Frame** | 2.5s slow-mo replay of the round-deciding kill | — | Later (v1.1) |

**Banners** (+5 Coins each, to reward flashy play): `FLAWLESS` (round won at 100 HP), `NO-SCOPE`, `CLUTCH 1v2`, `DOUBLE` (2v2), `COUNTERED` (you won the round right after picking against a revealed Thesis).

**Shorts-safe HUD:**
- Crosshair, hit markers, banners and the reveal card stay in the **center 31%** of screen width. That survives a 9:16 crop of a 16:9 recording.
- Killfeed (top-center), score, HP and ammo (bottom-center) stay in the **center 56%**, which survives a 1:1 crop.

---

## 3. Controls & Cross-Platform

### 3.1 PC (primary)

| Key | Action | Key | Action |
|---|---|---|---|
| WASD | Move | LMB / RMB | Fire / ADS (hold or toggle) |
| Space | Jump | R | Reload |
| C / Ctrl | Crouch / Slide | 1 / 2 / 3 | Primary / Secondary / Melee |
| Shift | Dash | G | Utility |
| F | Inspect | Tab | Scoreboard |

- Custom first-person camera with `MouseBehavior.LockCenter` and no mouse smoothing.
- Sensitivity from 0.05 to 5.00 (type-in field) plus a separate ADS multiplier.
- FOV slider from 70 to 90 (Roblox FOV is vertical).
- All keys rebindable. Full crosshair editor (shape, color, gap, outline), always free.

### 3.2 Mobile (supported at launch, basic)
- Touch buttons via `ContextActionService:BindAction(..., true)`: Fire, ADS, Reload, Slide, Dash, Swap, Utility. Jump and the move stick use Roblox defaults.
- Drag on the right half of the screen to aim. Separate touch sensitivity.
- **Later (v1.1):** HUD editor (drag, scale, opacity) and aim slowdown (sensitivity ×0.55 within the target hitbox + 1.5 studs, max 90 studs, off in smoke or while flashed). Assisted auto-fire will **never** be allowed in Ranked.

### 3.3 Console (supported at launch, basic)
- RT/LT fire/ADS, A jump, B crouch/slide, LB dash, RB utility, X reload, Y swap (hold for melee).
- The camera reads raw `Thumbstick2` with our own deadzone: **inner 0.12** by default (adjustable 0–0.30), **outer 0.98**, response exponent 1.8.
- **Later (v1.1):** hold RB for a radial wheel (4 slots + 4 pings), aim slowdown ×0.60 with 35% rotational tracking, turn boost (+60% yaw at the stick's edge), and a `HapticService` rumble on hits.

**Parity target:** at equal rating, win rate per input type stays within 45–55%. Watch it weekly once mobile and console make up > 10% of matches.

---

## 4. Retention & Progression

### 4.1 First Session
| Time | Beat |
|---|---|
| 0s | Spawn in the lobby **firing range** (target dummies). The starter loadout is equipped |
| ~20s | One prompt: "Press Q / tap Duel to queue." Players can keep shooting dummies while they wait |
| First match | A 5s card explains Counter-Pick. **Newcomer pool:** players with fewer than 10 matches are paired together when possible |
| ~4 matches | First unlock (Hornet, 150 Coins). Unlocks are the first progression hook |

### 4.2 Session Loop (3 minutes → 45)
1. **Auto-Requeue:** 5s countdown on the results screen, on by default.
2. **Rematch / "Run it back":** both sides accept within 8s → same arena, no queue.
3. **Next-unlock bar:** the results screen always shows "**85 / 150 Coins → Hornet**".
4. **Win streak:** +5 Coins per consecutive win, up to +25.
5. **First Win of the Day:** +100 Coins.
6. **Call-Outs:** click a player in the lobby → challenge. Rivalries form between people sharing a server.

### 4.3 Mastery

| System | Spec | Ship |
|---|---|---|
| **Duel Rating** | Hidden Elo (K=32) on every 1v1, used to pair players within the server | MVP |
| **Weekly Wins board** | In-lobby leaderboard (top 10, `OrderedDataStore`, resets Monday) | MVP |
| **Ranked tiers** | Bronze, Silver, Gold, Platinum, Diamond (III–I) + **Antithesis** (top 100). +20 RP for a win, −16 for a loss. 8-week seasons | v1.1 |
| **Weapon Mastery** | 20 levels per weapon. Rewards: L10 Tally (kill counter on the weapon), L20 **Gilded** skin. All primaries Gilded → **Inverted** skin | v1.2 |
| **Titles** | `Counter Artist` (most COUNTERED banners), `Untouchable` (most FLAWLESS rounds), weekly top 1% | v1.2 |

### 4.4 Social

| Feature | Spec | Ship |
|---|---|---|
| Duo queue | Invite a player in the server into a 2v2 party | MVP |
| Friend invites | `SocialService:PromptGameInvite` | MVP |
| Call-Outs | Private challenge, choice of first to 3/5/7. **No wagers of anything purchasable** | MVP |
| Spectate | Watch any live arena in the server from the lobby (camera only) | v1.1 |
| Clips / Theater | Record the last 15s of snapshots, replay in a 9:16 framing mode | v1.3 |
| Crews | Clan tags + weekly crew leaderboard | v1.3 |

---

## 5. Monetization & Economy (Fair-to-Play)

**Rules:**
- Coins are **earned only** and never sold.
- Robux buys **cosmetics only**: no stat items, no XP or Coin boosts, no loot boxes.
- Anything that shows skill (Rating, Gilded, Inverted, Titles) can't be bought.

### 5.1 Coins (earn-only)

| Source | Amount |
|---|---|
| Match win / loss | 40 / 15. Requires ≥ 1 round won or ≥ 100 damage |
| Win streak | +5 per consecutive win (max +25) |
| Banner | +5 each |
| First Win of the Day | +100 |
| Daily streak (Play-to-Claim: the day's reward unlocks after one match) | D1 25 · D2 25 · D3 50 · D4 50 · D5 75 · D6 75 · **D7 150** |

At roughly 10 matches per hour that's ~350–450 Coins/hour, so all weapons are unlocked in **~5 hours**.

**Sinks** once all weapons are owned: Coin-only palette skins (300–800 Coins) and name colors (500). Coins stay meaningful after the unlocks.

### 5.2 Robux Cosmetics

| Item | Price | How | Ship |
|---|---|---|---|
| **Founder Pack** (Neon palette for all weapons + `Founder` title). Sold during launch month only | 199 R$ | Game Pass | MVP |
| Palette Packs (e.g. Chrome, Ember, Void: one palette across every weapon) | 99 R$ each | Game Pass | MVP |
| Kill-effect colors (shatter recolors) | 79 R$ | Game Pass | MVP |
| Individual skins, inspect animations, finishers, MVP podium | 49–299 R$ | Developer Products (rotating shop) | v1.2 |
| Season Pass (40 tiers, cosmetic only) | 299 R$ | Developer Product | v1.3 |

**Why Game Passes at launch:** Roblox tracks pass ownership itself (`MarketplaceService:UserOwnsGamePassAsync`). That means no receipt handling and no way to lose a purchase in our own save data, which is the safest path for a first-time dev.

---

## 6. Technical & Performance

### 6.1 Project Layout (Rojo)
```
default.project.json
src/
  shared/   → ReplicatedStorage.Shared      Config (all tuning), WeaponDefs, Remotes
  server/   → ServerScriptService.Server    MatchService, CombatService, DataService, ShopService
  client/   → StarterPlayer.StarterPlayerScripts.Client
                                            CameraController, MovementController,
                                            WeaponController, HUD, PickScreen
```
Arenas, weapon models and UI art are built in Studio and saved in the place file. Code lives in this repo.

### 6.2 Networking
**Movement: the client moves the character, the server checks it.**
- This is Roblox's default network ownership, so movement feels responsive on PC.
- Every Heartbeat the server compares distance moved with what the player's state allows: 18 normal, 30 sliding, 111 during a 0.18s dash, with tolerance.
- 3 violations within 5s → the server snaps the player back. Repeat offenses → kick.

**Hit registration: "favor the shooter, within limits".**
1. **Client:** raycasts on fire (`RaycastParams` Include filter on body parts) and shows a hit marker right away.
2. **Client → server:** `Fire:FireServer(origin, direction, hitPart, fireTime)`, where `fireTime` comes from `workspace:GetServerTimeNow()`.
3. **Server checks:**
   - Fire rate and ammo, both tracked on the server.
   - Origin within 5 studs of the server-side position.
   - **Rewind** the target to `fireTime` using a 1s position history sampled every Heartbeat. **Rewind cap: 200 ms.**
   - The ray must pass within the rewound part inflated by 1 stud.
   - Line-of-sight raycast against map geometry.
4. **Server applies damage** and confirms the kill. Kill feedback always waits for the server.
5. **Death ordering:** if both players fire lethal shots, the earlier `fireTime` wins and the later shot is discarded.
6. **Grenades:** the server spawns and simulates them. Damage is by distance plus a line-of-sight check.
7. **Cosmetic effects** (tracers, impacts) go over an `UnreliableRemoteEvent`.

### 6.3 Servers, Characters, Data
- **One place, 16-player servers**, each holding the lobby + **4 arenas**. Matches start inside the server: no teleports, no loading screens, no cross-server queue at MVP.
  - The pairing window widens by 100 Elo every 5s.
  - **Later:** a cross-server Ranked queue (MemoryStore + `TeleportService`), once concurrent players reach about 200.
- `StreamingEnabled` **off** at MVP. The whole place stays under 8,000 parts, and having everything loaded avoids a common class of beginner bugs.
- **Avatars: R6** (Game Settings → Avatar). One uniform body size gives hitbox parity for free. Accessories have `CanQuery = false`.
- **Data:** one `DataStore` key per player holds Coins, unlocks, loadout, palettes, Elo, streak date and settings.
  - Load on join with retries. Save with `UpdateAsync` on leave, every 60s, and in `BindToClose`.
  - There's no trading, so plain DataStores are enough.

### 6.4 Performance Budgets

| Budget | Target |
|---|---|
| Frame rate | 144+ FPS on a mid-range PC, 60 FPS on a mid-range phone |
| Parts per arena | ≤ 1,500 |
| Textures | Almost none. Part color + SmoothPlastic only. One decal sheet for the UI |
| Weapon models | Built from ≤ 40 parts, or one MeshPart ≤ 2k tris |
| Kill shatter | 8 pooled shards, 1.5s life |
| Particles live per client | ≤ 150 |
| Decor | `CanCollide`, `CanQuery`, `CanTouch`, `CastShadow` all false |
| Join → lobby playable | ≤ 5s |

**Asset rule:** only use Creator Store models that contain **no scripts**. Delete any scripts they come with, because free models are the #1 source of backdoors.

---

## 7. MVP Build Plan

### 7.1 One-Time Setup (new to Studio)
1. Install **Roblox Studio**. Create a **Baseplate** place, then **File → Publish to Roblox**.
2. **Game Settings:**
   - Avatar → **R6**.
   - Security → **Enable Studio Access to API Services**, so saves work in testing.
3. Install **Rojo**: the `rojo` CLI (from its GitHub releases) and the Rojo Studio plugin.
4. In this repo, run `rojo serve`. In Studio, open **Plugins → Rojo → Connect**.
5. Test a 1v1 locally: **Test → Clients and Servers → 2 Players → Start**.

### 7.2 Milestones (each one ends with something playable)

| # | Milestone | Done when | Built by |
|---|---|---|---|
| M1 | Gun feel | First-person camera, Paragon fires with server-validated hits, HP, death | Claude (code) |
| M2 | Duel loop | Queue in lobby → moved into the Fulcrum arena → rounds → first to 3 → back to lobby | Claude + you (block out Fulcrum) |
| M3 | **Counter-Pick** | Pick screen, Thesis lock, reveal card, Antithesis pick, counter hints, all 11 items | Claude (code), you (weapon models) |
| M4 | Coins & saving | Coins awarded, unlock shop, DataStore save/load | Claude |
| M5 | Movement & juice | Slide, dash, hit markers, sounds, shatter, banners, Shorts-safe HUD | Claude + you (SFX from Creator Store) |
| M6 | 2v2 + platforms | Doubles, duo invite, Call-Outs, touch and gamepad bindings, settings menu | Claude |
| M7 | Ship | Mirrorline arena, Game Passes, icon + 3 thumbnails, private playtest with 5+ friends, go public | You + Claude |

**Cut first if time runs short:** Mirrorline (launch with Fulcrum only), Call-Outs, then 2v2. Duel + Counter-Pick + Coins is the minimum shippable game.

---

## 8. Post-Launch Roadmap & KPIs

| Version | Adds | Trigger |
|---|---|---|
| v1.1 | Ranked 1v1, Final Frame, spectate, mobile HUD editor + aim slowdown, console radial | D1 retention ≥ 20% |
| v1.2 | Wall-bounce, projectile weapons (Quarrel, Kickback), Weapon Mastery, rotating Robux shop | Average session ≥ 12 min |
| v1.3 | Season Pass, Clips/Theater, Crews, 3rd arena | ≥ 200 concurrent players |

**Cadence (solo):** update every two weeks on **Saturday**. Each update ships one headline item (weapon, arena, palette pack or limited-time mode).

**Launch KPIs**

| Metric | Target |
|---|---|
| Time from join to first shot | ≤ 10s |
| D1 / D7 retention | ≥ 25% / ≥ 8% |
| Average session | ≥ 15 min |
| Requeue + rematch rate | ≥ 60% |
| Crash rate | < 1% |

**Getting players (low budget):**
- Post clips of the reveal → counter-kill on TikTok and Shorts. The Shorts-safe HUD makes raw recordings usable.
- A small Roblox Ads Manager campaign in launch week.
- A Discord server for playtesters.
- A/B test the icon and thumbnails once traffic allows.
