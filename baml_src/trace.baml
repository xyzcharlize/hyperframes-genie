// One delivery trace per film. Stage spans land in BTEL. trace.json keeps the path.

class DeliveryStep {
    name: string,
    stage: string,
    status: string,
    started: string,
    ended: string,
    input: string,
    output: string,
}

class DeliveryTrace {
    slug: string,
    stages: DeliveryStep[],
}

function delivery_trace(slug: string, stage: string) -> trace.Options {
    trace.span(inputs = true).context(
        distinct_id = slug,
        metadata = { "slug": slug, "stage": stage },
    )
}

function film_slug(path: string) -> string {
    let parts = path.split("/");
    let last = parts.at(parts.length() - 1) ?? "";
    let slug = if (last == "plan.json" || last == "trace.json") {
        parts.at(parts.length() - 2) ?? ""
    } else {
        last
    };
    if (baml.regex.new("^[a-z0-9]+(-[a-z0-9]+)*$").match_full(slug) == null) {
        throw baml.errors.InvalidArgument { message: "film slug must be lowercase words separated by hyphens" }
    }
    slug
}

function trace_path(slug: string) -> string {
    `videos/${slug}/trace.json`
}

function stage_label(span_name: string) -> string {
    let bare = if (span_name.starts_with("user.")) {
        span_name.slice(5, span_name.length())
    } else {
        span_name
    };
    let mark = "_work";
    if (
        bare.length() > mark.length()
            && bare.slice(bare.length() - mark.length(), bare.length()) == mark
    ) {
        bare.slice(0, bare.length() - mark.length())
    } else {
        bare
    }
}

function json_text(value: json) -> string {
    match (value) {
        null => "",
        let text: string => text,
        _ => baml.json.stringify(value),
    }
}

function metadata_stage(value: json) -> string {
    match (value) {
        let fields: map<string, json> => json_text(fields.get("stage") ?? null),
        _ => "",
    }
}

function step_output(status: string, output: json, error: json) -> string {
    if (status == "return") {
        json_text(output)
    } else {
        json_text(error)
    }
}

function step_from_row(row: json) -> DeliveryStep? {
    match (row) {
        let cells: json[] => {
            if (cells.length() < 8) {
                return null;
            }
            DeliveryStep {
                name: stage_label(json_text(cells.at(0) ?? null)),
                stage: metadata_stage(cells.at(4) ?? null),
                status: json_text(cells.at(3) ?? null),
                started: json_text(cells.at(1) ?? null),
                ended: json_text(cells.at(2) ?? null),
                input: json_text(cells.at(5) ?? null),
                output: step_output(json_text(cells.at(3) ?? null), cells.at(6) ?? null, cells.at(7) ?? null),
            }
        },
        _ => null,
    }
}

function steps_from_query(query_body: string) -> DeliveryStep[] {
    let rows: json[] = match (baml.json.field(baml.json.parse(query_body), "rows")) {
        let items: json[] => items,
        _ => {
            let empty: json[] = [];
            empty
        },
    };
    let stages: DeliveryStep[] = [];
    for (let row in rows) {
        let step = step_from_row(row);
        if (step != null) {
            stages.push(step);
        }
    }
    stages
}

function same_step(left: DeliveryStep, right: DeliveryStep) -> bool {
    left.name == right.name
        && left.stage == right.stage
        && left.status == right.status
        && left.output == right.output
}

function merge_steps(recorded: DeliveryStep[], noted: DeliveryStep[]) -> DeliveryStep[] {
    let stages = recorded;
    for (let step in noted) {
        if (
            !stages.some((item) -> {
                same_step(item, step)
            })
        ) {
            stages.push(step);
        }
    }
    stages
}

function read_trace(slug: string) -> DeliveryTrace {
    let path = trace_path(slug);
    if (!baml.fs.exists(path)) {
        return DeliveryTrace { slug: slug, stages: [] };
    }
    baml.json.from_string<DeliveryTrace>(baml.fs.read(path))
}

function write_trace(slug: string, stages: DeliveryStep[]) -> string {
    let path = trace_path(slug);
    baml.fs.mkdir(`videos/${slug}`, baml.fs.MkdirOptions { recursive: true });
    let text = baml.json.stringify_pretty(baml.json.to_json(DeliveryTrace { slug: slug, stages: stages }));
    baml.fs.write(path, `${text}\n`);
    path
}

