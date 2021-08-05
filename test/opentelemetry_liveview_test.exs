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
    _ = :telemetry.detach(OpentelemetryLiveView)

    :application.stop(:opentelemetry)
    :application.set_env(:opentelemetry, :tracer, :otel_tracer_default)

    :application.set_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{scheduled_delay_ms: 1}}
    ])

    :application.start(:opentelemetry)

    :otel_batch_processor.set_exporter(:otel_exporter_pid, self())

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
    OpentelemetryLiveView.setup()

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
                    )}

    assert List.keysort(attributes, 0) == [
             "liveview.callback": "mount",
             "liveview.duration_ms": 42,
             "liveview.module": "SomeWeb.SomeLive"
           ]
  end

  test "records exceptions for the mount callback" do
    OpentelemetryLiveView.setup()

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

    attributes = assert_receive_bad_key_error_span("SomeWeb.SomeLive.mount")

    assert List.keysort(attributes, 0) == [
             {:"liveview.callback", "mount"},
             {:"liveview.duration_ms", 42},
             {:"liveview.module", "SomeWeb.SomeLive"}
           ]
  end

  test "records spans for the handle_params callback" do
    OpentelemetryLiveView.setup()
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
                    )}

    assert List.keysort(attributes, 0) == [
             "liveview.callback": "handle_params",
             "liveview.duration_ms": 42,
             "liveview.module": "SomeWeb.SomeLive",
             "liveview.uri": "https://foobar.com"
           ]
  end

  test "records exceptions for the handle_params callback" do
    OpentelemetryLiveView.setup()
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

    attributes = assert_receive_bad_key_error_span("SomeWeb.SomeLive.handle_params")

    assert List.keysort(attributes, 0) == [
             "liveview.callback": "handle_params",
             "liveview.duration_ms": 42,
             "liveview.module": "SomeWeb.SomeLive",
             "liveview.uri": "https://foobar.com"
           ]
  end

  test "records spans for the handle_event callback" do
    OpentelemetryLiveView.setup()
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
                    )}

    assert List.keysort(attributes, 0) == [
             "liveview.callback": "handle_event",
             "liveview.duration_ms": 42,
             "liveview.event": "some_event",
             "liveview.module": "SomeWeb.SomeLive"
           ]

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
                    )}

    assert List.keysort(attributes, 0) == [
             "liveview.callback": "handle_event",
             "liveview.duration_ms": 42,
             "liveview.event": "some_event",
             "liveview.module": "SomeWeb.SomeComponent"
           ]
  end

  test "allows modifying the duration attribute" do
    OpentelemetryLiveView.setup(duration: {:foo, :microsecond})

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
                    )}

    assert List.keysort(attributes, 0) == [
             foo: 42_000,
             "liveview.callback": "mount",
             "liveview.module": "SomeWeb.SomeLive"
           ]
  end

  defp assert_receive_bad_key_error_span(name) do
    expected_status = OpenTelemetry.status(:error, "Erlang error: :badkey")

    assert_receive {:span,
                    span(
                      name: ^name,
                      attributes: attributes,
                      kind: :internal,
                      events: [
                        event(
                          name: "exception",
                          attributes: [
                            {"exception.type", "Elixir.ErlangError"},
                            {"exception.message", "Erlang error: :badkey"},
                            {"exception.stacktrace", _stacktrace},
                            {:key, :name},
                            {:map, %{username: "foobar"}}
                          ]
                        )
                      ],
                      status: ^expected_status
                    )}

    attributes
  end
end
