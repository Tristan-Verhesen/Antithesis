# ANTITHESIS — Game Design Pitch

> **Every win creates its counter.**
> A round-based 1v1–5v5 arena shooter for Roblox. One life per round. The weapon you win a round with is **Burned** and sits out the next one.

Units: studs and seconds. All numbers are launch values. Put them in one server-side tuning table so they can be patched without a publish.

---

## 0. One-Page Summary

| | |
|---|---|
| **Genre** | Round-based competitive arena FPS (first-person) |
| **Formats** | 1v1 Duels, 2v2 Doubles, 3v3–5v5 Squads, lobby FFA ("The Pit") |
| **Session unit** | Quick Duel ≈ 3 min, Ranked Duel ≈ 5 min |
| **Core hook** | **Burn**: winning a round benches the primary you carried for one round |
| **Skill ceiling** | Momentum movement (slide, dash, wall-bounce), counter-strafe accuracy, deck mastery |
| **Skill floor** | No economy, no heroes, no abilities, 4 slots, infinite reserve ammo |
| **Art** | "Contrast": matte low-poly with two saturated, perspective-relative colors |
| **Business** | Cosmetic-only. Season pass, direct-purchase shop, no paid random items, no XP boosts |
| **Platforms** | Mobile, PC, Xbox, PlayStation, full crossplay |

---

## 1. Core Hook & Differentiator

### 1.1 Elevator Pitch
*Antithesis is a fast, one-life-per-round shooter. Every round you win, your weapon burns. Winners have to adapt and losers keep their best tool, so a match is never decided in the first round.*

### 1.2 The Burn Rule (signature mechanic)
- Each player brings a **Deck**: **3 primaries** + 1 secondary + 1 melee + 1 utility.
- In each round you carry **1 primary**, chosen during the Pick Phase.
- **Win a round → the primary every winning player carried is Burned for the next round.** It returns the round after that.
- Losers keep everything.
- Only primaries burn. The rule does not care which weapon got the kills, so it can't be dodged by finishing with a pistol.
- A drawn round causes no Burn.
- The tooltip is one sentence: **"Win with it, lose it for a round."** On the HUD, the Burned weapon card flips over and catches fire.

Why it works:
1. **Built-in comeback.** The leader always plays their 2nd- or 3rd-best weapon. Matches stay close, and close matches get requeued.
2. **Versatility is the skill.** Top players have to master 3+ weapons. That feeds mastery progression across the whole roster, which spreads skin demand across every weapon.
3. **No stale meta.** One dominant gun can never be used two rounds in a row by a winning player.

### 1.3 Versus the Market

| | Loadout duel shooters (*Rivals*-style) | Gun-game shooters (*Arsenal*-style) | **Antithesis** |
|---|---|---|---|
| Weapon variety in a match | Player picks once and often stays on one comfort weapon | Forced, random cycling | Player-built deck, **forced rotation only when winning** |
| Comeback mechanic | None | None | Burn |
| Movement | Slide/jump | Basic | Slide → slide-jump → dash → wall-bounce chains |
| Clip-readiness | Incidental | Incidental | **Built in**: Shorts-safe HUD, Final Frame slow-mo, 9:16 Theater |
| Time to first shot | Lobby | Instant | **Instant** (live lobby FFA while queueing) |

Low barrier: one new rule, explained in one sentence and shown on the HUD. Everything else follows conventions players already know.

### 1.4 Aesthetic: "Contrast"
- **Style:** clean stylized low-poly. Matte surfaces in two neutrals: off-white concrete `#E8E6E1` and graphite `#2B2D31`. No realistic textures.
- **Duality in the arenas:** every arena has 180° rotational symmetry and is split into a **light half and a dark half**. That gives instant orientation and callouts ("dark stairs"), and the symmetry means no side swaps are needed.
- **Perspective-relative colors:** your team is always **Cyan `#22D3EE`** and enemies are always **Orange `#FB923C`**. Blue/orange is colorblind-safe, and there are alternate palettes in Settings.
- **Enemy rim:** every enemy gets a thin orange outline (`Highlight`, FillTransparency 1, OutlineTransparency 0.4, DepthMode Occluded). Players can wear any avatar outfit, and dark outfits still can't camouflage.
- **No gore:** eliminated players shatter into low-poly shards in their team color. This keeps the experience at the broadest content-maturity rating.
- **Performance:** nearly every surface uses part color + SmoothPlastic. One 1024² trim atlas per arena. See §6.

---

## 2. Core Gameplay Loop & Mechanics

### 2.1 Movement

