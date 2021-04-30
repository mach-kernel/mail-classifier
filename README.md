# mail-classifier

Mail classification OTP actors. Grabs a stream of messages and transforms them into tuples of (message for label a, message for label b) before feedinng them into a naive bayes classifier.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pursuit_services` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pursuit_services, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pursuit_services](https://hexdocs.pm/pursuit_services).

