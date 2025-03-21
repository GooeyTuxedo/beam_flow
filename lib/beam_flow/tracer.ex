defmodule BeamFlow.Tracer do
  @moduledoc """
  Convenience module for OpenTelemetry tracing in BeamFlow.

  This module provides helper functions for working with OpenTelemetry
  traces and spans in a more Elixir-friendly way.
  """

  require OpenTelemetry.Tracer

  @doc """
  Creates a span and executes the given function within its context.

  ## Examples

      BeamFlow.Tracer.with_span "create_post", %{user_id: user.id} do
        # Create post logic here
      end
  """
  defmacro with_span(name, attrs \\ quote(do: %{}), do: block) do
    quote do
      normalized_attrs = BeamFlow.Tracer.normalize_attributes(unquote(attrs))

      OpenTelemetry.Tracer.with_span unquote(name), %{attributes: normalized_attrs} do
        unquote(block)
      end
    end
  end

  @doc """
  Creates a span with additional options and executes the given function.

  ## Examples

      BeamFlow.Tracer.with_span_opts "create_post", %{user_id: user.id}, kind: :server do
        # Create post logic here
      end
  """
  defmacro with_span_opts(name, attrs, opts, do: block) do
    quote do
      normalized_attrs = BeamFlow.Tracer.normalize_attributes(unquote(attrs))
      span_opts = Keyword.put(unquote(opts), :attributes, normalized_attrs)

      OpenTelemetry.Tracer.with_span unquote(name), span_opts do
        unquote(block)
      end
    end
  end

  @doc """
  Adds an event to the current span.

  ## Examples

      BeamFlow.Tracer.add_event("post.created", %{post_id: post.id})
  """
  def add_event(name, attrs \\ %{}) do
    normalized_attrs = normalize_attributes(attrs)
    OpenTelemetry.Tracer.add_event(name, normalized_attrs)
  end

  @doc """
  Sets attributes on the current span.

  ## Examples

      BeamFlow.Tracer.set_attributes(%{post_id: post.id, title: post.title})
  """
  def set_attributes(attrs) do
    normalized_attrs = normalize_attributes(attrs)
    OpenTelemetry.Tracer.set_attributes(normalized_attrs)
  end

  @doc """
  Returns the current span context.
  """
  def current_span_ctx do
    OpenTelemetry.Tracer.current_span_ctx()
  end

  @doc """
  Returns the trace ID for the current span, formatted as a hex string.
  """
  def current_trace_id do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        nil

      ctx ->
        trace_id = OpenTelemetry.Span.trace_id(ctx)
        # Handle both binary and integer formats
        cond do
          is_binary(trace_id) -> Base.encode16(trace_id, case: :lower)
          is_integer(trace_id) -> Integer.to_string(trace_id, 16)
          true -> nil
        end
    end
  end

  @doc """
  Returns the span ID for the current span, formatted as a hex string.
  """
  def current_span_id do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        nil

      ctx ->
        span_id = OpenTelemetry.Span.span_id(ctx)
        # Handle both binary and integer formats
        cond do
          is_binary(span_id) -> Base.encode16(span_id, case: :lower)
          is_integer(span_id) -> Integer.to_string(span_id, 16)
          true -> nil
        end
    end
  end

  @doc """
  Records an exception in the current span.

  ## Examples

      try do
        # Some code that might raise
      rescue
        e ->
          BeamFlow.Tracer.record_exception(e, __STACKTRACE__)
          reraise e, __STACKTRACE__
      end
  """
  def record_exception(exception, stacktrace \\ nil) do
    OpenTelemetry.Tracer.record_exception(exception, stacktrace)
  end

  @doc """
  Sets the status of the current span to error with an optional description.
  """
  def set_error(description \\ nil) do
    OpenTelemetry.Tracer.set_status(:error, description)
  end

  # Public helper for normalization (called from macros)
  @doc false
  def normalize_attributes(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn {k, v} -> {to_string(k), normalize_value(v)} end)
    |> Map.new()
  end

  def normalize_attributes(attrs) when is_list(attrs) do
    attrs
    |> Enum.map(fn {k, v} -> {to_string(k), normalize_value(v)} end)
    |> Enum.into(%{})
  end

  def normalize_attributes(_attrs), do: %{}

  # Convert values to types supported by OpenTelemetry
  defp normalize_value(v) when is_atom(v), do: to_string(v)
  defp normalize_value(v) when is_pid(v), do: inspect(v)
  defp normalize_value(v) when is_reference(v), do: inspect(v)
  defp normalize_value(v) when is_function(v), do: inspect(v)
  defp normalize_value(v) when is_map(v), do: inspect(v)
  defp normalize_value(v), do: v
end
