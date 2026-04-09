defmodule XactionsWeb.SessionController do
  use XactionsWeb, :controller

  def new(conn, _params) do
    render(conn, :new, error: nil)
  end

  def create(conn, %{"password" => password}) do
    hashed = Application.get_env(:xactions, :hashed_password)

    if hashed && Bcrypt.verify_pass(password, hashed) do
      conn
      |> put_session(:authenticated, true)
      |> redirect(to: ~p"/")
    else
      render(conn, :new, error: "Invalid password.")
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end
end
