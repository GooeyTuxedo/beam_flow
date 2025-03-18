defmodule BeamFlowWeb.Admin.PostLive.Helpers do
  @moduledoc """
  Helper functions for post LiveViews.
  """

  @doc """
  Returns CSS class for a post status badge.
  """
  def status_badge_color("draft"), do: "bg-gray-100 text-gray-800"
  def status_badge_color("published"), do: "bg-green-100 text-green-800"
  def status_badge_color("scheduled"), do: "bg-blue-100 text-blue-800"
  def status_badge_color(_else), do: "bg-gray-100 text-gray-800"

  @doc """
  Format a datetime for display.
  """
  def format_date(nil), do: ""

  def format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  end

  @doc """
  Generate post status options for selects.
  """
  def status_options do
    [
      {"Draft", "draft"},
      {"Published", "published"},
      {"Scheduled", "scheduled"}
    ]
  end
end
