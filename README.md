# marten-cdn-cache

A Marten middleware that makes pages CDN-cacheable (Cloudflare/CloudFront) by
(a) setting `Cache-Control` per a route/path policy and (b) stripping
`Set-Cookie` on **public** responses. Marten's Session/Flash middlewares add a
`Set-Cookie` to every response, which makes a CDN refuse to cache it
(`cf-cache-status: BYPASS`); this middleware removes it — but only on responses
you have explicitly marked public.

The default is conservative: every response is `private, no-store` until a rule
or handler concern opts it into public caching. A session/CSRF cookie is never
dropped on a private (form/admin/booking) response.

## Install

```yaml
# shard.yml
dependencies:
  marten_cdn_cache:
    github: stevegeek/marten-cdn-cache
```

```crystal
# src/project.cr
require "marten_cdn_cache"
```

## Configure

```crystal
# config/settings/base.cr
Marten.configure do |config|
  config.middleware = [
    Marten::CDNCache::Middleware,   # OUTERMOST — see ordering note below
    Marten::Middleware::GZip,
    Marten::Middleware::Session,
    Marten::Middleware::Flash,
    Marten::Middleware::I18n,
  ]
end

# config/initializers/cdn_cache.cr
Marten::CDNCache.settings.rules = [
  Marten::CDNCache::Rule.path_prefix("/assets/", Marten::CDNCache::Policy.immutable_asset),
  Marten::CDNCache::Rule.route_name("blog_index", Marten::CDNCache::Policy.public_cached(max_age: 300, s_maxage: 86_400)),
  Marten::CDNCache::Rule.predicate(Marten::CDNCache::Policy.private_no_store) { |r| r.path.starts_with?("/admin") },
]
# Everything else falls through to the default: private, no-store.
```

Per-handler overrides:

```crystal
class BlogIndex < Marten::Handler
  include Marten::CDNCache::Cacheable
  cacheable Marten::CDNCache::Policy.public_cached(max_age: 300)
end

class ContactForm < Marten::Handler
  include Marten::CDNCache::Uncacheable   # always private, no-store
end
```

## Middleware ordering — the `AssetServing` trap

`Marten::CDNCache::Middleware` must be the **outermost** middleware (first in
`config.middleware`) so it processes the response **last** — after Session/Flash
have set their cookies (Marten runs the chain head-first and unwinds).

In production, `Marten::Middleware::AssetServing` **short-circuits** asset paths:
it returns its own `Cache-Control: private, max-age=…` response and does *not*
call the rest of the chain. If you register `AssetServing` outermost
(`config.middleware.unshift(Marten::Middleware::AssetServing)`), the cache
middleware sits *inside* it and never sees asset responses — every asset ships
`private` and the CDN refuses to cache it.

Fix: keep the cache middleware at index 0 and insert `AssetServing` **after** it:

```crystal
# config/settings/production.cr
config.middleware.insert(1, Marten::Middleware::AssetServing)
```

**Dev hides this.** In dev/test, assets are served by a route handler through
the full chain, so it looks fine. The bug only appears in production mode.
Verify with a real run, not the dev server or specs:

```sh
MARTEN_ENV=production bin/server &
curl -sD- http://localhost:8000/assets/app.<hash>.css -o /dev/null
# Expect: Cache-Control: public, max-age=31536000, immutable
#         no Set-Cookie
```

## Scope

In: per-route `Cache-Control` + public-only cookie stripping. Out: the cache
*store* (Marten built-in), fragment caching (`{% cache %}`), and CDN *purge*
(deploy-time script).
