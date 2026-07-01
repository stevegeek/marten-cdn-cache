require "./spec_helper"

describe Marten::HTTP::Cookies do
  describe "#pending_set_cookies" do
    it "exposes cookies queued as Set-Cookie" do
      cookies = Marten::HTTP::Cookies.new
      cookies.set("sessionid", "abc")

      names = cookies.pending_set_cookies.map(&.name)
      names.should contain "sessionid"
    end
  end

  describe "#drop_set_cookie" do
    it "removes a pending Set-Cookie without queueing an expiry cookie" do
      cookies = Marten::HTTP::Cookies.new
      cookies.set("sessionid", "abc")

      cookies.drop_set_cookie("sessionid")

      cookies.pending_set_cookies.map(&.name).should_not contain "sessionid"
    end

    it "is a no-op when the named cookie was never set" do
      cookies = Marten::HTTP::Cookies.new
      cookies.set("other", "x")

      cookies.drop_set_cookie("sessionid")

      cookies.pending_set_cookies.map(&.name).should eq ["other"]
    end
  end
end
