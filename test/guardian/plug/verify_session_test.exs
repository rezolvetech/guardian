defmodule Backoffice.Guardian.Plug.VerifySessionTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Plug.Test
  import Backoffice.Guardian.TestHelper

  alias Backoffice.Guardian.Plug.VerifySession

  setup do
    config = Application.get_env(:bo_guardian, Backoffice.Guardian)
    algo = hd(Keyword.get(config, :allowed_algos))
    secret = Keyword.get(config, :secret_key)

    jose_jws = %{"alg" => algo}
    jose_jwk = %{"kty" => "oct", "k" => :base64url.encode(secret)}

    conn = conn_with_fetched_session(conn(:get, "/"))
    claims = Backoffice.Guardian.Claims.app_claims(%{"sub" => "user", "aud" => "aud"})

    {_, jwt} = jose_jwk
                  |> JOSE.JWT.sign(jose_jws, claims)
                  |> JOSE.JWS.compact

    {
      :ok,
      conn: conn,
      jwt: jwt,
      claims: claims,
      jose_jwk: jose_jwk,
      jose_jws: jose_jws
    }
  end

  test "with no JWT in the session at a default location", context do
    conn = run_plug(context.conn, VerifySession)
    assert Backoffice.Guardian.Plug.claims(conn) == {:error, :no_session}
    assert Backoffice.Guardian.Plug.current_token(conn) == nil
  end

  test "with no JWT in the session at a specified location", context do
    conn = run_plug(context.conn, VerifySession, %{key: :secret})
    assert Backoffice.Guardian.Plug.claims(conn, :secret) == {:error, :no_session}
    assert Backoffice.Guardian.Plug.current_token(conn, :secret) == nil
  end

  test "with a valid JWT in the session at the default location", context do
    conn =
      context.conn
      |> Plug.Conn.put_session(Backoffice.Guardian.Keys.base_key(:default), context.jwt)
      |> run_plug(VerifySession)

    assert Backoffice.Guardian.Plug.claims(conn) == {:ok, context.claims}
    assert Backoffice.Guardian.Plug.current_token(conn) == context.jwt
  end

  test "with a valid JWT in the session at a specified location", context do
    conn =
      context.conn
      |> Plug.Conn.put_session(Backoffice.Guardian.Keys.base_key(:secret), context.jwt)
      |> run_plug(VerifySession, %{key: :secret})

    assert Backoffice.Guardian.Plug.claims(conn, :secret) == {:ok, context.claims}
    assert Backoffice.Guardian.Plug.current_token(conn, :secret) == context.jwt
  end

  test "with an existing session in another location", context do
    conn =
      context.conn
      |> Plug.Conn.put_session(Backoffice.Guardian.Keys.base_key(:default), context.jwt)
      |> Backoffice.Guardian.Plug.set_claims(context.claims)
      |> Backoffice.Guardian.Plug.set_current_token(context.jwt)
      |> Plug.Conn.put_session(Backoffice.Guardian.Keys.base_key(:secret), context.jwt)
      |> run_plug(VerifySession, %{key: :secret})

    assert Backoffice.Guardian.Plug.claims(conn, :secret) == {:ok, context.claims}
    assert Backoffice.Guardian.Plug.current_token(conn, :secret) == context.jwt
  end
end
