require "tmpdir"

# Runs bundler-audit against an Audit's lockfile and stores the findings.
class AuditRunner
  def initialize(audit)
    @audit = audit
  end

  def call
    refresh = AdvisoryDatabase.refresh
    @audit.update!(
      results: scan,
      warnings: [refresh.warning].compact,
      advisory_db_updated_at: refresh.updated_at
    )
    @audit
  end

  private

  # The Scanner only reads a Gemfile.lock from a directory, so give it one.
  def scan
    Dir.mktmpdir("audit") do |dir|
      File.write(File.join(dir, "Gemfile.lock"), @audit.lockfile)
      Bundler::Audit::Scanner.new(dir).scan.map { |result| serialize(result) }
    end
  end

  def serialize(result)
    case result
    when Bundler::Audit::Results::UnpatchedGem
      advisory = result.advisory
      {
        type: "unpatched_gem",
        gem: {name: result.gem.name, version: result.gem.version.to_s},
        advisory: {
          id: advisory.id,
          cve: advisory.cve_id,
          ghsa: advisory.ghsa_id,
          url: advisory.url,
          title: advisory.title,
          description: advisory.description,
          criticality: advisory.criticality,
          date: advisory.date&.iso8601,
          patched_versions: advisory.patched_versions.map(&:to_s),
          unaffected_versions: advisory.unaffected_versions.map(&:to_s)
        }
      }
    when Bundler::Audit::Results::InsecureSource
      {type: "insecure_source", source: result.source}
    end
  end
end
