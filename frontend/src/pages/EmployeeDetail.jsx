import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field, Table } from '../components/ui'
import { useLoad } from '../hooks'
import { fromCents, toCents } from '../money'

export default function EmployeeDetail({ id, onBack }) {
  const [allVersions, setAllVersions] = useState(false)
  const [correcting, setCorrecting] = useState(null)
  const employee = useLoad(() => api.get(`/employees/${id}`), [id])
  const history = useLoad(() => api.get(`/employees/${id}/salary_records`, { all_versions: allVersions }), [id, allVersions])
  const refresh = () => { employee.reload(); history.reload(); setCorrecting(null) }
  const e = employee.data

  return (
    <section>
      <button className="link" onClick={onBack}>← Back to employees</button>
      <ErrorBox message={employee.error} />
      {e && (
        <div className="card">
          <h2>{e.name} <span className="muted">{e.employee_number}</span></h2>
          <p>{e.country} · {e.status} · hired {e.hire_date} · {e.department ?? 'no department'} / {e.job_title ?? 'no job title'}</p>
        </div>
      )}

      <h3>Salary history</h3>
      <label><input type="checkbox" checked={allVersions} onChange={(ev) => setAllVersions(ev.target.checked)} /> Show corrected-away versions too</label>
      <ErrorBox message={history.error} />
      <Table
        rows={history.data?.data}
        empty={history.loading ? 'Loading…' : 'No salary records yet.'}
        columns={[
          { label: 'From', key: 'effective_from' },
          { label: 'Version', key: 'version' },
          { label: 'Currency', key: 'currency' },
          { label: 'Base pay', key: 'base_pay' },
          { label: 'Gross', key: 'gross' },
          { label: 'Deductions', render: (r) => r.deductions.map((d) => `${d.label} ${d.amount}`).join(', ') || '—' },
          { label: 'Net', key: 'net' },
          { label: 'By', key: 'created_by' },
          { label: '', render: (r) => <button className="link" onClick={() => setCorrecting(r)}>Correct</button> },
        ]}
      />
      <SalaryForm key={correcting?.id ?? 'new'} employeeId={id} correcting={correcting} onSaved={refresh} onCancel={() => setCorrecting(null)} />
      <AssignmentForm employeeId={id} onSaved={refresh} />
    </section>
  )
}

function SalaryForm({ employeeId, correcting, onSaved, onCancel }) {
  const [form, setForm] = useState({
    effective_from: correcting?.effective_from ?? '', currency: correcting?.currency ?? '',
    base_pay: correcting?.base_pay ?? '', gross: correcting?.gross ?? correcting?.base_pay ?? '',
  })
  const [lines, setLines] = useState(correcting?.deductions ?? [])
  const [error, setError] = useState(null)
  const set = (key) => (ev) => setForm({ ...form, [key]: ev.target.value })

  // Net is worked out for the user from gross and the deduction lines (the server re-checks it).
  const gross = toCents(form.gross)
  const deducted = lines.reduce((sum, l) => sum + (toCents(l.amount) ?? 0), 0)
  const net = gross === null ? null : gross - deducted

  const setLine = (i, key, value) => setLines(lines.map((l, j) => (j === i ? { ...l, [key]: value } : l)))

  const submit = async (ev) => {
    ev.preventDefault()
    const salary_record = { ...form, currency: form.currency.toUpperCase(), net: net === null ? '' : fromCents(net), deductions: lines }
    try {
      if (correcting) {
        delete salary_record.effective_from
        await api.post(`/salary_records/${correcting.id}/correct`, { salary_record })
      } else {
        await api.post(`/employees/${employeeId}/salary_records`, { salary_record })
      }
      onSaved()
    } catch (err) { setError(err.message) }
  }

  return (
    <form className="card" onSubmit={submit}>
      <h3>{correcting ? `Correct the record from ${correcting.effective_from}` : 'Add a salary record'}</h3>
      <div className="toolbar">
        {!correcting && <Field label="Effective from"><input type="date" value={form.effective_from} onChange={set('effective_from')} required /></Field>}
        <Field label="Currency"><input value={form.currency} onChange={set('currency')} maxLength="3" placeholder="INR" required /></Field>
        <Field label="Base pay (monthly)"><input value={form.base_pay} onChange={set('base_pay')} required /></Field>
        <Field label="Gross"><input value={form.gross} onChange={set('gross')} required /></Field>
      </div>
      {lines.map((line, i) => (
        <div className="toolbar" key={i}>
          <Field label="Deduction"><input value={line.label} onChange={(ev) => setLine(i, 'label', ev.target.value)} required /></Field>
          <Field label="Amount"><input value={line.amount} onChange={(ev) => setLine(i, 'amount', ev.target.value)} required /></Field>
          <button type="button" onClick={() => setLines(lines.filter((_, j) => j !== i))}>Remove</button>
        </div>
      ))}
      <button type="button" onClick={() => setLines([...lines, { label: '', amount: '' }])}>Add deduction</button>
      <p>Net pay: <strong>{net === null ? '—' : fromCents(net)}</strong></p>
      <ErrorBox message={error} />
      <button type="submit">{correcting ? 'Save correction' : 'Save record'}</button>
      {correcting && <button type="button" onClick={onCancel}>Cancel</button>}
    </form>
  )
}

function AssignmentForm({ employeeId, onSaved }) {
  const [form, setForm] = useState({ department: '', job_title: '', effective_from: '' })
  const [error, setError] = useState(null)
  const set = (key) => (ev) => setForm({ ...form, [key]: ev.target.value })

  const submit = async (ev) => {
    ev.preventDefault()
    try {
      await api.post(`/employees/${employeeId}/assignments`, { assignment: form })
      setForm({ department: '', job_title: '', effective_from: '' }); setError(null); onSaved()
    } catch (err) { setError(err.message) }
  }

  return (
    <form className="card" onSubmit={submit}>
      <h3>Change department or job title</h3>
      <div className="toolbar">
        <Field label="Department"><input value={form.department} onChange={set('department')} required /></Field>
        <Field label="Job title"><input value={form.job_title} onChange={set('job_title')} required /></Field>
        <Field label="From"><input type="date" value={form.effective_from} onChange={set('effective_from')} required /></Field>
        <button type="submit">Save</button>
      </div>
      <ErrorBox message={error} />
    </form>
  )
}
