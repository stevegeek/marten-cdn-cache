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
end
