defmodule OpentelemetryLiveView do
  @moduledoc """
  OpentelemetryLiveView uses [telemetry](https://hexdocs.pm/telemetry/) handlers to create
  `OpenTelemetry` spans for LiveView *mount*, *handle_params*, and *handle_event*. The LiveView
  telemetry events that are used are documented [here](https://hexdocs.pm/phoenix_live_view/telemetry.html).

  ## Usage

  Add in your application start function a call to `setup/0`:

      def start(_type, _args) do
        # this register a tracer for your application
        OpenTelemetry.register_application_tracer(:my_app)

        # this configures the liveview tracing
        OpentelemetryLiveView.setup()

        children = [
          ...
        ]

        ...
      end

  """

  require OpenTelemetry.Tracer
  alias OpenTelemetry.Span
  alias OpentelemetryLiveView.Reason

  @tracer_id :opentelemetry_liveview

  @event_names [
                 {:live_view, :mount},
                 {:live_view, :handle_params},
                 {:live_view, :handle_event},
                 {:live_component, :handle_event}
               ]
               |> Enum.flat_map(fn {kind, callback_name} ->
                 Enum.map([:start, :stop, :exception], fn event_name ->
                   [:phoenix, kind, callback_name, event_name]
                 end)
               end)

  @doc """
  Initializes and configures the telemetry handlers.
  """
  @spec setup() :: :ok
  def setup do
    {:ok, otel_phx_vsn} = :application.get_key(@tracer_id, :vsn)
    OpenTelemetry.register_tracer(@tracer_id, otel_phx_vsn)

    :telemetry.attach_many(__MODULE__, @event_names, &process_event/4, %{})
  end

  defguardp is_liveview_kind(kind) when kind in [:live_view, :live_component]

  @doc false
  def process_event([:phoenix, kind, callback_name, :start], _measurements, meta, _config)
      when is_liveview_kind(kind) do
    module =
      case {kind, meta} do
        {:live_view, _} -> module_to_string(meta.socket.view)
        {:live_component, %{component: component}} -> module_to_string(component)
      end

    base_attributes = [
      "liveview.module": module,
      "liveview.callback": Atom.to_string(callback_name)
    ]

    attributes =
      Enum.reduce(meta, base_attributes, fn
        {:uri, uri}, acc ->
          Keyword.put(acc, :"liveview.uri", uri)

        {:component, component}, acc ->
          Keyword.put(acc, :"liveview.module", module_to_string(component))

        {:event, event}, acc ->
          Keyword.put(acc, :"liveview.event", event)

        _, acc ->
          acc
      end)

    span_name =
      case Keyword.fetch(attributes, :"liveview.event") do
        {:ok, event} -> "#{module}.#{event}"
        :error -> "#{module}.#{callback_name}"
      end

    OpentelemetryTelemetry.start_telemetry_span(@tracer_id, span_name, meta, %{kind: :internal})
    |> Span.set_attributes(attributes)
  end

  @doc false
  def process_event([:phoenix, kind, _kind, :stop], %{duration: duration}, meta, _config)
      when is_liveview_kind(kind) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    set_duration(ctx, duration)

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end

  @doc false
  def process_event(
        [:phoenix, :live_view, _kind, :exception],
        %{duration: duration},
        %{kind: kind, reason: reason, stacktrace: stacktrace} = meta,
        _config
      ) do
    ctx = OpentelemetryTelemetry.set_current_telemetry_span(@tracer_id, meta)

    set_duration(ctx, duration)

    {[reason: reason], attrs} = Reason.normalize(reason) |> Keyword.split([:reason])

    exception = Exception.normalize(kind, reason, stacktrace)
    message = Exception.message(exception)

    Span.record_exception(ctx, exception, stacktrace, attrs)
    Span.set_status(ctx, OpenTelemetry.status(:error, message))

    OpentelemetryTelemetry.end_telemetry_span(@tracer_id, meta)
  end

  defp set_duration(ctx, duration) do
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)
    Span.set_attribute(ctx, :duration_ms, duration_ms)
  end

  defp module_to_string(module) when is_atom(module) do
    case to_string(module) do
      "Elixir." <> name -> name
      erlang_module -> ":#{erlang_module}"
    end
  end
end
