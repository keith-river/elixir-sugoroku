defmodule NiigataSugorokuWeb.PageController do
  use NiigataSugorokuWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