function note_stage(
    slug: string,
    name: string,
    stage: string,
    status: string,
    input: string,
    output: string,
) -> string {
    let safe = film_slug(slug);
    let trace = read_trace(safe);
    trace.stages.push(
        DeliveryStep {
            name: name,
            stage: stage,
            status: status,
            started: "",
            ended: "",
            input: input,
            output: output,
        },
    );
    write_trace(safe, trace.stages)
}

function remember_stage(
    slug: string,
    name: string,
    stage: string,
    status: string,
    input: string,
    output: string,
) -> string {
    note_stage(slug, name, stage, status, input, output) catch_all (_) {
        _ => ""
    }
}

function with_stage(
    slug: string,
    name: string,
    stage: string,
    input: string,
    body: () -> string,
) -> string {
    let outcome = body() catch_all (e, ctx) {
        _ => {
            let _ = remember_stage(slug, name, stage, "error", input, ctx.to_string());
            throw e;
        },
    };
    let _ = remember_stage(slug, name, stage, "return", input, outcome);
    outcome
}

function query_spans(slug: string) -> string {
    let sql = `SELECT span_name, start_time, end_time, status, context_metadata, input_args, output_value, error_value FROM spans WHERE context_distinct_id = '${slug}' AND span_type = 'function' ORDER BY start_time`;
    let result = baml.sys.shell(
        "baml query --local --format json --max-rows 500 -",
        baml.sys.ProcessOptions {
            cwd: null,
            env: null,
            timeout_ms: 60000,
            stdin: sql,
            stderr: null,
        },
    );
    if (!result.ok()) {
        throw baml.errors.Io { message: `baml query failed: ${result.stderr.to_string()}${result.stdout.to_string()}` }
    }
    result.stdout.to_string()
}

function film_trace(slug: string) -> string {
    //# Rewrite trace.json from the sealed stage spans for this film.
    let safe = film_slug(slug);
    let recorded = steps_from_query(query_spans(safe));
    let noted = read_trace(safe).stages;
    write_trace(safe, merge_steps(recorded, noted))
}

function publish_video(
    dir: string,
    film: Film,
    check: bool = false,
    still: string = "assets/avatar-still.png",
) -> string {
    let slug = film.slug;
    with_stage(slug, "publish_video", "publish", dir, () -> {
        publish_video_work(dir, film, check = check, still = still, $trace = delivery_trace(slug, "publish"))
    })
}

function render_cut(dir: string, cut: string) -> string {
    let slug = film_slug(dir);
    with_stage(slug, "render_cut", cut, dir, () -> {
        render_cut_work(dir, cut, $trace = delivery_trace(slug, cut))
    })
}

function open_studio(dir: string, cut: string, port: int = 3002) -> string {
    let slug = film_slug(dir);
    let stage = if (cut == "voice") {
        "voice_studio"
    } else {
        "preview_studio"
    };
    with_stage(slug, "open_studio", stage, dir, () -> {
        open_studio_work(dir, cut, port, $trace = delivery_trace(slug, stage))
    })
}

function approve(dir: string, stage: string = "preview", note: string = "") -> string {
    let slug = film_slug(dir);
    let name = `${stage}_approved`;
    with_stage(slug, "approve", name, dir, () -> {
        approve_work(dir, stage, note, $trace = delivery_trace(slug, name))
    })
}

function reject(dir: string, stage: string = "preview", note: string = "") -> string {
    let slug = film_slug(dir);
    let name = `${stage}_rejected`;
    with_stage(slug, "reject", name, dir, () -> {
        reject_work(dir, stage, note, $trace = delivery_trace(slug, name))
    })
}

function swap_voice(dir: string, voice_id: string) -> string {
    let slug = film_slug(dir);
    with_stage(slug, "swap_voice", "voice", voice_id, () -> {
        swap_voice_work(dir, voice_id, $trace = delivery_trace(slug, "voice"))
    })
}

function add_lipsync(dir: string, avatar_id: string) -> string {
    let slug = film_slug(dir);
    with_stage(slug, "add_lipsync", "lipsync", avatar_id, () -> {
        add_lipsync_work(dir, avatar_id, $trace = delivery_trace(slug, "lipsync"))
    })
}

function sync_card(dir: string, step: string, studio_url: string = "") -> string {
    let slug = film_slug(dir);
    with_stage(slug, "sync_card", step, step, () -> {
        sync_card_work(dir, step, studio_url, $trace = delivery_trace(slug, step))
    })
}
