require "./spec_helper"

private def request_for(path : String, method : String = "GET") : Marten::HTTP::Request
  Marten::HTTP::Request.new(
    ::HTTP::Request.new(
      method: method,
      resource: path,
      headers: HTTP::Headers{"Host" => "example.com"},
    )
  )
end

describe Marten::CDNCache::Rule do
  policy = Marten::CDNCache::Policy.public_cached(max_age: 300)

  describe ".path_prefix" do
    it "matches a request whose path starts with the prefix" do
      rule = Marten::CDNCache::Rule.path_prefix("/assets/", policy)
      rule.matches?(request_for("/assets/app.css")).should be_true
    end

    it "does not match a different path" do
      rule = Marten::CDNCache::Rule.path_prefix("/assets/", policy)
      rule.matches?(request_for("/blog")).should be_false
    end
  end

  describe ".predicate" do
    it "matches when the block returns true" do
      rule = Marten::CDNCache::Rule.predicate(policy) { |request| request.method == "GET" }
      rule.matches?(request_for("/anything")).should be_true
    end

    it "does not match when the block returns false" do
      rule = Marten::CDNCache::Rule.predicate(policy) { |request| request.method == "POST" }
      rule.matches?(request_for("/anything", method: "GET")).should be_false
    end
  end

  describe ".route_name" do
    it "matches a request resolving to the named route's handler" do
      rule = Marten::CDNCache::Rule.route_name("blog_index", policy)
      rule.matches?(request_for("/blog")).should be_true
    end

    it "does not match a different route" do
      rule = Marten::CDNCache::Rule.route_name("blog_index", policy)
      rule.matches?(request_for("/contact")).should be_false
    end

    it "does not match an unresolvable path" do
      rule = Marten::CDNCache::Rule.route_name("blog_index", policy)
      rule.matches?(request_for("/assets/app.css")).should be_false
    end
  end

  it "exposes its policy" do
    Marten::CDNCache::Rule.path_prefix("/x", policy).policy.should eq policy
  end
end
