import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Notice, Table } from '../components/ui'
import { useLoad } from '../hooks'

export default function ImportPage() {
  const [batch, setBatch] = useState(null)
  const [error, setError] = useState(null)
  const past = useLoad(() => api.get('/imports'), [batch?.status])

  const upload = async (e) => {
    e.preventDefault()
    const form = new FormData()
    form.append('file', e.target.elements.file.files[0])
    try {
      setBatch(await api.upload('/imports', form)); setError(null)
    } catch (err) { setError(err.message) }
  }

  return (
    <section>
      <p className="muted">
        One-time migration from Excel. Columns: employee_number, name, country, hire_date, department, job_title, currency,
        base_pay, gross, deductions (e.g. <code>Income tax:100;Pension:50</code>), net, effective_from. Dates as 2024-01-31. Monthly pay only.
        Nothing is loaded until you review the results and commit.
      </p>
      <form className="toolbar" onSubmit={upload}>
        <input type="file" name="file" accept=".csv,.xlsx" required />
        <button type="submit">Check file</button>
      </form>
      <ErrorBox message={error} />
      {batch && <Batch id={batch.id} onChanged={setBatch} />}
      <h3>Earlier imports</h3>
      <Table
        rows={past.data?.data}
        empty="No imports yet."
        columns={[
          { label: 'Id', key: 'id' }, { label: 'File', key: 'filename' }, { label: 'Status', key: 'status' },
          { label: 'Rows', key: 'total_rows' }, { label: 'Accepted', key: 'accepted_rows' }, { label: 'Rejected', key: 'rejected_rows' },
          { label: '', render: (b) => <button className="link" onClick={() => setBatch(b)}>Open</button> },
        ]}
      />
    </section>
  )
}

function Batch({ id, onChanged }) {
  const [confirm, setConfirm] = useState(false)
  const [error, setError] = useState(null)
  const summary = useLoad(() => api.get(`/imports/${id}`), [id])
  const rejected = useLoad(() => api.get(`/imports/${id}/rejected_rows`), [id])
  const recon = useLoad(() => api.get(`/imports/${id}/reconciliation`), [id, summary.data?.status])
  const b = summary.data

  const commit = async () => {
    try {
      onChanged(await api.post(`/imports/${id}/commit`, { confirm_rejected_rows: confirm })); setError(null)
    } catch (err) { setError(err.message) }
  }

  if (!b) return <ErrorBox message={summary.error} />
  return (
    <div className="card">
      <h3>Import #{b.id}: {b.filename} <span className="muted">({b.status})</span></h3>
      <p>{b.total_rows} rows · <strong>{b.accepted_rows} accepted</strong> · <strong>{b.rejected_rows} rejected</strong></p>

      <h4>Rejected rows</h4>
      <button type="button" onClick={() => api.download(`/imports/${id}/rejected_rows.csv`, {}, `import-${id}-rejected.csv`)}>Download as CSV</button>
      <Table
        rows={rejected.data?.data}
        empty="No rejected rows."
        columns={[
          { label: 'Row', key: 'row_number' },
          { label: 'Employee', render: (r) => r.raw.employee_number },
          { label: 'Why it was rejected', render: (r) => r.reasons.join('; ') },
        ]}
      />

      <h4>Reconciliation (compare with your Excel totals)</h4>
      {recon.data && (
        <>
          <Notice>{recon.data.balanced ? 'Balanced: every row in the file is either accepted or rejected.' : 'NOT balanced.'}</Notice>
          {recon.data.loaded_matches_accepted === true && <Notice>Loaded data matches the accepted rows.</Notice>}
          {recon.data.loaded_matches_accepted === false && <p className="error">Loaded data does NOT match the accepted rows.</p>}
          <Table
            rows={recon.data.currencies.map((c) => ({ ...c, id: c.currency }))}
            columns={[
              { label: 'Currency', key: 'currency' },
              { label: 'In file (rows / gross / net)', render: (c) => `${c.file.rows} / ${c.file.gross} / ${c.file.net}` },
              { label: 'Accepted', render: (c) => `${c.accepted.rows} / ${c.accepted.gross} / ${c.accepted.net}` },
              { label: 'Rejected', render: (c) => `${c.rejected.rows} / ${c.rejected.gross} / ${c.rejected.net}` },
              { label: 'Loaded', render: (c) => (c.loaded ? `${c.loaded.rows} / ${c.loaded.gross} / ${c.loaded.net}` : '—') },
            ]}
          />
        </>
      )}

      {b.status === 'staged' && (
        <>
          {b.rejected_rows > 0 && (
            <label><input type="checkbox" checked={confirm} onChange={(e) => setConfirm(e.target.checked)} /> I understand the {b.rejected_rows} rejected rows will NOT be loaded</label>
          )}
          <ErrorBox message={error} />
          <button type="button" onClick={commit}>Load {b.accepted_rows} accepted rows</button>
        </>
      )}
    </div>
  )
}
