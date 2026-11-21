# Changelog

## Unreleased

### Changed

- With `safe: true` or a `profile:` set, HTML rendering of a document that still
  holds `Carvex.Raw` after plugin steps now fails with
  `%Carvex.CarveError{reason: :raw_not_allowed}` instead of emitting the HTML
  verbatim. Pass `render: [allow_raw: true]` if every plugin emitting
  `Carvex.Raw` is trusted. Syntax-highlighted code is unaffected.

### Added

- `render: [allow_raw: boolean]` option (default `false`).
