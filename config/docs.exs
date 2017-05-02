use Mix.Config

config :guardian, Backoffice.Guardian,
      issuer: "MyApp",
      ttl: { 1, :days },
      verify_issuer: true,
      secret_key: "woiuerojksldkjoierwoiejrlskjdf",
      serializer: Backoffice.Guardian.TestGuardianSerializer
