# Errors the API maps to HTTP statuses (see ApplicationController).
module AppErrors
  class Base < StandardError; end
  class Unauthorized < Base; end # 401: no or bad identity token
  class Forbidden < Base; end    # 403: signed in, but the role does not allow this
  class Conflict < Base; end     # 409: a concurrent or repeated write got there first
  class BadRequest < Base; end   # 422: the request cannot be answered as asked
end
