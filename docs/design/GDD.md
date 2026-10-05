# Camboree: Game Design Document (working draft)

> Living document. "Open question" marks things that aren't decided yet. Scoring details are in [`scoring-v0.md`](scoring-v0.md).

## Pitch

A 1–4 player cozy photography RPG set in **Ayesso City**. You take over your grandmother's photo studio, learn to shoot, and help the city come alive one photo at a time. Each style of photography plays like a different game.

**Inspirations:** Stardew Valley, WarioWare, Pokémon Snap, Katamari Damacy, Animal Crossing.

## Core goals

- A fun game I'd want to play solo or with friends, and one that doesn't feel like a cheap one-off.
- 1–4 players. RPG structure. Multiple game styles, all built around photography.
- Encourage and simulate traditional photography, participation in your community, history, and appreciation of the world around us.
- Solo replayability, a fun co-op story, and a fast-paced versus mode.
- All cosmetics are purchasable. Achievement unlocks should feel more special, for example a cool colorway or a slightly different variant.
- Weird, silly, and swaggy fr.

## Story

**Core messages**

- Photography is accessible to anyone.
- Being involved in your community is good.
- Past vs. present vs. future, and then past **and** present **and** future.
- Balance.
- Passing of the torch.

**Setup:** Your grandmother runs a studio in the city and is a world-renowned old-school photographer. She invites you out for some arbitrary reason, then announces she's retiring and picks you to run the studio. She gives you a basic film camera and a basic digital camera, and she stays integral to the story.

## Game modes

> Naming decision: camera terms (Program, Manual, Burst) are kept for **camera assist tiers**, not game modes, to avoid confusion.

| Mode | Players | Notes |
|---|---|---|
| **Story** | 1–4 co-op | Priority. The main RPG. |
| **Versus** | 2–4 | Later. Everyone shoots the same scene against a clock, and a judge scores the results. |
| **Burst** | 1–4 | WarioWare/Mario Party-style photo microgames. **Prototype this first**, because it's the cheapest way to test whether the core shot loop is fun. |

**Co-op idea:** shared shoots with roles. One player is the photographer, and the others handle lighting, set design, or modeling.

## Core gameplay loop

### 1. Shot loop (10–30 s)

**Spot → Prep → Frame → Shoot → Reveal**

- **Spot:** subjects have visible "moments" (a dog mid-zoom, a skater about to land, light hitting a building).
- **Prep:** set exposure for the environment *before* the action starts. Manual players are rewarded for anticipating.
- **Frame:** the scene keeps changing while you line up the shot.
- **Shoot:** the click needs weight and tactile sound.
- **Reveal:** an instant, readable score breakdown plus one coaching line. This is how players learn photography without a tutorial.

### 2. Shoot loop (5–15 min)

**Brief → Gather → Shoot → Cull → Edit → Deliver**

- **Brief:** an NPC gig, a calendar event, or a self-directed outing. The brief defines what success means.
- **Gather:** travel, set up, find subjects. This is the step that differs most between styles.
- **Shoot:** limited shots (film roll, memory card) prevent spam-clicking.
- **Cull:** pick your best few. This is where taste develops. Clients may value different things than the raw score does.
- **Edit:** light edits only (crop, exposure, a few filters).
- **Deliver:** see the NPC's reaction and get paid.

Photos can be shot independently or for a gig. Every photo can go into your portfolio or social feed, but **only paid jobs are scored for rewards**.

- Independent photos: cull and edit once at the end of the day.
- Gigs: cull and edit at the end of each gig.

Photoshoots have a minimum score to earn rewards. Exceeding it, or scoring perfectly, increases the payout.

### 3. Meta loop (days–weeks)

**Earn → Invest → Unlock → Story**

- Earn money plus reputation for each style.
- Invest in gear, studio decoration, and cosmetics.
- Unlock new briefs, locations, and calendar events.
- NPC arcs advance at style milestones, and the world visibly changes.

**Day structure:** a day/night cycle with a limited number of outings creates Stardew-style choices (chase golden hour, or go to the market event?).

**Replay hooks:** a photo collection (Pokédex-style), personal bests, and Burst high scores.

### Gear doesn't equal skill

Better gear is **not** a score multiplier. Gear unlocks **briefs**. A client who wants a creamy blurred-background portrait needs a fast prime, and a bird shoot needs reach. Skill sets your score. Gear sets which jobs you can take. Style levels can increase the payout multiplier.

Open question: image quality and pixel count as a 0.2×–1.0× multiplier (tiers 1–5)?

## The camera

### Assist tiers

| Tier | What the player controls | Reward |
|---|---|---|
| **Auto** | Point and shoot, with a few clicks at most. | Base |
| **Assisted** | Aperture priority or shutter priority. | Higher |
| **Manual** | Full exposure triangle (ISO, aperture, shutter) and manual focus. | Highest |

### Controls (draft)

- **Controller:** shoulder buttons pick the setting, the D-pad (or sticks) changes the value, A shoots, and triggers handle autofocus and manual focus.
  - Open question: the original idea was "left stick moves the value up, right stick moves it down."
