export const ErrorBox = ({ message }) => (message ? <p className="error" role="alert">{message}</p> : null)

export const Notice = ({ children }) => (children ? <p className="notice">{children}</p> : null)

export function Table({ columns, rows, empty = 'Nothing to show.' }) {
  if (!rows?.length) return <p className="muted">{empty}</p>
  return (
    <div className="table-wrap">
      <table>
        <thead><tr>{columns.map((c) => <th key={c.label}>{c.label}</th>)}</tr></thead>
        <tbody>
          {rows.map((row, i) => (
            <tr key={row.id ?? i}>{columns.map((c) => <td key={c.label}>{c.render ? c.render(row) : row[c.key]}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export const Field = ({ label, children }) => (
  <label className="field"><span>{label}</span>{children}</label>
)
