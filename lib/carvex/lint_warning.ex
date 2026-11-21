defmodule Carvex.LintWarning do
  @moduledoc """
  A diagnostic returned by `Carvex.lint/2`.

  `line` and `column` are 1-based. `start_offset` and `end_offset` are 0-based
  UTF-8 **byte** offsets into the linted source, end exclusive, so the flagged
  text is `binary_part(source, w.start_offset, w.end_offset - w.start_offset)`.
  `rule` is carve-rs's stable rule id, e.g. `"unattached-block-attribute"`.
  """

  defstruct [:line, :column, :rule, :message, :start_offset, :end_offset]

  @type t :: %__MODULE__{
          line: pos_integer(),
          column: pos_integer(),
          rule: String.t(),
          message: String.t(),
          start_offset: non_neg_integer(),
          end_offset: non_neg_integer()
        }
end
