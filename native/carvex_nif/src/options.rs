//! Options decoded from Elixir and their conversion into `carve::Options`.
//!
//! Extension option mapping ported from carve-py (MIT),
//! https://github.com/markup-carve/carve-py src/lib.rs `build_configured_extension`.

use carve::extensions::registry;
use carve::{
    AsciiHeadingIds, Autolink, AutolinkOptions, CarveExtension, CodeGroup, CodeGroupOptions,
    ContentMode, CrossrefStyle, ExternalLinks, ExternalLinksOptions, FencedRender,
    FencedRenderOptions, HeadingLevelShift, HeadingLevelShiftOptions, HeadingNumbers,
    HeadingNumbersOptions, HeadingPermalinks, HeadingPermalinksOptions, HeadingReference,
    HeadingReferenceOptions, ImgFence, ListType, MathBlock, MathBlockOptions, Mode, Options,
    Position, Profile, SmartTypographyMode, TableOfContents, TableOfContentsOptions, Tabs,
    TabsMode, TabsOptions, Wikilinks, WikilinksOptions,
};

use crate::engine::{NifError, invalid_option};

#[derive(NifUnitEnum, Clone, Copy)]
pub enum ModeEx {
    Interactive,
    Static,
}

#[derive(NifUnitEnum, Clone, Copy)]
pub enum ProfileEx {
    Full,
    Article,
    Comment,
    Minimal,
}

#[derive(NifUnitEnum, Clone, Copy)]
pub enum AsciiEx {
    Off,
    Fold,
    Strict,
}

#[derive(NifUnitEnum, Clone, Copy)]
pub enum SmartEx {
    Glyph,
    Source,
    QuotesSource,
}

#[derive(NifUnitEnum, Clone, Copy)]
pub enum TargetEx {
    Html,
    Markdown,
    PlainText,
    Ansi,
    Carve,
}

#[derive(NifUntaggedEnum, Clone)]
pub enum OptValue {
    Bool(bool),
    Int(i64),
    Str(String),
    Strs(Vec<String>),
    Ints(Vec<i64>),
}

pub type ExtensionSpec = (String, Vec<(String, OptValue)>);

#[derive(NifMap)]
pub struct CarveOptionsEx {
    pub extensions: Vec<ExtensionSpec>,
    pub safe: bool,
    pub profile: Option<ProfileEx>,
    pub profile_base_host: Option<String>,
    pub mode: ModeEx,
    pub sections: bool,
    pub source_lines: bool,
    pub positions: bool,
    pub lowercase_heading_ids: bool,
    pub ascii_heading_ids: AsciiEx,
    pub mention_url: Option<String>,
    pub tag_url: Option<String>,
    pub symbols: Vec<(String, String)>,
    pub smart_typography: SmartEx,
    pub align_tables: bool,
    pub lint_caption_hints: bool,
}

impl From<ModeEx> for Mode {
    fn from(mode: ModeEx) -> Self {
        match mode {
            ModeEx::Interactive => Mode::Interactive,
            ModeEx::Static => Mode::Static,
        }
    }
}

impl From<ProfileEx> for Profile {
    fn from(profile: ProfileEx) -> Self {
        match profile {
            ProfileEx::Full => Profile::full(),
            ProfileEx::Article => Profile::article(),
            ProfileEx::Comment => Profile::comment(),
            ProfileEx::Minimal => Profile::minimal(),
        }
    }
}

impl From<AsciiEx> for AsciiHeadingIds {
    fn from(ascii: AsciiEx) -> Self {
        match ascii {
            AsciiEx::Off => AsciiHeadingIds::Off,
            AsciiEx::Fold => AsciiHeadingIds::Fold,
            AsciiEx::Strict => AsciiHeadingIds::Strict,
        }
    }
}

impl From<SmartEx> for SmartTypographyMode {
    fn from(smart: SmartEx) -> Self {
        match smart {
            SmartEx::Glyph => SmartTypographyMode::Glyph,
            SmartEx::Source => SmartTypographyMode::Source,
            SmartEx::QuotesSource => SmartTypographyMode::QuotesSource,
        }
    }
}

/// An option value's conversion into an extension option field type.
trait FromOpt: Sized {
    fn from_opt(value: &OptValue) -> Option<Self>;
}

impl FromOpt for String {
    fn from_opt(value: &OptValue) -> Option<Self> {
        match value {
            OptValue::Str(s) => Some(s.clone()),
            _ => None,
        }
    }
}

impl FromOpt for bool {
    fn from_opt(value: &OptValue) -> Option<Self> {
        match value {
            OptValue::Bool(b) => Some(*b),
            _ => None,
        }
    }
}

impl FromOpt for u8 {
    fn from_opt(value: &OptValue) -> Option<Self> {
        match value {
            OptValue::Int(i) => u8::try_from(*i).ok(),
            _ => None,
        }
    }
}

impl FromOpt for Vec<String> {
    fn from_opt(value: &OptValue) -> Option<Self> {
        match value {
            OptValue::Strs(v) => Some(v.clone()),
            _ => None,
        }
    }
}

