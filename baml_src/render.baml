// Turn a Film into HyperFrames HTML. No model calls.

function html_escape(value: string) -> string {
    value.replace_all("&", "&amp;").replace_all("<", "&lt;").replace_all(">", "&gt;").replace_all(
        "\"",
        "&quot;",
    )
}

function to_tenths(n: float) -> int {
    (n * 10.0).round().ifloor()
}

function format_tenths(tenths: int) -> string {
    let whole = tenths / 10;
    let frac = tenths % 10;
    `${whole}.${frac}`
}

// `type` is a BAML keyword, so the HyperFrames variable schema is built as JSON text.
function variable_decl(id: string, kind: string, label: string, default: string) -> string {
    let i = baml.json.to_string(id);
    let k = baml.json.to_string(kind);
    let l = baml.json.to_string(label);
    let d = baml.json.to_string(default);
    `{"id":${i},"type":${k},"label":${l},"default":${d}}`
}

function variable_decls(beat: Beat, palette: Palette) -> string {
    let decls = [
        variable_decl("eyebrow", "string", "Eyebrow", beat.eyebrow),
        variable_decl("headline", "string", "Headline", beat.headline),
        variable_decl("body", "string", "Body", beat.body),
        variable_decl("ground", "color", "Ground", palette.ground),
        variable_decl("ink", "color", "Ink", palette.ink),
        variable_decl("accent", "color", "Accent", palette.accent),
    ];
    html_escape(`[${decls.join(",")}]`)
}

function variable_values(beat: Beat, palette: Palette) -> string {
    let values: map<string, string> = {};
    let _e = values.set("eyebrow", beat.eyebrow);
    let _h = values.set("headline", beat.headline);
    let _b = values.set("body", beat.body);
    let _g = values.set("ground", palette.ground);
    let _i = values.set("ink", palette.ink);
    let _a = values.set("accent", palette.accent);
    html_escape(baml.json.to_string(values))
}

function card_html(beat: Beat, palette: Palette, width: int, height: int) -> string {
    let id = beat.id;
    let tenths = to_tenths(beat.seconds);
    let slot = format_tenths(tenths);
    // End the clip one tenth early so the last frame is inside the slot.
    let clip = format_tenths(tenths - 1);
    let rule = format_tenths(tenths - 8);
    let headline = if (width >= 1600) {
        88
    } else {
        64
    };
    let decls = variable_decls(beat, palette);
    `
        <template>
          <style>
            #root {
              position: absolute;
              inset: 0;
              background: var(--ground, ${palette.ground});
              color: var(--ink, ${palette.ink});
              font-family: Inter, sans-serif;
            }
            #${id}-stage {
              position: absolute;
              inset: 10%;
            }
            #${id}-copy {
              width: 100%;
              height: 100%;
              display: flex;
              flex-direction: column;
              justify-content: flex-end;
              gap: 28px;
            }
            #${id}-eyebrow {
              margin: 0;
              opacity: 0;
              font-size: 28px;
              font-weight: 600;
              letter-spacing: 0.14em;
              text-transform: uppercase;
            }
            #${id}-headline {
              margin: 0;
              max-width: 16ch;
              font-size: ${headline}px;
              font-weight: 600;
              letter-spacing: -0.035em;
              line-height: 0.98;
            }
            #${id}-body {
              margin: 0;
              max-width: 28ch;
              opacity: 0;
              font-size: 32px;
              font-weight: 400;
              line-height: 1.35;
            }
            #${id}-rule {
              width: 100%;
              height: 8px;
              background: var(--accent, ${palette.accent});
            }
          </style>
          <div
            id="root"
            data-composition-id="${id}"
            data-width="${width}"
            data-height="${height}"
            data-composition-variables="${decls}"
          >
            <div id="${id}-stage" class="clip" data-start="0" data-duration="${clip}" data-track-index="1">
              <div id="${id}-copy">
                <p id="${id}-eyebrow" data-var-text="eyebrow">${html_escape(beat.eyebrow)}</p>
                <h1 id="${id}-headline" data-var-text="headline">${html_escape(beat.headline)}</h1>
                <p id="${id}-body" data-var-text="body">${html_escape(beat.body)}</p>
                <div id="${id}-rule"></div>
              </div>
            </div>
          </div>
          <script>
            const tl = gsap.timeline({ paused: true });
            tl.fromTo("#${id}-headline", { y: 18 }, { y: 0, duration: 0.7, ease: "power4.out" }, 0);
            tl.fromTo("#${id}-eyebrow", { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.4, ease: "power3.out" }, 0.15);
            tl.fromTo("#${id}-body", { opacity: 0, y: 16 }, { opacity: 1, y: 0, duration: 0.5, ease: "power2.out" }, 0.45);
            tl.fromTo("#${id}-rule", { scaleX: 0 }, { scaleX: 1, duration: ${rule}, ease: "power1.inOut", transformOrigin: "0% 50%" }, 0);
            window.__timelines["${id}"] = tl;
          </script>
        </template>
    `
}

