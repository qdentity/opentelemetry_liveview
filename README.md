# OpentelemetryLiveView
![Build Status](https://github.com/qdentity/opentelemetry_liveview/workflows/Tests/badge.svg)

Telemetry handler that creates Opentelemetry spans from Phoenix LiveView events.

After installing, setup the handler in your application behaviour before your
top-level supervisor starts.

```elixir
OpentelemetryLiveView.setup()
```

## Installation

```elixir
def deps do
  [
    {:opentelemetry_liveview, "~> 1.0.0-rc"}
  ]
end
```

## Acknowledgements

See https://github.com/opentelemetry-beam/opentelemetry_phoenix for tracing Phoenix web requests.
The code and tests in this repository are based on that library.
