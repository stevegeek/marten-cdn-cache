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

      unless Marten::CDNCache.settings.enabled
        # Still scrub the internal header so it never reaches the HTTP client,
        # even when the middleware is disabled (a handler concern may have set it).
        response.headers.delete(INTERNAL_POLICY_HEADER)
        return response
      end

      policy = resolve_policy(request, response)
      apply(policy, response)
      response
    end

    # Determines the policy for this request/response. A handler opt-in/out
    # header (Task 8) wins; otherwise the first matching rule; otherwise the
    # default. A non-GET/HEAD request can never end up public.
    private def resolve_policy(request : Marten::HTTP::Request, response : Marten::HTTP::Response) : Policy
      candidate = candidate_policy(request, response)

      # Hard safety net: only GET/HEAD may ever be public-cached. Anything else
      # (form submit, admin mutation) must be private, no-store unconditionally —
      # never the user-configured default_policy, which may itself be public.
      if candidate.public? && !cacheable_method?(request)
        return Policy.private_no_store
      end

      candidate
    end

    private def candidate_policy(request : Marten::HTTP::Request, response : Marten::HTTP::Response) : Policy
      # A handler opt-in/out (via the internal header) wins over settings rules.
      if header = response.headers[INTERNAL_POLICY_HEADER]?
        response.headers.delete(INTERNAL_POLICY_HEADER)
        return Policy.deserialize(header)
      end

      Marten::CDNCache.settings.rules.each do |rule|
        return rule.policy if rule.matches?(request)
      end
      Marten::CDNCache.settings.default_policy
    end

    private def cacheable_method?(request : Marten::HTTP::Request) : Bool
      method = request.method.upcase
      method == "GET" || method == "HEAD"
    end

    # Applies the resolved policy to the response. On a public + strip_cookies
    # policy it scrubs the session cookie and `Vary: Cookie` so a CDN can cache
    # the response — UNLESS the response still carries a CSRF cookie, in which
    # case it conservatively downgrades to the default (never cache a tokened
    # page, never drop the token).
    private def apply(policy : Policy, response : Marten::HTTP::Response) : Nil
      if policy.public? && policy.strip_cookies && carries_csrf_cookie?(response)
        # CSRF safety net: never cache a response that sets a CSRF token.
        # Use Policy.private_no_store unconditionally — the user-configured
        # default_policy may be public and would defeat this invariant.
        policy = Policy.private_no_store
      end

      response.headers["Cache-Control"] = policy.cache_control_header

      strip_cookies(response) if policy.public? && policy.strip_cookies
    end

    private def carries_csrf_cookie?(response : Marten::HTTP::Response) : Bool
      csrf_name = Marten.settings.csrf.cookie_name
      response.cookies.pending_set_cookies.any? { |cookie| cookie.name == csrf_name }
    end

    # Drops the session `Set-Cookie` and removes `Cookie` from `Vary`. Other
    # `Vary` tokens (`Accept-Encoding`, `Accept-Language`) are preserved.
    private def strip_cookies(response : Marten::HTTP::Response) : Nil
      response.cookies.drop_set_cookie(Marten.settings.sessions.cookie_name)

      vary = response.headers["Vary"]?
      return if vary.nil?

      remaining = vary
        .split(/\s*,\s*/)
        .reject { |token| token.downcase == "cookie" || token.empty? }

      if remaining.empty?
        response.headers.delete("Vary")
      else
        response.headers["Vary"] = remaining.join(", ")
      end
    end
  end
end
