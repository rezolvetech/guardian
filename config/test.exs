use Mix.Config

config :bo_guardian, Backoffice.Guardian,
      issuer: "MyApp",
      allowed_algos: ["HS512", "ES512"],
      token_ttl: %{
        "refresh" => { 30, :days },
        "access" =>  {1, :days}
      },
      ttl: {2, :days},
      allowed_drift: 2000,
      verify_issuer: true,
      secret_key: "woiuerojksldkjoierwoiejrlskjdf",
      serializer: Backoffice.Guardian.TestGuardianSerializer,
      hooks: Backoffice.Guardian.Hooks.Test,
      system_foo: {:system, "FOO"},
      permissions: %{
        default: [:read, :write, :update, :delete],
        other: [:other_read, :other_write, :other_update, :other_delete]
      }
