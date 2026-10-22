require "test_helper"

class AdvisoryDatabaseTest < ActiveSupport::TestCase
  Database = Bundler::Audit::Database

  # Minitest's stub on a fake instance standing in for the on-disk checkout.
  def fake_database(update: nil)
    db = Object.new
    db.define_singleton_method(:last_updated_at) { STORED_DB_TIME }
    db.define_singleton_method(:update!) { |**| update ? raise(update) : true }
    db
  end

  context "AdvisoryDatabase.refresh" do
    should "pull when a stored database exists" do
      db = fake_database

      Database.stub(:exists?, true) do
        Database.stub(:new, db) do
          refresh = AdvisoryDatabase.refresh

          assert_equal STORED_DB_TIME, refresh.updated_at
          assert_nil refresh.warning
        end
      end
    end

    should "fall back to the stored database with a warning when the pull fails" do
      db = fake_database(update: Database::UpdateFailed)

      Database.stub(:exists?, true) do
        Database.stub(:new, db) do
          refresh = AdvisoryDatabase.refresh

          assert_equal STORED_DB_TIME, refresh.updated_at
          assert_equal "Unable to fetch the latest advisories; falling back to stored database " \
            "last updated 2026-10-01 12:30 UTC.", refresh.warning
        end
      end
    end

    should "raise Unavailable when nothing is stored and the download fails" do
      failing = ->(**) { raise Database::DownloadFailed }

      Database.stub(:exists?, false) do
        Database.stub(:download, failing) do
          assert_raises(AdvisoryDatabase::Unavailable) { AdvisoryDatabase.refresh }
        end
      end
    end
  end
end
