# hyperframes-genie

Cursor plans the film with the model on your subscription. BAML turns that plan into a HyperFrames project. No API key.

The plan is a `FilmPlan` (`baml_src/film.baml`): scenes, copy, colors, and timing. Words on screen only, three or four scenes, each 3 to 5 seconds, total under 15 seconds. Pass that plan's file. An empty run does not write a video.

## Run

Install the BAML CLI once (`curl -fsSL https://pkg.boundaryml.com/install.sh | sh -s`), then:

```bash
export PATH="$HOME/.baml/bin:$PATH"

baml test
baml run main -- --plan_file videos/hello-world/plan.json
```

Each video is one folder and one `plan.json`. The preview cut is silent: a still avatar and no voice. After a Studio review, that same file gains a HeyGen `voice_id` and the avatar stays a still. After a second Studio review, it gains the HeyGen `avatar_id` and keeps that reviewed voice.

```text
videos/
  <slug>/
    plan.json                 # story, silent until voice_id and avatar_id are set
    reviews.json              # Studio reviews, not committed
    index.html
    compositions/
    renders/
      preview-cut.mp4
```

`baml run main` writes the folder named by the plan's slug. Hello World is `videos/hello-world`. `--plan` accepts the same JSON inline. `--out` is the video folder. `--check true` runs `npm run check` after writing.

```bash
baml run main -- --plan_file videos/hello-world/plan.json --check true
```

Render the preview cut first. That uses HyperFrames quality `draft`, writes `renders/preview-cut.mp4`, and opens Studio at `http://127.0.0.1:<port>/#project/<slug>`. Nothing in this sequence calls HeyGen. An extra composition take still goes through `render_take`.

```bash
baml run render_cut -- --dir videos/hello-world --cut preview
baml run approve -- --dir videos/hello-world --stage preview
baml run swap_voice -- --dir videos/hello-world --voice_id <heygen-voice>
baml run open_studio -- --dir videos/hello-world --cut voice
baml run approve -- --dir videos/hello-world --stage voice
baml run add_lipsync -- --dir videos/hello-world --avatar_id <avatar>

cd videos/hello-world
npm run dev
npm run check
```

Agent skills for this repo live in `.agents/skills`: `baml-core` plus the HyperFrames pack.
