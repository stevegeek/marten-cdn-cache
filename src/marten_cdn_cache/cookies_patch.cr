# Reopen Marten's HTTP cookie store to expose two helpers the cache middleware
# needs: a public read of the pending Set-Cookie list, and a way to drop a
# pending Set-Cookie entirely (without emitting an expiry cookie the way
# `#delete` would — the CDN needs the response to carry no `Set-Cookie` at all).
module Marten
  module HTTP
    class Cookies
      # Public, read-only view of the cookies that will be written as
      # `Set-Cookie` headers for this response.
      def pending_set_cookies : Array(::HTTP::Cookie)
        set_cookies
      end

      # Removes any pending `Set-Cookie` for `name` so it is never emitted.
      #
      # Unlike `#delete`, this does NOT queue an expiry cookie — the goal is for
      # the response to carry no `Set-Cookie` for this name at all.
      def drop_set_cookie(name : String) : Nil
        set_cookies.reject! { |cookie| cookie.name == name }
        cookies.delete(name)
      end
    end
  end
end
