defmodule Backoffice.GuardianTest do
  @moduledoc false

  use ExUnit.Case, async: true

  setup do
    claims = %{
      "aud" => "User:1",
      "typ" => "access",
      "exp" => Backoffice.Guardian.Utils.timestamp + 10_000,
      "iat" => Backoffice.Guardian.Utils.timestamp,
      "iss" => "MyApp",
      "sub" => "User:1",
      "something_else" => "foo"
    }

    config = Application.get_env(:bo_guardian, Backoffice.Guardian)
    algo = hd(Keyword.get(config, :allowed_algos))
    secret = Keyword.get(config, :secret_key)

    jose_jws = %{"alg" => algo}
    jose_jwk = %{"kty" => "oct", "k" => :base64url.encode(secret)}

    {_, jwt} = jose_jwk
                  |> JOSE.JWT.sign(jose_jws, claims)
                  |> JOSE.JWS.compact

    es512_jose_jwk = JOSE.JWK.generate_key({:ec, :secp521r1})
    es512_jose_jws = JOSE.JWS.from_map(%{"alg" => "ES512"})
    es512_jose_jwt = es512_jose_jwk
      |> JOSE.JWT.sign(es512_jose_jws, claims)
      |> JOSE.JWS.compact
      |> elem(1)

    {
      :ok,
      %{
        claims: claims,
        jwt: jwt,
        jose_jws: jose_jws,
        jose_jwk: jose_jwk,
        es512: %{
          jwk: es512_jose_jwk,
          jws: es512_jose_jws,
          jwt: es512_jose_jwt
        }
      }
    }
  end

  test "config with a value" do
    assert Backoffice.Guardian.config(:issuer) == "MyApp"
  end

  test "config with no value" do
    assert Backoffice.Guardian.config(:not_a_thing) == nil
  end

  test "config with a default value" do
    assert Backoffice.Guardian.config(:not_a_thing, :this_is_a_thing) == :this_is_a_thing
  end

  test "config with a system value" do
    assert Backoffice.Guardian.config(:system_foo) == nil
    System.put_env("FOO", "foo")
    assert Backoffice.Guardian.config(:system_foo) == "foo"
  end

  test "it fetches the currently configured serializer" do
    assert Backoffice.Guardian.serializer == Backoffice.Guardian.TestGuardianSerializer
  end

  test "it returns the current app name" do
    assert Backoffice.Guardian.issuer == "MyApp"
  end

  test "it verifies the jwt", context do
    assert Backoffice.Guardian.decode_and_verify(context.jwt) == {:ok, context.claims}
  end

  test "it verifies the jwt with custom secret %JOSE.JWK{} struct", context do
    secret = context.es512.jwk
    assert Backoffice.Guardian.decode_and_verify(context.es512.jwt, %{secret: secret}) == {:ok, context.claims}
  end

  test "it verifies the jwt with custom secret tuple", context do
    secret = {Backoffice.Guardian.TestHelper, :secret_key_function, [context.es512.jwk]}
    assert Backoffice.Guardian.decode_and_verify(context.es512.jwt, %{secret: secret}) == {:ok, context.claims}
  end

  test "it verifies the jwt with custom secret map", context do
    secret = context.es512.jwk |> JOSE.JWK.to_map |> elem(1)
    assert Backoffice.Guardian.decode_and_verify(context.es512.jwt, %{secret: secret}) == {:ok, context.claims}
  end

  test "verifies the issuer", context do
    assert Backoffice.Guardian.decode_and_verify(context.jwt) == {:ok, context.claims}
  end

  test "fails if the issuer is not correct", context do
    claims = %{
      typ: "access",
      exp: Backoffice.Guardian.Utils.timestamp + 10_000,
      iat: Backoffice.Guardian.Utils.timestamp,
      iss: "not the issuer",
      sub: "User:1"
    }

    {_, jwt} = context.jose_jwk
                  |> JOSE.JWT.sign(context.jose_jws, claims)
                  |> JOSE.JWS.compact

    assert Backoffice.Guardian.decode_and_verify(jwt) == {:error, :invalid_issuer}
  end

  test "fails if the expiry has passed", context do
    claims = Map.put(context.claims, "exp", Backoffice.Guardian.Utils.timestamp - 10)
    {_, jwt} = context.jose_jwk
                  |> JOSE.JWT.sign(context.jose_jws, claims)
                  |> JOSE.JWS.compact

    assert Backoffice.Guardian.decode_and_verify(jwt) == {:error, :token_expired}
  end

  test "it is invalid if the typ is incorrect", context do
    response = Backoffice.Guardian.decode_and_verify(
      context.jwt,
      %{typ: "something_else"}
    )

    assert response == {:error, :invalid_type}
  end

  test "verify! with a jwt", context do
    assert Backoffice.Guardian.decode_and_verify!(context.jwt) == context.claims
  end

  test "verify! with a bad token", context do
    claims = Map.put(context.claims, "exp", Backoffice.Guardian.Utils.timestamp - 10)
    {_, jwt} = context.jose_jwk
                  |> JOSE.JWT.sign(context.jose_jws, claims)
                  |> JOSE.JWS.compact

    assert_raise(RuntimeError, fn() -> Backoffice.Guardian.decode_and_verify!(jwt) end)
  end

  test "serializer" do
    assert Backoffice.Guardian.serializer == Backoffice.Guardian.TestGuardianSerializer
  end

  test "encode_and_sign(object)" do
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign("thinger")

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["typ"] == "access"
    assert claims["aud"] == "thinger"
    assert claims["sub"] == "thinger"
    assert claims["iat"]
    assert claims["exp"] > claims["iat"]
    assert claims["iss"] == Backoffice.Guardian.issuer
  end

  test "encode_and_sign(object, audience)" do
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign("thinger", "my_type")

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["typ"] == "my_type"
    assert claims["aud"] == "thinger"
    assert claims["sub"] == "thinger"
    assert claims["iat"]
    assert claims["exp"] > claims["iat"]
    assert claims["iss"] == Backoffice.Guardian.issuer
  end

  test "encode_and_sign(object, type, claims)" do
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      some: "thing"
    )

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["typ"] == "my_type"
    assert claims["aud"] == "thinger"
    assert claims["sub"] == "thinger"
    assert claims["iat"]
    assert claims["exp"] > claims["iat"]
    assert claims["iss"] == Backoffice.Guardian.issuer
    assert claims["some"] == "thing"
  end

  test "encode_and_sign(object, aud) with ttl" do
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      ttl: {5, :days}
    )

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["exp"] == claims["iat"] + 5 * 24 * 60 * 60
  end

  test "encode_and_sign(object, aud) with ttl in claims" do
    claims = Backoffice.Guardian.Claims.app_claims
    |> Backoffice.Guardian.Claims.ttl({5, :days})

    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign("thinger", "my_type", claims)

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["exp"] == claims["iat"] + 5 * 24 * 60 * 60
  end

  test "encode_and_sign(object, aud) with ttl, number and period as binaries" do
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      ttl: {"5", "days"}
    )

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["exp"] == claims["iat"] + 5 * 24 * 60 * 60
  end

  test "encode_and_sign(object, aud) with ttl in claims, number and period as binaries" do
    claims = Backoffice.Guardian.Claims.app_claims
    |> Backoffice.Guardian.Claims.ttl({"5", "days"})

    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign("thinger", "my_type", claims)

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["exp"] == claims["iat"] + 5 * 24 * 60 * 60
  end

  test "encode_and_sign(object, aud) with exp and iat" do
    iat = Backoffice.Guardian.Utils.timestamp - 100
    exp = Backoffice.Guardian.Utils.timestamp + 100

    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      %{"exp" => exp, "iat" => iat})

    {:ok, claims} = Backoffice.Guardian.decode_and_verify(jwt)
    assert claims["exp"] == exp
    assert claims["iat"] == iat
  end

  test "encode_and_sign with a serializer error" do
    {:error, reason} = Backoffice.Guardian.encode_and_sign(%{error: :unknown})
    assert reason
  end

  test "encode_and_sign calls before_encode_and_sign hook" do
    {:ok, _, _} = Backoffice.Guardian.encode_and_sign("before_encode_and_sign", "send")
    assert_received :before_encode_and_sign
  end

  test "encode_and_sign calls before_encode_and_sign hook w/ error" do
    {:error, reason} = Backoffice.Guardian.encode_and_sign("before_encode_and_sign", "error")
    assert reason == "before_encode_and_sign_error"
  end

  test "encode_and_sign calls after_encode_and_sign hook" do
    {:ok, _, _} = Backoffice.Guardian.encode_and_sign("after_encode_and_sign", "send")
    assert_received :after_encode_and_sign
  end

  test "encode_and_sign calls after_encode_and_sign hook w/ error" do
    {:error, reason} = Backoffice.Guardian.encode_and_sign("after_encode_and_sign", "error")
    assert reason == "after_encode_and_sign_error"
  end

  test "encode_and_sign with custom secret" do
    secret = "ABCDEF"
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      some: "thing",
      secret: secret
    )

    {:error, :invalid_token} = Backoffice.Guardian.decode_and_verify(jwt)
    {:ok, _claims} = Backoffice.Guardian.decode_and_verify(jwt, %{secret: secret})
  end

  test "encode_and_sign custom headers and custom secret %JOSE.JWK{} struct", context do
    secret = context.es512.jwk
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      headers: %{"alg" => "ES512"},
      some: "thing",
      secret: secret
    )

    {:error, :invalid_token} = Backoffice.Guardian.decode_and_verify(jwt)
    {:ok, _claims} = Backoffice.Guardian.decode_and_verify(jwt, %{secret: secret})
  end

  test "encode_and_sign custom headers and custom secret function without args" do
    secret = {Backoffice.Guardian.TestHelper, :secret_key_function}
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      some: "thing",
      secret: secret
    )

    {:error, :invalid_token} = Backoffice.Guardian.decode_and_verify(jwt)
    {:ok, _claims} = Backoffice.Guardian.decode_and_verify(jwt, %{secret: secret})
  end

  test "encode_and_sign custom headers and custom secret function with args", context do
    secret = {Backoffice.Guardian.TestHelper, :secret_key_function, [context.es512.jwk]}
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      headers: %{"alg" => "ES512"},
      some: "thing",
      secret: secret
    )

    {:error, :invalid_token} = Backoffice.Guardian.decode_and_verify(jwt)
    {:ok, _claims} = Backoffice.Guardian.decode_and_verify(jwt, %{secret: secret})
  end

  test "encode_and_sign custom headers and custom secret map", context do
    secret = context.es512.jwk |> JOSE.JWK.to_map |> elem(1)
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      headers: %{"alg" => "ES512"},
      some: "thing",
      secret: secret
    )

    {:error, :invalid_token} = Backoffice.Guardian.decode_and_verify(jwt)
    {:ok, _claims} = Backoffice.Guardian.decode_and_verify(jwt, %{secret: secret})
  end

  test "peeking at the headers" do
    secret = "ABCDEF"
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      some: "thing",
      secret: secret,
      headers: %{"foo" => "bar"}
    )

    header = Backoffice.Guardian.peek_header(jwt)
    assert header["foo"] == "bar"
  end

  test "peeking at the payload" do
    secret = "ABCDEF"
    {:ok, jwt, _} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      some: "thing",
      secret: secret,
      headers: %{"foo" => "bar"}
    )

    header = Backoffice.Guardian.peek_claims(jwt)
    assert header["some"] == "thing"
  end

  test "revoke" do
    {:ok, jwt, claims} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      some: "thing"
    )

    assert Backoffice.Guardian.revoke!(jwt, claims) == :ok
  end

  test "refresh" do

    old_claims = Backoffice.Guardian.Claims.app_claims
                 |> Map.put("iat", Backoffice.Guardian.Utils.timestamp - 100)
                 |> Map.put("exp", Backoffice.Guardian.Utils.timestamp + 100)

    {:ok, jwt, claims} = Backoffice.Guardian.encode_and_sign(
      "thinger",
      "my_type",
      old_claims
    )

    {:ok, new_jwt, new_claims} = Backoffice.Guardian.refresh!(jwt, claims)

    refute jwt == new_jwt

    refute Map.get(new_claims, "jti") == nil
    refute Map.get(new_claims, "jti") == Map.get(claims, "jti")

    refute Map.get(new_claims, "iat") == nil
    refute Map.get(new_claims, "iat") == Map.get(claims, "iat")

    refute Map.get(new_claims, "exp") == nil
    refute Map.get(new_claims, "exp") == Map.get(claims, "exp")
  end

  test "exchange" do
      {:ok, jwt, claims} = Backoffice.Guardian.encode_and_sign("thinger", "refresh")

      {:ok, new_jwt, new_claims} = Backoffice.Guardian.exchange(jwt, "refresh", "access")

      refute jwt == new_jwt
      refute Map.get(new_claims, "jti") == nil
      refute Map.get(new_claims, "jti") == Map.get(claims, "jti")

      refute Map.get(new_claims, "exp") == nil
      refute Map.get(new_claims, "exp") == Map.get(claims, "exp")
      assert Map.get(new_claims, "typ") == "access"
    end

    test "exchange with claims" do
      {:ok, jwt, claims} = Backoffice.Guardian.encode_and_sign("thinger", "refresh", some: "thing")

      {:ok, new_jwt, new_claims} = Backoffice.Guardian.exchange(jwt, "refresh", "access")

      refute jwt == new_jwt
      refute Map.get(new_claims, "jti") == nil
      refute Map.get(new_claims, "jti") == Map.get(claims, "jti")

      refute Map.get(new_claims, "exp") == nil
      refute Map.get(new_claims, "exp") == Map.get(claims, "exp")
      assert Map.get(new_claims, "typ") == "access"
      assert Map.get(new_claims, "some") == "thing"
    end

    test "exchange with list of from typs" do
      {:ok, jwt, claims} = Backoffice.Guardian.encode_and_sign("thinger", "rememberMe")

      {:ok, new_jwt, new_claims} = Backoffice.Guardian.exchange(jwt, ["refresh", "rememberMe"], "access")

      refute jwt == new_jwt
      refute Map.get(new_claims, "jti") == nil
      refute Map.get(new_claims, "jti") == Map.get(claims, "jti")

      refute Map.get(new_claims, "exp") == nil
      refute Map.get(new_claims, "exp") == Map.get(claims, "exp")
      assert Map.get(new_claims, "typ") == "access"
    end

    test "exchange with atom typ" do
      {:ok, jwt, claims} = Backoffice.Guardian.encode_and_sign("thinger", "refresh")

      {:ok, new_jwt, new_claims} = Backoffice.Guardian.exchange(jwt, :refresh, :access)

      refute jwt == new_jwt
      refute Map.get(new_claims, "jti") == nil
      refute Map.get(new_claims, "jti") == Map.get(claims, "jti")

      refute Map.get(new_claims, "exp") == nil
      refute Map.get(new_claims, "exp") == Map.get(claims, "exp")
      assert Map.get(new_claims, "typ") == "access"
    end

    test "exchange with a wrong from typ" do
      {:ok, jwt, _claims} = Backoffice.Guardian.encode_and_sign("thinger")
      assert  Backoffice.Guardian.exchange(jwt, "refresh", "access") == {:error, :incorrect_token_type}
  end

end
