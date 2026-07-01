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
end
