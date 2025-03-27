defmodule BeamFlow.Content.MediaStorageTest do
  use BeamFlow.DataCase, async: true

  alias BeamFlow.Content.MediaStorage

  describe "generate_unique_filename/1" do
    # This is a private function, so we'll test it indirectly

    test "store_file generates a unique filename with date structure" do
      # Create a temp file for testing
      path = Path.join(System.tmp_dir!(), "test_file.jpg")
      File.write!(path, "test content")

      # Create a mock upload struct
      upload = %{
        path: path,
        content_type: "image/jpeg",
        client_name: "test_file.jpg"
      }

      # Store the file
      {:ok, storage_path} = MediaStorage.store_file(upload, "test_file.jpg")

      # Verify path structure
      assert storage_path =~ ~r|/uploads/\d{4}/\d{2}/\d{2}/[a-f0-9]+\.jpg|

      # Clean up
      MediaStorage.delete_file(storage_path)
      File.rm(path)
    end
  end

  describe "public_to_storage_path/1" do
    test "converts public path to storage path" do
      public_path = "/uploads/2025/03/26/abc123.jpg"
      storage_path = MediaStorage.public_to_storage_path(public_path)

      # The storage path should be in the configured directory
      storage_dir = Application.get_env(:beam_flow, :media_storage_dir, "priv/static/uploads")
      assert storage_path == Path.join(storage_dir, "2025/03/26/abc123.jpg")
    end
  end

  describe "store_file/2" do
    test "stores a file and returns the public path" do
      # Create a temp file for testing
      path = Path.join(System.tmp_dir!(), "test_file.jpg")
      File.write!(path, "test content")

      # Create a mock upload struct
      upload = %{
        path: path,
        content_type: "image/jpeg",
        client_name: "test_file.jpg"
      }

      # Store the file
      {:ok, public_path} = MediaStorage.store_file(upload, "test_file.jpg")

      # Verify the file exists in the storage location
      storage_path = MediaStorage.public_to_storage_path(public_path)
      assert File.exists?(storage_path)

      # Clean up
      MediaStorage.delete_file(public_path)
      File.rm(path)
    end
  end

  describe "delete_file/1" do
    test "deletes a file by public path" do
      # Create a temp file for testing
      path = Path.join(System.tmp_dir!(), "test_file.jpg")
      File.write!(path, "test content")

      # Create a mock upload struct
      upload = %{
        path: path,
        content_type: "image/jpeg",
        client_name: "test_file.jpg"
      }

      # Store the file
      {:ok, public_path} = MediaStorage.store_file(upload, "test_file.jpg")
      storage_path = MediaStorage.public_to_storage_path(public_path)

      # Verify the file exists
      assert File.exists?(storage_path)

      # Delete the file
      assert :ok = MediaStorage.delete_file(public_path)

      # Verify the file no longer exists
      refute File.exists?(storage_path)

      # Clean up
      File.rm(path)
    end
  end
end