impl FromOpt for Vec<u8> {
    fn from_opt(value: &OptValue) -> Option<Self> {
        match value {
            OptValue::Ints(v) => v.iter().map(|i| u8::try_from(*i).ok()).collect(),
            OptValue::Strs(v) if v.is_empty() => Some(Vec::new()),
            _ => None,
        }
    }
}

/// One extension's option list, looked up by key.
struct Opts<'a> {
    extension: &'a str,
    pairs: &'a [(String, OptValue)],
}

impl Opts<'_> {
    fn check_keys(&self, accepted: &[&str]) -> Result<(), NifError> {
        match self
            .pairs
            .iter()
            .find(|(k, _)| !accepted.contains(&k.as_str()))
        {
            Some((key, _)) => Err(invalid_option(format!(
                "unknown option {key:?} for extension {:?} (accepted: {})",
                self.extension,
                accepted.join(", ")
            ))),
            None => Ok(()),
        }
    }

    fn raw(&self, key: &str) -> Option<&OptValue> {
        self.pairs
            .iter()
            .rev()
            .find(|(k, _)| k == key)
            .map(|(_, v)| v)
    }

    fn get<T: FromOpt>(&self, key: &str) -> Result<Option<T>, NifError> {
        self.raw(key)
            .map(|value| {
                T::from_opt(value).ok_or_else(|| {
                    invalid_option(format!(
                        "option {key:?} for extension {:?} has the wrong type",
                        self.extension
                    ))
                })
            })
            .transpose()
    }

    fn set<T: FromOpt>(&self, key: &str, field: &mut T) -> Result<(), NifError> {
        if let Some(value) = self.get(key)? {
            *field = value;
        }
        Ok(())
    }

    fn enum_value<T: Copy>(&self, key: &str, values: &[(&str, T)]) -> Result<Option<T>, NifError> {
        let Some(value) = self.get::<String>(key)? else {
            return Ok(None);
        };
        values
            .iter()
            .find(|(name, _)| *name == value)
            .map(|(_, v)| Some(*v))
            .ok_or_else(|| {
                invalid_option(format!(
                    "unknown value {value:?} for option {key:?} of extension {:?} (accepted: {})",
                    self.extension,
                    values
                        .iter()
                        .map(|(n, _)| *n)
                        .collect::<Vec<_>>()
                        .join(", ")
                ))
            })
    }
}

/// Builds the boxed extensions for `spec`. Names arrive in registry (kebab) spelling.
pub fn build_extensions(spec: &[ExtensionSpec]) -> Result<Vec<Box<dyn CarveExtension>>, NifError> {
    spec.iter()
        .map(|(name, pairs)| build_extension(name, pairs))
        .collect()
}

