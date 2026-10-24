// Offline checks for the per-film delivery trace.

test "film slug is the video folder" {
    assert.equal(film_slug("videos/hello-world"), "hello-world");
    assert.equal(film_slug("videos/hello-world/plan.json"), "hello-world");
    assert.equal(film_slug("hello-world"), "hello-world")
}

test "query rows become one delivery path" {
    let body = `{"rows":[["user.publish_video_work","2026-10-24T07:02:56Z","2026-10-24T07:02:57Z","return",{"slug":"hello-world","stage":"publish"},{"dir":"videos/hello-world"},"videos/hello-world",null],["user.sync_card_work","2026-10-24T07:02:57Z","2026-10-24T07:02:58Z","user_error",{"slug":"hello-world","stage":"publish"},{"step":"publish"},null,{"error":"missing card"}]]}`;
    let trace = baml.json.from_string<DeliveryTrace>(steps_document("hello-world", body));
    assert.equal(trace.slug, "hello-world");
    assert.equal(trace.stages.length(), 2);
    assert.equal(trace.stages.at(0)?.name ?? "", "publish_video");
    assert.equal(trace.stages.at(0)?.stage ?? "", "publish");
    assert.equal(trace.stages.at(0)?.output ?? "", "videos/hello-world");
    assert.equal(trace.stages.at(1)?.name ?? "", "sync_card");
    assert.equal(trace.stages.at(1)?.status ?? "", "user_error");
    assert.equal(trace.stages.at(1)?.output ?? "", `{"error":"missing card"}`)
}

function trace_ping_work(slug: string) -> string {
    slug
}

test "a stage call returns its film slug" {
    let slug = "trace-probe";
    assert.equal(trace_ping_work(slug, $trace = delivery_trace(slug, "ping")), slug)
}

function steps_document(slug: string, query_body: string) -> string {
    baml.json.stringify_pretty(
        baml.json.to_json(DeliveryTrace { slug: slug, stages: steps_from_query(query_body) }),
    )
}

test "a noted stage is kept when the recording has no span yet" {
    let slug = "trace-probe";
    drop_if_present(trace_path(slug));
    let _ = note_stage(slug, "publish_video", "publish", "return", "videos/trace-probe", "videos/trace-probe");
    let traced = film_trace_from("", slug);
    assert.equal(traced.stages.length(), 1);
    assert.equal(traced.stages.at(0)?.name ?? "", "publish_video");
    let again = film_trace_from(
        `{"rows":[["user.publish_video_work","t0","t1","return",{"stage":"publish"},{"dir":"videos/trace-probe"},"videos/trace-probe",null]]}`,
        slug,
    );
    assert.equal(again.stages.length(), 1);
    assert.equal(again.stages.at(0)?.started ?? "", "t0");
    drop_if_present(trace_path(slug));
    baml.fs.remove_dir(`videos/${slug}`)
}

function film_trace_from(query_body: string, slug: string) -> DeliveryTrace {
    let safe = film_slug(slug);
    let recorded = if (query_body == "") {
        let empty: DeliveryStep[] = [];
        empty
    } else {
        steps_from_query(query_body)
    };
    let merged = merge_steps(recorded, read_trace(safe).stages);
    let _ = write_trace(safe, merged);
    read_trace(safe)
}
