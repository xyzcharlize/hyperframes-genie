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
    let parsed = film_from_json(
        "{\"title\":\"Ada\",\"slug\":\"ada\",\"aspect\":\"Landscape\",\"palette\":{\"ground\":\"#111111\",\"ink\":\"#ffffff\",\"accent\":\"#ffcc00\"},\"beats\":[{\"id\":\"open\",\"eyebrow\":\"One\",\"headline\":\"Hello\",\"body\":\"World enough.\",\"seconds\":4.0}]}",
    );
    assert.equal(parsed.title, "Ada");
    assert.equal(parsed.width, 1920);
    assert.equal(parsed.beats.at(0)?.headline ?? "", "Hello")
}

test "each video keeps its plan and its two cuts" {
    let paths = video_paths("ceramic-studio");
    let preview = resolve_cut("preview");
    let voice = resolve_cut("voice");
    let lipsync = resolve_cut("lipsync");
    assert.equal(paths.root, "videos/ceramic-studio");
    assert.equal(paths.plan, "videos/ceramic-studio/plan.json");
    assert.equal(paths.renders, "videos/ceramic-studio/renders");
    assert.equal(paths.reviews, "videos/ceramic-studio/reviews.json");
    assert.equal(preview.quality, "draft");
    assert.equal(preview.take, "preview-cut");
    assert.equal(preview.plan_file, "plan.json");
    assert.equal(preview.renders, true);
    assert.equal(render_quality(preview.quality), "draft");
    assert.equal(cut_output(paths.root, "preview"), "videos/ceramic-studio/renders/preview-cut.mp4");
    assert.equal(voice.quality, "voice");
    assert.equal(voice.renders, false);
    assert.equal(voice.plan_file, "plan.json");
    assert.equal(lipsync.quality, "lipsync");
    assert.equal(lipsync.renders, false);
    assert.equal(lipsync.plan_file, "plan.json");
    assert.equal(render_output(paths.root, "looks"), "videos/ceramic-studio/renders/looks.mp4");
    let film = demo_film();
    let plan = plan_from_film(film);
    assert.equal(plan.slug, "hyperframes-genie");
    assert.equal(plan.aspect, Aspect.Landscape);
    assert.equal(plan.beats.length(), 3)
}

test "an unknown cut is rejected" {
    let looks = cut_output("videos/ceramic-studio", "looks") catch (e) {
        baml.errors.InvalidArgument => e.message,
    };
    let named = cut_output("videos/ceramic-studio", "preview-cut") catch (e) {
        baml.errors.InvalidArgument => e.message,
    };
    assert.equal(looks, "cut must be preview, voice, or lipsync");
    assert.equal(named, "cut must be preview, voice, or lipsync")
}

test "one story makes a silent preview plan and a HeyGen production plan" {
    let film = demo_film();
    let plan = video_plan_from_film(film);
    let again = baml.json.from_string<VideoPlan>(baml.json.to_string(plan));
    let reread = film_from_json(baml.json.to_string(plan));
    assert.equal(again.still, "assets/avatar-still.png");
    assert.equal(again.voice_id, "");
    assert.equal(again.avatar_id, "");
    assert.equal(again.script, narration_script(film.beats));
    assert.equal(reread.slug, film.slug);
    assert.equal(reread.beats.length(), film.beats.length())
}

test "production stays blocked until a person approves the same script" {
    let film = demo_film();
    let plan = video_plan_from_film(film);
    let missing = voice_swap_block(null, plan.script, "voc1") ?? "";
    let rejected = voice_swap_block(
        StageReview { status: "rejected", note: "no", script: plan.script, voice_id: "" },
        plan.script,
        "voc1",
    )
        ?? "";
    let unnamed = voice_swap_block(
        StageReview { status: "approved", note: "ok", script: plan.script, voice_id: "" },
        plan.script,
        "",
    )
        ?? "";
    let swapped = with_voice(plan, "voc1");
    let voice_ok = voice_swap_block(
        StageReview { status: "approved", note: "ok", script: plan.script, voice_id: "" },
        plan.script,
        "voc1",
    );
    let ready_plan = with_avatar(swapped, "ava1");
    let no_voice_review = lipsync_block(null, ready_plan) ?? "";
    let ready = lipsync_block(
        StageReview { status: "approved", note: "ok", script: swapped.script, voice_id: "voc1" },
        ready_plan,
    );
    let body = heygen_request(ready_plan);
    assert.equal(missing, "Review the preview in Studio before swapping the voice.");
    assert.equal(rejected, "Voice swap is blocked because the preview was rejected.");
    assert.equal(
        unnamed,
        "Name the HeyGen voice_id. The preview is silent, and this voice is often not an avatar's default voice.",
    );
    assert.equal(voice_ok, null);
    assert.equal(swapped.voice_id, "voc1");
    assert.equal(swapped.avatar_id, "");
    assert.equal(
        no_voice_review,
        "Review the HeyGen voice in Studio before adding the lip-sync avatar.",
    );
    assert.equal(ready_plan.avatar_id, "ava1");
    assert.equal(ready_plan.voice_id, "voc1");
    assert.equal(ready, null);
    assert.is_true(body.includes("\"type\":\"avatar\""));
    assert.is_true(body.includes("\"avatar_id\":\"ava1\""));
    assert.is_true(body.includes("\"voice_id\":\"voc1\""))
}

test "studio opens on the project after a cut" {
    assert.equal(studio_project("videos/hyperframes-genie"), "hyperframes-genie");
    assert.equal(
        studio_url("videos/ceramic-studio", port = 3017),
        "http://127.0.0.1:3017/#project/ceramic-studio",
    );
    let url = studio_from_output(
        "{\"schemaVersion\":1,\"operation\":\"start\",\"ok\":true,\"result\":{\"state\":\"started\",\"mode\":\"background\",\"projectName\":\"hyperframes-genie\",\"projectDir\":\"/workspace/videos/hyperframes-genie\",\"host\":\"127.0.0.1\",\"port\":3017,\"pid\":1,\"serverUrl\":\"http://127.0.0.1:3017\",\"studioUrl\":\"http://127.0.0.1:3017/#project/hyperframes-genie\",\"ready\":true}}",
    );
    assert.equal(url, "http://127.0.0.1:3017/#project/hyperframes-genie")
}
