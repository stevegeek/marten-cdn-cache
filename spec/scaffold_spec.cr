require "./spec_helper"

describe Marten::CDNCache do
  it "exposes its version" do
    Marten::CDNCache::VERSION.should eq "0.1.1"
  end
end
