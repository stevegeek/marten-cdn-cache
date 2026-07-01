require "marten"
require "./marten_cdn_cache/cookies_patch"
require "./marten_cdn_cache/policy"
require "./marten_cdn_cache/rule"

# CDN-friendly cache-control middleware for Marten.
#
# Sets `Cache-Control` per a route/path policy and strips `Set-Cookie` on
# *public* responses so a CDN (Cloudflare/CloudFront) will cache them. The
# default is conservative — `private, no-store` — and routes opt INTO public
# caching via settings rules or handler concerns.
module Marten::CDNCache
  VERSION = "0.1.0"

  # Resolves a parameterless named route to its handler class. Returns nil if
  # the route does not exist or cannot be reversed without parameters.
  def self.route_handler_for(name : String) : Marten::Handlers::Base.class | Nil
    Marten.routes.resolve(Marten.routes.reverse(name)).handler
  rescue Marten::Routing::Errors::NoReverseMatch | Marten::Routing::Errors::NoResolveMatch
    nil
  end
end
