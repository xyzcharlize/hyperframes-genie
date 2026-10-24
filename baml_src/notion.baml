// Hyperframes Genie Status. Option names are the pipeline steps.

class CardWrite {
    status: string,
    studio_url: string,
    voice_id: string,
    avatar_id: string,
    silent_cut: string,
}

class NotionPageRef {
    id: string,
}

class NotionQueryResult {
    results: NotionPageRef[],
}

function card_status(step: string) -> string {
    match (step) {
        "publish" => "Preview cut",
        "preview_studio" => "Studio review",
        "preview_approved" => "HeyGen voice",
        "preview_rejected" => "Rework",
        "voice_set" => "HeyGen voice",
        "voice_studio" => "Voice review",
        "voice_approved" => "Lip-sync avatar",
        "voice_rejected" => "Rework",
        "lipsync_set" => "Done",
        _ => {
            throw baml.errors.InvalidArgument { message: "unknown card step" }
        },
    }
}

function card_write(
    step: string,
    slug: string,
    studio_url: string,
    voice_id: string,
    avatar_id: string,
) -> CardWrite {
    let status = card_status(step);
    let link = if (step == "preview_studio" || step == "voice_studio") {
        studio_url
    } else {
        ""
    };
    let voice = if (
        step == "voice_set"
            || step == "voice_studio"
            || step == "voice_approved"
            || step == "lipsync_set"
    ) {
        voice_id
    } else {
        ""
    };
    let avatar = if (step == "lipsync_set") {
        avatar_id
    } else {
        ""
    };
    let silent = if (step == "preview_studio") {
        `videos/${slug}/renders/preview-cut.mp4`
    } else {
        ""
    };
    CardWrite {
        status: status,
        studio_url: link,
        voice_id: voice,
        avatar_id: avatar,
        silent_cut: silent,
    }
}

function status_property(name: string) -> string {
    `{"status":{"name":${baml.json.to_string(name)}}}`
}

function url_property(url: string) -> string {
    `{"url":${baml.json.to_string(url)}}`
}

function text_property(value: string) -> string {
    `{"rich_text":[{"type":"text","text":{"content":${baml.json.to_string(value)}}}]}`
}

function notion_properties_body(write: CardWrite) -> string {
    let parts: string[] = [];
    parts.push(`"Status":${status_property(write.status)}`);
    if (write.studio_url != "") {
        parts.push(`"Lastest Studio Link":${url_property(write.studio_url)}`);
    }
    if (write.voice_id != "") {
        parts.push(`"Voice_id":${text_property(write.voice_id)}`);
    }
    if (write.avatar_id != "") {
        parts.push(`"Avatar_id":${text_property(write.avatar_id)}`);
    }
    if (write.silent_cut != "") {
        parts.push(`"Silent Preview Cut (mp4)":${text_property(write.silent_cut)}`);
    }
    `{"properties":{${parts.join(",")}}}`
}

function notion_page_ids(body: string) -> string[] {
    baml.json.from_string<NotionQueryResult>(body).results.map((page) -> {
        page.id
    })
}

function notion_token() -> string? {
    let token = baml.env.get("NOTION_TOKEN");
    if (token != null && token != "") {
        return token;
    }
    let key = baml.env.get("NOTION_API_KEY");
    if (key != null && key != "") {
        return key;
    }
    null
}

function notion_headers(token: string) -> map<string, string> {
    {
        "Authorization": `Bearer ${token}`,
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    }
}

function notion_request(method: string, url: string, token: string, body: string) -> string {
    let response = baml.http.send(
        baml.http.Request.from_url(url)
            .set_method(method)
            .set_headers(notion_headers(token))
            .set_body(body)
            .set_timeout(baml.time.Duration.from_seconds(30)),
    );
    let text = response.text();
    if (!response.ok()) {
        throw baml.errors.Io { message: `Notion ${method} failed (${response.status_code}): ${text}` }
    }
    text
}

function sync_card(dir: string, step: string, studio_url: string = "") -> string {
    let plan = read_plan(dir);
    let write = card_write(step, plan.slug, studio_url, plan.voice_id, plan.avatar_id);
    let token = notion_token();
    if (token == null) {
        return write.status;
    }
    let query = notion_request(
        "POST",
        "https://api.notion.com/v1/databases/a10ffad1-a332-46bc-8c0f-44c702779d92/query",
        token,
        `{"filter":{"property":"Slug","rich_text":{"equals":${baml.json.to_string(plan.slug)}}}}`,
    );
    let ids = notion_page_ids(query);
    if (ids.length() != 1) {
        throw baml.errors.InvalidArgument {
            message: `Slug ${plan.slug} must match one Hyperframes Genie card.`,
        }
    }
    let page = ids.at(0) ?? "";
    let _ = notion_request("PATCH", `https://api.notion.com/v1/pages/${page}`, token, notion_properties_body(write));
    write.status
}
