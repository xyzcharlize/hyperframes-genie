// LLM function only. Normalization and HTML live outside this file.

function PlanFilm(brief: string) -> FilmPlan {
    client: "openai/gpt-4o-mini"
    prompt: `
        You plan a short HyperFrames title film: words on screen, no voiceover, no captions, no music.
        Use three or four scenes. Each scene lasts 3 to 5 seconds. The total stays under 15 seconds.
        A headline is at most eight words. A body line is one sentence under eighteen words.
        Colors are six-digit hex, and the ink must stay readable on the ground.
        The slug and every scene id are kebab-case. Use Landscape unless the brief asks for vertical or square.
        ${ctx.output_format()}

        Brief:
        ${brief}
    `
}

// Pass a client from tests or a host. Null keeps the function's own client.
function plan_film(brief: string, client: ai.Client? = null) -> FilmPlan {
    //# Ask for a typed film plan
    if (client == null) {
        PlanFilm(brief)
    } else {
        PlanFilm@spec(brief).call(client = client)
    }
}
