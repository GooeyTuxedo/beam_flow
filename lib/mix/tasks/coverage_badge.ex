defmodule Mix.Tasks.CoverageBadge do
  @moduledoc "Generates a coverage badge for the README"
  use Mix.Task

  @shortdoc "Generates a coverage badge"
  def run(_args) do
    # Make sure we can run ExCoveralls tasks
    Application.ensure_all_started(:ex_coveralls)

    # Run coveralls.json - use an empty environment map to avoid potential issues with sensitive env vars
    Mix.shell().info("Running coverage...")
    {_msg, 0} = System.cmd("mix", ["coveralls.json"], into: IO.stream(:stdio, :line), env: %{})

    # Read the JSON report
    {:ok, json} = File.read("cover/excoveralls.json")
    {:ok, data} = Jason.decode(json)

    # Calculate total coverage from source files
    coverage = calculate_coverage_from_source_files(data)

    # Determine color based on coverage
    color =
      cond do
        coverage >= 90 -> "brightgreen"
        coverage >= 80 -> "green"
        coverage >= 70 -> "yellowgreen"
        coverage >= 60 -> "yellow"
        true -> "red"
      end

    # Create badge URL (using shields.io)
    badge_url = "https://img.shields.io/badge/coverage-#{coverage}%25-#{color}"

    # Output for use in README
    IO.puts("\nCoverage Badge URL for README:")
    IO.puts("[![Coverage](#{badge_url})](cover/excoveralls.html)")
  end

  # Calculate coverage from source files
  defp calculate_coverage_from_source_files(%{"source_files" => source_files}) do
    # Process each file to get covered and relevant lines
    file_stats =
      Enum.map(source_files, fn file ->
        coverage = file["coverage"]
        # Count non-nil and positive values as covered lines
        # Count total relevant lines (non-nil values in coverage)
        {
          Enum.count(coverage, fn line -> line != nil && line > 0 end),
          Enum.count(coverage, fn line -> line != nil end)
        }
      end)

    # Calculate total covered and relevant lines
    {total_covered, total_relevant} =
      Enum.reduce(file_stats, {0, 0}, fn {covered, relevant}, {acc_covered, acc_relevant} ->
        {acc_covered + covered, acc_relevant + relevant}
      end)

    # Calculate percentage
    case total_relevant do
      0 -> 0.0
      _total -> Float.round(total_covered / total_relevant * 100, 1)
    end
  end

  # Fallback to zero if we can't find source_files
  defp calculate_coverage_from_source_files(_no_files) do
    Mix.shell().error("Could not find source_files in coverage data")
    0.0
  end
end
