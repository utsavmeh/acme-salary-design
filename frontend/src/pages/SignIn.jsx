import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field } from '../components/ui'

export default function SignIn({ notice, onSignedIn }) {
  const [form, setForm] = useState({ username: '', password: '' })
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)
  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    setBusy(true)
    try {
      onSignedIn(await api.login(form.username, form.password))
    } catch (err) {
      setError(err.message)
      setForm({ ...form, password: '' })
    } finally { setBusy(false) }
  }

  return (
    <div className="app narrow">
      <h1>ACME Salary Management</h1>
      <form onSubmit={submit} className="card">
        {notice && <p className="notice">{notice}</p>}
        <Field label="Username"><input value={form.username} onChange={set('username')} autoComplete="username" autoFocus required /></Field>
        <Field label="Password"><input type="password" value={form.password} onChange={set('password')} autoComplete="current-password" required /></Field>
        <ErrorBox message={error} />
        <button type="submit" disabled={busy}>Sign in</button>
        <p className="muted">Accounts are created by the system operators. Forgotten password? Ask them for a new one-time password.</p>
      </form>
    </div>
  )
}
