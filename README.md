# hyperframes-genie

BAML plans a short film. HyperFrames renders that plan to video.

The model returns a typed plan (scenes, copy, colors, timing). Ordinary BAML turns the plan into a HyperFrames project: `index.html` plus one composition per scene. An empty brief writes the built-in demo and does not call a model.

## Run

Install the BAML CLI once (`curl -fsSL https://pkg.boundaryml.com/install.sh | sh -s`), then:

```bash
export PATH="$HOME/.baml/bin:$PATH"

baml test
baml run main
```

`baml run main` writes `videos/hyperframes-genie`. Pass a brief to plan with `gpt-4o-mini` (`OPENAI_API_KEY` must be set):

```bash
baml run main -- --brief "A 12 second intro for a ceramic studio" --check true
```

`--out` is a relative project path. `--check true` runs `npm run check` after writing.

Preview and render from the video directory:

```bash
cd videos/hyperframes-genie
npm run dev
npm run check
npm run render
```

Agent skills for this repo live in `.agents/skills` (Cursor) and `.claude/skills` (Claude Code): `baml-core` plus the HyperFrames pack.
