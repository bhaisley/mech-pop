# Dependency and asset inventory — 0.2.0 preview

The runtime contains project-specific game code/art/audio plus the Godot engine and licensed fonts. Development applications and model weights are not bundled. This inventory records provenance; it does not assign an open-source license to the original game.

| Item | Exact source / version | Use and terms |
| --- | --- | --- |
| Three.js | r160, bundled in `game/vendor/three.min.js` | Browser renderer, MIT. [Included notice](game/vendor/THREE-LICENSE.txt) |
| Godot Web single-threaded release template | 4.7.2.stable.official.ed1daf0bf | Browser simulation runtime. [Included engine and dependency notices](game/runtime/GODOT_NOTICES.txt) |
| Godot Standard and macOS templates | 4.7.2.stable.official.ed1daf0bf | Bundled runtime. MIT plus bundled dependency notices, extracted from the pinned binary into `third_party/GODOT_NOTICES.txt`. [Official license](https://godotengine.org/license/) |
| Engine libraries, including SDL input support | The inventory returned by this exact Godot runtime | Bundled as part of Godot, with their individual licenses in the same notices file. No separate unversioned SDL package was added. |
| Barlow SemiBold; Barlow Condensed Bold and Black Italic | Google Fonts `ofl/barlow` and `ofl/barlowcondensed`; Jeremy Tribby | Bundled original TTF files, unchanged, SIL Open Font License 1.1. Notices in `ui/fonts/OFL.txt` and `third_party/Barlow-OFL.txt`. [Barlow](https://github.com/google/fonts/tree/main/ofl/barlow), [Barlow Condensed](https://github.com/google/fonts/tree/main/ofl/barlowcondensed) |
| Blender | 4.5.11 LTS, existing local installation | Development tool only. Original game geometry and rigging authored with `tools/build_mechs.py`; no external meshes or add-ons adopted. [Blender license](https://www.blender.org/about/license/) |
| SuperCollider | 3.14.1, official universal macOS application | GPL-3.0 development tool only. Original SynthDefs and NRT scores render 27 shared cues and six additional sounds for each of the eight chassis. No third-party samples or recordings. [Project](https://github.com/supercollider/supercollider) |
| Audacity | 3.7.9, installed | Available development editor/audition tool; no runtime component or third-party effect plugin. |
| FFmpeg | 8.1.1, local GPL-enabled build | Development processing/analysis only. Binary is not bundled. SkyPort/hangar use PCM WAV; expansion themes use Vorbis from retained lossless masters. |
| Python / NumPy | Python 3.9.6 for standard scripts; Python 3.12 / NumPy 2.3.5 for audio finishing | Development automation only; no environment/packages bundled with the app. NumPy is BSD-licensed. |
| ComfyUI | Main 0.22.0; dedicated music lane 0.33.0 | Existing remote development service. Generation prompts and workflows retained under `audio/source/music/`; not required at runtime. |
| YuE2-3B | M-A-P, YuE2 | Rendered the instrumental performances for Tideglass Station, Cinder Foundry and Aurora Relay. The source recordings, ABC scores, prompts and loop edits are in `audio/source/music/yue2/`. [Model card](https://huggingface.co/m-a-p/YuE2-3B) · [Weight license and creator terms](https://github.com/multimodal-art-projection/YuE/blob/main/MODEL_LICENSE) |
| MiniMax-Music3 | Upstream MiniMax-Music3; existing fp16 DiT, bf16 encoder and DAV VAE in music lane | Generated five accepted original recordings: the initial source yielded SkyPort/hangar cues, and four new sources provide distinct expansion themes. Community license retained in `third_party/MiniMax-Music3-LICENSE.txt`; UI credits identify MiniMax-Music3. The license requires separate prior authorization above its stated $20M annual product/service revenue threshold. [Upstream license](https://huggingface.co/MiniMaxAI/MiniMax-Music3/blob/main/LICENSE) |
| Built-in ImageGen | Tool did not expose an underlying model identifier | Nova construction reference and eight stage mattes created specifically for this game. Exact prompts/provenance retained in `art_source/characters/nova/` and `art_source/environments/`. The mattes ship; the construction sheet is source/reference only. The arena provenance file identifies the prompt for each expansion painting. |
| Original code, models, UI and SFX | This repository | Created for MECH★POP. Source geometry, data, shaders, synthesis graphs and scripts retained. No license is assigned to original content without the user's direction. |
| User-supplied concept poster and brief | Concept poster in `docs/media/original-concept.png` | Original product/art direction reference, published at the creator’s request. It is concept art, not a screenshot or a statement of current platform availability. Platform/studio marks in the concept are not reproduced in the runtime. |

No Stable Audio model, external Foley library, marketplace asset pack, copied commercial-game character, borrowed song, proprietary engine or network service is required by the delivered app. Stable Audio 3 Small-SFX was researched but not installed or adopted.

## Generated music provenance

The dedicated ComfyUI job used seed 27491, matching 108-second text-encoder and latent controls, and an original instrumental prompt with no named artist/song. The source duration was 107.996 seconds. The final battle loop is approximately 95.252 seconds and the hangar loop 30 seconds, with circular crossfades. `loop-edit.json` records the numerical edit, estimated pulse and seam measurement. These are generated/edited assets, not human-composed performances or a claim of guaranteed musical originality.

Upstream MiniMax terms are retained despite differing repackaged checkpoint metadata. The game does not expose a music-generation service or ship weights. Recheck applicable terms before a wider commercial release. All licensing discussion should be read against the actual included license texts.

Four expansion sources each retain their own workflow, prompt, seed and source FLAC under audio/source/music/. Their edited 48 kHz/24-bit WAV masters and quality-7 Vorbis files retain exact hashes and edit decisions. Vorbis tools 1.4.3/libVorbis 1.3.7 were used only during development. The optional room gateway uses Python 3.11+ and the versions pinned in server/requirements.txt; those packages are installed separately, not embedded into the Mac app.

## Inventory files

`docs/ASSET_MANIFEST.json` records SHA-256 hashes and provenance categories for shipped original assets, models, fonts and notices. The release download includes its executable/PCK hashes; MEDIA_PROVENANCE.json identifies the public presentation assets. Required notices are both in the project and included in the game resources; a readable copy accompanies the release package.
