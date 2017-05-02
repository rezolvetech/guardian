defmodule Backoffice.Guardian.KeysTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "base_key with atom" do
    assert Backoffice.Guardian.Keys.base_key(:foo) == :bo_guardian_foo
  end

  test "base_key beginning with guardian_" do
    assert Backoffice.Guardian.Keys.base_key("bo_guardian_foo") == :bo_guardian_foo
  end

  test "claims key" do
    assert Backoffice.Guardian.Keys.claims_key(:foo) == :bo_guardian_foo_claims
  end

  test "resource key" do
    assert Backoffice.Guardian.Keys.resource_key(:foo) == :bo_guardian_foo_resource
  end

  test "jwt_key" do
    assert Backoffice.Guardian.Keys.jwt_key(:foo) == :bo_guardian_foo_jwt
  end
end
