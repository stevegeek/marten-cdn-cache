module Marten::CDNCache
  # Application settings for the CDN-cache middleware, exposed under the
  # `cdn_cache` namespace (`Marten.settings.cdn_cache`). Read them through the
  # typed `Marten::CDNCache.settings` helper.
  class Settings < Marten::Conf::Settings
    namespace :cdn_cache

    property enabled : Bool = true
    property rules : Array(Rule) = [] of Rule

    @default_policy : Policy?

    # The policy applied when no rule matches. Conservative by default.
    def default_policy : Policy
      @default_policy ||= Policy.private_no_store
    end

    def default_policy=(policy : Policy) : Policy
      @default_policy = policy
    end

    # Restores defaults. Used to isolate specs that mutate global settings.
    def reset! : Nil
      @enabled = true
      @rules = [] of Rule
      @default_policy = nil
    end
  end
end