// The pipeline beat is a diagram: silent still, then HeyGen voice, then lip-sync.
function pipeline_html(beat: Beat, palette: Palette, width: int, height: int) -> string {
    let id = beat.id;
    let tenths = to_tenths(beat.seconds);
    let clip = format_tenths(tenths - 1);
    let decls = variable_decls(beat, palette);
    let headline = if (width >= 1600) {
        72
    } else {
        56
    };
    `
        <template>
          <style>
            #root {
              position: absolute;
              inset: 0;
              background: var(--ground, ${palette.ground});
              color: var(--ink, ${palette.ink});
              font-family: Inter, sans-serif;
            }
            #${id}-stage { position: absolute; inset: 10%; }
            #${id}-copy { display: flex; flex-direction: column; gap: 28px; height: 100%; }
            #${id}-eyebrow {
              margin: 0;
              font-size: 28px;
              font-weight: 600;
              letter-spacing: 0.14em;
              text-transform: uppercase;
            }
            #${id}-headline {
              margin: 0;
              max-width: 16ch;
              font-size: ${headline}px;
              font-weight: 600;
              letter-spacing: -0.035em;
              line-height: 0.98;
            }
            #${id}-steps { display: flex; gap: 28px; margin-top: 12px; }
            #${id}-steps article {
              flex: 1;
              border-top: 8px solid var(--accent, ${palette.accent});
              padding-top: 20px;
            }
            #${id}-steps p { margin: 0; font-size: 28px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; }
            #${id}-steps h2 { margin: 12px 0 0; font-size: 40px; font-weight: 600; letter-spacing: -0.03em; }
            #${id}-step-2, #${id}-step-3 { opacity: 0; }
            #${id}-body { margin: 0; max-width: 36ch; font-size: 32px; line-height: 1.35; }
          </style>
          <div id="root" data-composition-id="${id}" data-width="${width}" data-height="${height}" data-composition-variables="${decls}">
            <div id="${id}-stage" class="clip" data-start="0" data-duration="${clip}" data-track-index="1">
              <div id="${id}-copy">
                <p id="${id}-eyebrow" data-var-text="eyebrow">${html_escape(beat.eyebrow)}</p>
                <h1 id="${id}-headline" data-var-text="headline">${html_escape(beat.headline)}</h1>
                <div id="${id}-steps">
                  <article id="${id}-step-1"><p>01</p><h2>Silent still</h2></article>
                  <article id="${id}-step-2"><p>02</p><h2>HeyGen voice</h2></article>
                  <article id="${id}-step-3"><p>03</p><h2>Lip-sync</h2></article>
                </div>
                <p id="${id}-body" data-var-text="body">${html_escape(beat.body)}</p>
              </div>
            </div>
          </div>
          <script>
            const tl = gsap.timeline({ paused: true });
            tl.fromTo("#${id}-step-2", { opacity: 0, y: 16 }, { opacity: 1, y: 0, duration: 0.45, ease: "power2.out" }, 0.35);
            tl.fromTo("#${id}-step-3", { opacity: 0, y: 16 }, { opacity: 1, y: 0, duration: 0.45, ease: "power2.out" }, 0.7);
            window.__timelines["${id}"] = tl;
          </script>
        </template>
    `
}

