require "./spec_helper"

describe "marten-cdn-cache integration" do
  it "strips the session Set-Cookie on a public route end-to-end" do
    Marten::CDNCache.settings.rules = [
      Marten::CDNCache::Rule.route_name("session_page", Marten::CDNCache::Policy.public_cached(max_age: 300)),
    ]

    response = Marten::Spec.client.get("/session-page")

    response.headers["Cache-Control"].should eq "public, max-age=300"
    response.cookies.pending_set_cookies.map(&.name)
      .should_not contain Marten.settings.sessions.cookie_name
  end

  it "keeps the session Set-Cookie on a private route end-to-end" do
    # No rule → default private/no-store.
    response = Marten::Spec.client.get("/session-page")

    response.headers["Cache-Control"].should eq "private, no-store"
    response.cookies.pending_set_cookies.map(&.name)
      .should contain Marten.settings.sessions.cookie_name
  end
end
