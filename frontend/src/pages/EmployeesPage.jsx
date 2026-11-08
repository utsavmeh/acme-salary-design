import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field, Table } from '../components/ui'
import { useLoad } from '../hooks'
import EmployeeDetail from './EmployeeDetail'

const EMPTY_FILTERS = { q: '', country: '', department: '', status: '' }

export default function EmployeesPage() {
  const [filters, setFilters] = useState(EMPTY_FILTERS)
  const [applied, setApplied] = useState(EMPTY_FILTERS)
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState(null)
  const [exportError, setExportError] = useState(null)
  const list = useLoad(() => api.get('/employees', { ...applied, page }), [applied, page])

  if (selected) return <EmployeeDetail id={selected} onBack={() => { setSelected(null); list.reload() }} />

  const search = (e) => { e.preventDefault(); setPage(1); setApplied(filters) }
  const exportCsv = () => api.download('/employees/export', applied, 'employees.csv').catch((e) => setExportError(e.message))
  const set = (key) => (e) => setFilters({ ...filters, [key]: e.target.value })
  const totalPages = list.data ? Math.max(1, Math.ceil(list.data.total / list.data.per_page)) : 1

  return (
    <section>
      <form className="toolbar" onSubmit={search}>
        <Field label="Name or number"><input value={filters.q} onChange={set('q')} /></Field>
        <Field label="Country"><input value={filters.country} onChange={set('country')} maxLength="2" placeholder="IN" /></Field>
        <Field label="Department"><input value={filters.department} onChange={set('department')} /></Field>
        <Field label="Status">
          <select value={filters.status} onChange={set('status')}>
            <option value="">Any</option><option value="active">Active</option><option value="inactive">Inactive</option>
          </select>
        </Field>
        <button type="submit">Search</button>
        <button type="button" onClick={exportCsv}>Export CSV</button>
      </form>
      <ErrorBox message={list.error || exportError} />
      <Table
        rows={list.data?.data}
        empty={list.loading ? 'Loading…' : 'No employees match.'}
        columns={[
          { label: 'Number', key: 'employee_number' },
          { label: 'Name', render: (e) => <button className="link" onClick={() => setSelected(e.id)}>{e.name}</button> },
          { label: 'Country', key: 'country' },
          { label: 'Department', key: 'department' },
          { label: 'Job title', key: 'job_title' },
          { label: 'Base pay (monthly)', render: (e) => e.current_salary ? `${e.current_salary.currency} ${e.current_salary.base_pay}` : '—' },
          { label: 'Net', render: (e) => e.current_salary ? `${e.current_salary.currency} ${e.current_salary.net}` : '—' },
        ]}
      />
      {list.data && (
        <p className="pager">
          <button disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
          Page {page} of {totalPages} · {list.data.total} employees
          <button disabled={page >= totalPages} onClick={() => setPage(page + 1)}>Next</button>
        </p>
      )}
      <NewEmployee onCreated={() => list.reload()} />
    </section>
  )
}

function NewEmployee({ onCreated }) {
  const blank = { employee_number: '', name: '', country: '', hire_date: '' }
  const [form, setForm] = useState(blank)
  const [error, setError] = useState(null)
  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    try {
      await api.post('/employees', { employee: { ...form, country: form.country.toUpperCase() } })
      setForm(blank); setError(null); onCreated()
    } catch (err) { setError(err.message) }
  }

  return (
    <details className="card">
      <summary>Add an employee</summary>
      <form className="toolbar" onSubmit={submit}>
        <Field label="Employee number"><input value={form.employee_number} onChange={set('employee_number')} required /></Field>
        <Field label="Name"><input value={form.name} onChange={set('name')} required /></Field>
        <Field label="Country (2 letters)"><input value={form.country} onChange={set('country')} maxLength="2" required /></Field>
        <Field label="Hire date"><input type="date" value={form.hire_date} onChange={set('hire_date')} required /></Field>
        <button type="submit">Add</button>
      </form>
      <ErrorBox message={error} />
    </details>
  )
}
