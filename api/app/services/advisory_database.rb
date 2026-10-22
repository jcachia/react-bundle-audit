# Keeps the local ruby-advisory-db current, the library equivalent of
# `bundle-audit check --update`.
class AdvisoryDatabase
  class Unavailable < StandardError; end

  Refresh = Data.define(:updated_at, :warning)

  # Both the update (git pull) and last_updated_at (git log) Dir.chdir into the
  # checkout, which raises if two threads do it at once.
  LOCK = Mutex.new

  # Pulls the latest advisories on every call. If the fetch fails but a stored
  # copy exists, carries on with it and reports a warning; with no stored copy
  # there is nothing to scan against, so raises Unavailable.
  def self.refresh
    LOCK.synchronize do
      warning = fetch
      Refresh.new(updated_at: current.last_updated_at, warning: warning)
    end
  rescue Bundler::Audit::Database::DownloadFailed
    raise Unavailable, "Unable to download the advisory database and none is stored locally."
  end

  def self.fetch
    if Bundler::Audit::Database.exists?
      current.update!(quiet: true)
    else
      Bundler::Audit::Database.download(quiet: true)
    end
    nil
  rescue Bundler::Audit::Database::UpdateFailed
    stored_at = current.last_updated_at.utc.strftime("%Y-%m-%d %H:%M UTC")
    "Unable to fetch the latest advisories; falling back to stored database last updated #{stored_at}."
  end
  private_class_method :fetch

  def self.current
    Bundler::Audit::Database.new
  end
  private_class_method :current
end
