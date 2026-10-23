// Write a Film to disk. One plan.json, then the local preview cut.

function assert_safe_dir(dir: string) -> string {
    let ok = baml.regex.new("^[A-Za-z0-9._/-]+$").match_full(dir) != null;
    if (!ok || dir.includes("..") || dir.starts_with("/")) {
        throw baml.errors.InvalidArgument {
            message: "output directory must be a relative path of letters, numbers, and ._-/",
        }
    }
    dir
}

function run_shell(
    command: string,
    cwd: string?,
    timeout_ms: int = 180000,
) -> baml.sys.ShellOutput {
    baml.sys.shell(
        command,
        baml.sys.ProcessOptions {
            cwd: cwd,
            env: null,
            timeout_ms: timeout_ms,
            stdin: null,
            stderr: null,
        },
    )
}

class VideoPaths {
    root: string,
    plan: string,
    reviews: string,
    renders: string,
}

class CutSpec {
    quality: string @description("draft for the preview; voice and lipsync are later HeyGen stages"),
    take: string @description("preview-cut, voice-cut, or lipsync-cut"),
    plan_file: string,
    renders: bool @description("only the preview cut is rendered locally"),
    @@description("Preview, then Studio, then a HeyGen voice, then Studio, then the lip-sync avatar.")
}

// One folder per video: plan, composition, and a renders/ directory for every take.
function video_paths(slug: string) -> VideoPaths {
    let root = `videos/${slug}`;
    VideoPaths {
        root: root,
        plan: `${root}/plan.json`,
        reviews: `${root}/reviews.json`,
        renders: `${root}/renders`,
    }
}

function render_output(dir: string, take: string) -> string {
    `${dir}/renders/${take}.mp4`
}

// Preview renders locally. Voice and lip-sync wait for a Studio review.
function resolve_cut(cut: string) -> CutSpec {
    match (cut) {
        "preview" => {
            CutSpec { quality: "draft", take: "preview-cut", plan_file: "plan.json", renders: true }
        },
        "voice" => {
            CutSpec { quality: "voice", take: "voice-cut", plan_file: "plan.json", renders: false }
        },
        "lipsync" => {
            CutSpec {
                quality: "lipsync",
                take: "lipsync-cut",
                plan_file: "plan.json",
                renders: false,
            }
        },
        _ => {
            throw baml.errors.InvalidArgument {
                message: "cut must be preview, voice, or lipsync",
            }
        },
    }
}

function cut_output(dir: string, cut: string) -> string {
    render_output(dir, resolve_cut(cut).take)
}

function ensure_scaffold(dir: string) -> void {
    if (baml.fs.exists(`${dir}/package.json`)) {
        return;
    }
    // Init owns package.json, the CLI pin, and hyperframes.json.
    let result = run_shell(`HYPERFRAMES_SKIP_SKILLS=1 npx --yes hyperframes init ${dir} --non-interactive`, null);
    if (!result.ok()) {
        throw baml.errors.Io { message: `hyperframes init failed: ${result.stderr.to_string()}` }
    }
}

// HyperFrames init writes this guide. This repo does not use it.
function drop_claude_md(dir: string) -> void {
    let path = `${dir}/CLAUDE.md`;
    if (baml.fs.exists(path)) {
        baml.fs.remove(path);
    }
}

function write_files(dir: string, film: Film) -> void {
    baml.fs.mkdir(`${dir}/compositions`, baml.fs.MkdirOptions { recursive: true });
    let files = render_project(film);
    for (let path in files.keys()) {
        let body = files.get(path) ?? "";
        baml.fs.write(`${dir}/${path}`, body);
    }
}

function check_project(dir: string) -> string {
    let result = run_shell("npm run check -- --json", dir);
    let stdout = result.stdout.to_string();
    let stderr = result.stderr.to_string();
    if (!result.ok()) {
        throw baml.errors.Io { message: `hyperframes check failed: ${stderr}${stdout}` }
    }
    stdout
}

function write_project(dir: string, film: Film, check: bool = false) -> string {
    //# Scaffold once, then replace the composition with the plan
    let safe = assert_safe_dir(dir);
    ensure_scaffold(safe);
    drop_claude_md(safe);
    write_files(safe, film);
    if (check) {
        check_project(safe);
    }
    safe
}

function drop_if_present(path: string) -> void {
    if (baml.fs.exists(path)) {
        baml.fs.remove(path);
    }
}

function drop_legacy_plans(dir: string) -> void {
    drop_if_present(`${dir}/preview-plan.json`);
    drop_if_present(`${dir}/voice-plan.json`);
    drop_if_present(`${dir}/lipsync-plan.json`);
    drop_if_present(`${dir}/production-plan.json`);
}

function read_plan(dir: string) -> VideoPlan {
    baml.json.from_string<VideoPlan>(baml.fs.read(`${dir}/plan.json`))
}

function write_plan(dir: string, plan: VideoPlan) -> string {
    let path = `${dir}/plan.json`;
    baml.fs.write(path, baml.json.to_string(plan));
    drop_legacy_plans(dir);
    path
}

