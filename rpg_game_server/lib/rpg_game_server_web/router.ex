defmodule RpgGameServerWeb.Router do
  use RpgGameServerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RpgGameServerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug RpgGameServerWeb.AuthPlug
  end

  scope "/", RpgGameServerWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # =================================================================
  # 1. ROTAS PÚBLICAS (Sem Token)
  # =================================================================
  scope "/api", RpgGameServerWeb do
    pipe_through :api

    post "/login", AuthController, :login
    post "/register", AuthController, :register
  end

  # =================================================================
  # 2. ROTAS PROTEGIDAS (Com Token)
  # =================================================================
  scope "/api", RpgGameServerWeb do
    # O segredo está aqui: passa pelo :api E DEPOIS pelo :auth
    pipe_through [:api, :auth]

    # Note que removi o :user_id da rota de index.
    # Como você já tem o token, o controller sabe quem é o usuário!
    get "/characters", CharacterController, :index
    post "/characters", CharacterController, :create
    delete "/characters/:id", CharacterController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", RpgGameServerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rpg_game_server, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RpgGameServerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
