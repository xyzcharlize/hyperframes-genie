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

Each video is one folder. One story becomes two video plans. The preview plan is a still avatar and a local TTS voice. The production plan is a HeyGen lip-sync of the same words. Its `voice_id` is the speaking voice, often not the avatar's default, and the cut stays blocked until a person approves the preview.

```text
videos/
  <slug>/
    plan.json                 # shared story
    preview-plan.json         # still avatar, local TTS
    production-plan.json      # HeyGen lip-sync
    approval.json             # written by approve, not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4
```

`baml run main` writes `videos/hyperframes-genie`. To render a plan from Cursor, pass the JSON. `--plan` accepts the same JSON inline. `--out` is the video folder. `--check true` runs `npm run check` after writing.

```bash
baml run main -- --plan_file videos/ceramic-studio/plan.json --check true
```

Render the preview cut, then Studio opens for fine adjustments. That render uses HyperFrames quality `draft`, writes `renders/preview-cut.mp4`, and returns the Studio URL `http://127.0.0.1:<port>/#project/<slug>`. It does not call HeyGen. `render_cut --cut production` refuses until `approval.json` approves the same script, and even then it does not start the paid lip-sync. Once `production-cut.mp4` exists, open Studio on that cut too. An extra composition take still goes through `render_take`.

```bash
baml run render_cut -- --dir videos/hyperframes-genie --cut preview
baml run open_studio -- --dir videos/hyperframes-genie --cut preview
baml run open_studio -- --dir videos/hyperframes-genie --cut production
baml run approve -- --dir videos/hyperframes-genie --note "ship the lip-sync"
baml run reject -- --dir videos/hyperframes-genie --note "hold"

cd videos/hyperframes-genie
npm run dev
npm run check
```

Agent skills for this repo live in `.agents/skills`: `baml-core` plus the HyperFrames pack.
