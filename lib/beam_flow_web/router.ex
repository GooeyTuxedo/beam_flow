defmodule BeamFlowWeb.Router do
  use BeamFlowWeb, :router

  import BeamFlowWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BeamFlowWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug :browser
    plug :require_authenticated_user
    plug :put_root_layout, {BeamFlowWeb.AdminLayouts, :root}
    plug :put_layout, {BeamFlowWeb.AdminLayouts, :app}
    # Additional admin-specific plugs can be added here
  end

  pipeline :editor do
    plug :browser
    plug :require_authenticated_user
    plug :put_root_layout, {BeamFlowWeb.EditorLayouts, :root}
    plug :put_layout, {BeamFlowWeb.EditorLayouts, :app}
    # Additional editor-specific plugs can be added here
  end

  pipeline :author do
    plug :browser
    plug :require_authenticated_user
    plug :put_root_layout, {BeamFlowWeb.AuthorLayouts, :root}
    plug :put_layout, {BeamFlowWeb.AuthorLayouts, :app}
    # Additional author-specific plugs can be added here
  end

  scope "/", BeamFlowWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", BeamFlowWeb do
  #   pipe_through :api
  # end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:beam_flow, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BeamFlowWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{BeamFlowWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", BeamFlowWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{BeamFlowWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", BeamFlowWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{BeamFlowWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/admin", BeamFlowWeb.Admin, as: :admin do
    pipe_through :admin

    live_session :admin_area,
      on_mount: [
        {BeamFlowWeb.UserAuth, :ensure_authenticated},
        {BeamFlowWeb.LiveAuth, {:ensure_role, :admin}},
        {BeamFlowWeb.LiveAuth, :audit_access}
      ] do
      live "/", DashboardLive, :index
      live "/users", UserLive.Index, :index
      live "/users/new", UserLive.Index, :new
      live "/users/:id/edit", UserLive.Index, :edit
      live "/users/:id", UserLive.Show, :show

      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Index, :new
      live "/posts/:id/edit", PostLive.Index, :edit
      live "/posts/:id", PostLive.Show, :show

      # These routes will be implemented later as we build features
      # live "/categories", CategoryLive.Index, :index
      # live "/tags", TagLive.Index, :index
      # live "/media", MediaLive.Index, :index
      # live "/comments", CommentLive.Index, :index
      # live "/settings", SettingsLive, :index
    end
  end

  # Editor routes with full post management
  scope "/editor", BeamFlowWeb.Editor, as: :editor do
    pipe_through :editor

    live_session :editor_area,
      on_mount: [
        {BeamFlowWeb.UserAuth, :ensure_authenticated},
        {BeamFlowWeb.LiveAuth, {:ensure_role, :editor}},
        {BeamFlowWeb.LiveAuth, :audit_access}
      ] do
      live "/", DashboardLive, :index

      # Post management routes
      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Index, :new
      live "/posts/:id/edit", PostLive.Index, :edit
      live "/posts/:id", PostLive.Show, :show

      # Future routes for comments and media
      # live "/comments", CommentLive.Index, :index
      # live "/media", MediaLive.Index, :index
    end
  end

  # Author routes with own content management
  scope "/author", BeamFlowWeb.Author, as: :author do
    pipe_through :author

    live_session :author_area,
      on_mount: [
        {BeamFlowWeb.UserAuth, :ensure_authenticated},
        {BeamFlowWeb.LiveAuth, {:ensure_role, :author}},
        {BeamFlowWeb.LiveAuth, :audit_access}
      ] do
      live "/", DashboardLive, :index

      # Post management routes
      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Index, :new
      live "/posts/:id/edit", PostLive.Index, :edit
      live "/posts/:id", PostLive.Show, :show
    end
  end
end
