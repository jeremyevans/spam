require 'coverage'

Coverage.start(methods: true)

require_relative(ARGV[0])

Minitest.after_run do
  Spam::Model.update_associations_coverage
end
