// Film plan: the Cursor agent fills this. Rendering does not call a model API.

enum Aspect {
    Landscape,
    Portrait,
    Square,
}

class Palette {
    ground: string,
    ink: string,
    accent: string,
}

class Beat {
    id: string @description("unique kebab-case id"),
    eyebrow: string @description("at most 4 words"),
    headline: string @description("at most 8 words"),
    body: string @description("one sentence, at most 18 words"),
    seconds: float @description("scene length from 3 to 5"),
}

class FilmPlan {
    title: string,
    slug: string @description("kebab-case folder name"),
    aspect: Aspect @description("Landscape unless the brief asks for vertical or square"),
    palette: Palette @description("six-digit hex colors; ink must stay readable on ground"),
    beats: Beat[] @description("3 or 4 scenes, total under 15 seconds"),
}

class Film {
    title: string,
    slug: string,
    width: int,
    height: int,
    palette: Palette,
    beats: Beat[],
}

function frame_for(aspect: Aspect) -> FrameSize {
    match (aspect) {
        Aspect.Landscape => FrameSize { width: 1920, height: 1080 },
        Aspect.Portrait => FrameSize { width: 1080, height: 1920 },
        Aspect.Square => FrameSize { width: 1080, height: 1080 },
    }
}

class FrameSize {
    width: int,
    height: int,
}

function is_hex(color: string) -> bool {
    baml.regex.new("^#[0-9a-fA-F]{6}$").match_full(color) != null
}

function safe_id(raw: string) -> string {
    let dashed = raw.to_lower_case()
        .replace_all(baml.regex.new("[^a-z0-9]+"), "-")
        .replace_all(baml.regex.new("^-+"), "")
        .replace_all(baml.regex.new("-+$"), "");
    let body = if (dashed == "") {
        "beat"
    } else {
        dashed
    };
    if (baml.regex.new("^[0-9]").has_match(body)) {
        `b-${body}`
    } else {
        body
    }
}

function clamp_seconds(n: float) -> float {
    if (!n.is_finite() || n < 3.0) {
        3.0
    } else if (n > 5.0) {
        5.0
    } else {
        n
    }
}

function sum_seconds(beats: Beat[]) -> float {
    beats.reduce(
        (total, beat) -> {
            total + beat.seconds
        },
        0.0,
    )
}

function unique_ids(beats: Beat[]) -> Beat[] {
    let seen: map<string, int> = {};
    let out: Beat[] = [];
    for (let beat in beats) {
        let base = safe_id(beat.id);
        let id = base;
        let n = 2;
        while (seen.get(id) != null) {
            id = `${base}-${n}`;
            n = n + 1;
        }
        let _ = seen.set(id, 1);
        out.push(Beat { ...beat, id: id });
    }
    out
}

// Drop trailing scenes until the film fits the no-music budget.
function cap_total(beats: Beat[]) -> Beat[] {
    let out = beats.map((beat) -> {
        Beat { ...beat, seconds: clamp_seconds(beat.seconds) }
    });
    while (sum_seconds(out) > 15.0 && out.length() > 1) {
        out.pop();
    }
    out
}

function color_or(value: string, fallback: string) -> string {
    if (is_hex(value)) {
        value
    } else {
        fallback
    }
}

function normalize(plan: FilmPlan) -> Film {
    //# Repair ids, colors, and timing before any HTML is written
    let title = if (plan.title == "") {
        "Untitled"
    } else {
        plan.title
    };
    let slug = safe_id(
        if (plan.slug == "") {
            title
        } else {
            plan.slug
        },
    );
    let frame = frame_for(plan.aspect);
    let palette = Palette {
        ground: color_or(plan.palette.ground, "#12141a"),
        ink: color_or(plan.palette.ink, "#f4f1ea"),
        accent: color_or(plan.palette.accent, "#d6ff4a"),
    };
    let beats = cap_total(unique_ids(plan.beats));
    let ready = if (beats.length() == 0) {
        [
            Beat {
                id: "open",
                eyebrow: "Hyperframes",
                headline: title,
                body: "A short film.",
                seconds: 4.0,
            },
        ]
    } else {
        beats
    };
    Film {
        title: title,
        slug: if (slug == "beat" || slug == "main") {
            "film"
        } else {
            slug
        },
        width: frame.width,
        height: frame.height,
        palette: palette,
        beats: ready,
    }
}

function film_from_json(raw: string) -> Film {
    normalize(baml.json.from_string<FilmPlan>(raw))
}

function aspect_for(width: int, height: int) -> Aspect {
    if (width == height) {
        Aspect.Square
    } else if (height > width) {
        Aspect.Portrait
    } else {
        Aspect.Landscape
    }
}

// The plan saved next to a video, after ids and timing are repaired.
function plan_from_film(film: Film) -> FilmPlan {
    FilmPlan {
        title: film.title,
        slug: film.slug,
        aspect: aspect_for(film.width, film.height),
        palette: film.palette,
        beats: film.beats,
    }
}

function demo_film() -> Film {
    normalize(
        FilmPlan {
            title: "Hyperframes Genie",
            slug: "hyperframes-genie",
            aspect: Aspect.Landscape,
            palette: Palette { ground: "#12141a", ink: "#f4f1ea", accent: "#d6ff4a" },
            beats: [
                Beat {
                    id: "open",
                    eyebrow: "BAML",
                    headline: "Plan the film in types",
                    body: "A model returns scenes, copy, and color. Nothing else.",
                    seconds: 4.0,
                },
                Beat {
                    id: "make",
                    eyebrow: "Hyperframes",
                    headline: "HTML is the timeline",
                    body: "Each scene is a paused composition the renderer can seek.",
                    seconds: 4.0,
                },
                Beat {
                    id: "render",
                    eyebrow: "Genie",
                    headline: "Then it becomes video",
                    body: "Check the composition, preview it, and render the mp4.",
                    seconds: 4.0,
                },
            ],
        },
    )
}
