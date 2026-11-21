#[macro_use]
extern crate rustler;

mod engine;
mod highlight;
mod options;
mod sanitize;

use carve::{CarveWriterOptions, Mode};

use crate::engine::{NifError, isolated};
use crate::highlight::SyntectOptions;
use crate::options::{CarveOptionsEx, TargetEx, with_options};
use crate::sanitize::SanitizeOptions;

// `Result<T, NifError>` returns encode as `{:ok, t} | {:error, {kind, message}}`;
// `Result<T, String>` as `{:ok, t} | {:error, message}`.

#[derive(NifStruct)]
#[module = "Carvex.LintWarning"]
struct LintWarningEx {
    line: usize,
    column: usize,
    rule: String,
    message: String,
    start_offset: usize,
    end_offset: usize,
}

#[nif(schedule = "DirtyCpu")]
fn parse(source: &str, options: CarveOptionsEx) -> Result<String, NifError> {
    isolated(|| {
        with_options(&options, |o| {
            carve::try_to_json(&carve::parse_with_options(source, o)).map_err(engine::ast)
        })
    })
}

#[nif(schedule = "DirtyCpu")]
fn render_source(
    source: &str,
    target: TargetEx,
    options: CarveOptionsEx,
) -> Result<String, NifError> {
    isolated(|| {
        with_options(&options, |o| match target {
            TargetEx::Html => carve::try_to_html_with_options(source, o).map_err(engine::profile),
            TargetEx::Markdown => {
                carve::try_to_markdown_with_options(source, o).map_err(engine::write)
            }
            TargetEx::PlainText => {
                carve::try_to_plain_text_with_options(source, o).map_err(engine::profile)
            }
            TargetEx::Ansi => carve::try_to_ansi_with_options(source, o).map_err(engine::profile),
            TargetEx::Carve => carve::try_to_carve_with_options(source, o).map_err(engine::write),
        })
    })
}

#[nif(schedule = "DirtyCpu")]
fn render_json(json: &str, target: TargetEx, options: CarveOptionsEx) -> Result<String, NifError> {
    isolated(|| {
        with_options(&options, |o| {
            let doc = carve::from_json(json).map_err(engine::ast)?;
            if let TargetEx::Carve = target {
                let doc = match &o.profile {
                    Some(profile) => {
                        carve::apply_profile_with_typography(
                            doc,
                            profile,
                            o.profile_base_host.as_deref(),
                            o.smart_typography,
                        )
                        .map_err(engine::profile)?
                        .doc
                    }
                    None => doc,
                };
                let writer = CarveWriterOptions::default().with_align_tables(o.align_tables);
                return carve::render_carve_with_options(&doc, &writer).map_err(engine::render);
            }
            let is_html = matches!(target, TargetEx::Html);
            let mode = if is_html { o.mode } else { Mode::Interactive };
            // Extension `before_render` hooks and the profile; without this an
            // edited document would silently skip both.
            let doc = carve::prepare_document_for_render(doc, o, mode, is_html)
                .map_err(engine::profile)?;
            match target {
                TargetEx::Html => {
                    carve::render_html_owned_with_options(doc, o).map_err(engine::render)
                }
                TargetEx::Markdown => {
                    carve::render_markdown_with_options(&doc, o).map_err(engine::render)
                }
                TargetEx::PlainText => {
                    carve::render_plain_text_with_options(&doc, o).map_err(engine::render)
                }
                TargetEx::Ansi => carve::render_ansi_with_options(&doc, o).map_err(engine::render),
                TargetEx::Carve => unreachable!("handled above"),
            }
        })
    })
}

#[nif(schedule = "DirtyCpu")]
fn lint(source: &str, options: CarveOptionsEx) -> Result<Vec<LintWarningEx>, NifError> {
    isolated(|| {
        with_options(&options, |o| {
            Ok(carve::lint_carve_with_options(source, o)
                .into_iter()
                .map(|w| LintWarningEx {
                    line: w.line,
                    column: w.column,
                    rule: w.rule.to_string(),
                    message: w.message,
                    start_offset: w.start,
                    end_offset: w.end,
                })
                .collect())
        })
    })
}

#[nif]
fn extensions() -> Vec<String> {
    carve::extensions::registry::keys()
        .map(str::to_string)
        .collect()
}

#[nif(schedule = "DirtyCpu")]
fn safe_html(
    html: &str,
    sanitize: Option<SanitizeOptions>,
    escape: bool,
) -> Result<String, String> {
    let html = match &sanitize {
        Some(s) => sanitize::clean(html, s)?,
        None => html.to_string(),
    };
    Ok(if escape {
        sanitize::escape_html(&html)
    } else {
        html
    })
}

#[nif(schedule = "DirtyCpu")]
fn syntect_highlight(
    source: &str,
    language: &str,
    options: SyntectOptions,
) -> Result<String, String> {
    highlight::highlight(source, language, &options)
}

#[nif]
fn syntect_themes() -> Vec<String> {
    highlight::theme_names()
}

rustler::init!("Elixir.Carvex.Native");
