ENV["MARTEN_ENV"] = "test"

require "spec"
require "sqlite3"
require "../src/marten_cdn_cache"
require "marten/spec"

require "./test_project/app"

# Fixed test secret — reproducible failures beat per-run randomness. Must stay
# >= 32 bytes to satisfy Marten's secret-key length guidance.
SPEC_SECRET_KEY = "__insecure_spec_secret_DO_NOT_USE__"

Marten.configure :test do |config|
  config.secret_key = SPEC_SECRET_KEY
  config.log_level = ::Log::Severity::None

  config.installed_apps = [MartenCDNCacheSpecApp]

  config.database do |db|
    db.backend = :sqlite
    db.name = ":memory:"
  end
end
