# defmodule BeamFlow.Content.Storage.S3 do
#   @behaviour BeamFlow.Content.Storage.Adapter

#   require Logger
#   require BeamFlow.Tracer
#   alias BeamFlow.Tracer

#   @impl true
#   def store_file(temp_path, filename) do
#     Tracer.with_span "media_storage.s3.store_file", %{filename: filename} do
#       # Implementation using ExAws or similar
#       # ...
#     end
#   end

#   @impl true
#   def delete_file(path) do
#     Tracer.with_span "media_storage.s3.delete_file", %{path: path} do
#       # Implementation using ExAws or similar
#       # ...
#     end
#   end
# end
