# Koreans v1 - honest audit (2026-10-08)

Version 1 is a Japanese clone with a Korean identity layer. This lists what is done, what is verified where, and
everything still missing for a fully playable, fully Korean civilization, most important first.

## Done

| Part | State | Verified |
|---|---|---|
| Civ `zpKoreans` (lobby + editor, hotkey K) | vanilla Japanese entry field for field, own name/rollover | owner's match 2026-10-08: civ picked, match started |
| Age0 tech `zpAge0Korean` | activates `YPAge0Japanese` + marker `zpKoreanVisuals` | same match (Japanese start, Korean TC appeared) |
| Flags (object flag, lobby/HC/legacy buttons, icon, techtree, both postgame flags) | Korean Empire flag through the owner's Flag Maker templates | in-game flag on the TC panel and player list seen; postgame/HC not yet seen |
| Korean Town Center, Barracks, Stable | from the first upgrade (Colonial) on; Discovery Age keeps the vanilla Asian look | TC seen in game (before the age fix); Barracks, Stable and the age switch not yet seen |
| Home city | Japanese scene and cards, named Hanseong, hero Samyeong Daesa | static only |
| AI personality | Empress Myeongseong (name, tooltip) | static only |
| Korean villager voices | 34 lines, 22 soundsets defined, **not used by any unit** (owner) | files and definitions checked |
| Separate add-on | `koreans/` in AoP -> export -> public repo | export checked offline; AoP + add-on together not yet run in game |

## A. Blocking for real play

1. **The AI cannot play Koreans properly.** The AoP AI core decides by civ id: 67 `cCivJapanese` checks and
   `civIsAsian()` (46 uses) do not know `zpKoreans`, so an AI Korean is treated as a European civ: no wonder
   age-ups (it will likely stay in the Discovery Age), no shrine, Dojo or Daimyo logic, generic cards. A random-civ
   AI can roll Koreans. Fixing it touches the adopted core files (rule 7: core stays byte for byte, mod AI only in
   `aipiraterules.xs`) - needs the owner's decision on how.
2. **AoP maps branch on the civ name "Japanese"**: 19 scripts in `randmaps/` (+34 in `game/randmaps/`), 67 checks
   (Asian politician/consulate switchers, map setup). Koreans fall through to the generic branch on those maps.
3. **Tech Tree screen**: vanilla has per-civ `Data/uitechtree/techtreedata_<civ>.xml` (additive per the official
   table) and a class-bound WPF page `Data/wpfg/pages/uitechtree/techtree_<civ>.xaml`. Koreans have neither; the
   in-game Tech Tree for Koreans is probably empty. Research: can a mod add a page for a new civ at all?
4. **Two mods together are untested in game.** The official docs say additive files (`civmods`, `techtreemods`,
   `stringmods`, `homecity`...) merge; one match with AoP + the add-on must confirm it, plus the add-on's priority
   above AoP for the shared animfiles and soundset file.
5. **Korean Town Center model** still fails `gr2_lint` (6 checks: texture budget, texel density, UV lineage);
   shipped on the owner's go. Barracks and Stable pass (23/0 and 25/0) but live under the bench path
   `art/zbench_korean_military/` and carry material-binding warnings in `xmlcheck`.

## B. It still looks and sounds Japanese

6. **Units**: the whole roster is Japanese (Ashigaru, Samurai, Yumi, Naginata Rider, Yabusame, Shinobi, Morutaru,
   Flaming Arrow, Atakebune, Tekkousen, Fune, Daimyo, Dojo armies). No Korean unit (the WoL study suggests Hwacha,
   turtle ship, long-range archers, Panokseon).
7. **Wonders** are the five Japanese ones (Golden Pavilion, Great Buddha, Shogunate, Torii Gates, Toshogu Shrine)
   with Japanese art, names and age-up bonuses.
8. **Every other building** is Japanese by culture: Shrine (house), Dojo, Castle, Consulate, Rice Paddy, Dock,
   Market, walls, Trading Post.
9. **Villagers and explorers**: the Japanese villager model and rules (villagers cannot hunt); explorers are the
   Japanese monks (the home city hero name is only a rename). A switch to the Chinese villager was judged too
   invasive (3 Japanese settler cards and Zen Diet target `ypSettlerJapanese`).
10. **Voices**: villager soundsets defined but not wired (`civlogic` in `ypsettlerjapanese_snds` /
    `ypfishingboatasian_snds` would do it - see the `aoe3de-soundsets` skill); soldiers, monks, ships and the
    home city speak Japanese. AoE2 also has Korean soldier, monk and king lines (soldier lines are already in AoP).
11. **Home city**: Japanese 3D scene (Edo), Japanese card set and default deck, Japanese card art.
12. **Lobby and menu art** still Japanese: history preview `h_pc_japanese`, independence icon, AI avatar
    (Tokugawa's face for the Empress), matchmaking textures, legacy flag button sets, legacy postgame texture. The
    Consulate & Age Up flag was not made (that template needs the Photoshop 2020 warp).
13. **Personality**: Tokugawa's chatset (a male voice, Japanese-themed lines) and avatar; no Korean chat lines, no
    portrait, no home-city chat set.
14. **Text**: the 14 non-English languages show the English strings; the civ rollover lists the Japanese units; no
    civ history / encyclopedia entry; no leader quotes or loading tips.
15. **Editor names** still read "Barracks Japanese" / "Stable Japanese" (plan P3: rewrite to "Asian Barracks" /
    "Asian Stable" in 15 languages).
16. **Random names**: no Korean explorer, ship or unit name lists.
17. **Balance**: identical to Japan; nothing in the gameplay is Korean yet.

## C. Housekeeping

18. `statsid KR` and `gameid ypack` are copied conventions, untested online; multiplayer needs both mods on every
    machine.
19. The `korean-civ` branch (full AoP fork prototype) is superseded by the add-on and kept as history.
