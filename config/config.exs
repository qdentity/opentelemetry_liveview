import Config

if config_env() == :test do
  config :opentelemetry, processors: [{:otel_batch_processor, %{scheduled_delay_ms: 1}}]
end
