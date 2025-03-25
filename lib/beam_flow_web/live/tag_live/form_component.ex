defmodule BeamFlowWeb.TagLive.FormComponent do
  use BeamFlowWeb, :live_component

  alias BeamFlow.Content
  alias BeamFlow.Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.simple_form
        for={@form}
        id="tag-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input
          field={@form[:slug]}
          type="text"
          label="Slug"
          placeholder="Leave blank to generate automatically"
        />

        <:actions>
          <.button phx-disable-with="Saving...">Save Tag</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{tag: tag} = assigns, socket) do
    changeset = Content.change_tag(tag)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"tag" => tag_params}, socket) do
    changeset =
      socket.assigns.tag
      |> Content.change_tag(tag_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"tag" => tag_params}, socket) do
    atom_params =
      for {k, v} <- tag_params, into: %{} do
        {String.to_existing_atom(k), v}
      end

    atom_params = Map.put(atom_params, :current_user, socket.assigns.current_user)

    save_tag(socket, socket.assigns.action, atom_params)
  end

  defp save_tag(socket, :edit, tag_params) do
    Logger.info("Updating tag", tag_id: socket.assigns.tag.id)

    case Content.update_tag(socket.assigns.tag, tag_params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag updated successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warn("Failed to update tag",
          tag_id: socket.assigns.tag.id,
          errors: inspect(changeset.errors)
        )

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_tag(socket, :new, tag_params) do
    Logger.info("Creating new tag")

    case Content.create_tag(tag_params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag created successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warn("Failed to create tag", errors: inspect(changeset.errors))

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
