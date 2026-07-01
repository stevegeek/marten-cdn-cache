module Marten::CDNCache
  # Handler concern: opt a handler INTO a public cache policy.
  #
  # ```
  # class BlogIndex < Marten::Handler
  #   include Marten::CDNCache::Cacheable
  #   cacheable Marten::CDNCache::Policy.public_cached(max_age: 300, s_maxage: 86_400)
  # end
  # ```
  #
  # On `after_dispatch` it stores the selected policy in an internal response
  # header that `Marten::CDNCache::Middleware` reads (and deletes) on the way out.
  module Cacheable
    macro included
      @@cdn_cache_policy : Marten::CDNCache::Policy? = nil

      class_getter cdn_cache_policy

      extend Marten::CDNCache::Cacheable::ClassMethods

      after_dispatch :__cdn_cache_apply_policy
    end

    module ClassMethods
      def cacheable(policy : Marten::CDNCache::Policy) : Nil
        @@cdn_cache_policy = policy
      end
    end

    private def __cdn_cache_apply_policy : Nil
      policy = self.class.cdn_cache_policy
      return if policy.nil?

      response!.headers[Marten::CDNCache::Middleware::INTERNAL_POLICY_HEADER] = policy.serialize
    end
  end

  # Handler concern: force a handler's responses to `private, no-store`,
  # overriding any settings rule. Use on forms / admin / booking handlers.
  module Uncacheable
    macro included
      after_dispatch :__cdn_cache_mark_uncacheable
    end

    private def __cdn_cache_mark_uncacheable : Nil
      response!.headers[Marten::CDNCache::Middleware::INTERNAL_POLICY_HEADER] =
        Marten::CDNCache::Policy.private_no_store.serialize
    end
  end
end
