ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    def sign_in_as(user)
      session_record = user.sessions.create!(user_agent: "TestAgent", ip_address: "127.0.0.1")
      post "/session", params: { email_address: user.email_address, password: "password" }
      session_record
    end
  end
end
