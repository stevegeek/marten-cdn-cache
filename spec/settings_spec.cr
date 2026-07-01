require "./spec_helper"

describe Marten::CDNCache::Settings do
  it "is reachable through the typed accessor" do
    Marten::CDNCache.settings.should be_a Marten::CDNCache::Settings
  end

  it "defaults to enabled with no rules and a private default policy" do
    settings = Marten::CDNCache.settings
    settings.enabled.should be_true
    settings.rules.should be_empty
    settings.default_policy.cache_control_header.should eq "private, no-store"
  end

  it "accepts rules and a custom default policy" do
    settings = Marten::CDNCache.settings
    settings.rules = [
      Marten::CDNCache::Rule.path_prefix("/assets/", Marten::CDNCache::Policy.immutable_asset),
    ]
    settings.default_policy = Marten::CDNCache::Policy.public_cached(max_age: 60)

    Marten::CDNCache.settings.rules.size.should eq 1
    Marten::CDNCache.settings.default_policy.cache_control_header.should eq "public, max-age=60"
  end

  it "resets back to defaults" do
    Marten::CDNCache.settings.enabled = false
    Marten::CDNCache.settings.reset!
    Marten::CDNCache.settings.enabled.should be_true
  end
end
