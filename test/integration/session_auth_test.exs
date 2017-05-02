defmodule Backoffice.Guardian.Integration.SessionAuthTest do
  @moduledoc false
  use ExUnit.Case
  use Plug.Test

  import Backoffice.Guardian.TestHelper

  alias Backoffice.Guardian.Plug.LoadResource
  alias Backoffice.Guardian.Plug.VerifySession
  alias Backoffice.Guardian.Claims

  defmodule TestSerializer do
    @moduledoc false
    @behaviour Backoffice.Guardian.Serializer

    def from_token("Company:" <> id), do: {:ok, id}
    def for_token(_), do: {:ok, nil}
  end

  test "load current resource with a valid jwt in session" do
    claims = Claims.app_claims(%{"sub" => "Company:42", "aud" => "aud"})
    jwt = build_jwt(claims)

    conn = conn(:get, "/")

    conn =
      conn
      |> conn_with_fetched_session
      |> put_session(Backoffice.Guardian.Keys.base_key(:default), jwt)
      |> run_plug(VerifySession)
      |> run_plug(LoadResource, serializer: TestSerializer)

    assert Backoffice.Guardian.Plug.current_resource(conn) == "42"
    assert Backoffice.Guardian.Plug.claims(conn) == {:ok, claims}
    assert Backoffice.Guardian.Plug.current_token(conn) == jwt
  end
end
