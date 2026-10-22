require "test_helper"

class AuditRunnerTest < ActiveSupport::TestCase
  context "AuditRunner#call" do
    setup do
      @audit = Audit.new(lockfile: VULNERABLE_LOCKFILE)
    end

    should "store findings for vulnerable gems" do
      stub_advisory_refresh! { AuditRunner.new(@audit).call }

      assert @audit.persisted?
      finding = @audit.results.find { |r| r["type"] == "unpatched_gem" }
      assert finding, "expected at least one advisory for nokogiri 1.5.0"
      assert_equal "nokogiri", finding["gem"]["name"]
      assert_equal "1.5.0", finding["gem"]["version"]
      assert finding["advisory"]["id"].present?
    end

    should "record the advisory db date and no warnings on a clean fetch" do
      stub_advisory_refresh! { AuditRunner.new(@audit).call }

      assert_equal STORED_DB_TIME, @audit.advisory_db_updated_at
      assert_empty @audit.warnings
    end

    should "record the fallback warning" do
      stub_advisory_refresh!(warning: "stale") { AuditRunner.new(@audit).call }

      assert_equal ["stale"], @audit.warnings
    end

    should "flag insecure sources" do
      lockfile = VULNERABLE_LOCKFILE.sub("https://rubygems.org/", "http://rubygems.org/")
      audit = Audit.new(lockfile: lockfile)

      stub_advisory_refresh! { AuditRunner.new(audit).call }

      assert audit.results.any? { |r| r["type"] == "insecure_source" }
    end
  end
end
