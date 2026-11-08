import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field, Table } from '../components/ui'
import { useLoad } from '../hooks'

export default function RatesPage({ me }) {
  const [history, setHistory] = useState(false)
  const rates = useLoad(() => api.get('/exchange_rates', { all_versions: history }), [history])
  const canEdit = me.roles.includes('rate_manager')

  return (
    <section>
      <p className="muted">One fixed rate per currency per calendar year (1 unit of currency = rate USD). Changes never overwrite: a new version is added with a reason.</p>
      <label><input type="checkbox" checked={history} onChange={(e) => setHistory(e.target.checked)} /> Show all versions</label>
      <ErrorBox message={rates.error} />
      <Table
        rows={rates.data?.data}
        empty={rates.loading ? 'Loading…' : 'No rates yet.'}
        columns={[
          { label: 'Currency', key: 'currency' }, { label: 'Year', key: 'year' }, { label: 'Rate to USD', key: 'rate_to_usd' },
          { label: 'Version', key: 'version' }, { label: 'Reason', key: 'reason' }, { label: 'Set by', key: 'set_by' },
          { label: 'When', render: (r) => new Date(r.created_at).toLocaleString() },
        ]}
      />
      {canEdit ? <RateForm onSaved={rates.reload} /> : <p className="muted">Only rate managers can change rates.</p>}
    </section>
  )
}

function RateForm({ onSaved }) {
  const blank = { currency: '', year: new Date().getFullYear(), rate_to_usd: '', reason: '' }
  const [form, setForm] = useState(blank)
  const [error, setError] = useState(null)
  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    try {
      await api.post('/exchange_rates', { exchange_rate: { ...form, currency: form.currency.toUpperCase() } })
      setForm(blank); setError(null); onSaved()
    } catch (err) { setError(err.message) }
  }

  return (
    <form className="card" onSubmit={submit}>
      <h3>Set or correct a rate</h3>
      <div className="toolbar">
        <Field label="Currency"><input value={form.currency} onChange={set('currency')} maxLength="3" placeholder="INR" required /></Field>
        <Field label="Year"><input type="number" value={form.year} onChange={set('year')} required /></Field>
        <Field label="Rate to USD"><input value={form.rate_to_usd} onChange={set('rate_to_usd')} placeholder="0.012" required /></Field>
        <Field label="Reason"><input value={form.reason} onChange={set('reason')} required /></Field>
        <button type="submit">Save rate</button>
      </div>
      <ErrorBox message={error} />
    </form>
  )
}
