ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "shoulda/context"

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    VULNERABLE_LOCKFILE = <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          nokogiri (1.5.0)

      PLATFORMS
        ruby

      DEPENDENCIES
        nokogiri

      BUNDLED WITH
         2.5.0
    LOCK

    STORED_DB_TIME = Time.utc(2026, 10, 1, 12, 30)

    # Only tests that reach the advisory db fetch (a git pull) need this.
    def stub_advisory_refresh!(warning: nil, &block)
      refresh = AdvisoryDatabase::Refresh.new(updated_at: STORED_DB_TIME, warning: warning)
      AdvisoryDatabase.stub(:refresh, refresh, &block)
    end
  end
end
