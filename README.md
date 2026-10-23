# hyperframes-genie

Cursor plans the film with the model on your subscription. BAML turns that plan into a HyperFrames project. No API key.

The plan is a `FilmPlan` (`baml_src/film.baml`): scenes, copy, colors, and timing. Words on screen only, three or four scenes, each 3 to 5 seconds, total under 15 seconds. An empty run writes the built-in demo and does not ask a model for anything.

## Run

Install the BAML CLI once (`curl -fsSL https://pkg.boundaryml.com/install.sh | sh -s`), then:

```bash
export PATH="$HOME/.baml/bin:$PATH"

baml test
baml run main
```

Each video is one folder. One story moves through three stages. The preview cut is silent: a still avatar and no voice. After a Studio review, a HeyGen voice is added and the avatar stays a still. After a second Studio review, the HeyGen lip-sync avatar is added, using that reviewed voice.

```text
videos/
  <slug>/
    plan.json                 # shared story
    preview-plan.json         # still avatar, silent
    voice-plan.json           # still avatar, HeyGen voice
    lipsync-plan.json         # HeyGen lip-sync, reviewed voice
    reviews.json              # Studio reviews, not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4
```

`baml run main` writes `videos/hyperframes-genie`. To render a plan from Cursor, pass the JSON. `--plan` accepts the same JSON inline. `--out` is the video folder. `--check true` runs `npm run check` after writing.

```bash
baml run main -- --plan_file videos/ceramic-studio/plan.json --check true
```

Render the preview cut first. That uses HyperFrames quality `draft`, writes `renders/preview-cut.mp4`, and opens Studio at `http://127.0.0.1:<port>/#project/<slug>`. Nothing in this sequence calls HeyGen. An extra composition take still goes through `render_take`.

```bash
baml run render_cut -- --dir videos/hyperframes-genie --cut preview
baml run approve -- --dir videos/hyperframes-genie --stage preview
baml run swap_voice -- --dir videos/hyperframes-genie --voice_id <heygen-voice>
baml run open_studio -- --dir videos/hyperframes-genie --cut voice
baml run approve -- --dir videos/hyperframes-genie --stage voice
baml run add_lipsync -- --dir videos/hyperframes-genie --avatar_id <avatar>

cd videos/hyperframes-genie
npm run dev
npm run check
```

Agent skills for this repo live in `.agents/skills`: `baml-core` plus the HyperFrames pack.
