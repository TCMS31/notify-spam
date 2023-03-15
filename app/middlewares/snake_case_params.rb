# frozen_string_literal: true

# The mail provider posts PascalCase keys ("RecordType", "TypeCode", "BouncedAt")
# while Active Record wants snake_case. Normalising once at the edge keeps every
# layer below it idiomatic Ruby.
#
# Only bodies the app can actually parse are touched, and a malformed body is
# left alone so Rails can turn it into a 400 rather than an opaque 500 raised
# from inside middleware.
class SnakeCaseParams
  def initialize(app)
    @app = app
  end

  def call(env)
    normalize!(ActionDispatch::Request.new(env))
    @app.call(env)
  end

  private

  def normalize!(request)
    request.request_parameters.deep_transform_keys! { |key| underscore(key) }
    request.query_parameters.deep_transform_keys! { |key| underscore(key) }
  rescue ActionDispatch::Http::Parameters::ParseError
    # Malformed body: nothing to normalize. ActionDispatch renders a 400.
    nil
  end

  def underscore(key)
    key.respond_to?(:underscore) ? key.underscore : key
  end
end
