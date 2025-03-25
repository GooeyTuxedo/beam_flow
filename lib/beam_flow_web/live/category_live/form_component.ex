defmodule BeamFlowWeb.CategoryLive.FormComponent do
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
        id="category-form"
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
        <.input field={@form[:description]} type="textarea" label="Description" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Category</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{category: category} = assigns, socket) do
    changeset = Content.change_category(category)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"category" => category_params}, socket) do
    changeset =
      socket.assigns.category
      |> Content.change_category(category_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"category" => category_params}, socket) do
    atom_params =
      for {k, v} <- category_params, into: %{} do
        {String.to_existing_atom(k), v}
      end

    atom_params = Map.put(atom_params, :current_user, socket.assigns.current_user)

    save_category(socket, socket.assigns.action, atom_params)
  end

  defp save_category(socket, :edit, category_params) do
    Logger.info("Updating category", category_id: socket.assigns.category.id)

    case Content.update_category(socket.assigns.category, category_params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category updated successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warn("Failed to update category",
          category_id: socket.assigns.category.id,
          errors: inspect(changeset.errors)
        )

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_category(socket, :new, category_params) do
    Logger.info("Creating new category")

    case Content.create_category(category_params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category created successfully")
         |> push_patch(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warn("Failed to create category", errors: inspect(changeset.errors))

        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
