import Config

config :logger, level: :warning

# Integration tests run against a real PostgreSQL database. Create it with:
#   createdb phoenix_kit_comments_test
config :phoenix_kit_comments, ecto_repos: [PhoenixKitComments.Test.Repo]

config :phoenix_kit_comments, PhoenixKitComments.Test.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "phoenix_kit_comments_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# `PhoenixKit.RepoHelper` resolves this — without it every context-layer DB
# call in the module falls into its own rescue and returns a plausible
# nothing, which is exactly how several tests came to assert the rescue.
config :phoenix_kit, repo: PhoenixKitComments.Test.Repo
