# Feature inventory

**What this page is.** A plain-language list of every feature the brief asks this game to have,
what state each one is in, and what this project does differently from the reference material
the brief was written against. It is written for the owner, not for programmers: every row says
what a player would see, not which class draws it.

**What this page is not.** It is not a promise about dates, and it is not a description of
anything that exists. A row marked *Planned* has no code behind it, and the game does not draw a
mock screen for it. If a row says *Built*, the file named beside it is the thing that does it.

**Nothing here is copied from the reference material.** The reference folder in the owner's
private Drive informed *which features matter* and *where they sit on the screen*. No name,
icon, picture, number, sentence, unit or piece of art from it is in this repository, and none is
planned to be. The game's own words are in `src/ui/strings.gd`; its own numbers come from
`data/`; its own marks are the licensed icons recorded in `THIRD_PARTY_LICENSES.md`.

## 1. The three words this page uses

| Word | What it means |
| --- | --- |
| **MVP** | Needed for the first version a person could play for an hour without hitting a dead end: one country, one economy loop, one political loop, and an honest interface. |
| **LATER** | Wanted, designed in outline, and deliberately **not** built yet. It goes in after the MVP works, because a system with no real data behind it is a mock screen. |
| **REJECTED** | Will **not** be built, with the reason written down. Some of the brief's features are rejected on principle, not for lack of time. |

Every row also says whether it is **Built** (with the file), **Planned** (designed, not built), or
**Not possible yet** (blocked on data or on another system). "Built" is never used loosely: it
means there is code, a test, and a screen or command a player can reach.

## 2. The main screen, zone by zone

The brief describes a single game screen with fixed zones. This is what became of each one.

| Zone | What the brief asks for | Call | State today |
| --- | --- | --- | --- |
| Top-left | The player's avatar, Gold Coins, Red Gems, level and experience | **MVP** | **Built.** `src/ui/hud/game_hud.gd` shows the profile's avatar, both currencies, level and the experience bar. The avatar is the licensed icon recorded in `data/ui/icon_sources.json` (`src/ui/icons/icon_view.gd`), tinted by the theme, with a drawing in code as the fallback — never a photograph. |
| Top-right | The country's flag, which opens the country's overview | **MVP** | **Built.** The flag button opens `src/ui/hud/country_overview_panel.gd`, which reuses the same "what do we know about this country" panel as the map. |
| Below the top bar | A strip of the country's key figures | **MVP** | **Built**, and limited to what the data supports: population, area and GDP appear with their as-of year, currency appears with its ISO code, and anything the data lacks is printed as *Not available* rather than zero. |
| Left rail | Messages and alerts, with a count of unread | **MVP** for messages; **LATER** for alerts as a separate thing | **Built** for messages: `messages_panel.gd` reads the campaign's own event log and shows an unread count. Alerts that interrupt play are **LATER** — the game does not interrupt, because that is the pressure the brief's reference relies on. |
| Right rail | Daily reward, events, news, diplomat movements | **REJECTED** for daily rewards; **MVP** for news; **LATER** for diplomat movements | **Built** for news (`news_panel.gd`, printed from the same log as a newspaper page). Diplomat movements need diplomacy, which does not exist yet. Daily rewards are rejected in §4. |
| Bottom-left | Menu, research, missions | **MVP** for menu; **LATER** for research and missions | **Built** for the menu and the tutorial. Research needs an economy to spend against; missions need things to do. |
| Bottom-centre | A category bar that opens a tabbed panel for each part of the game | **MVP** | **Built** as a shell: seven categories, one of them (Country) with a real panel behind it. The other six say they are planned instead of opening a mock screen. |
| Bottom-right | The date, and the speed the clock runs at | **MVP** | **Built.** Four speeds, pause, and the in-game date in the world's own calendar. |

Three rules govern all of it, and they are not negotiable:

1. **Real or visibly missing.** A figure is read from a file the game ships or from the running
   campaign. A gap is printed as *Not available* — never a zero, never a plausible guess.
