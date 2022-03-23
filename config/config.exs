import Config

if config_env() == :test do
  config :opentelemetry, processors: [{:ot_batch_processor, %{scheduled_delay_ms: 1}}]
end
