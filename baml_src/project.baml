// Write a Film to disk and render its preview and production cuts.

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
    preview_plan: string,
    production_plan: string,
    approval: string,
    renders: string,
}

class CutSpec {
    quality: string @description("draft for the preview composition; production is not a HyperFrames quality"),
    take: string @description("preview-cut, or production-cut after approval"),
    plan_file: string @description("preview-plan.json or production-plan.json"),
    needs_approval: bool,
    @@description("Preview is a still avatar and local TTS. Production is a HeyGen lip-sync.")
}

// One folder per video: plan, composition, and a renders/ directory for every take.
function video_paths(slug: string) -> VideoPaths {
    let root = `videos/${slug}`;
    VideoPaths {
        root: root,
        plan: `${root}/plan.json`,
        preview_plan: `${root}/preview-plan.json`,
        production_plan: `${root}/production-plan.json`,
        approval: `${root}/approval.json`,
        renders: `${root}/renders`,
    }
}

function render_output(dir: string, take: string) -> string {
    `${dir}/renders/${take}.mp4`
}

// Preview is local. Production is the HeyGen plan and stays gated.
function resolve_cut(cut: string) -> CutSpec {
    //# Allow only the two named cuts
    match (cut) {
        "preview" => {
            CutSpec {
                quality: "draft",
                take: "preview-cut",
                plan_file: "preview-plan.json",
                needs_approval: false,
            }
        },
        "production" => {
            CutSpec {
                quality: "heygen",
                take: "production-cut",
                plan_file: "production-plan.json",
                needs_approval: true,
            }
        },
        _ => {
            throw baml.errors.InvalidArgument {
                message: "cut must be preview (still avatar, local TTS) or production (HeyGen lip-sync after approval)",
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

function publish_video(
    dir: string,
    film: Film,
    check: bool = false,
    local_voice: string = "af_heart",
    still: string = "assets/avatar-still.png",
    avatar_id: string = "",
    heygen_voice: string = "",
) -> string {
    //# One story, then a preview plan and a production plan. A rewrite drops approval.
    let safe = write_project(dir, film, check = check);
    baml.fs.mkdir(`${safe}/renders`, baml.fs.MkdirOptions { recursive: true });
    if (!baml.fs.exists(`${safe}/renders/.gitkeep`)) {
        baml.fs.write(`${safe}/renders/.gitkeep`, "");
    }
    let preview = preview_plan_from_film(film, voice_id = local_voice, still = still);
    let production = production_plan_from_film(film, avatar_id = avatar_id, voice_id = heygen_voice);
    baml.fs.write(`${safe}/plan.json`, baml.json.to_string(plan_from_film(film)));
    baml.fs.write(`${safe}/preview-plan.json`, baml.json.to_string(preview));
    baml.fs.write(`${safe}/production-plan.json`, baml.json.to_string(production));
    let approval = `${safe}/approval.json`;
    if (baml.fs.exists(approval)) {
        baml.fs.remove(approval);
    }
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

function read_approval(dir: string) -> Approval? {
    let path = `${dir}/approval.json`;
    if (!baml.fs.exists(path)) {
        return null;
    }
    baml.json.from_string<Approval>(baml.fs.read(path))
}

function write_review(dir: string, status: "approved" | "rejected", note: string) -> string {
    let safe = assert_safe_dir(dir);
    let preview_path = `${safe}/preview-plan.json`;
    if (!baml.fs.exists(preview_path)) {
        throw baml.errors.InvalidArgument { message: "Write the preview plan before reviewing it." }
    }
    if (status == "approved" && !baml.fs.exists(`${safe}/renders/preview-cut.mp4`)) {
        throw baml.errors.InvalidArgument { message: "Render the preview cut and review it before approving." }
    }
    let preview = baml.json.from_string<PreviewPlan>(baml.fs.read(preview_path));
    let path = `${safe}/approval.json`;
    baml.fs.write(
        path,
        baml.json.to_string(Approval { status: status, note: note, script: preview.script }),
    );
    path
}

function approve(dir: string, note: string = "") -> string {
    write_review(dir, "approved", note)
}

function reject(dir: string, note: string = "") -> string {
    write_review(dir, "rejected", note)
}

function render_cut(dir: string, cut: string) -> string {
    //# Preview renders locally. Production never starts a HeyGen call.
    let spec = resolve_cut(cut);
    let safe = assert_safe_dir(dir);
    if (spec.needs_approval) {
        let plan_path = `${safe}/production-plan.json`;
        if (!baml.fs.exists(plan_path)) {
            throw baml.errors.InvalidArgument { message: "Missing production-plan.json. Run baml run main first." }
        }
        let plan = baml.json.from_string<ProductionPlan>(baml.fs.read(plan_path));
        let block = production_block(read_approval(safe), plan);
        if (block != null) {
            throw baml.errors.InvalidArgument { message: block }
        }
        throw baml.errors.InvalidArgument {
            message: "The preview is approved. Refusing to start the HeyGen lip-sync.",
        }
    }
    //# Render the cut, then open Studio for fine adjustments.
    render_take(safe, quality = spec.quality, take = spec.take);
    open_studio(safe, cut)
}