function publish_video(
    dir: string,
    film: Film,
    check: bool = false,
    local_voice: string = "af_heart",
    still: string = "assets/avatar-still.png",
) -> string {
    //# One plan. HeyGen ids start empty. A rewrite drops reviews and old stage files.
    let safe = write_project(dir, film, check = check);
    baml.fs.mkdir(`${safe}/renders`, baml.fs.MkdirOptions { recursive: true });
    if (!baml.fs.exists(`${safe}/renders/.gitkeep`)) {
        baml.fs.write(`${safe}/renders/.gitkeep`, "");
    }
    let _ = write_plan(safe, video_plan_from_film(film, local_voice = local_voice, still = still));
    drop_if_present(`${safe}/reviews.json`);
    drop_if_present(`${safe}/approval.json`);
    safe
}

function render_quality(name: string) -> string {
    match (name) {
        "draft" => "draft",
        "looks" => "looks",
        "delivery" => "delivery",
        _ => {
            throw baml.errors.InvalidArgument { message: "quality must be draft, looks, or delivery" }
        },
    }
}

// Extra take. The usual files come from render_cut.
function render_take(dir: string, quality: string = "looks", take: string = "") -> string {
    let safe = assert_safe_dir(dir);
    let q = render_quality(quality);
    let name = if (take == "") {
        q
    } else {
        safe_id(take)
    };
    if (!baml.fs.exists(`${safe}/package.json`)) {
        throw baml.errors.InvalidArgument { message: `no HyperFrames project at ${safe}` }
    }
    baml.fs.mkdir(`${safe}/renders`, baml.fs.MkdirOptions { recursive: true });
    let output = render_output(safe, name);
    let result = run_shell(`npm run render -- --quality ${q} --output renders/${name}.mp4`, safe, timeout_ms = 300000);
    if (!result.ok()) {
        throw baml.errors.Io { message: `hyperframes render failed: ${result.stderr.to_string()}${result.stdout.to_string()}` }
    }
    output
}

function read_reviews(dir: string) -> Reviews {
    let path = `${dir}/reviews.json`;
    if (!baml.fs.exists(path)) {
        return Reviews { preview: null, voice: null };
    }
    baml.json.from_string<Reviews>(baml.fs.read(path))
}

function write_reviews(dir: string, reviews: Reviews) -> string {
    let path = `${dir}/reviews.json`;
    baml.fs.write(path, baml.json.to_string(reviews));
    path
}

function review_stage(
    dir: string,
    stage: string,
    status: "approved" | "rejected",
    note: string,
) -> string {
    let safe = assert_safe_dir(dir);
    let reviews = read_reviews(safe);
    if (stage == "preview") {
        if (!baml.fs.exists(`${safe}/renders/preview-cut.mp4`)) {
            throw baml.errors.InvalidArgument { message: "Render the preview cut and review it in Studio first." }
        }
        let plan = read_plan(safe);
        return write_reviews(
            safe,
            Reviews {
                preview: StageReview { status: status, note: note, script: plan.script, voice_id: "" },
                voice: null,
            },
        );
    }
    if (stage == "voice") {
        let plan = read_plan(safe);
        if (plan.voice_id == "") {
            throw baml.errors.InvalidArgument { message: "Swap the local voice to a HeyGen voice_id before this review." }
        }
        return write_reviews(
            safe,
            Reviews {
                preview: reviews.preview,
                voice: StageReview {
                    status: status,
                    note: note,
                    script: plan.script,
                    voice_id: plan.voice_id,
                },
            },
        );
    }
    throw baml.errors.InvalidArgument { message: "stage must be preview or voice" }
}

function approve(dir: string, stage: string = "preview", note: string = "") -> string {
    review_stage(dir, stage, "approved", note)
}

function reject(dir: string, stage: string = "preview", note: string = "") -> string {
    review_stage(dir, stage, "rejected", note)
}

function swap_voice(dir: string, voice_id: string) -> string {
    //# Keep the still avatar. Replace only the local voice. Do not call HeyGen.
    let safe = assert_safe_dir(dir);
    let plan = read_plan(safe);
    let block = voice_swap_block(read_reviews(safe).preview, plan.script, voice_id);
    if (block != null) {
        throw baml.errors.InvalidArgument { message: block }
    }
    let path = write_plan(safe, with_voice(plan, voice_id));
    let reviews = read_reviews(safe);
    write_reviews(safe, Reviews { preview: reviews.preview, voice: null });
    path
}

function add_lipsync(dir: string, avatar_id: string) -> string {
    //# Attach the avatar to the reviewed voice. Do not start the paid render.
    let safe = assert_safe_dir(dir);
    let plan = with_avatar(read_plan(safe), avatar_id);
    let block = lipsync_block(read_reviews(safe).voice, plan);
    if (block != null) {
        throw baml.errors.InvalidArgument { message: block }
    }
    write_plan(safe, plan)
}

function render_cut(dir: string, cut: string) -> string {
    //# Only the preview cut renders. Later stages do not call HeyGen.
    let spec = resolve_cut(cut);
    let safe = assert_safe_dir(dir);
    if (!spec.renders) {
        throw baml.errors.InvalidArgument {
            message: "Only the preview cut renders. Swap the voice or add the lip-sync avatar after the Studio reviews. Those steps do not call HeyGen.",
        }
    }
    render_take(safe, quality = spec.quality, take = spec.take);
    open_studio(safe, cut)
}
