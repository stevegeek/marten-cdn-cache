module Marten::CDNCache
  # A single classification rule: a matcher over the request + the `Policy` to
  # apply when it matches. Build one with `.path_prefix`, `.route_name`, or
  # `.predicate`. The middleware tries rules in order; first match wins.
  class Rule
    alias Matcher = Proc(Marten::HTTP::Request, Bool)

    getter policy : Policy

    def initialize(@matcher : Matcher, @policy : Policy)
    end

    # Matches any request whose path starts with `prefix` (e.g. `/assets/`).
    def self.path_prefix(prefix : String, policy : Policy) : Rule
      new(->(request : Marten::HTTP::Request) { request.path.starts_with?(prefix) }, policy)
    end

    # Matches a request that resolves to the handler of the named route.
    #
    # Limitation: only parameterless named routes are supported (the marketing /
    # blog / static-page case). Routes that require parameters cannot be reversed
    # without them — use `.path_prefix` or `.predicate` for those.
    def self.route_name(name : String, policy : Policy) : Rule
      # Resolve the handler class once at construction — it's stable after
      # startup. Per-request matching then only needs one resolve() call.
      # If the route is unknown at construction time, target is nil and the
      # matcher safely returns false without crashing.
      target = Marten::CDNCache.route_handler_for(name)
      new(
        ->(request : Marten::HTTP::Request) do
          return false if target.nil?
          begin
            Marten.routes.resolve(request.path).handler == target
          rescue Marten::Routing::Errors::NoResolveMatch
            false
          end
        end,
        policy,
      )
    end

    # Matches when the supplied block returns true for the request.
    def self.predicate(policy : Policy, &block : Marten::HTTP::Request -> Bool) : Rule
      new(block, policy)
    end

    def matches?(request : Marten::HTTP::Request) : Bool
      @matcher.call(request)
    end
  end
end
