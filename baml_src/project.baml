// Write a Film to disk and, when asked, scaffold or check it with Hyperframes.

function assert_safe_dir(dir: string) -> string {
    let ok = baml.regex.new("^[A-Za-z0-9._/-]+$").match_full(dir) != null;
    if (!ok || dir.includes("..") || dir.starts_with("/")) {
        throw baml.errors.InvalidArgument {
            message: "output directory must be a relative path of letters, numbers, and ._-/",
        }
    }
    dir
}

function run_shell(command: string, cwd: string?) -> baml.sys.ShellOutput {
    baml.sys.shell(
        command,
        baml.sys.ProcessOptions {
            cwd: cwd,
            env: null,
            timeout_ms: 180000,
            stdin: null,
            stderr: null,
        },
    )
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
