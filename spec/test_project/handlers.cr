module Test
  class BlogIndexHandler < Marten::Handler
    def get
      respond("blog index")
    end
  end

  class ContactHandler < Marten::Handler
    def get
      respond("contact form")
    end
  end

  class CachedPageHandler < Marten::Handler
    include Marten::CDNCache::Cacheable
    cacheable Marten::CDNCache::Policy.public_cached(max_age: 600)

    def get
      respond("cached page")
    end
  end

  class NeverCacheHandler < Marten::Handler
    include Marten::CDNCache::Uncacheable

    def get
      respond("never cached")
    end
  end

  # Touches the session so Session middleware emits a Set-Cookie, letting the
  # integration spec prove the cookie is stripped on a public response.
  class SessionPageHandler < Marten::Handler
    def get
      request.session[:visited] = "1"
      respond("session page")
    end
  end
end
