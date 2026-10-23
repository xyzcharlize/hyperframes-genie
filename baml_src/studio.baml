// HyperFrames Studio is the preview server. Open it after a cut exists.

class StudioServer {
    studioUrl: string,
    ready: bool,
    projectName: string,
    port: int,
}

class StudioLaunch {
    ok: bool,
    result: StudioServer,
}

function studio_project(dir: string) -> string {
    let parts = dir.split("/");
    let last = parts.at(parts.length() - 1) ?? "";
    if (last == "") {
        "video"
    } else {
        last
    }
}

function studio_url(dir: string, port: int = 3002) -> string {
    `http://127.0.0.1:${port}/#project/${studio_project(dir)}`
}

function studio_from_output(stdout: string) -> string {
    let launch = baml.json.from_string<StudioLaunch>(stdout);
    if (!launch.ok || !launch.result.ready || launch.result.studioUrl == "") {
        throw baml.errors.InvalidArgument { message: "HyperFrames Studio did not become ready." }
    }
    launch.result.studioUrl
}

function open_studio(dir: string, cut: string, port: int = 3002) -> string {
    //# The cut file must exist. Studio then edits that composition.
    let safe = assert_safe_dir(dir);
    let spec = resolve_cut(cut);
    if (!baml.fs.exists(`${safe}/package.json`)) {
        throw baml.errors.InvalidArgument { message: `no HyperFrames project at ${safe}` }
    }
    let mp4 = render_output(safe, spec.take);
    if (!baml.fs.exists(mp4)) {
        throw baml.errors.InvalidArgument { message: `Render ${spec.take} before opening Studio.` }
    }
    let result = run_shell(
        `npx --yes hyperframes@0.8.188 preview --background --json --no-open --port ${port}`,
        safe,
        timeout_ms = 180000,
    );
    if (!result.ok()) {
        throw baml.errors.Io {
            message: `HyperFrames Studio failed: ${result.stderr.to_string()}${result.stdout.to_string()}`,
        }
    }
    studio_from_output(result.stdout.to_string())
}