fn build_extension(
    key: &str,
    pairs: &[(String, OptValue)],
) -> Result<Box<dyn CarveExtension>, NifError> {
    let Some(default) = registry::by_key(key) else {
        return Err(invalid_option(format!("unknown carve extension: {key}")));
    };
    if pairs.is_empty() {
        return Ok(default);
    }
    let o = Opts {
        extension: key,
        pairs,
    };
    macro_rules! configured {
        ($ty:ty, $ctor:path, [$($field:ident),* $(,)?]) => {{
            o.check_keys(&[$(stringify!($field)),*])?;
            let mut opts = <$ty>::default();
            $(o.set(stringify!($field), &mut opts.$field)?;)*
            Ok(Box::new($ctor(opts)) as Box<dyn CarveExtension>)
        }};
    }
    match key {
        "autolink" => configured!(AutolinkOptions, Autolink::with_options, [allowed_schemes]),
        "code-group" => configured!(
            CodeGroupOptions,
            CodeGroup::with_options,
            [
                wrapper_class,
                panel_class,
                label_class,
                radio_class,
                id_prefix
            ]
        ),
        "external-links" => configured!(
            ExternalLinksOptions,
            ExternalLinks::with_options,
            [target, rel, nofollow]
        ),
        "heading-level-shift" => configured!(
            HeadingLevelShiftOptions,
            HeadingLevelShift::with_options,
            [shift]
        ),
        "heading-permalinks" => configured!(
            HeadingPermalinksOptions,
            HeadingPermalinks::with_options,
            [
                symbol,
                css_class,
                aria_label,
                levels,
                prepend,
                show_on_hover,
                copy_to_clipboard,
                lowercase_ids
            ]
        ),
        "heading-reference" => configured!(
            HeadingReferenceOptions,
            HeadingReference::with_options,
            [css_class]
        ),
        "math-block" => configured!(MathBlockOptions, MathBlock::with_options, [language]),
        "wikilinks" => configured!(
            WikilinksOptions,
            Wikilinks::with_options,
            [css_class, new_window]
        ),
        "heading-numbers" => {
            o.check_keys(&["min_level", "label", "crossref"])?;
            let mut opts = HeadingNumbersOptions::default();
            o.set("min_level", &mut opts.min_level)?;
            o.set("label", &mut opts.label)?;
            if let Some(v) = o.enum_value(
                "crossref",
                &[
                    ("number", CrossrefStyle::Number),
                    ("number-title", CrossrefStyle::NumberTitle),
                    ("title", CrossrefStyle::Title),
                ],
            )? {
                opts.crossref = v;
            }
            Ok(Box::new(HeadingNumbers::with_options(opts)))
        }
        "table-of-contents" => {
            o.check_keys(&[
                "min_level",
                "max_level",
                "list_type",
                "css_class",
                "position",
                "lowercase_ids",
            ])?;
            let mut opts = TableOfContentsOptions::default();
            o.set("min_level", &mut opts.min_level)?;
            o.set("max_level", &mut opts.max_level)?;
            o.set("css_class", &mut opts.css_class)?;
            o.set("lowercase_ids", &mut opts.lowercase_ids)?;
            if let Some(v) =
                o.enum_value("list_type", &[("ul", ListType::Ul), ("ol", ListType::Ol)])?
            {
                opts.list_type = v;
            }
            if let Some(v) = o.enum_value(
                "position",
                &[("top", Position::Top), ("bottom", Position::Bottom)],
            )? {
                opts.position = v;
            }
            Ok(Box::new(TableOfContents::with_options(opts)))
        }
        "tabs" => {
            o.check_keys(&[
                "mode",
                "wrapper_class",
                "tab_class",
                "label_class",
                "radio_class",
                "id_prefix",
            ])?;
            let mut opts = TabsOptions::default();
            o.set("wrapper_class", &mut opts.wrapper_class)?;
            o.set("tab_class", &mut opts.tab_class)?;
            o.set("label_class", &mut opts.label_class)?;
            o.set("radio_class", &mut opts.radio_class)?;
            o.set("id_prefix", &mut opts.id_prefix)?;
            if let Some(v) =
                o.enum_value("mode", &[("css", TabsMode::Css), ("aria", TabsMode::Aria)])?
            {
                opts.mode = v;
            }
            Ok(Box::new(Tabs::with_options(opts)))
        }
        "fenced-render" => {
            o.check_keys(&[
                "languages",
                "css_class",
                "tag",
                "content_mode",
                "wrap_in_figure",
                "figure_class",
            ])?;
            let mode = o
                .enum_value(
                    "content_mode",
                    &[("text", ContentMode::Text), ("json", ContentMode::Json)],
                )?
                .unwrap_or(ContentMode::Text);
            // Use the engine's constructor: it fills in `css_class`, `tag` and
            // `figure_class` from the options given, so set the rest afterwards.
            let languages = o
                .get::<Vec<String>>("languages")?
                .unwrap_or_else(|| vec!["mermaid".into()]);
            let mut opts =
                FencedRenderOptions::new(languages, o.get("css_class")?, o.get("tag")?, mode);
            o.set("wrap_in_figure", &mut opts.wrap_in_figure)?;
            o.set("figure_class", &mut opts.figure_class)?;
            Ok(Box::new(FencedRender::with_options(opts)))
        }
        "img-fence" => {
            o.check_keys(&[
                "allow_style",
                "allow_links",
                "allow_animation",
                "allow_external_images",
            ])?;
            let flag = |k: &str| -> Result<bool, NifError> { Ok(o.get(k)?.unwrap_or(false)) };
            Ok(Box::new(
                ImgFence::new()
                    .allow_style(flag("allow_style")?)
                    .allow_links(flag("allow_links")?)
                    .allow_animation(flag("allow_animation")?)
                    .allow_external_images(flag("allow_external_images")?),
            ))
        }
        _ => Err(invalid_option(format!("extension {key} takes no options"))),
    }
}

/// Runs `f` with `carve::Options` built from `spec`. The boxed extensions live in
/// this frame, outliving the `Options<'_>` that borrows them.
pub fn with_options<T>(
    spec: &CarveOptionsEx,
    f: impl FnOnce(&Options<'_>) -> Result<T, NifError>,
) -> Result<T, NifError> {
    let extensions = build_extensions(&spec.extensions)?;
    let mut options = Options::new()
        .with_mode(spec.mode.into())
        .with_sections(spec.sections)
        .with_source_lines(spec.source_lines)
        .with_positions(spec.positions)
        .with_lowercase_heading_ids(spec.lowercase_heading_ids)
        .with_ascii_heading_ids(spec.ascii_heading_ids.into())
        .with_raw_html(!spec.safe)
        .with_align_tables(spec.align_tables);
    for ext in &extensions {
        options = options.with_extension(ext.as_ref());
    }
    for (name, value) in &spec.symbols {
        options = options.with_symbol(name.clone(), value.clone());
    }
    if let Some(url) = &spec.mention_url {
        options = options.with_mention_url(url.clone());
    }
    if let Some(url) = &spec.tag_url {
        options = options.with_tag_url(url.clone());
    }
    if let Some(host) = &spec.profile_base_host {
        options = options.with_profile_base_host(host.clone());
    }
    if let Some(profile) = spec.profile {
        options = options.with_profile(profile.into());
    }
    options.smart_typography = spec.smart_typography.into();
    options.lint_caption_looking_paragraph = spec.lint_caption_hints;
    f(&options)
}
