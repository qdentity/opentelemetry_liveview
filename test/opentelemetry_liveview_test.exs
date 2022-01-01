defmodule OpentelemetryLiveViewTest do
  use ExUnit.Case, async: false

  # require OpenTelemetry.Tracer
  # require OpenTelemetry.Span
  require Record

  # alias PhoenixMeta, as: Meta

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry/include/otel_span.hrl") do
    Record.defrecord(name, spec)
  end

  for {name, spec} <- Record.extract_all(from_lib: "opentelemetry_api/include/opentelemetry.hrl") do
    Record.defrecord(name, spec)
  end

  setup do
    :application.stop(:opentelemetry)
    :application.set_env(:opentelemetry, :tracer, :otel_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

    OpentelemetryLiveView.setup()

    :ok
  end

  @meta %{socket: %{view: SomeWeb.SomeLive}}

  @bad_key_error %{
    kind: :error,
    reason: {:badkey, :name, %{username: "foobar"}},
    stacktrace: [
      {MyStore.Users, :sort_by_name, 2, [file: 'lib/my_store/users.ex', line: 159]},
      {Enum, :"-to_sort_fun/1-fun-0-", 3, [file: 'lib/enum.ex', line: 2542]},
      {:lists, :sort, 2, [file: 'lists.erl', line: 969]}
    ]
  }

  test "records spans for the mount callback" do
    :telemetry.execute(
      [:phoenix, :live_view, :mount, :start],
      %{system_time: System.system_time()},
      @meta
    )

    :telemetry.execute(
      [:phoenix, :live_view, :mount, :stop],
      %{duration: System.convert_time_unit(42, :millisecond, :native)},
      @meta
    )

    assert_receive {:span,
                    span(
                      name: "SomeWeb.SomeLive.mount",
                      kind: :internal,
                      attributes: attributes
                    ) = span}

    assert :otel_attributes.map(attributes) == %{
             duration_ms: 42,
             "liveview.callback": "mount",
             "liveview.module": "SomeWeb.SomeLive"
           }

    assert_instrumentation_library(span)
  end

  test "records exceptions for the mount callback" do
    :telemetry.execute(
      [:phoenix, :live_view, :mount, :start],
      %{system_time: System.system_time()},
      @meta
    )

    :telemetry.execute(
      [:phoenix, :live_view, :mount, :exception],
      %{duration: System.convert_time_unit(42, :millisecond, :native)},
      Map.merge(@meta, @bad_key_error)
    )

    {span, attributes} = assert_receive_bad_key_error_span("SomeWeb.SomeLive.mount")

    assert :otel_attributes.map(attributes) == %{
             duration_ms: 42,
             "liveview.callback": "mount",
             "liveview.module": "SomeWeb.SomeLive"
           }

    assert_instrumentation_library(span)
  end

  test "records spans for the handle_params callback" do
    meta = Map.put(@meta, :uri, "https://foobar.com")

    :telemetry.execute(
      [:phoenix, :live_view, :handle_params, :start],
      %{system_time: System.system_time()},
      meta
    )

    :telemetry.execute(
      [:phoenix, :live_view, :handle_params, :stop],
      %{duration: System.convert_time_unit(42, :millisecond, :native)},
      meta
    )

    assert_receive {:span,
                    span(
                      name: "SomeWeb.SomeLive.handle_params",
                      kind: :internal,
                      attributes: attributes
                    ) = span}

    assert :otel_attributes.map(attributes) == %{
             duration_ms: 42,
             "liveview.callback": "handle_params",
             "liveview.module": "SomeWeb.SomeLive",
             "liveview.uri": "https://foobar.com"
           }

    assert_instrumentation_library(span)
  end

  test "records exceptions for the handle_params callback" do
    meta = Map.put(@meta, :uri, "https://foobar.com")

    :telemetry.execute(
      [:phoenix, :live_view, :handle_params, :start],
      %{system_time: System.system_time()},
      meta
    )

    :telemetry.execute(
      [:phoenix, :live_view, :handle_params, :exception],
      %{duration: System.convert_time_unit(42, :millisecond, :native)},
      Map.merge(meta, @bad_key_error)
    )

    {span, attributes} = assert_receive_bad_key_error_span("SomeWeb.SomeLive.handle_params")

    assert :otel_attributes.map(attributes) == %{
             duration_ms: 42,
             "liveview.callback": "handle_params",
             "liveview.module": "SomeWeb.SomeLive",
             "liveview.uri": "https://foobar.com"
           }

    assert_instrumentation_library(span)
  end

  test "records spans for the handle_event callback" do
    meta = Map.put(@meta, :event, "some_event")

    :telemetry.execute(
      [:phoenix, :live_view, :handle_event, :start],
      %{system_time: System.system_time()},
      meta
    )

    :telemetry.execute(
      [:phoenix, :live_view, :handle_event, :stop],
      %{duration: System.convert_time_unit(42, :millisecond, :native)},
      meta
    )

    assert_receive {:span,
                    span(
                      name: "SomeWeb.SomeLive.some_event",
                      kind: :internal,
                      attributes: attributes
                    ) = span}

    assert :otel_attributes.map(attributes) == %{
             duration_ms: 42,
             "liveview.callback": "handle_event",
             "liveview.event": "some_event",
             "liveview.module": "SomeWeb.SomeLive"
           }

    assert_instrumentation_library(span)

    # for live_component
    meta = %{socket: %{}, event: "some_event", component: SomeWeb.SomeComponent}

    :telemetry.execute(
      [:phoenix, :live_component, :handle_event, :start],
      %{system_time: System.system_time()},
      meta
    )

    :telemetry.execute(
      [:phoenix, :live_component, :handle_event, :stop],
      %{duration: System.convert_time_unit(42, :millisecond, :native)},
      meta
    )

    assert_receive {:span,
                    span(
                      name: "SomeWeb.SomeComponent.some_event",
                      kind: :internal,
                      attributes: attributes
                    ) = span}

    assert :otel_attributes.map(attributes) == %{
             duration_ms: 42,
             "liveview.callback": "handle_event",
             "liveview.event": "some_event",
             "liveview.module": "SomeWeb.SomeComponent"
           }

    assert_instrumentation_library(span)
  end

  defp assert_receive_bad_key_error_span(name) do
    expected_status = OpenTelemetry.status(:error, "Erlang error: :badkey")

    assert_receive {:span,
                    span(
                      name: ^name,
                      attributes: attributes,
                      kind: :internal,
                      events: events,
                      status: ^expected_status
                    ) = span}

    assert [event(name: "exception", attributes: exception_attributes)] = :otel_events.list(events)

    # The :map field is filtered because attribute values can only contain
    # primitives or lists of primitives (not maps).
    #
    # See https://opentelemetry.io/docs/reference/specification/common/common/#attributes
    assert %{
             "exception.type" => "Elixir.ErlangError",
             "exception.message" => "Erlang error: :badkey",
             "exception.stacktrace" => _stacktrace,
             key: :name
           } = :otel_attributes.map(exception_attributes)

    {span, attributes}
  end

  defp assert_instrumentation_library(span) do
    lib_from_otel =
      span
      |> span(:instrumentation_library)
      |> instrumentation_library()
      |> Map.new()

    opentelemetry_liveview_version =
      Application.loaded_applications()
      |> List.keyfind(:opentelemetry_liveview, 0)
      |> elem(2)
      |> to_string()

    assert %{name: "opentelemetry_liveview", version: ^opentelemetry_liveview_version} =
             lib_from_otel
  end
end
