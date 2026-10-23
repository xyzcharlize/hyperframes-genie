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
    renders: string,
}

class CutSpec {
    quality: string @description("draft for preview, delivery for production"),
    take: string @description("preview-cut or production-cut"),
    @@description("Preview-cut first, then production-cut.")
}

// One folder per video: plan, composition, and a renders/ directory for every take.
function video_paths(slug: string) -> VideoPaths {
    let root = `videos/${slug}`;
    VideoPaths { root: root, plan: `${root}/plan.json`, renders: `${root}/renders` }
}

function render_output(dir: string, take: string) -> string {
    `${dir}/renders/${take}.mp4`
}

// preview-cut is draft; production-cut is delivery.
function resolve_cut(cut: string) -> CutSpec {
    //# Allow only the two named cuts
    match (cut) {
        "preview" => CutSpec { quality: "draft", take: "preview-cut" },
        "production" => CutSpec { quality: "delivery", take: "production-cut" },
        _ => {
            throw baml.errors.InvalidArgument {
                message: "cut must be preview (draft, renders/preview-cut.mp4) or production (delivery, renders/production-cut.mp4)",
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
    write_files(safe, film);
    if (check) {
        check_project(safe);
    }
    safe
}

function publish_video(dir: string, film: Film, check: bool = false) -> string {
    //# Composition at the video root, plan beside it, takes under renders/
    let safe = write_project(dir, film, check = check);
    baml.fs.mkdir(`${safe}/renders`, baml.fs.MkdirOptions { recursive: true });
    if (!baml.fs.exists(`${safe}/renders/.gitkeep`)) {
        baml.fs.write(`${safe}/renders/.gitkeep`, "");
    }
    baml.fs.write(`${safe}/plan.json`, baml.json.to_string(plan_from_film(film)));
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

function render_cut(dir: string, cut: string) -> string {
    //# Map the cut onto a HyperFrames quality and take
    let spec = resolve_cut(cut);
    render_take(dir, quality = spec.quality, take = spec.take)
}
