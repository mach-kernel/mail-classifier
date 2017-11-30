defmodule PursuitServices.Shapes.GmailMessage do
  # @enforce_keys [:id, :threadId]

  defstruct [
    :body,
    :filename,
    :headers,
    :historyId,
    :id,
    :internalDate,
    :labelIds,
    :mimeType,
    :name,
    :partId,
    :parts,
    :payload,
    :raw,
    :sizeEstimate,
    :snippet,
    :threadId,
    :value
  ]

  use ExConstructor
end