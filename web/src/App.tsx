import { useState, type SubmitEvent } from 'react'
import { ApiError, createAudit, type Audit, type Finding } from './api'
import './App.css'

function FindingCard({ finding }: { finding: Finding }) {
  if (finding.type === 'insecure_source') {
    return (
      <li className="finding">
        <h3>Insecure source</h3>
        <p>{finding.source}</p>
      </li>
    )
  }

  const { gem, advisory } = finding
  return (
    <li className="finding">
      <h3>
        {gem.name} {gem.version}
        {advisory.criticality && (
          <span className={`badge ${advisory.criticality}`}>{advisory.criticality}</span>
        )}
      </h3>
      <p>
        <strong>{advisory.title}</strong>
      </p>
      <dl>
        <dt>Advisory</dt>
        <dd>
          {advisory.url ? (
            <a href={advisory.url} target="_blank" rel="noreferrer">
              {advisory.cve ?? advisory.ghsa ?? advisory.id}
            </a>
          ) : (
            advisory.id
          )}
        </dd>
        <dt>Fixed in</dt>
        <dd>{advisory.patched_versions.join(', ') || 'No patched version available'}</dd>
      </dl>
    </li>
  )
}

function App() {
  const [lockfile, setLockfile] = useState('')
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<string[]>([])
  const [audit, setAudit] = useState<Audit | null>(null)

  async function handleSubmit(event: SubmitEvent<HTMLFormElement>) {
    event.preventDefault()
    setLoading(true)
    setErrors([])
    setAudit(null)
    try {
      setAudit(await createAudit(lockfile))
    } catch (error) {
      setErrors(error instanceof ApiError ? error.messages : ['Something went wrong.'])
    } finally {
      setLoading(false)
    }
  }

  return (
    <main>
      <h1>Gemfile.lock audit</h1>
      <p>Paste a Gemfile.lock to check its gems against the Ruby Advisory Database.</p>

      <form onSubmit={handleSubmit}>
        <textarea
          value={lockfile}
          onChange={(e) => setLockfile(e.target.value)}
          placeholder="GEM&#10;  remote: https://rubygems.org/&#10;  specs:&#10;    ..."
          rows={16}
          spellCheck={false}
          aria-label="Gemfile.lock contents"
        />
        <button type="submit" disabled={loading || lockfile.trim() === ''}>
          {loading ? 'Auditing…' : 'Run audit'}
        </button>
      </form>

      {errors.length > 0 && (
        <ul className="errors" role="alert">
          {errors.map((message) => (
            <li key={message}>{message}</li>
          ))}
        </ul>
      )}

      {audit && (
        <section aria-live="polite">
          {audit.warnings.map((warning) => (
            <p key={warning} className="warning">
              {warning}
            </p>
          ))}
          {audit.results.length === 0 ? (
            <p className="clean">No vulnerabilities found.</p>
          ) : (
            <>
              <h2>
                {audit.results.length} {audit.results.length === 1 ? 'issue' : 'issues'} found
              </h2>
              <ul className="findings">
                {audit.results.map((finding, i) => (
                  <FindingCard key={i} finding={finding} />
                ))}
              </ul>
            </>
          )}
          {audit.advisory_db_updated_at && (
            <p className="meta">
              Advisory database as of {new Date(audit.advisory_db_updated_at).toLocaleString()}
            </p>
          )}
        </section>
      )}
    </main>
  )
}

export default App
