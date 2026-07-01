Marten.routes.draw do
  path "/blog", Test::BlogIndexHandler, name: "blog_index"
  path "/contact", Test::ContactHandler, name: "contact"
end
