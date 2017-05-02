defmodule Backoffice.Guardian.Integration.HeaderAuthTest do
  @moduledoc false
  use ExUnit.Case
  use Plug.Test
  import Backoffice.Guardian.TestHelper

  alias Backoffice.Guardian.Plug.LoadResource
  alias Backoffice.Guardian.Plug.VerifyHeader
  alias Backoffice.Guardian.Claims

  defmodule TestSerializer do
    @moduledoc false
    @behaviour Backoffice.Guardian.Serializer

    def from_token("Org:" <> id), do: {:ok, id}
    def for_token(_), do: {:ok, nil}
  end

  test "load current resource with a valid jwt in authorization header" do
    claims = Claims.app_claims(%{"sub" => "Org:37", "aud" => "aud"})
    jwt = build_jwt(claims)

    conn = conn(:get, "/")

    conn =
      conn
      |> put_req_header("authorization", jwt)
      |> run_plug(VerifyHeader)
      |> run_plug(LoadResource, serializer: TestSerializer)

    assert Backoffice.Guardian.Plug.current_resource(conn) == "37"
    assert Backoffice.Guardian.Plug.claims(conn) == {:ok, claims}
    assert Backoffice.Guardian.Plug.current_token(conn) == jwt
  end
end
