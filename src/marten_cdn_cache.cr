require "marten"

# CDN-friendly cache-control middleware for Marten.
#
# Sets `Cache-Control` per a route/path policy and strips `Set-Cookie` on
# *public* responses so a CDN (Cloudflare/CloudFront) will cache them. The
# default is conservative — `private, no-store` — and routes opt INTO public
# caching via settings rules or handler concerns.
module Marten::CDNCache
  VERSION = "0.1.0"
end