- **Mouse:** wheel for manual focus, right click to autofocus, left click to shoot.
- **In-game tip:** set your settings before the action begins based on the environment, then make small adjustments as the light, shade, and movement change.

### Views

- Shooting is first person and can be done anywhere.
- Exploring uses a third-person camera with full 360° control.

### Film photography

- Film is sold at the camera shop. Price depends on ISO and grain: 100, 200, 400, 800, 1600, 3200, in color and black and white.
- 36 shots per roll. During a shoot, time passes based on the shots you have.
- Film must be developed before it can be edited. The **darkroom minigame** is physics-based (Cooking Mama-style), with time, heat, and agitation.
- Later, after the camera shop clerks' story, a film machine is revived. You can drop off film and get it back after some time passes.
- Cheaper to get into than digital, pays more per photo, and limits how many images you get.

### Digital photography

- Brief review after each shot, with the option to delete.
- Card size limits the shots per outing (values to be tuned):

| Card | Photos |
|---|---|
| 512 MB (starter) | 25 |
| 2 GB | 100 |
| 4 GB | 200 |
| 16 GB | 800 |
| 32 GB | 1600 |
| 64 GB | 3200 |

### Kit and inventory

Set up your bag before a shoot: film rolls, lenses, tripod, filters (UV, VND, black mist, star, prism?), batteries, cleaning tools, and lighting or flash. Upgrading the camera bag lets you carry more.

### Lenses

Start with a kit lens or two (18–55, 55–250) and a nifty-fifty 50 mm. The full range unlocks in the shop as you invest more. Different lenses suit different styles, which gently pushes players to try them. An NPC could customize lenses (and maybe 3D-print parts).

**Primes:** 50 mm (f/1.2, 1.4, 1.8, 2, 2.8) · 35 mm (f/1.2–2.8) · 85 mm (f/1.2–2.8) · 28 mm (f/2.8, 3.5) · 24 mm · 20 mm · 16 mm · 10 mm · 8 mm fisheye · 100 mm f/2.8 macro · 90 mm f/2.8 macro (worse focusing distance) · 300 mm f/2.8 (big money)

**Zooms:** 28–70 f/2.8 · 24–70 f/2.8 · 7–14 f/2.8–3.5 · 14–24 f/2.8 · 18–28 f/3.5–5.6 · 100–500 f/4.5–7.1 · 180–600 f/5.6–6.3 · 55–200 · 18–400

## Photography styles

Each style plays differently, and some overlap. Paid shoots earn more, and pay varies by style.

| Style | Gameplay | Examples |
|---|---|---|
| **Portrait** | Slower and staged: build the set, pose the subject, light it. On a timer and paid by the hour. | Headshots, full-body posing |
| **Street** | Explore the city, which advances the social side of the game and unlocks things through exploration. | Architecture, people, festivals |
| **Nature** | Explore set biomes. Time of day and season change both the landscape and the animals. | Landscapes, wildlife |
| **Sport** | Quick-time events built around moments in different sports. | Running, tennis, skateboarding |
| **Commercial / Product** | Stage the product and lighting, like designing a room in Animal Crossing. | Restaurants, stores |

**Events:** big calendar events, one or more per style, that offer large environments and more money.

- Portrait: fashion week, a gala, school picture day
- Street: festivals, a car show
- Nature: animal migrations, the zoo
- Sport: a track meet, an "olympics", championships
- Commercial: the farmers market, store promotions

**Subjects react:** NPCs and animals have states (shy, curious, showing off) that respond to the player: waiting, treats, noises, golden hour. A "pose" button and absurd props add to the silliness.

**After a shoot:** pick, lightly edit, then upload to **Camboree**, the in-game photo app (think early Instagram or VSCO), or print.

**Gigs:** characters post requests, either for a portrait shoot or for a photo that meets certain criteria.

## Locations: Ayesso City

- **The Studio:** the main hub, with an apartment upstairs. Fully decoratable.
- The city can be explored on foot. A bike, skateboard, or rollerskates can be bought at the sporting goods shop. Rails, ledges, and stairs everywhere for skating.
- Quick travel in the city is by **van**, which also reaches the outer areas.
- Interiors need **high ceilings** so the camera can move freely.
- Accessibility idea: a city without stairs-only routes, so wheelchair players can reach everything.

| Location | Notes |
|---|---|
| **Camera Shop** | Cameras, lenses, flash and lighting, camera bags, tripods, cleaning tools, batteries, filters, film. |
| **Barber Shop / Salon** | Change your hair, gossip, meet people. Run by twins who butt heads. The shop's look is split right down the middle. |
| **Art Gallery** | Opens later. Citizens and the player submit work. Higher-scoring photos are more likely to sell. Patrons pause at your work, and talking with them can lead to a sale. |
| **Gym / Park** | Portraits, wildlife, street, and sport. The gym building has workout equipment and a spa. The park has tennis, basketball, soccer/baseball fields, and a skatepark. |
| **Sporting goods store** | Bike, skateboard, rollerskates. |
| **Restaurants** | Pizza shop, Big City Bagels, BBQ/southern food, a fancy restaurant, *I'm Wokkin' Here* (a big-city Asian spot). Some start as **food trucks**. Supporting them with product photography helps them get a physical location, which means more business for both of you. |
| **Clothing stores** | Hats, tops and bottoms, shoes and socks, jewelry. |
| **Pet shelter** | A stray-cat collectathon with mini puzzles to bring cats to the (very nice, no-kill) shelter, where citizens adopt them. |
| Grocery store, school, hospital | |
| **Detectives** | Maybe a detective team keeps the peace instead of police. |
| **Forest** | Maybe magical: learn spells such as time manipulation, a day/night switch, or underwater breathing, each with a cooldown of a few days. |
| **Trails** | Views of the city and nature from afar, and walking access to farther locations. |
| Lake / river / waterfall | |