2. **Touch first, keyboard too.** Every control is at least 48 px tall (40 px on a very short
   window, with the exception recorded and measured), reachable with keyboard and mouse, and
   described to a screen reader.
3. **No pressure.** Nothing in the interface counts down at a player who is not playing.

**The marks.** Every symbol on the shell — the avatar, map, messages, news, menu, tutorial,
pause and the seven categories — is a licensed game-icons.net file, pinned to one commit,
credited in `THIRD_PARTY_LICENSES.md` and cross-checked against `data/ui/icon_sources.json` by
`tests/suites/test_icons_licensed.gd`. Each meaning also keeps the drawn shape it had before
(`src/ui/hud/shell_icon.gd`), and `src/ui/icons/icon_view.gd` uses it when the file cannot be
read: a missing asset leaves a legible button, never a blank space. Nothing here is traced from
the reference material; the crosswalk names the author and the licence of every file.

**The notes page.** *What is new* (`src/ui/screens/whats_new/`, reached from the main menu's
Library group and from the pause menu) says what changed in the build the player is running. Each
line carries the files that make it true, and a test reads them, so the page cannot describe work
that was reverted. It ends with **Not in this build**, because a notes page that only lists
additions turns "in progress" into a claim nobody checked. The rules are in
`docs/WHAT_IS_NEW.md`.

## 3. The game's systems

Each system below is one paragraph of plain language, then its call, then what is actually in the
build. The order roughly follows the brief.

### 3.1 Buildings and infrastructure — **LATER**

A nation is made of buildings: power stations, farms, factories, schools, hospitals, roads,
housing, offices and defences. The brief's shape is a large catalogue in about nine groups, with
electricity as a hard limit — a building that needs power cannot run without it.

*The call:* **LATER.** This is not a small system: it needs a construction queue, upkeep, inputs
and outputs, and a power balance that is honest. Building it before the economy exists would mean
inventing prices and production rates, which is exactly what this project refuses to do.

*What is in the build:* nothing. The six unbuilt categories say so on screen. The icons for the
groups exist (`buildings`, `industry`, `housing`, `electricity`, `health`, `education`,
`transport` in `data/ui/icon_crosswalk.json`) so the interface is ready when the system is.

*What we will change:* the catalogue will be **smaller and justified** — every building's numbers
traceable to a source or clearly labelled a design choice — and electricity will be a *limit with
a visible cause*, so a blackout says which buildings stopped and why.

### 3.2 Diplomacy — **LATER**

Relations with other countries, in the brief: an embassy, a relationship score from 0 to 100, and
around sixteen actions (gifts, treaties, sanctions and so on).

*The call:* **LATER.** Diplomacy needs two things this build does not have: a political model for
another country to *want* something, and real data about the relationship. The brief's sixteen
actions are a menu; without a reason for the other side to say no, they are a vending machine.

*What is in the build:* nothing but the icon and the category, which is planned.

