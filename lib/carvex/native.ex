defmodule Carvex.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release
  github_url = Mix.Project.config()[:package][:links][:GitHub]

  force_build = System.get_env("CARVEX_BUILD") in ~w[1 true] || Mix.env() in [:dev, :test]

  use RustlerPrecompiled,
    otp_app: :carvex,
    crate: "carvex_nif",
    base_url: "#{github_url}/releases/download/v#{version}",
    force_build: force_build,
    mode: mode,
    # RustlerPrecompiled's default targets (0.10 includes aarch64-unknown-linux-musl);
    # keep in sync with the release matrix in .github/release.pkl.
    version: version

  def parse(_source, _options), do: :erlang.nif_error(:nif_not_loaded)
  def render_source(_source, _target, _options), do: :erlang.nif_error(:nif_not_loaded)
  def render_json(_json, _target, _options), do: :erlang.nif_error(:nif_not_loaded)
  def lint(_source, _options), do: :erlang.nif_error(:nif_not_loaded)
  def extensions, do: :erlang.nif_error(:nif_not_loaded)
  def safe_html(_html, _sanitize, _escape), do: :erlang.nif_error(:nif_not_loaded)
  def syntect_highlight(_source, _language, _options), do: :erlang.nif_error(:nif_not_loaded)
  def syntect_themes, do: :erlang.nif_error(:nif_not_loaded)
end
