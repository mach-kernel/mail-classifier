defmodule PursuitServices.Shapes.RawMessage do
  # @enforce_keys [:raw]
  defstruct [:raw]

  @type t :: %__MODULE__{raw: binary}

  use ExConstructor
end