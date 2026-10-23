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

Each video is one folder. The plan and the composition sit at its root, and every render is a separate file under `renders/`:

```text
videos/
  <slug>/
    plan.json
    index.html
    compositions/
    renders/
      draft.mp4
      looks.mp4
      delivery.mp4
```

`baml run main` writes `videos/hyperframes-genie`. To render a plan from Cursor, pass the JSON. `--plan` accepts the same JSON inline. `--out` is the video folder. `--check true` runs `npm run check` after writing.

```bash
baml run main -- --plan_file videos/ceramic-studio/plan.json --check true
```

Render a named take so a second render does not replace the first. Preview from the video directory:

```bash
baml run render_take -- --dir videos/hyperframes-genie --quality draft --take draft
baml run render_take -- --dir videos/hyperframes-genie --quality delivery --take delivery

cd videos/hyperframes-genie
npm run dev
npm run check
```

Agent skills for this repo live in `.agents/skills`: `baml-core` plus the HyperFrames pack.