// The studio beat shows a still of HyperFrames Studio beside the refine hint.
function studio_html(beat: Beat, palette: Palette, width: int, height: int) -> string {
    let id = beat.id;
    let tenths = to_tenths(beat.seconds);
    let clip = format_tenths(tenths - 1);
    let decls = variable_decls(beat, palette);
    let headline = if (width >= 1600) {
        72
    } else {
        56
    };
    `
        <template>
          <style>
            #root {
              position: absolute;
              inset: 0;
              background: var(--ground, ${palette.ground});
              color: var(--ink, ${palette.ink});
              font-family: Inter, sans-serif;
            }
            #${id}-stage { position: absolute; inset: 8% 6%; display: flex; gap: 48px; align-items: center; }
            #${id}-copy { flex: 1; display: flex; flex-direction: column; gap: 28px; }
            #${id}-eyebrow {
              margin: 0;
              font-size: 28px;
              font-weight: 600;
              letter-spacing: 0.14em;
              text-transform: uppercase;
            }
            #${id}-headline {
              margin: 0;
              max-width: 12ch;
              font-size: ${headline}px;
              font-weight: 600;
              letter-spacing: -0.035em;
              line-height: 0.98;
            }
            #${id}-body { margin: 0; max-width: 22ch; font-size: 32px; line-height: 1.35; }
            #${id}-rule { width: 100%; height: 8px; background: var(--accent, ${palette.accent}); transform: scaleX(0); transform-origin: 0% 50%; }
            #${id}-still {
              width: 52%;
              height: 78%;
              object-fit: cover;
              object-position: left center;
              border: 8px solid var(--accent, ${palette.accent});
            }
          </style>
          <div id="root" data-composition-id="${id}" data-width="${width}" data-height="${height}" data-composition-variables="${decls}">
            <div id="${id}-stage" class="clip" data-start="0" data-duration="${clip}" data-track-index="1">
              <div id="${id}-copy">
                <p id="${id}-eyebrow" data-var-text="eyebrow">${html_escape(beat.eyebrow)}</p>
                <h1 id="${id}-headline" data-var-text="headline">${html_escape(beat.headline)}</h1>
                <p id="${id}-body" data-var-text="body">${html_escape(beat.body)}</p>
                <div id="${id}-rule"></div>
              </div>
              <img id="${id}-still" src="assets/studio.png" alt="" />
            </div>
          </div>
          <script>
            const tl = gsap.timeline({ paused: true });
            tl.fromTo("#${id}-rule", { scaleX: 0 }, { scaleX: 1, duration: 1.2, ease: "power1.inOut" }, 0.2);
            window.__timelines["${id}"] = tl;
          </script>
        </template>
    `
}

function scene_html(beat: Beat, palette: Palette, width: int, height: int) -> string {
    if (beat.id == "pipeline") {
        pipeline_html(beat, palette, width, height)
    } else if (beat.id == "studio") {
        studio_html(beat, palette, width, height)
    } else {
        card_html(beat, palette, width, height)
    }
}

function scene_src(number: int, id: string) -> string {
    `compositions/${number}-${id}.html`
}

function scene_host(
    beat: Beat,
    palette: Palette,
    start: int,
    width: int,
    height: int,
    number: int,
) -> string {
    let slot = format_tenths(to_tenths(beat.seconds));
    let begin = format_tenths(start);
    let values = variable_values(beat, palette);
    let src = scene_src(number, beat.id);
    `
        <div
          id="${beat.id}"
          data-composition-id="${beat.id}"
          data-composition-src="${src}"
          data-start="${begin}"
          data-duration="${slot}"
          data-track-index="1"
          data-track-kind="graphics"
          data-width="${width}"
          data-height="${height}"
          data-variable-values="${values}"
        ></div>
    `
}

function index_html(film: Film) -> string {
    //# Mount one scene host per beat on a single paused timeline
    let hosts: string[] = [];
    let cursor = 0;
    let number = 1;
    for (let beat in film.beats) {
        hosts.push(scene_host(beat, film.palette, cursor, film.width, film.height, number));
        cursor = cursor + to_tenths(beat.seconds);
        number = number + 1;
    }
    let duration = format_tenths(cursor);
    let title = html_escape(film.title);
    `
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="UTF-8" />
            <meta name="viewport" content="width=${film.width}, height=${film.height}" />
            <title>${title}</title>
            <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              html, body {
                margin: 0;
                width: ${film.width}px;
                height: ${film.height}px;
                overflow: hidden;
                background: ${film.palette.ground};
                font-family: Inter, sans-serif;
              }
            </style>
          </head>
          <body>
            <div
              id="root"
              data-composition-id="main"
              data-start="0"
              data-duration="${duration}"
              data-width="${film.width}"
              data-height="${film.height}"
            >
              ${hosts.join("")}
            </div>
            <script>
              const tl = gsap.timeline({ paused: true });
              window.__timelines["main"] = tl;
            </script>
          </body>
        </html>
    `
}

function render_project(film: Film) -> map<string, string> {
    let files: map<string, string> = {};
    let _index = files.set("index.html", index_html(film));
    let number = 1;
    for (let beat in film.beats) {
        let _file = files.set(
            scene_src(number, beat.id),
            scene_html(beat, film.palette, film.width, film.height),
        );
        number = number + 1;
    }
    files
}
