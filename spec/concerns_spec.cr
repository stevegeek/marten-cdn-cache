require "./spec_helper"

describe "handler cache concerns" do
  describe Marten::CDNCache::Cacheable do
    it "makes the handler's response public via the internal header" do
      response = Marten::Spec.client.get("/cached")
      response.headers["Cache-Control"].should eq "public, max-age=600"
    end

    it "never leaks the internal policy header to the client" do
      response = Marten::Spec.client.get("/cached")
      response.headers[Marten::CDNCache::Middleware::INTERNAL_POLICY_HEADER]?.should be_nil
    end

    it "wins over a conflicting settings rule" do
      Marten::CDNCache.settings.rules = [
        Marten::CDNCache::Rule.path_prefix("/cached", Marten::CDNCache::Policy.private_no_store),
      ]
      response = Marten::Spec.client.get("/cached")
      response.headers["Cache-Control"].should eq "public, max-age=600"
    end
  end

  describe Marten::CDNCache::Uncacheable do
    it "forces private, no-store even when a rule says public" do
      Marten::CDNCache.settings.rules = [
        Marten::CDNCache::Rule.path_prefix("/never", Marten::CDNCache::Policy.public_cached(max_age: 300)),
      ]
      response = Marten::Spec.client.get("/never")
      response.headers["Cache-Control"].should eq "private, no-store"
    end
  end
end
