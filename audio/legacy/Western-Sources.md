# Western 2D sound sources

Downloaded and prepared on 2026-10-13. All three source pages offer CC0 1.0.
License: https://creativecommons.org/publicdomain/zero/1.0/

| Source | Author | Project clips | Original download |
|---|---|---|---|
| [Battle Sound Effects](https://opengameart.org/content/battle-sound-effects) | artisticdude; uploaded by Ogrebane | sword_0/1/2, bow | https://opengameart.org/sites/default/files/battle_sound_effects_0.zip |
| [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) | artisticdude | magic_charge, magic_release, metal_hit, body_hit, reload_0/1, coin, dash, monster_organic/heavy/insect, bubble, splash, ui_click | https://opengameart.org/sites/default/files/rpg_sound_pack.zip |
| [Gunshots](https://opengameart.org/content/gunshots) | kurt | gun_0/1/2, gun_heavy | https://opengameart.org/sites/default/files/Black%20Powder.wav |

Edits: selected short transients, mono conversion, DC removal, filtered resampling to 44.1 kHz, 2 ms attack and 30 ms tail fade, PCM16, peak normalized to -9.12 dBFS. Gun clips use isolated shots from the Black Powder recording; no repeated multi-shot recording is played for one attack. The bow uses Bow.wav, not a wood-creaking sample. Full per-clip hashes and crop positions are in manifest.json. Reproduce using tools/prepare_western_audio.py and the extracted source packages. Source recordings are not claimed as original work by this project.

Existing synthesized win/loss and achievement stingers, as well as previous audio resources, remain available. Sound selection is separated from gameplay randomness. The game mixer limits repeated hit/creature events and reserves channels for UI and important attacks.
