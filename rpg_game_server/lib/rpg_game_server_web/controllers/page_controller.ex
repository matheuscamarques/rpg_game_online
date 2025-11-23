defmodule RpgGameServerWeb.PageController do
  use RpgGameServerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
