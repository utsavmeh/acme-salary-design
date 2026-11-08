import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field, Notice, Table } from '../components/ui'
import { useLoad } from '../hooks'

export default function AuditPage() {
  const [filters, setFilters] = useState({ actor: '', action_name: '' })
  const [applied, setApplied] = useState(filters)
  const [page, setPage] = useState(1)
  const [verdict, setVerdict] = useState(null)
  const events = useLoad(() => api.get('/audit_events', { ...applied, page }), [applied, page])
  const set = (key) => (e) => setFilters({ ...filters, [key]: e.target.value })

  const verify = async () => {
    const result = await api.get('/audit_events/verify')
    setVerdict(result.valid ? 'The audit log is intact.' : `The audit log was tampered with at event #${result.broken_at_id}.`)
  }

  return (
    <section>
      <form className="toolbar" onSubmit={(e) => { e.preventDefault(); setPage(1); setApplied(filters) }}>
        <Field label="Person (username)"><input value={filters.actor} onChange={set('actor')} /></Field>
        <Field label="Action"><input value={filters.action_name} onChange={set('action_name')} placeholder="employee.viewed" /></Field>
        <button type="submit">Filter</button>
        <button type="button" onClick={verify}>Verify log integrity</button>
      </form>
      <Notice>{verdict}</Notice>
      <ErrorBox message={events.error} />
      <Table
        rows={events.data?.data}
        empty={events.loading ? 'Loading…' : 'No events.'}
        columns={[
          { label: 'When', render: (e) => new Date(e.occurred_at).toLocaleString() },
          { label: 'Who', key: 'actor' }, { label: 'Action', key: 'action' },
          { label: 'Target', render: (e) => (e.target_type ? `${e.target_type} ${e.target_id}` : '') },
          { label: 'Details', render: (e) => JSON.stringify(e.details) },
        ]}
      />
      <p className="pager">
        <button disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button> Page {page}
        <button disabled={!events.data || page * events.data.per_page >= events.data.total} onClick={() => setPage(page + 1)}>Next</button>
      </p>
    </section>
  )
}
