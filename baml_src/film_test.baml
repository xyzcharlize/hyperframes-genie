// Offline tests for planning glue and the HyperFrames emitter.

test "normalize repairs a sloppy plan" {
    let film = normalize(
        FilmPlan {
            title: "Ada & the Loom",
            slug: "Ada & the Loom",
            aspect: Aspect.Portrait,
            palette: Palette { ground: "navy", ink: "#fff", accent: "#00ccaa" },
            beats: [
                Beat {
                    id: "Open!",
                    eyebrow: "One",
                    headline: "Hello",
                    body: "First.",
                    seconds: 99.0,
                },
                Beat {
                    id: "open",
                    eyebrow: "Two",
                    headline: "Again",
                    body: "Second.",
                    seconds: 1.0,
                },
                Beat {
                    id: "2nd",
                    eyebrow: "Three",
                    headline: "Third",
                    body: "Third.",
                    seconds: 4.0,
                },
                Beat {
                    id: "extra",
                    eyebrow: "Four",
                    headline: "Fourth",
                    body: "Fourth.",
                    seconds: 4.0,
                },
                Beat {
                    id: "overflow",
                    eyebrow: "Five",
                    headline: "Fifth",
                    body: "Fifth.",
                    seconds: 4.0,
                },
            ],
        },
    );
    assert.equal(film.slug, "ada-the-loom");
    assert.equal(film.width, 1080);
    assert.equal(film.height, 1920);
    assert.equal(film.palette.ground, "#12141a");
    assert.equal(film.palette.ink, "#f4f1ea");
    assert.equal(film.palette.accent, "#00ccaa");
    assert.equal(film.beats.length(), 3);
    assert.equal(film.beats.at(0)?.id ?? "", "open");
    assert.equal(film.beats.at(1)?.id ?? "", "open-2");
    assert.equal(film.beats.at(0)?.seconds ?? 0.0, 5.0);
    assert.equal(film.beats.at(1)?.seconds ?? 0.0, 3.0);
    assert.is_true(sum_seconds(film.beats) <= 15.0)
}

test "empty plan still renders one scene" {
    let film = normalize(
        FilmPlan {
            title: "",
            slug: "",
            aspect: Aspect.Square,
            palette: Palette { ground: "#111111", ink: "#eeeeee", accent: "#ff8800" },
            beats: [],
        },
    );
    assert.equal(film.title, "Untitled");
    assert.equal(film.slug, "untitled");
    assert.equal(film.width, 1080);
    assert.equal(film.beats.length(), 1);
    assert.equal(film.beats.at(0)?.id ?? "", "open")
}

test "demo project is a seekable HyperFrames film" {
    let film = demo_film();
    let files = render_project(film);
    let index = files.get("index.html") ?? "";
    let open = files.get("compositions/open.html") ?? "";
    assert.equal(sum_seconds(film.beats), 12.0);
    assert.is_true(index.includes("data-composition-id=\"main\""));
    assert.is_true(index.includes("data-duration=\"12.0\""));
    assert.is_true(index.includes("data-composition-src=\"compositions/open.html\""));
    assert.is_true(index.includes("data-composition-src=\"compositions/make.html\""));
    assert.is_true(index.includes("data-composition-src=\"compositions/render.html\""));
    assert.is_true(index.includes("data-start=\"4.0\""));
    assert.is_true(index.includes("data-start=\"8.0\""));
    assert.is_true(open.includes("<template>"));
    assert.is_true(open.includes("window.__timelines[\"open\"]"));
    assert.is_true(open.includes("class=\"clip\""));
    assert.is_true(open.includes("data-var-text=\"headline\""));
    assert.is_true(open.includes("&quot;type&quot;:&quot;string&quot;"));
    assert.is_true(open.includes("&quot;type&quot;:&quot;color&quot;"));
    assert.is_true(open.includes("scaleX"));
    assert.equal(files.length(), 4)
}

test "copy is escaped and a saved plan parses" {
    let film = normalize(
        FilmPlan {
            title: "Marks",
            slug: "marks",
            aspect: Aspect.Landscape,
            palette: Palette { ground: "#101010", ink: "#f5f5f5", accent: "#ffd000" },
            beats: [
                Beat {
                    id: "marks",
                    eyebrow: "A & B",
                    headline: "Less < than",
                    body: "Quote \"here\".",
                    seconds: 4.0,
                },
            ],
        },
    );
    let scene = render_project(film).get("compositions/marks.html") ?? "";
    assert.is_true(scene.includes("A &amp; B"));
    assert.is_true(scene.includes("Less &lt; than"));
    assert.is_true(scene.includes("Quote &quot;here&quot;."));
    let parsed = PlanFilm@spec("brief").parse(
        "{\"title\":\"Ada\",\"slug\":\"ada\",\"aspect\":\"Landscape\",\"palette\":{\"ground\":\"#111111\",\"ink\":\"#ffffff\",\"accent\":\"#ffcc00\"},\"beats\":[{\"id\":\"open\",\"eyebrow\":\"One\",\"headline\":\"Hello\",\"body\":\"World enough.\",\"seconds\":4.0}]}",
    );
    assert.equal(parsed.title, "Ada");
    assert.equal(parsed.aspect, Aspect.Landscape);
    assert.equal(normalize(parsed).beats.at(0)?.headline ?? "", "Hello")
}
