defmodule Carvex.CarveError do
  @moduledoc """
  Raised (or returned) when parsing, rendering, sanitizing, or highlighting a Carve document fails.

  `reason` holds the underlying cause. Engine failures are `{kind, message}` where
  `kind` is one of `:profile_violation`, `:invalid_ast`, `:render`, `:invalid_option`
  or `:panic`; other reasons include `{:highlight, error}`, `{:invalid_node, term}`,
  `{:unknown_ast_type, type}`, `{:unknown_ast_field, type, key}` and `:raw_not_allowed`.
  """

  defexception [:reason, message: "An error occurred transforming the Carve document"]

  @type t :: %__MODULE__{reason: term(), message: String.t()}

  @doc false
  @spec native({atom(), String.t()}) :: t()
  def native({kind, msg} = reason),
    do: %__MODULE__{reason: reason, message: "carve #{kind}: #{msg}"}
end