**Van-only destinations:** beach, mountains, a small town or village.

## Characters

- Many characters. **Each one needs a purpose**, so the world feels cohesive and not like only about 8 people matter.
- Some characters have longer, more important stories.
- Parts of a character unlock as you progress through the photography styles.
- As the story progresses, NPCs visibly change how they live: taking photos themselves, modeling, eating out, enjoying nature, exercising, walking around town, and being more social and respectful.

### Grandmother

The player character's grandmother. A world-famous photographer who owns the studio. She covers all the costs, and you run the studio and pursue photography. She has mastered every type of photography, traveled the world, and has many connections. She used to be super serious but has gotten chill and wacky in her golden years. She gives you your first two cameras (film and digital), teaches you the basics, and gives more in-depth tutorials over time.

### Rival photographer (the player names them)

A rich, entitled, snobby photographer and influencer who only uses whatever expensive gear is popular. They came to town to take over the studio because they think notoriety matters most, and they stay out of spite after you get it. Their arc: their worldview breaks and gets rebuilt. They become more open-minded and peaceful, and they end up finding joy in the act of photography instead of the status and fame.

### Bob & Viv (camera store clerks)

A kind older couple who are against phone photography (and maybe AI art) and want traditional photography to come back. Bob is a pacifist who was a war photographer in his youth, documenting the war for history's sake (roughly the Vietnam era). Over their arc they become more accepting of modern technology while more people take up traditional photography, which balances the story.

### George & Georgia (barber shop / salon)

Twins: Georgia is the cosmetologist and George is the barber. They inherited the shop from their parents, who retired on a forever-cruise around the world. Both trained and studied to be exceptional. One wants to style celebrities, and the other wants regulars and a community space.

- **George:** sharp, precise, stubborn, bald.
- **Georgia:** free-spirited and bubbly. She's the older twin, by 22 minutes.

### The Fisherman

An old fisherman who was friends with Grandmother back in the day. He stopped shooting to work and support his elderly family, and then got stuck. There's no beef between them, but it's awkward. He's chill but closed off, very old-school, very old, and kind of depressed. He lives on a small boat called **The Shrimp Bait** and looks like a mix of a homeless pirate and an old-school lighthouse keeper.

### Art Gallery Curator & Intern

Not written yet.

## Player character

- Cute and simplified, with proportions like older Harvest Moon games or Ness in SSB64.
- Everything is customizable, with full RGB:
  - **Head:** eyes, hair, mouth, nose, facial hair, lashes, eyebrows, lips. Many options, plus unlockables. Rated **ES for Everyone Slay**.
  - **Skin details:** freckles, moles, scars, vitiligo.
  - **Representation:** amputee options, wheelchairs.
  - **Clothing:** hats, face accessories, tops, bottoms, socks, shoes, backpack. It has to be drippy, with genuinely cool options.

## Art direction

- Low-poly, N64/GameCube era, on the cuter side.
- Cel-shaded outlines can be toggled on or off.
- Possible tools: Blender, Maya, picoCAD 2.

## Music & audio

- Different songs for different locations, using the same "sound font" so it all feels unified.
- Camera actions (changing settings, loading film, firing the shutter) need weight. They should sound tactile and satisfying.
- Characters speak in gibberish sounds.

## Scope: vertical slice

The full design is a multi-year game. The first playable slice is:

1. **Burst mode prototype:** the camera plus scoring v0 in microgames. ← *we are here: a sandbox round (4★ within 5 shots) with a polaroid, star chimes, and pillar bars*
   - Next: **briefs** that change what a good shot means each round ("blurry background", "freeze the runner", "subject on the left third"). This turns one sandbox into a game.
2. One hub block of Ayesso City, Grandmother, and the full loop (settings → shoot → score → sell).
3. One style, probably Street or Nature.
4. The film darkroom minigame as the "wow" feature.

**Deferred:** full cosmetics, the gallery, the spell forest, and Versus mode.

## Open questions

- Is the shot loop mostly **reactive** (catch moments, Snap-style) or mostly **planned** (stage scenes, Animal Crossing-style)? Pick one default, and make the other a variation for specific styles.
- How should the Assisted tier split: aperture priority and shutter priority, or a single "program" tier?
- The controller layout for changing values.
- Image quality / pixel-count multiplier.
- Is the city free of stairs-only routes? (accessibility)
- Is the forest magic in or out?
- The gallery curator and intern.
