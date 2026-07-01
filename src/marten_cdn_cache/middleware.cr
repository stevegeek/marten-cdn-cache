module Marten::CDNCache
  # Sets `Cache-Control` per the configured rules and (in Task 7) strips
  # `Set-Cookie` on public responses so a CDN will cache them.
  #
  # Register it as the OUTERMOST middleware (first in `config.middleware`) so it
  # processes the response LAST — after Session/Flash have set their cookies.
  # See the README for the `AssetServing` ordering trap.
  class Middleware < Marten::Middleware
    # Internal-only header by which a handler concern selects a policy. The
    # middleware reads and then DELETES it, so it never reaches the client.
    INTERNAL_POLICY_HEADER = "X-Marten-CDNCache-Policy"

    def call(
      request : Marten::HTTP::Request,
      get_response : Proc(Marten::HTTP::Response),
    ) : Marten::HTTP::Response
      response = get_response.call
      return response unless Marten::CDNCache.settings.enabled

      policy = resolve_policy(request, response)
      response.headers["Cache-Control"] = policy.cache_control_header
      response
    end

    # Determines the policy for this request/response. A handler opt-in/out
    # header (Task 8) wins; otherwise the first matching rule; otherwise the
    # default. A non-GET/HEAD request can never end up public.
    private def resolve_policy(request : Marten::HTTP::Request, response : Marten::HTTP::Response) : Policy
      candidate = candidate_policy(request, response)

      # Hard safety net: only GET/HEAD may ever be public-cached. Anything else
      # (form submit, admin mutation) is forced back to the conservative default.
      if candidate.public? && !cacheable_method?(request)
        return Marten::CDNCache.settings.default_policy
      end

      candidate
    end

    private def candidate_policy(request : Marten::HTTP::Request, response : Marten::HTTP::Response) : Policy
      Marten::CDNCache.settings.rules.each do |rule|
        return rule.policy if rule.matches?(request)
      end
      Marten::CDNCache.settings.default_policy
    end

    private def cacheable_method?(request : Marten::HTTP::Request) : Bool
      method = request.method.upcase
      method == "GET" || method == "HEAD"
    end
  end
end
