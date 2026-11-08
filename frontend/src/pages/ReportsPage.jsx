import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field, Notice, Table } from '../components/ui'

const REPORTS = {
  pay_summary: { label: 'Pay summary (headcount, average, lowest, highest)', params: ['group_by', 'department', 'country', 'job_title', 'as_of'] },
  top_paid: { label: 'Highest paid employees', params: ['department', 'country', 'limit', 'as_of'] },
  hikes: { label: 'Biggest salary increases in a year', params: ['year', 'sort_by', 'limit'] },
  data_quality: { label: 'Data quality (gaps in the data)', params: [] },
}

const PERSON = [
  { label: '#', key: 'rank' }, { label: 'Number', key: 'employee_number' }, { label: 'Name', key: 'name' },
  { label: 'Department', key: 'department' }, { label: 'Job title', key: 'job_title' },
]

const COLUMNS = {
  pay_summary: (r) => [
    { label: 'Group', key: 'group' }, { label: 'Headcount', key: 'headcount' },
    { label: `Total (${r.groups[0]?.unit ?? ''})`, key: 'total' }, { label: 'Average', key: 'average' },
    { label: 'Lowest', key: 'lowest' }, { label: 'Highest', key: 'highest' },
    { label: 'Excluded (no rate)', key: 'excluded_for_missing_rate' },
    { label: 'Original amounts', render: (g) => g.original_amounts.map((o) => `${o.currency} ${o.total_base_pay}`).join(', ') },
  ],
  top_paid: () => [
    ...PERSON, { label: 'Country', key: 'country' },
    { label: 'Base pay', render: (r) => `${r.unit} ${r.base_pay}` },
    { label: 'Original', render: (r) => `${r.original_currency} ${r.original_base_pay}` },
  ],
  hikes: (r) => [
    ...PERSON, { label: 'Effective', key: 'effective_from' },
    { label: 'Old → new', render: (x) => `${x.currency} ${x.old_base_pay} → ${x.new_base_pay}` },
    { label: 'Increase', render: (x) => `${x.currency} ${x.increase}` },
    { label: 'Increase %', render: (x) => `${x.percent_increase}%` },
    ...(r.currency_mode === 'usd' ? [{ label: 'Increase (USD)', render: (x) => x.increase_usd ?? 'no rate' }] : []),
  ],
}

export default function ReportsPage() {
  const [name, setName] = useState('pay_summary')
  const [params, setParams] = useState({ currency_mode: 'usd', group_by: 'department', year: new Date().getFullYear() })
  const [result, setResult] = useState(null)
  const [error, setError] = useState(null)
  const set = (key) => (e) => setParams({ ...params, [key]: e.target.value })
  const report = REPORTS[name]

  const run = async (e) => {
    e.preventDefault()
    try {
      setResult(await api.get(`/reports/${name}`, params)); setError(null)
    } catch (err) { setResult(null); setError(err.message) }
  }

  return (
    <section>
      <form className="toolbar" onSubmit={run}>
        <Field label="Report">
          <select value={name} onChange={(e) => { setName(e.target.value); setResult(null) }}>
            {Object.entries(REPORTS).map(([id, r]) => <option key={id} value={id}>{r.label}</option>)}
          </select>
        </Field>
        {name !== 'data_quality' && (
          <Field label="Show amounts in">
            <select value={params.currency_mode} onChange={set('currency_mode')}>
              <option value="usd">USD</option><option value="native">Original currency (one currency only)</option>
            </select>
          </Field>
        )}
        {report.params.includes('group_by') && (
          <Field label="Group by">
            <select value={params.group_by} onChange={set('group_by')}>
              <option value="department">Department</option><option value="country">Country</option>
              <option value="job_title">Job title</option><option value="none">Everyone</option>
            </select>
          </Field>
        )}
        {report.params.includes('sort_by') && (
          <Field label="Rank by">
            <select value={params.sort_by ?? 'percent'} onChange={set('sort_by')}>
              <option value="percent">Percentage increase</option><option value="amount">Amount (USD)</option>
            </select>
          </Field>
        )}
        {report.params.filter((p) => ['department', 'country', 'job_title', 'year', 'limit', 'as_of'].includes(p)).map((p) => (
          <Field key={p} label={p.replace('_', ' ')}>
            <input type={p === 'as_of' ? 'date' : 'text'} value={params[p] ?? ''} onChange={set(p)} />
          </Field>
        ))}
        <button type="submit">Run report</button>
      </form>
      <ErrorBox message={error} />
      {result && <Result name={name} result={result} />}
    </section>
  )
}

function Result({ name, result }) {
  const rows = name === 'pay_summary' ? result.groups : result.rows
  return (
    <div>
      <p className="muted">As of {result.as_of} · amounts in {result.currency_mode === 'usd' ? 'USD' : 'original currency'}</p>
      {result.missing_rates.length > 0 && (
        <p className="error" role="alert">
          Exchange rate missing, so these amounts are NOT included: {result.missing_rates.map((m) => `${m.currency} ${m.year} (${m.amounts_affected})`).join(', ')}.
          Ask a rate manager to add them.
        </p>
      )}
      {name === 'data_quality' ? <DataQuality result={result} /> : <Table rows={rows} columns={COLUMNS[name](result)} empty="No data for this report." />}
      {result.skipped_currency_changes > 0 && <Notice>{result.skipped_currency_changes} change(s) of currency were not ranked.</Notice>}
      {result.rates_used.length > 0 && (
        <p className="muted">Rates used: {result.rates_used.map((r) => `${r.currency} ${r.year} = ${r.rate_to_usd} USD`).join(' · ')}</p>
      )}
    </div>
  )
}

function DataQuality({ result }) {
  const cols = [{ label: 'Number', key: 'employee_number' }, { label: 'Name', key: 'name' }]
  return (
    <>
      <h3>Active employees without a salary record ({result.employees_without_salary.length})</h3>
      <Table rows={result.employees_without_salary} columns={cols} empty="None." />
      <h3>Employees with pay but no department ({result.employees_without_department.length})</h3>
      <Table rows={result.employees_without_department} columns={cols} empty="None." />
    </>
  )
}
