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

private def run_middleware(request : Marten::HTTP::Request, response : Marten::HTTP::Response) : Marten::HTTP::Response
  Marten::CDNCache::Middleware.new.call(request, ->{ response })
end

describe Marten::CDNCache::Middleware do
  describe "#call default policy" do
    it "applies private, no-store when no rule matches" do
      response = run_middleware(request_for("/unknown"), Marten::HTTP::Response.new("body"))
      response.headers["Cache-Control"].should eq "private, no-store"
    end
  end

  describe "#call rule matching" do
    it "applies the policy of the first matching rule" do
      Marten::CDNCache.settings.rules = [
        Marten::CDNCache::Rule.path_prefix("/assets/", Marten::CDNCache::Policy.immutable_asset),
        Marten::CDNCache::Rule.route_name("blog_index", Marten::CDNCache::Policy.public_cached(max_age: 300)),
      ]

      assets = run_middleware(request_for("/assets/app.css"), Marten::HTTP::Response.new("css"))
      assets.headers["Cache-Control"].should eq "public, max-age=31536000, immutable"

      blog = run_middleware(request_for("/blog"), Marten::HTTP::Response.new("blog"))
      blog.headers["Cache-Control"].should eq "public, max-age=300"
    end
  end

  describe "#call method guard" do
    it "never makes a non-GET/HEAD request public" do
      Marten::CDNCache.settings.rules = [
        Marten::CDNCache::Rule.route_name("contact", Marten::CDNCache::Policy.public_cached(max_age: 300)),
      ]

      response = run_middleware(request_for("/contact", method: "POST"), Marten::HTTP::Response.new("ok"))
      response.headers["Cache-Control"].should eq "private, no-store"
    end

    it "allows HEAD to be public" do
      Marten::CDNCache.settings.rules = [
        Marten::CDNCache::Rule.path_prefix("/blog", Marten::CDNCache::Policy.public_cached(max_age: 300)),
      ]
      response = run_middleware(request_for("/blog", method: "HEAD"), Marten::HTTP::Response.new(""))
      response.headers["Cache-Control"].should eq "public, max-age=300"
    end
  end

  describe "#call when disabled" do
    it "leaves the response untouched" do
      Marten::CDNCache.settings.enabled = false
      response = run_middleware(request_for("/unknown"), Marten::HTTP::Response.new("body"))
      response.headers["Cache-Control"]?.should be_nil
    end
  end
end
