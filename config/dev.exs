use Mix.Config

config :bo_guardian, Backoffice.Guardian,
      issuer: "MyApp",
      ttl: { 1, :days },
      token_ttl: %{
        "refresh" => { 30, :days },
        "access" =>  {1, :days}
      },
      verify_issuer: true,
      secret_key: "woiuerojksldkjoierwoiejrlskjdf",
      serializer: Backoffice.Guardian.TestGuardianSerializer
