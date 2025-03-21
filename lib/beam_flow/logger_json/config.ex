defmodule BeamFlow.LoggerJSON.Config do
  @moduledoc """
  Configuration module for LoggerJSON integration.

  This module provides helper functions and configuration hooks for LoggerJSON.
  """

  require Logger

  @doc """
  Sets up LoggerJSON formatter for production.
  """
  def setup do
    # No need for custom formatters at this stage
    # We'll keep it simple to avoid dependencies on internal LoggerJSON APIs
    :ok
  end
end
