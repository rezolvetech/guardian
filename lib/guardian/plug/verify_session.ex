defmodule Backoffice.Guardian.Plug.VerifySession do
  @moduledoc """
  Use this plug to verify a token contained in a session.

  ## Example

      plug Backoffice.Guardian.Plug.VerifySession

  You can also specify a location to look for the token

  ## Example

      plug Backoffice.Guardian.Plug.VerifySession, key: :secret

  Verifying the session will update the claims on the request,
  available with Backoffice.Guardian.Plug.claims/1

  In the case of an error, the claims will be set to { :error, reason }
  """
  import Backoffice.Guardian.Keys

  @doc false
  def init(opts \\ %{}), do: Enum.into(opts, %{})

  @doc false
  def call(conn, opts) do
    key = Map.get(opts, :key, :default)

    case Backoffice.Guardian.Plug.claims(conn, key) do
      {:ok, _} -> conn
      {:error, _} ->
        jwt = Plug.Conn.get_session(conn, base_key(key))

        if jwt do
          case Backoffice.Guardian.decode_and_verify(jwt, %{}) do
            {:ok, claims} ->
              conn
              |> Backoffice.Guardian.Plug.set_claims({:ok, claims}, key)
              |> Backoffice.Guardian.Plug.set_current_token(jwt, key)
            {:error, reason} ->
              conn
              |> Plug.Conn.delete_session(base_key(key))
              |> Backoffice.Guardian.Plug.set_claims({:error, reason}, key)
          end
        else
          conn
        end
    end
  end
end