| Mechanic | Spec |
|---|---|
| Base speed | 18 studs/s, always running (no sprint key) |
| Acceleration / stop | 0 → 18 in 0.06s, 18 → 0 in 0.05s. Snappy, so counter-strafing is real |
| Counter-strafe accuracy | Perfect first-shot accuracy when speed < 4 studs/s |
| Weapon speed mult | SMG/Knife/melee 1.05–1.10 · AR/Burst/Crossbow 1.00 · Shotgun 0.97 · Sniper/Launcher 0.92 |
| ADS speed mult | 0.65 |
| Jump | 7.0 stud apex. Coyote time 100 ms, jump buffer 120 ms |
| Crouch | 9 studs/s, eye height drops 2.5 studs in 0.08s (crouch-peek / jiggle) |
| **Slide** | Crouch at ≥ 14 studs/s → enter at 30 studs/s, decays to 12 over 0.75s. 1.0s cooldown after slide ends. Downhill slopes sustain speed |
| **Slide-jump** | Keeps horizontal velocity, hard cap 32 studs/s (stays readable, no infinite bhop) |
| **Dash** | 1 charge, 4.0s recharge. 20 studs over 0.18s, follows input direction, usable in air (no vertical gain). Can't fire during the 0.18s |
| **Wall-bounce** | Airborne within 1.5 studs of a wall + Jump → reflect horizontal velocity × 0.9 + 38 studs/s up. Max 2 per airtime, 0.3s lockout between, resets on landing |
| Air control | 30% of ground acceleration |
| Fall damage | None |
| Weapon swap | 0.35s standard, 0.20s to secondary, 0.15s to melee |

Skill chain: **slide → slide-jump → wall-bounce → dash-cancel into ADS**. Each link is optional, so new players are still viable and experts get a visible ceiling.

### 2.2 Gunplay
- **HP:** 100. No shields, no regen within a round.
- **Hit multipliers:** Head ×2.0, Torso ×1.0, Limbs ×0.85, unless a weapon overrides them.
- **Ammo:** infinite reserve, magazines only. Ammo management is not a skill test here.
- **Recoil:** deterministic pattern for the first 6 shots plus ±10% random, so it can be learned.
- **Spread:** zero first-shot spread when ADS or stationary. Hip-fire bloom recovers in 0.25s.
- **Hitscan** for bullets. **Projectile** for Crossbow, Launcher and grenades (server-simulated, see §6).
- **Hitbox parity:** every character uses the same invisible hitbox rig. Avatar scale and accessories never change the hitbox (§6.3).

### 2.3 Launch Weapon Roster (17 items)

**Primaries (7)**

| Name | Type | Damage (body / head) | Fire rate | Mag / Reload | Falloff | TTK body / head | Role |
|---|---|---|---|---|---|---|---|
| **Paragon** | Assault Rifle, auto | 24 / 48 | 600 RPM | 30 / 2.0s | 70→140 studs to 75% | 0.40s / 0.20s | All-rounder |
| **Hornet** | SMG, auto | 17 / 30 | 900 RPM | 34 / 1.7s | 25→60 to 55% | 0.33s / 0.20s | Close-range, fast handling |
| **Breaker** | Pump Shotgun | 10 × 12 pellets (head ×1.5) | 72 RPM | 6 / 0.45s per shell | Full ≤10, 30% at 30 | One-shot ≤ ~9 studs | Corner holder |
| **Meridian** | Bolt Sniper | 95 / 250 (limbs 80) | 1.4s cycle | 5 / 2.6s | None | Headshot one-tap, body + any chip damage | Long sightlines. 0.25s scope-in, 8° hip cone |
| **Triad** | Burst Rifle, 3-round | 30 / 60 | 1,100 RPM in burst, 0.32s between bursts | 24 / 2.1s | 80→160 to 80% | 0.43s / one burst | Precision mid-range |
| **Quarrel** | Crossbow, projectile | 85 / 170 (limbs 70) | 0.9s per bolt | 1 / — | Bolt 320 studs/s, 0.35× gravity | Head one-shot | Skill-shot clips |
| **Kickback** | Rocket Launcher, projectile | 90 direct + splash 70→20 over 9 studs | 0.85s | 4 / 2.8s | 150 studs/s | Direct hit = kill | Rocket-jumping (self-damage capped at 25) |

**Secondaries (3)**

| Name | Type | Damage (body / head) | Fire rate | Mag / Reload | Notes |
|---|---|---|---|---|---|
| **Ward** | Pistol, semi | 22 / 50 | 400 RPM cap | 12 / 1.3s | Two-tap head. Reliable finisher |
| **Verdict** | Revolver | 50 / 110 | 0.46s | 6 / 2.2s | Head one-tap, heavy recoil |
| **Flicker** | Machine Pistol, auto | 14 / 25 | 1,000 RPM | 20 / 1.5s | Falloff 15→40 to 50% |

