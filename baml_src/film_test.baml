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
    let production = resolve_cut("production");
    assert.equal(paths.root, "videos/ceramic-studio");
    assert.equal(paths.plan, "videos/ceramic-studio/plan.json");
    assert.equal(paths.renders, "videos/ceramic-studio/renders");
    assert.equal(paths.preview_plan, "videos/ceramic-studio/preview-plan.json");
    assert.equal(paths.production_plan, "videos/ceramic-studio/production-plan.json");
    assert.equal(paths.approval, "videos/ceramic-studio/approval.json");
    assert.equal(preview.quality, "draft");
    assert.equal(preview.take, "preview-cut");
    assert.equal(preview.plan_file, "preview-plan.json");
    assert.equal(preview.needs_approval, false);
    assert.equal(render_quality(preview.quality), "draft");
    assert.equal(safe_id(preview.take), "preview-cut");
    assert.equal(cut_output(paths.root, "preview"), "videos/ceramic-studio/renders/preview-cut.mp4");
    assert.equal(production.quality, "heygen");
    assert.equal(production.take, "production-cut");
    assert.equal(production.plan_file, "production-plan.json");
    assert.equal(production.needs_approval, true);
    assert.equal(safe_id(production.take), "production-cut");
    assert.equal(
        cut_output(paths.root, "production"),
        "videos/ceramic-studio/renders/production-cut.mp4",
    );
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
    assert.equal(
        looks,
        "cut must be preview (still avatar, local TTS) or production (HeyGen lip-sync after approval)",
    );
    assert.equal(
        named,
        "cut must be preview (still avatar, local TTS) or production (HeyGen lip-sync after approval)",
    )
}

test "one story makes a local preview plan and a HeyGen production plan" {
    let film = demo_film();
    let preview = preview_plan_from_film(film);
    let production = production_plan_from_film(film);
    let again = baml.json.from_string<PreviewPlan>(baml.json.to_string(preview));
    assert.equal(again.avatar, "still");
    assert.equal(again.voice, "local-tts");
    assert.equal(preview.voice_id, "af_heart");
    assert.equal(preview.still, "assets/avatar-still.png");
    assert.equal(preview_plan_from_film(film, voice_id = "Nope").voice_id, "af_heart");
    assert.equal(production.avatar, "heygen-lipsync");
    assert.equal(production.voice, "heygen");
    assert.equal(production.avatar_id, "");
    assert.equal(production.voice_id, "");
    assert.equal(preview.script, production.script);
    assert.equal(preview.script, narration_script(film.beats));
    assert.equal(preview.slug, production.slug);
    assert.equal(preview.beats.length(), production.beats.length());
    let bad = production_plan_from_film(film, avatar_id = "a b", voice_id = "ok") catch (e) {
        baml.errors.InvalidArgument => e.message,
    };
    assert.equal(bad, "avatar_id must be a HeyGen id")
}

test "production stays blocked until a person approves the same script" {
    let plan = production_plan_from_film(demo_film());
    let missing = production_block(null, plan) ?? "";
    let rejected = production_block(Approval { status: "rejected", note: "no", script: plan.script }, plan) ?? "";
    let stale = production_block(Approval { status: "approved", note: "", script: "other words" }, plan) ?? "";
    let unnamed = production_block(Approval { status: "approved", note: "ok", script: plan.script }, plan) ?? "";
    let avatar_only = production_plan_from_film(demo_film(), avatar_id = "ava1");
    let no_voice = production_block(Approval { status: "approved", note: "ok", script: avatar_only.script }, avatar_only)
        ?? "";
    let ready_plan = production_plan_from_film(demo_film(), avatar_id = "ava1", voice_id = "voc1");
    let ready = production_block(Approval { status: "approved", note: "ok", script: ready_plan.script }, ready_plan);
    let body = heygen_request(ready_plan);
    assert.equal(missing, "Approve the preview before the HeyGen production cut.");
    assert.equal(rejected, "Production cut is blocked because the preview was rejected.");
    assert.equal(stale, "The story changed after approval. Review the preview again.");
    assert.equal(unnamed, "Production plan needs a HeyGen avatar_id.");
    assert.equal(
        no_voice,
        "Production plan needs a voice_id. The speaking voice is its own HeyGen id, often not the avatar's default.",
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
