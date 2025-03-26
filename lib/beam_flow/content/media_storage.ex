defmodule BeamFlow.Content.MediaStorage do
  @moduledoc """
  Storage adapter for media files with configurable backends.
  Currently supports local filesystem storage with a path to support S3 in the future.
  """
  require Logger
  require BeamFlow.Tracer
  require OpenTelemetry.Tracer
  alias BeamFlow.Tracer

  @storage_dir Application.compile_env(:beam_flow, :media_storage_dir, "priv/static/uploads")
  @public_path "/uploads"

  @doc """
  Stores a media file to the configured storage backend.

  Returns `{:ok, path}` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> store_file(upload, "image.jpg")
      {:ok, "/uploads/2025/03/26/abcd1234.jpg"}
  """
  def store_file(%{path: temp_path}, filename) do
    Tracer.with_span "media_storage.store_file", %{filename: filename} do
      # Generate a unique filename with date-based path
      unique_filename = generate_unique_filename(filename)
      target_path = build_storage_path(unique_filename)
      public_path = build_public_path(unique_filename)

      # Ensure directory exists
      target_dir = Path.dirname(target_path)
      File.mkdir_p!(target_dir)

      # Copy the file
      case File.cp(temp_path, target_path) do
        :ok ->
          Tracer.add_event("media.stored", %{
            path: target_path,
            public_path: public_path
          })

          {:ok, public_path}

        {:error, reason} ->
          Tracer.set_error("Failed to store media file")
          Tracer.add_event("media.store_failed", %{reason: reason})
          {:error, reason}
      end
    end
  end

  @doc """
  Deletes a media file from the configured storage backend.

  Returns `:ok` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> delete_file("/uploads/2025/03/26/abcd1234.jpg")
      :ok
  """
  def delete_file(public_path) do
    Tracer.with_span "media_storage.delete_file", %{path: public_path} do
      storage_path = public_to_storage_path(public_path)

      case File.rm(storage_path) do
        :ok ->
          Tracer.add_event("media.deleted", %{path: storage_path})
          :ok

        {:error, reason} ->
          Tracer.set_error("Failed to delete media file")
          Tracer.add_event("media.delete_failed", %{reason: reason})
          {:error, reason}
      end
    end
  end

  @doc """
  Returns the absolute file system path for a media file.
  """
  def public_to_storage_path(public_path) do
    relative_path = String.replace_prefix(public_path, @public_path, "")
    Path.join(@storage_dir, relative_path)
  end

  # Generates a unique filename including a date-based path
  defp generate_unique_filename(original_filename) do
    # Get date parts for folder structure
    date = Date.utc_today()
    year = date.year

    # Format month and day with leading zeros
    month_str = date.month |> Integer.to_string() |> String.pad_leading(2, "0")
    day_str = date.day |> Integer.to_string() |> String.pad_leading(2, "0")

    # Generate random part
    random_bytes = :crypto.strong_rand_bytes(8)
    random = Base.encode16(random_bytes, case: :lower)

    # Keep original extension
    ext = Path.extname(original_filename)

    # Create path with date structure
    Path.join(["#{year}", month_str, day_str, "#{random}#{ext}"])
  end

  # Builds the full storage path
  defp build_storage_path(filename) do
    Path.join(@storage_dir, filename)
  end

  # Builds the public URL path
  defp build_public_path(filename) do
    Path.join(@public_path, filename)
  end
end
