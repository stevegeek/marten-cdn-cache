Marten.routes.draw do
  path "/blog", Test::BlogIndexHandler, name: "blog_index"
  path "/contact", Test::ContactHandler, name: "contact"
  path "/cached", Test::CachedPageHandler, name: "cached_page"
  path "/never", Test::NeverCacheHandler, name: "never_cache"
  path "/session-page", Test::SessionPageHandler, name: "session_page"
end
