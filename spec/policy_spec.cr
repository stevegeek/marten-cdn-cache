require "./spec_helper"

describe Marten::CDNCache::Policy do
  describe "#initialize" do
    it "defaults to a conservative private policy" do
      policy = Marten::CDNCache::Policy.new
      policy.visibility.should eq :private
      policy.public?.should be_false
      policy.strip_cookies.should be_false
    end

    it "rejects an unknown visibility" do
      expect_raises(ArgumentError, /visibility/) do
        Marten::CDNCache::Policy.new(visibility: :secret)
      end
    end
  end

  describe "#cache_control_header" do
    it "renders private + no max-age as no-store" do
      Marten::CDNCache::Policy.private_no_store.cache_control_header.should eq "private, no-store"
    end

    it "renders private + max-age" do
      policy = Marten::CDNCache::Policy.new(visibility: :private, max_age: 60)
      policy.cache_control_header.should eq "private, max-age=60"
    end

    it "renders a public page policy with s-maxage" do
      policy = Marten::CDNCache::Policy.public_cached(max_age: 300, s_maxage: 86_400)
      policy.cache_control_header.should eq "public, max-age=300, s-maxage=86400"
    end

    it "renders an immutable asset policy" do
      Marten::CDNCache::Policy.immutable_asset.cache_control_header
        .should eq "public, max-age=31536000, immutable"
    end
  end

  describe "convenience constructors" do
    it "public_cached strips cookies by default" do
      Marten::CDNCache::Policy.public_cached(max_age: 300).strip_cookies.should be_true
    end

    it "immutable_asset is public and strips cookies" do
      policy = Marten::CDNCache::Policy.immutable_asset
      policy.public?.should be_true
      policy.strip_cookies.should be_true
    end
  end

  describe "serialization" do
    it "round-trips a public policy" do
      original = Marten::CDNCache::Policy.public_cached(max_age: 300, s_maxage: 86_400, immutable: true)
      restored = Marten::CDNCache::Policy.deserialize(original.serialize)

      restored.visibility.should eq :public
      restored.max_age.should eq 300
      restored.s_maxage.should eq 86_400
      restored.immutable.should be_true
      restored.strip_cookies.should be_true
    end

    it "round-trips a private no-store policy" do
      restored = Marten::CDNCache::Policy.deserialize(Marten::CDNCache::Policy.private_no_store.serialize)
      restored.public?.should be_false
      restored.max_age.should be_nil
    end
  end
end