*What we will change:* a relationship will be **explained in a sentence** ("they accepted because
their trade with you is worth more than the offer they refused"), and the score will be derived
from recorded events rather than nudged by a click.

### 3.3 Military, intelligence and internal security — **LATER**

Force structure, spies, saboteurs and coups, in the brief.

*The call:* **LATER**, and the *covert* half is on the owner-decision list in §6: a game that lets
a player run saboteurs and coups has to answer what it is teaching.

*What is in the build:* nothing. No unit, no order, no hidden number.

### 3.4 Economy: contracts, loans, taxes, income and expenses — **LATER (the first thing after the MVP shell)**

Resource contracts, loans, tax sliders, and the two tables every player wants: where the money
comes from, and where it goes.

*The call:* **LATER**, and it is the largest item in the MVP's own queue. It needs the country's
real figures as a starting point, which is what the reconnaissance in
`docs/DATA_CANDIDATES.md` (Milestone 11, Task 4) is for. It will also need a rule the player can read.

*What is in the build:* nothing is simulated. The country's population, area, GDP and currency
are *shown*, from the shipped data, and never changed by the game.

*What we will change:* the two tables will **reconcile to the last unit** — income minus expenses
equals the balance, always, and the test suite checks it — and a tax change will show its effect
on households, not only on the treasury.

### 3.5 Ministries and ministers — **LATER**

About fifteen ministries, each with a minister, in the brief. The brief's reference ties minister
quality to payment tiers.

*The call:* **LATER**, and the paid-tier part is **REJECTED**. Ministers will have **skills and
loyalty**, earned and changed by what happens, never bought. A minister who is good at health and
disloyal is more interesting than one who is expensive.

*What is in the build:* nothing.

### 3.6 The United Nations: resolutions, votes, bribery, security council — **LATER, and partly an owner decision**

*The call:* **LATER.** The General Assembly and the Security Council are real institutions with
real rules, and a game that models them has to take a position on vetoes and on bribery as a
mechanic. That position is the owner's to take (§6).

*What is in the build:* nothing.

### 3.7 Ideology and religion — **LATER, and an owner decision**

The brief wants ideology and religion to have effects. This project has a **neutrality rule**: it
does not tell a player which belief is better, and it does not put a faith or a political
alignment on a scoreboard.

*The call:* **LATER**, pending the decision in §6. The likely shape is that a country's *recorded*
composition affects **what a policy costs politically**, never whether it is "right".

*What is in the build:* nothing. No religion or ideology field is in a save.

### 3.8 Public ratings and attractions — **LATER**

How the public sees the government, and what draws people and money to a country.

*The call:* **LATER.** A rating has to be **explained**: "approval fell because electricity
prices rose and nothing else changed". A number that moves without a sentence is a decoration.

### 3.9 The research tree — **MVP (a short one)**

Spending on research to unlock better buildings, policies and units.

*The call:* **MVP**, but **short**: a first version with a handful of branches that each unlock
something a player can see in the same session. The brief's full tree is **LATER**.

*What is in the build:* nothing yet; the icon (`research`, `research_tree`) and the category
("Research") exist as planned.

### 3.10 The space programme — **LATER**

*The call:* **LATER.** It is the most expensive thing in the brief and the least connected to
the national systems that would make it meaningful.

*What is in the build:* nothing.

### 3.11 Rankings and the four ways to win — **MVP for rankings, LATER for victory conditions**

*The call:* rankings **MVP** (a table of countries by a measure the game actually tracks, with the
measure named). Four victory types **LATER**: each one needs the system it measures to exist
first, and a victory screen for a system that is not built is a lie with a trophy.

*What is in the build:* nothing. The country comparison screen compares recorded statistics and
never invents a rank.

### 3.12 News and messages — **MVP — Built**

*The call:* **MVP**, and it is the interface's spine: every system that changes something writes
an event, and the news page and the messages rail print those events.

*What is in the build:* `src/core/events/event_log.gd` (a typed, capped log with a documented
migration), `messages_panel.gd`, `news_panel.gd`, `docs/EVENT_LOG.md`. Four event types are
recorded today: campaign started, campaign loaded, autosave, manual save.

### 3.13 Missions — **LATER**

*The call:* **LATER.** A mission is a promise of a reward; the reward has to be worth something,
which needs the economy.

*What is in the build:* nothing.

### 3.14 Daily rewards — **REJECTED**

*The call:* **REJECTED** as a pressure mechanic. See §4.

*What is in the build:* nothing, and nothing is lost by not opening the game for a day.

### 3.15 Profile, level and VIP — **MVP — Built**

*The call:* **MVP**, with one change: **VIP is earned, never bought.** It is derived from the
player's level and unlocks one extra clock speed at VIP 5. It never gates essential gameplay and
there is no way to pay for it, because there is no payment of any kind in this game.

*What is in the build:* `src/ui/screens/profile/`, `docs/PROGRESSION.md`, the avatar gallery of
twenty drawings, and the level/experience strip on the game screen.

## 4. What this project refuses, and why

| Refused feature | Why it is refused |
| --- | --- |
| An in-game **store** | There is nothing to sell. A store in a single-player game is a shop with no goods, and its only function is to make a player feel short of something. |
| **Gem purchases** and "instantly complete for gems" | This turns patience into a price. A player who cannot wait is a player being charged for the game's own pacing. |
| **Sign-in prompts**, accounts and cloud saves by default | The game works offline and stores saves on the device. An account is a way to watch a player, and this game has nothing to watch. |
| **Daily-login pressure** — streaks, "come back tomorrow or lose it" | It punishes a player for having a life. Nothing in this game expires while the game is closed. |
| **Absurd numbers** — treasuries in the quadrillions, "one million soldiers" | A number a player cannot picture is a number a player cannot judge. Figures stay in the range of the real world they describe, and a missing figure stays missing. |
| Paid **minister tiers** and paid **speed** | Skill and pace are earned by playing. See §3.5 and §3.15. |

## 5. What we change from the reference's approach

| Change | What it means in practice |
| --- | --- |
| **Realistic data** | Every starting figure comes from a recorded source with an as-of year. Where no source gives a figure, the game prints *Not available*; it never fills the gap. |
| **Real political systems and elections** | Elections follow a stated rule (turnout, seats, a result the player can check) rather than a random "you lost" card. The rules are written down before they are coded. |
| **Ministers with skills and loyalty, not paid tiers** | A minister's usefulness is visible and explained; loyalty changes with what the government does. |
| **Explanations of why things changed** | Every moving number has a sentence beside it naming its cause. If nothing caused a change, nothing changed. |
| **Search and filters in every long list** | Any list longer than about a dozen rows gets a search field and a filter. The country picker already does this; every later list will. |
| **Accessible touch targets** | 48 px minimum, 40 px only on a very short window, both measured in `docs/CONTROL_SIZES.md` and enforced by tests. |
| **Both themes, reduced motion, keyboard** | Every new screen is checked in the light and dark palettes, with reduced motion on, and reachable without a mouse. |

## 6. Decisions only the owner can make

These two change what the game *is*, so they are written here rather than decided quietly in
code.

1. **Religion: effects or neutrality?** The brief gives religion effects on the country. This
   project's neutrality rule says it never ranks a faith. The options as the owner sees them:
   (a) religion appears only as **recorded composition in the data**, with no effect on any
   score; (b) religion affects **political cost** — a policy's price in approval and stability —
   with no direction of "better" implied; (c) religion is left out of the game entirely. Until the
   owner chooses, nothing religious is in a save, a formula or a screen.
2. **"Annexation" and "nuclear war": literal or abstract?** The brief allows both as outcomes.
   The options: (a) they appear **only as abstract strategic results** — a country's status
   changes, no map redrawing, no footage, no casualties as a score; (b) they are **not modelled**
   at all; (c) they are modelled in detail, which this project's own design notes argue against.
   Until the owner chooses, neither exists, and the military system stays LATER.

Both decisions are recorded as open questions in `docs/OPEN_ENDED_DESIGN.md` too, so they cannot
be answered by accident in a later milestone.

## 7. Summary

| Call | Count | Systems |
| --- | --- | --- |
| **MVP** | 9 | top bar and currencies, country overview, figures strip, messages and news, menu and category bar, clock and speed, profile/level/VIP, a short research tree, rankings |
| **LATER** | 13 | buildings, diplomacy, military and intelligence, economy, ministries, the UN, ideology and religion, public ratings, the full research tree, space programme, victory conditions, missions, diplomat movements |
| **REJECTED** | 6 | store, gem purchases, instant completion, sign-in prompts, daily-login pressure, absurd numbers |
| **Owner decision** | 2 | religion effects versus neutrality; annexation and nuclear war literal or abstract |

The MVP is deliberately small. It is the smallest set of systems that lets one country be played
for an hour with every figure and every message traceable to a source, and it is the only part of
this page that will be called "done" when it is done.
