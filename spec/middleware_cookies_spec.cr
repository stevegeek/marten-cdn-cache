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

private def public_rule(path : String) : Marten::CDNCache::Rule
  Marten::CDNCache::Rule.path_prefix(path, Marten::CDNCache::Policy.public_cached(max_age: 300))
end

describe Marten::CDNCache::Middleware do
  describe "cookie stripping on public responses" do
    it "drops the session Set-Cookie and scrubs Cookie from Vary" do
      Marten::CDNCache.settings.rules = [public_rule("/blog")]

      response = Marten::HTTP::Response.new("blog")
      response.cookies.set(Marten.settings.sessions.cookie_name, "abc")
      response.headers["Vary"] = "Accept-Encoding, Cookie"

      run_middleware(request_for("/blog"), response)

      response.cookies.pending_set_cookies.map(&.name)
        .should_not contain Marten.settings.sessions.cookie_name
      response.headers["Vary"].should eq "Accept-Encoding"
    end

    it "deletes Vary entirely when Cookie was the only token" do
      Marten::CDNCache.settings.rules = [public_rule("/blog")]

      response = Marten::HTTP::Response.new("blog")
      response.headers["Vary"] = "Cookie"

      run_middleware(request_for("/blog"), response)

      response.headers["Vary"]?.should be_nil
    end
  end

  describe "private responses" do
    it "never strips cookies" do
      response = Marten::HTTP::Response.new("contact form")
      response.cookies.set(Marten.settings.sessions.cookie_name, "abc")

      run_middleware(request_for("/contact"), response)

      response.cookies.pending_set_cookies.map(&.name)
        .should contain Marten.settings.sessions.cookie_name
      response.headers["Cache-Control"].should eq "private, no-store"
    end
  end

  describe "CSRF safety net" do
    it "downgrades to no-store and keeps the CSRF cookie on a public-marked route" do
      Marten::CDNCache.settings.rules = [public_rule("/blog")]

      response = Marten::HTTP::Response.new("blog")
      response.cookies.set(Marten.settings.csrf.cookie_name, "tok")

      run_middleware(request_for("/blog"), response)

      response.headers["Cache-Control"].should eq "private, no-store"
      response.cookies.pending_set_cookies.map(&.name)
        .should contain Marten.settings.csrf.cookie_name
    end
  end
end
