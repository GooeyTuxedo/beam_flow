defmodule BeamFlowWeb.API.V1.PostController do
  use BeamFlowWeb, :controller

  # Fix alias ordering
  alias BeamFlow.Accounts.Auth
  alias BeamFlow.Content
  alias BeamFlow.Content.Post
  alias BeamFlow.Logger
  alias BeamFlow.Tracer

  require BeamFlow.Tracer
  require OpenTelemetry.Tracer

  def index(conn, params) do
    Tracer.with_span "api.posts.index", %{
      client_ip: format_ip(conn.remote_ip),
      user_agent: get_user_agent(conn),
      query_params: inspect(params)
    } do
      filters = build_filters(params)

      Tracer.add_event("filters.built", %{filters: inspect(filters)})

      posts = Content.list_posts(filters)

      Tracer.add_event("response.generated", %{post_count: length(posts)})

      conn
      |> json(%{
        data: Enum.map(posts, &post_to_json/1)
      })
    end
  end

  def show(conn, %{"id" => id}) do
    Tracer.with_span "api.posts.show", %{
      post_id: id,
      client_ip: format_ip(conn.remote_ip),
      user_agent: get_user_agent(conn)
    } do
      case get_post(id) do
        %Post{} = post ->
          Tracer.add_event("post.found", %{
            title: post.title,
            status: post.status,
            author_id: post.user_id
          })

          conn |> json(%{data: post_to_json(post)})

        nil ->
          Tracer.add_event("post.not_found", %{})
          Tracer.set_error("Post not found")

          conn
          |> put_status(:not_found)
          |> json(%{error: %{status: 404, message: "Post not found"}})
      end
    end
  end

  def create(conn, %{"post" => post_params}) do
    user = conn.assigns.current_user

    Tracer.with_span "api.posts.create", %{
      user_id: user.id,
      role: user.role,
      client_ip: format_ip(conn.remote_ip)
    } do
      # Ensure user_id is set to the current user
      post_params = Map.put(post_params, "user_id", user.id)

      Tracer.add_event("request.received", %{
        title: Map.get(post_params, "title"),
        status: Map.get(post_params, "status", "draft")
      })

      case Auth.authorize(user, :create, {:post, nil}) do
        :ok ->
          Tracer.add_event("authorization.success", %{})
          create_and_respond(conn, user, post_params)

        {:error, :unauthorized} ->
          Tracer.add_event("authorization.failed", %{})
          Tracer.set_error("Not authorized to create posts")

          conn
          |> put_status(:forbidden)
          |> json(%{error: %{status: 403, message: "Not authorized to create posts"}})
      end
    end
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    Tracer.with_span "api.posts.update", %{
      post_id: id,
      user_id: conn.assigns.current_user.id,
      role: conn.assigns.current_user.role,
      client_ip: format_ip(conn.remote_ip)
    } do
      # Refactored to reduce nesting
      with %Post{} = post <- get_post(id),
           :ok <- Auth.authorize(conn.assigns.current_user, :update, {:post, post}) do
        Tracer.add_event("authorization.success", %{})
        Tracer.add_event("post.found", %{title: post.title, status: post.status})

        update_post_and_respond(conn, post, post_params)
      else
        nil ->
          Tracer.add_event("post.not_found", %{})
          Tracer.set_error("Post not found")

          conn
          |> put_status(:not_found)
          |> json(%{error: %{status: 404, message: "Post not found"}})

        {:error, :unauthorized} ->
          Tracer.add_event("authorization.failed", %{})
          Tracer.set_error("Not authorized to update post")

          conn
          |> put_status(:forbidden)
          |> json(%{error: %{status: 403, message: "Not authorized to update this post"}})
      end
    end
  end

  def delete(conn, %{"id" => id}) do
    Tracer.with_span "api.posts.delete", %{
      post_id: id,
      user_id: conn.assigns.current_user.id,
      role: conn.assigns.current_user.role,
      client_ip: format_ip(conn.remote_ip)
    } do
      # Refactored to reduce nesting
      with %Post{} = post <- get_post(id),
           :ok <- Auth.authorize(conn.assigns.current_user, :delete, {:post, post}) do
        Tracer.add_event("authorization.success", %{})
        Tracer.add_event("post.found", %{title: post.title, status: post.status})

        delete_post_and_respond(conn, post, id)
      else
        nil ->
          Tracer.add_event("post.not_found", %{})
          Tracer.set_error("Post not found")

          conn
          |> put_status(:not_found)
          |> json(%{error: %{status: 404, message: "Post not found"}})

        {:error, :unauthorized} ->
          Tracer.add_event("authorization.failed", %{})
          Tracer.set_error("Not authorized to delete post")

          conn
          |> put_status(:forbidden)
          |> json(%{error: %{status: 403, message: "Not authorized to delete this post"}})
      end
    end
  end

  # Helper functions

  # Fix implicit try
  defp get_post(id) do
    Content.get_post!(id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp create_and_respond(conn, user, post_params) do
    case Content.create_post(post_params) do
      {:ok, post} ->
        Logger.audit("api.post.create", user, %{post_id: post.id})

        Tracer.add_event("post.created", %{
          post_id: post.id,
          title: post.title,
          slug: post.slug
        })

        conn
        |> put_status(:created)
        |> put_resp_header("location", "/api/v1/posts/#{post.id}")
        |> json(%{data: post_to_json(post)})

      {:error, changeset} ->
        Tracer.add_event("post.validation_failed", %{
          errors: inspect(changeset.errors)
        })

        Tracer.set_error("Validation failed")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            status: 422,
            message: "Validation failed",
            details: format_changeset_errors(changeset)
          }
        })
    end
  end

  defp update_post_and_respond(conn, post, post_params) do
    user = conn.assigns.current_user

    case Content.update_post(post, post_params) do
      {:ok, updated_post} ->
        Logger.audit("api.post.update", user, %{post_id: post.id})

        Tracer.add_event("post.updated", %{
          post_id: updated_post.id,
          title: updated_post.title,
          slug: updated_post.slug
        })

        json(conn, %{data: post_to_json(updated_post)})

      {:error, changeset} ->
        Tracer.add_event("post.update_failed", %{
          errors: inspect(changeset.errors)
        })

        Tracer.set_error("Validation failed")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            status: 422,
            message: "Validation failed",
            details: format_changeset_errors(changeset)
          }
        })
    end
  end

  defp delete_post_and_respond(conn, post, id) do
    user = conn.assigns.current_user

    case Content.delete_post(post) do
      {:ok, _post} ->
        Logger.audit("api.post.delete", user, %{post_id: id})

        Tracer.add_event("post.deleted", %{})

        send_resp(conn, :no_content, "")

      {:error, _changeset} ->
        Tracer.set_error("Failed to delete post")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{status: 500, message: "Failed to delete post"}})
    end
  end

  defp post_to_json(post) do
    author =
      if Ecto.assoc_loaded?(post.user),
        do: %{
          id: post.user.id,
          name: post.user.name
        },
        else: nil

    %{
      id: post.id,
      title: post.title,
      slug: post.slug,
      content: post.content,
      excerpt: post.excerpt,
      status: post.status,
      published_at: post.published_at,
      inserted_at: post.inserted_at,
      updated_at: post.updated_at,
      author: author
    }
  end

  # Reduce complexity by splitting filter building into separate functions
  defp build_filters(params) do
    []
    |> add_status_filter(params["status"])
    |> add_search_filter(params["search"])
    |> add_limit_filter(params["limit"])
    |> add_sort_filter(params["sort"])
  end

  defp add_status_filter(filters, nil), do: filters
  defp add_status_filter(filters, ""), do: filters
  defp add_status_filter(filters, status), do: [{:status, status} | filters]

  defp add_search_filter(filters, nil), do: filters
  defp add_search_filter(filters, ""), do: filters
  defp add_search_filter(filters, search), do: [{:search, search} | filters]

  defp add_limit_filter(filters, nil), do: filters
  defp add_limit_filter(filters, ""), do: filters
  defp add_limit_filter(filters, limit), do: [{:limit, parse_integer(limit)} | filters]

  defp add_sort_filter(filters, sort) do
    sort_option =
      case sort do
        "title_asc" -> {:title, :asc}
        "title_desc" -> {:title, :desc}
        "created_asc" -> {:inserted_at, :asc}
        "created_desc" -> {:inserted_at, :desc}
        "published_asc" -> {:published_at, :asc}
        "published_desc" -> {:published_at, :desc}
        _other -> {:inserted_at, :desc}
      end

    [{:order_by, sort_option} | filters]
  end

  defp parse_integer(string) when is_binary(string) do
    case Integer.parse(string) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp parse_integer(int) when is_integer(int), do: int
  defp parse_integer(_value), do: nil

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_ip(ip) when is_tuple(ip), do: to_string(:inet.ntoa(ip))
  defp format_ip(_ip), do: "unknown"

  defp get_user_agent(conn) do
    case get_req_header(conn, "user-agent") do
      [user_agent] -> user_agent
      _other -> "unknown"
    end
  end
end