**Melee (3), always carried, move ×1.10**

| Name | Damage | Swing | Special |
|---|---|---|---|
| **Edge** (Knife) | 45 | 0.40s | Backstab (within 60° of target's back) = 100 |
| **Vow** (Katana) | 55 | 0.55s | Hold-release **Lunge**: 12 studs forward, 65 damage, 3.0s cooldown |
| **Breach** (Hammer) | 70 | 0.90s | Launches target up at 30 studs/s, which sets up air shots |

**Utility (4), pick 1 per Deck**

| Name | Charges/round | Spec |
|---|---|---|
| **Glare** (Flash) | 2 | Pops 1.2s after throw. 2.0s blind if within 50° of view, 0.8s peripheral. "Dark flash" accessibility option |
| **Crack** (Frag) | 1 | 2.4s cookable fuse. 100 within 3 studs → 25 at a 10-stud radius. Self-damage on |
| **Veil** (Smoke) | 1 | 11-stud sphere for 7s. Blocks aim assist and enemy nameplates |
| **Spring** (Jump Pad) | 1 | 0.4s deploy, launches at 70 studs/s up and keeps horizontal momentum, lasts 15s. **Enemies can use it too** |

**Unlocks:** new players start with Paragon, Hornet, Breaker, Ward, Edge and Glare. Everything else unlocks by account level 10 (about 10 matches, ~40 min). Order: L2 Meridian, L3 Crack, L4 Verdict, L5 Triad, L6 Veil, L7 Vow, L8 Quarrel, L9 Flicker + Spring, L10 Kickback + Breach. Ranked requires L10.

### 2.4 Match Flow

**Round timeline**

| Phase | Duration | Notes |
|---|---|---|
| Pick Phase | **8s** (Round 1: **12s**) | Choose an un-Burned primary. Burn flip animation plays here |
| Countdown | **3s** | Frozen, can look around and inspect |
| Live | **60s** (1v1) · **75s** (2v2) · **90s** (3v3–5v5) | One life per round |
| Collapse (overtime) | **15s** | Ring shrinks from the arena edge to 8 studs radius around center. 20 HP/s outside |
| Round End | **4s** | 2.5s **Final Frame** + 1.5s score update |

**Round resolution**
1. The last team with a living player wins.
2. If several teams survive Collapse, the team with higher total remaining HP wins.
3. Simultaneous death: the earliest validated lethal `fireTime` wins (§6.1). An exact tie is a **Draw**: the round is replayed with no Burn.

**Formats**

| Mode | Teams | Win condition | Avg. length | Queue |
|---|---|---|---|---|
| **Quick Duel** | 1v1 | First to 3 | ~3 min | In-server |
| **Ranked Duel** | 1v1 | First to 5 | ~5 min | Cross-server (MMR) |
| **Doubles** | 2v2 | First to 5 | ~6.5 min | Casual in-server, Ranked cross-server |
| **Squads** | 3v3–5v5 (dynamic) | First to 5 | ~7–8 min | In-server first, then cross-server |
| **The Pit** | FFA lobby | None (respawn 1.5s) | Continuous | Plays while queueing |
| **Call-Out** | 1v1 / 2v2 private | FT3 / FT5 / FT7 | — | Direct challenge |

**Dynamic Squads:** the matchmaker forms the largest even teams it can within 25s of queue start (minimum 3v3) and picks the arena by team size. **Ranked Squads ships in Season 2**, so launch queues aren't split thin.

**Launch arenas (4, all 180° rotationally symmetric with a light half and a dark half)**

| Arena | Size | Formats | Identity |
|---|---|---|---|
| **Fulcrum** | ~90 × 60 | 1v1, 2v2 | 3 lanes and a central bridge. Pure duel |
| **Prism** | ~70 × 70, 3 floors | 1v1, 2v2 | Vertical. Wall-bounce shafts |
| **Mirrorline** | ~140 × 100 | 3v3 | Mid-range, Spring pad perches |
| **Null Yard** | ~220 × 160 | 4v4, 5v5 | Container yard with long Meridian sightlines |

### 2.5 Audio & Visual Feedback ("Juice")

**Hit and kill feedback**

| Event | Visual | Audio |
|---|---|---|
| Body hit | White X, 120 ms | Soft tick |
| Headshot | Larger yellow X, 160 ms, yellow damage number | **"Crunch"**: 3 kHz metal tink layered over an 80 Hz thump |
| Kill | Red X. Victim freezes for 60 ms, then **Shatters** into 14 pooled shards pushed along the bullet direction | Kill "ding" that rises **+2 semitones per kill within a round** (cap 5) |
| Headshot kill | 2° FOV punch for 80 ms | Crunch + ding |
| Taking damage | Directional edge indicator, 0.5s | Muffled impact |
| Low HP (< 30) | 40% desaturation | Heartbeat |
| Round win | **Burn flip**: weapon card ignites (0.8s) | Whoosh + 1.2s stinger |

Damage numbers stack inside a 0.6s window and scale in size with damage.

**Banners** appear center-top, are worth +10 XP each, and reward flashy play:
`DOUBLE` · `TRIPLE` · `ACE` (wipe in 3v3+) · `CLUTCH 1vX` · `FLAWLESS` (round won at 100 HP) · `LONGSHOT` (headshot > 120 studs) · `NO-SCOPE` (unscoped Meridian kill) · `AIRBORNE` (kill while in air) · `REBOUND` (kill within 1s of a wall-bounce)

**Final Frame:** every round ends with a 2.5s replay of the round-deciding kill at 0.35× speed from the killer's POV, with the banner overlaid. Everyone in the match sees it. This is the game's built-in highlight moment, and it shows off the killer's cosmetics.

**Shorts-Safe HUD** (clip-native layout rule):
- **Critical zone, center 31% of screen width:** crosshair, hit markers, damage numbers, banners, Final Frame. This survives a full-height 9:16 crop of a 16:9 recording.
- **Secondary zone, center 56%:** killfeed (top-center, **not** top-right), round score, HP and ammo (bottom-center). This survives the 1:1 crop used in split-screen "gameplay + facecam" Shorts.
- Nothing important lives in the outer edges.

---

## 3. Cross-Platform Accessibility & Controls

Input type is detected from the last input used, and the HUD and prompts swap live. Crossplay is always on.

### 3.1 Mobile (Touch)

**Default layout: "Thumbs"**
- **Left:** floating joystick that spawns wherever the thumb lands in the left 40% of the screen.
- **Right cluster:** **Fire** (96 px; drag while holding to aim), ADS toggle, Jump, Crouch/Slide, Dash, Reload, Utility, Melee quick-swap.
- **Top-center:** weapon cards, tap to swap.
- **Presets:** Thumbs, Claw-3 (extra left-side Fire), Claw-4. A full HUD editor sets position, scale and opacity per button and saves to the player profile.
- Optional gyro aim, off by default, sensitivity 0.5–3.0.
- All buttons come from one sprite sheet (single texture).

**Fire modes**
- **Manual** (default): standard tap or hold to fire.
- **Assisted Fire** (auto-fire): fires once the reticle has overlapped an enemy torso hitbox for 150 ms, and never targets the head. Available in The Pit, Quick Duel and casual modes. **Disabled in Ranked**, because auto-fire plus aim assist works like a triggerbot against PC players.

**Aim assist** (Touch and Controller only, never KBM)

| Parameter | Touch | Controller |
|---|---|---|
| Slowdown (sensitivity mult inside assist cone) | 0.55 | 0.60 |
| Assist cone | Target hitbox + 1.5 studs (min 1.5°) | Same |
| Rotational tracking (share of target's angular velocity) | 30% | 35% |
| Tracking condition | Only while the player is giving move or aim input | Same |
| ADS pull | Casual: 0.12s, ≤ 2.5°. **Ranked: none** | Same |
| Max range | 90 studs | 90 studs |
| Disabled when | Target is in smoke, target is ≥ 50% behind cover, player is flashed, **target is dashing** | Same |

Dashing breaking aim assist is deliberate counterplay, and it gives the movement skill extra value.

**Parity KPI:** at equal MMR, win rate per input class stays within **47–53%** and headshot-rate deltas are reviewed weekly. Aim assist values are live-tuned from the server tuning table.

### 3.2 Console (Xbox / PlayStation)

**Default layout**

| Input | Action |
|---|---|
| LS / RS | Move / Aim |
| RT / LT | Fire / ADS |
| A | Jump (also wall-bounce) |
| B | Crouch / Slide |
| LB | Dash |
| RB tap | Throw utility |
| **RB hold** | **Radial wheel**: 4 weapon slots (Primary, Secondary, Melee, Utility) + 4 quick pings (Enemy, Push, Fall Back, Nice). Select with RS, release to confirm |
| X | Reload / Interact |
| Y tap / hold | Swap primary↔secondary / Melee |
| D-pad | Pings, emotes, inspect |

Alternate presets: **Tactical** (crouch on R3) and **Bumper Jumper**.

**Stick tuning**
- Read raw `Thumbstick1` / `Thumbstick2` positions and apply our own deadzones in a custom camera controller instead of relying on the default control scripts.
- **Inner deadzone:** 0.10 by default, adjustable 0–0.30 per stick. **Outer deadzone:** 0.98.
- **Response curves:** Standard (exponent 1.8, default), Linear, Dynamic (S-curve).
- Separate hip, ADS and scoped sensitivity, plus an X/Y ratio.
- **Turn boost:** after the stick sits at the outer edge for > 0.2s, yaw speed ramps +60% over 0.3s, so 180° turns are possible.
- **Haptics** (`HapticService`): light on fire, medium on hit, strong on taking damage or getting a kill. Can be toggled.
- **10-foot UI:** every menu is gamepad-navigable (`GuiService.SelectedObject`), with a minimum text size of 18 px at 1080p.

### 3.3 Accessibility (all platforms)
Colorblind palettes, dark flash, reduced screen shake and FOV punch, damage-number toggle, subtitle-style sound indicators (direction of footsteps and gunfire), and a **free** full crosshair editor (shape, color, gap, outline). The crosshair basics are never sold.

---

## 4. Retention & Progression

### 4.1 First-Time User Experience
| Time | Beat |
|---|---|
| 0s | Spawn into **The Pit** with a loadout. Shooting starts before any menu appears |
| ~10s | Contextual prompts: Slide, then Dash, then Wall-bounce, each shown once after the player first moves |
| ~60s | Prompt: "Your first Duel is ready." Auto-queue for Quick Duel |
| First match | 5s animated card explains Burn. Newcomer pool (account level < 5). Fill with a **clearly labeled** "Trainee" bot if the queue takes > 20s |
| ~40 min | Level 10. All weapons unlocked, Ranked unlocked |

### 4.2 Session Loop: from 3 minutes to 45
1. **Zero-wait loop:** the game is played in The Pit while queueing. Queue pops → 2s fade → in-server move to the arena. No teleport and no loading screen for casual modes.
2. **Auto-Requeue:** a 5s countdown on the results screen, on by default.
3. **Rematch / "Run it back"** (1v1, 2v2): both sides accept within 8s → same arena, no queue. Opponents who rematch 3+ times get a **Rival** tag and show up in friend suggestions.
4. **Nearest goals:** the results screen always shows the 2 closest milestones, e.g. "37 XP to Pass Tier 12" or "3 kills to Hornet Mastery 9".
5. **Heat:** each consecutive match win in a session gives +10% XP, up to +50%. It persists for 15 min after the last match, so leaving early costs it.
6. **Playtime Drops:** a Supply Drop for every 15 min of **in-match** time (time idling in The Pit doesn't count), max 3 per day. They land at 15, 30 and 45 minutes, so the target session length is the reward schedule.
7. **Daily:** First Win of the Day +500 XP, plus 3 Daily Contracts that each take 2–4 matches (e.g. "Win a round with a weapon you just un-Burned").
8. **Burn itself:** forced variety cuts down on match-to-match fatigue.

All XP bonuses (Heat, party, Premium) are additive, with a total cap of +100%.

### 4.3 Ranked

| Tier | Divisions | Notes |
|---|---|---|
| Bronze, Silver, Gold, Platinum, Diamond, Onyx | III → I | 100 RP per division |
| **Antithesis** | — | Global top 250 per ladder |

- Separate **Duel** and **Team** ladders (Team = Doubles at launch, Squads from Season 2).
- Hidden Glicko-2 MMR. Visible RP: **+20 for a win, −16 for a loss**, ±8 depending on how hidden MMR compares to visible rank.
- 5 placement matches. A demotion shield gives 3 losses at 0 RP before dropping (below Onyx).
- RP decays above Diamond after 7 days of inactivity.
- **Season soft reset:** hidden MMR is compressed 40% toward the median.
- Season rewards: a tier-colored weapon wrap (animated for Diamond+), plus an exclusive title for Antithesis tier. **Never purchasable.**

### 4.4 Weapon Mastery
Every weapon has 30 levels. Weapon XP: 1 per point of damage, +50 per kill, +100 per round won while carrying it. XP to the next level = `500 + 100 × level`.

| Level | Reward |
|---|---|
| 5 | Matte camo |
| 10 | **Tally**: a live kill counter on the weapon model |
| 15 | Inspect variant |
| 20 | Animated camo |
| 25 | Mastery Kill Effect (shatter variant unique to the weapon) |
| 30 | **Gilded** camo + weapon title |
| All 7 primaries Gilded | **Inverted** camo: negative-color finish on every weapon. Prestige flex |

Burn means mastering several weapons is part of winning, so mastery and competitive play push the same way.

**Kill effect families:** Shatter (default), Ember (burns to ash, ties to Burn), Glitch, Prism, Void.

### 4.5 Dynamic Titles
Recomputed weekly from rolling 7-day stats. Top 1% per stat, shown on nameplates in The Pit and in matches, and lost at the next reset unless re-earned:
`Untouchable` (Flawless rounds) · `Comeback Kid` (FT5 wins from 1–4 or worse) · `Burn Specialist` (win rate in post-Burn rounds) · `Skybound` (airborne kills) · `Longshot` (> 120-stud headshots) · `Executioner` (melee kills).

### 4.6 Social Hooks
- **Director Cam (spectating):**
  - Modes: POV, Chase (8 studs behind), **Broadcast** (camera rigs authored per arena that auto-cut to the latest damage events), and Free cam (private matches only).
  - 0.4× slow-mo on kills, applied on the spectator's client.
  - **3s delay in Ranked** to prevent ghosting.
  - The Pit has a live board of the top-ranked matches. Click one to spectate.
- **Reel (clipping):**
  - The server keeps a rolling 15s snapshot buffer (positions, aim, shots, cosmetic IDs).
  - After any round, **Clip It**, or auto-flagged highlights (multi-kills, clutches), save the clip as ~10–30 KB of packed data. 12 free slots.
  - **Theater** in the lobby replays clips with Director Cam, 0.25–1× speed, HUD hide, and a **9:16 Frame** guide for recording vertical clips with Roblox's native capture.
  - Clips can be shared with a 6-character code.
  - Because the snapshots include cosmetic IDs, every shared clip shows off the player's skins and finishers.
- **Crews:**
  - Up to 30 members and a 4-character tag. Creating one costs 2,500 Flux (a currency sink).
  - **Crew Points** come from members' match wins, capped at 10 per member per day so smurf farming doesn't pay.
  - Weekly crew leaderboard; the top 100 get banner flair.
  - **Crew Clash** weekend LTM: 5v5 crew vs crew.
- **Call-Outs (challenges):**
  - Challenge anyone from their lobby nameplate or your recent-opponents list.
  - Pick FT3/5/7, a custom weapon whitelist, and Burn on/off.
  - **Stakes are Rep only.** Rep is earned, non-tradeable and non-purchasable, and has its own leaderboard.
  - Wagering anything that can be bought with Robux or traded is a gambling-policy risk and stays out.
- **Party play:** +10% XP per friend in the party (max +30%), game invites via `SocialService:PromptGameInvite`, and join-friend.

---

## 5. Monetization & Economy (Fair-to-Play)

**Guiding rule: if it signals skill, it cannot be bought.** Ranked rewards, mastery camos, Inverted, Dynamic Titles and Rep can only be earned.

### 5.1 Antithesis Pass (per 8-week season)
| | |
|---|---|
| Tiers | 60, at 1,000 XP each |
| Free track | 20 rewards, including 1 kill effect and ~2,000 Flux |
| Premium | **449 R$**: all 60 tiers |
| Premium + 15 tiers | **1,199 R$** |
| Tier skip | 75 R$ each (season cosmetics only) |
| Contents | 12 weapon skins, 2 kill effects, 1 Finisher (tier 60), 2 inspects, 1 MVP podium animation, 2 animated crosshairs, 1 hit-sound pack, charms and sprays, titles |
| Pacing | About 2,050 XP/day at 30 min/day → completes in about 29 active days (around week 6 at 5 days/week) |

Match XP: 220 for a win, 150 for a loss, +10 per banner. Daily Contracts: 3 × 250 XP.

### 5.2 Shop (direct purchase, no premium currency)
6 daily rotating slots plus a weekly featured bundle.

| Item | Robux | Flux |
|---|---|---|
| Common weapon skin | 79 | 1,200 |
| Rare weapon skin | 179 | 3,000 |
| Epic skin (custom model parts) | 349 | — |
| Legendary skin (animated + custom fire/reload SFX) | 599 | — |
| Weapon charm | 49 | 800 |
| Animated crosshair pack | 99 | — |
| Inspect animation | 149 | — |
| Hit/kill sound pack (only the owner hears it; footsteps and enemy audio cues are never altered) | 149 | — |
| MVP podium animation (end-of-match podium) | 199 | — |
| Kill effect (plays on every kill) | 249 | — |
| **Finisher** (custom animated Final Frame on the match-winning kill, seen by everyone in the match) | 399 | — |
| Bundles | −30% vs separate | — |
| **Starter Pack** (once, first 7 days): Rare skin + kill effect + 1,000 Flux | 99 | — |

**Guardrails**
- No stat items, no XP or mastery boosts for sale, and no gameplay gamepasses.
- Skins never change silhouette, hitbox, tracer visibility or muzzle-flash size.
- **No paid random items at launch.** Supply Drops are earned only. If paid randomness is ever added, gate it with `PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted` and show odds.
- Native **Private Servers** at 100 R$/month for Call-Outs and crew scrims.
- **Roblox Premium:** +10% Flux and a nameplate badge. Premium engagement payouts reward exactly the retention this design targets.
- Post-launch test: opt-in rewarded video ads ("double Flux for this match") for eligible users only.

### 5.3 Daily Streak & Soft Currency ("Flux")
**7-day Streak, Play-to-Claim** (the day's reward unlocks after completing 1 match, which turns logins into sessions):

| Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Reward | 100 Flux | 150 Flux | Contract reroll + 150 | 200 Flux | Supply Drop | 250 Flux | **Streak Cache**: 400 Flux + guaranteed Rare charm/spray |

- **Streak Shield:** earned by finishing all weekly contracts. It automatically saves one missed day, so a single missed day doesn't make players quit.
- Every completed 7-day cycle adds a flame to the profile. 4 cycles earns the title `Unextinguished`.

**Flux faucets** (engaged player, ~10 matches/day)

| Source | Per day |
|---|---|
| Matches (30 for a win, 18 for a loss; **cap 600/day**; requires ≥ 150 damage or 1 round won) | ~240 |
| Daily Contracts (3 × 75) | 225 |
| Streak (average) | ~180 |
| Playtime Drops (3 × ~50) | ~150 |
| **Total** | **~800** |

That buys a Common skin every 1.5 days or a Rare every ~4 days, so free players always have something close to buy.

**Sinks:** Flux shop items, crew creation (2,500), nameplate colors (500), contract rerolls after the free one (100). The Pit pays no Flux, which stops AFK farming.

---

## 6. Technical & Engine Performance

### 6.1 Networking

**Movement: client-owned, server-validated**

| Option | Verdict |
|---|---|
| Full server-authoritative movement | Rejected for launch. Adds input latency on mobile networks, and the movement tech would feel sluggish |
| **Client network ownership + server Movement Budget** | **Chosen.** Responsive locally and validated every Heartbeat |

- Each Heartbeat, allowed displacement = `maxSpeed(state) × dt + tolerance`.
- The server tracks dash charges, slide cooldown and the wall-bounce count, and debits them when the client fires the `Ability` remote. Only a server-approved ability expands the movement budget for its window.
- 3 violations within 5s → the server corrects the CFrame (rubber-band). Repeat offenses → flag for review, then kick.
- Re-evaluate Roblox's server-authority character physics once it is production-ready. Keep the validator either way as defense in depth.

**Hit registration: "favor the shooter, within limits"**
1. **Client:** raycasts locally on fire (`RaycastParams`, Include filter on the Hitbox collision group). Shows an optimistic hit marker. Kill confirmations always wait for the server.
2. **Packet:** packed with `buffer` into ~30 bytes: shotId u16, `fireTime` (from `workspace:GetServerTimeNow()`), origin 3×f32, direction 3×i16, targetId u8, hitPart u8, hitOffset 3×i16. Sent over a reliable `RemoteEvent` and batched per frame.
3. **Server validation:**
   - Fire rate and ammo, both tracked on the server.
   - Origin within 3 studs + speed × latency of the shooter's server-side position history.
   - **Rewind** target hitboxes to `fireTime` using a 1.0s ring buffer sampled every Heartbeat. **Rewind cap: 250 ms.** Above that, shots are judged at 250 ms, so high-ping players have to lead their targets and low-ping victims don't die behind walls.
   - The ray must pass within the rewound hitbox inflated by 0.75 studs.
   - Line-of-sight raycast against static map collision only.
4. **Death ordering:** a lethal shot is credited by earliest validated `fireTime`. Shots that dead players fire later are discarded. **Projectiles already in flight still land**, so a rocket can trade.
5. **Projectiles** (Quarrel, Kickback, grenades): the server simulates them and decides hits. The shooter's client spawns a cosmetic copy instantly. The server and observers fast-forward the projectile by half the RTT (capped at 150 ms) so all views line up.
6. **Melee:** detected on the client, validated on the server against rewound positions (range + 2 studs).
7. **Cosmetic traffic** (tracers, impacts, footstep VFX, spectator snapshots at 20 Hz) goes over `UnreliableRemoteEvent`, staying under the per-payload size limit.
8. **Stat anomaly detection:** if a player's headshot rate is more than 3σ above their MMR bracket over 200+ shots, flag them for review. This runs on top of Roblox's platform client anti-cheat.

### 6.2 Server Topology
- **Main place, 32-player servers:** The Pit plus **8 arena instances** (6 small, 2 large), 4,000 studs apart, each in its own collision group.
  - Casual queues match players within the server, so a match starts with no teleport or loading.
  - **StreamingEnabled**, with `Player.ReplicationFocus` set to the player's current arena. Clients only stream the arena they're in.
- **Ranked:** a cross-server queue in a MemoryStore sorted map, keyed by MMR bucket. The window widens ±50 MMR every 5s, up to ±400 at 35s. Matched players go to a reserved server of a lean Ranked place (1 arena, no Pit) via `TeleportService`.
- **Squads fallback:** if the in-server queue can't fill 3v3 within 25s, fall back to the cross-server queue.
- **Data:** session-locked DataStore profiles (`UpdateAsync` lock). Saves at match end, on a 60s autosave, on `PlayerRemoving` and in `BindToClose`. Weekly leaderboards and Dynamic Title counters live in MemoryStore sorted maps and are snapshotted to DataStore at reset.

### 6.3 Characters & Hitboxes
- R15 avatars for visuals, so players see their own avatars. Body scale is locked in the experience's Avatar settings.
- A **uniform invisible hitbox rig** (Head, Torso, Limbs) is welded to `HumanoidRootPart`. Only hitbox parts are queryable for weapons; avatar meshes and accessories are excluded from hit detection.
- First person: the local avatar is hidden and replaced by custom viewmodel arms.
- Movement physics run through `ControllerManager` (Ground and Air controllers) so slide, dash and air-control values can be tuned directly.

### 6.4 Asset & Performance Budgets

| Budget | Target |
|---|---|
| Peak client memory (reference: low-end Android, 3 GB RAM) | **≤ 900 MB** |
| Join → playable in The Pit (mid-range mobile) | **≤ 8s** |
| Instances per arena | ≤ 2,000 (small) / ≤ 4,000 (large) |
| Arena textures | 1 × 1024² trim atlas + ≤ 4 × 512² decals. Everything else is part color + SmoothPlastic |
| Weapon viewmodel | LOD0 ≤ 4k tris, one 512² texture. `SurfaceAppearance` is allowed **only** on viewmodels |
| Weapon world model | ≤ 800 tris, part colors, no textures |
| Kill Shatter | 14 pooled shards (6 on Low), 2.0s life, no player collision |
| Live particles per client | ≤ 250 High / 120 Medium / 50 Low. Each kill effect ≤ 40 particles, ≤ 0.8s |
| Dynamic lights per arena | ≤ 8 |
| Concurrent audio voices | ≤ 24. SFX are mono and ≤ 2s |
| `Highlight` instances | ≤ 8 (enemy rims only; in The Pit, only the 8 nearest enemies. The engine cap is 31) |

**Mesh rules**
- Props use `RenderFidelity = Performance`. Hero meshes use `Automatic` (engine LODs).
- Collision fidelity is `Box` or `Hull`.
- Decor has `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` set to false. Fewer queryable parts also means faster raycasts.
- Backdrop and skyline models use `Model.LevelOfDetail = StreamingMesh`.

**Juice Level (auto-scaling):**
- The client tracks a rolling 5s average frame time. If it goes above 22 ms, quality drops one tier (High → Medium → Low).
- Quality never rises mid-match, so it doesn't oscillate.
- **Low tier:** no Bloom, SunRays or DepthOfField; 6 shards per kill; simplified damage numbers.
- Players can override it in Settings.

**Why performance = discovery:** Roblox recommendations weight engagement and retention, and crashes, slow joins and low frame rates hurt both. Treat the budgets above as ship blockers, not nice-to-haves.

---

## 7. Launch KPIs & Live-Ops

**Launch targets**

| Metric | Target |
|---|---|
| Time from join to first shot / first match | ≤ 10s / ≤ 30s |
| Crash rate | < 0.5% of sessions |
| D1 / D7 / D30 retention | ≥ 35% / ≥ 12% / ≥ 5% |
| Avg. playtime per DAU | ≥ 30 min |
| Requeue rate after a match | ≥ 70% |
| Input-class win-rate parity (equal MMR) | 47–53% |
| Pass conversion (of WAU) | ≥ 4% |

**Cadence**

| When | What |
|---|---|
| Weeks −6 to −2 | Closed alpha in private servers. Tune TTK and aim assist |
| Weeks −2 to 0 | Open beta, progress wiped at launch. Testers get a `Beta` title |
| Launch (Friday) | Season 1. Free `Founder` title for the first 14 days. Sponsored ads plus icon/thumbnail A/B tests showing the Burn flip and Final Frame |
| Every Saturday | Shop refresh + one rotating LTM: **Inferno** (losers burn too) · **One Chamber** (Verdict only, 1 bullet, +1 per kill) · **Rocket Duels** (Kickback + Spring only) · **Blade Night** (melee + utility only) |
| Week 4 | Mid-season weapon drop (8th primary) + balance patch |
| Week 8 → Season 2 | Ranked Squads, 5th arena, new Pass, ranked soft reset |
