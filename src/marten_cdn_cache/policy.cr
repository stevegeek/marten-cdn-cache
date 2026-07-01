module Marten::CDNCache
  # An immutable description of how a response should be cached.
  #
  # `visibility` is `:public` (CDN-cacheable) or `:private`. A private policy
  # with no `max_age` renders as `private, no-store` — the conservative default.
  # `strip_cookies` is only ever honored by the middleware on public responses.
  struct Policy
    VALID_VISIBILITIES = {:public, :private}

    getter visibility : Symbol
    getter max_age : Int32?
    getter s_maxage : Int32?
    getter immutable : Bool
    getter strip_cookies : Bool

    def initialize(
      @visibility : Symbol = :private,
      @max_age : Int32? = nil,
      @s_maxage : Int32? = nil,
      @immutable : Bool = false,
      @strip_cookies : Bool = false,
    )
      unless VALID_VISIBILITIES.includes?(@visibility)
        raise ArgumentError.new("Invalid visibility #{@visibility.inspect}; expected :public or :private")
      end
    end

    # The conservative default: not cacheable anywhere.
    def self.private_no_store : Policy
      new(visibility: :private)
    end

    # A public, CDN-cacheable page policy. Strips cookies by default since the
    # response is going to a shared cache.
    def self.public_cached(
      max_age : Int32,
      s_maxage : Int32? = nil,
      immutable : Bool = false,
      strip_cookies : Bool = true,
    ) : Policy
      new(
        visibility: :public,
        max_age: max_age,
        s_maxage: s_maxage,
        immutable: immutable,
        strip_cookies: strip_cookies,
      )
    end

    # A long-lived immutable asset policy (content-fingerprinted files).
    def self.immutable_asset(max_age : Int32 = 31_536_000) : Policy
      new(visibility: :public, max_age: max_age, immutable: true, strip_cookies: true)
    end

    def public? : Bool
      visibility == :public
    end

    # Renders the `Cache-Control` header value for this policy.
    def cache_control_header : String
      if public?
        String.build do |io|
          io << "public"
          io << ", max-age=" << max_age if max_age
          io << ", s-maxage=" << s_maxage if s_maxage
          io << ", immutable" if immutable
        end
      elsif age = max_age
        "private, max-age=#{age}"
      else
        "private, no-store"
      end
    end

    # Compact serialization used to carry a handler-selected policy through an
    # internal response header (see `Cacheable`/`Uncacheable`). Never sent to
    # the client — the middleware deletes the header after reading it.
    def serialize : String
      String.build do |io|
        io << visibility
        io << ";max_age=" << max_age
        io << ";s_maxage=" << s_maxage
        io << ";immutable=" << immutable
        io << ";strip_cookies=" << strip_cookies
      end
    end

    def self.deserialize(value : String) : Policy
      segments = value.split(';')
      visibility = segments.shift? == "public" ? :public : :private

      fields = {} of String => String
      segments.each do |segment|
        key, _, val = segment.partition('=')
        fields[key] = val
      end

      new(
        visibility: visibility,
        max_age: parse_int(fields["max_age"]?),
        s_maxage: parse_int(fields["s_maxage"]?),
        immutable: fields["immutable"]? == "true",
        strip_cookies: fields["strip_cookies"]? == "true",
      )
    end

    private def self.parse_int(value : String?) : Int32?
      return nil if value.nil? || value.empty?
      value.to_i?
    end
  end
end
