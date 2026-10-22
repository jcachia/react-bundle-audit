export type UnpatchedGem = {
  type: 'unpatched_gem'
  gem: { name: string; version: string }
  advisory: {
    id: string
    cve: string | null
    ghsa: string | null
    url: string | null
    title: string
    description: string
    criticality: string | null
    date: string | null
    patched_versions: string[]
    unaffected_versions: string[]
  }
}

export type InsecureSource = { type: 'insecure_source'; source: string }

export type Finding = UnpatchedGem | InsecureSource

export type Audit = {
  id: number
  results: Finding[]
  warnings: string[]
  advisory_db_updated_at: string | null
  created_at: string
}

export class ApiError extends Error {
  messages: string[]

  constructor(messages: string[]) {
    super(messages.join('\n'))
    this.messages = messages
  }
}

export async function createAudit(lockfile: string): Promise<Audit> {
  let response: Response
  try {
    response = await fetch('/api/audits', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ lockfile }),
    })
  } catch {
    throw new ApiError(['Could not reach the server.'])
  }

  const body = await response.json().catch(() => null)
  if (!response.ok) {
    throw new ApiError(body?.errors ?? [`Request failed (${response.status}).`])
  }
  return body as Audit
}
