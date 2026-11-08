import { useState } from 'react'
import { api } from '../api'
import { ErrorBox, Field } from '../components/ui'

// Shown after sign-in with a one-time password: nothing else works until a new one is chosen.
export default function ChangePassword({ forced, onChanged }) {
  const [form, setForm] = useState({ current: '', next: '', confirm: '' })
  const [error, setError] = useState(null)
  const set = (key) => (e) => setForm({ ...form, [key]: e.target.value })

  const submit = async (e) => {
    e.preventDefault()
    if (form.next !== form.confirm) { setError('The new passwords do not match'); return }
    try {
      onChanged(await api.changePassword(form.current, form.next))
    } catch (err) { setError(err.message) }
  }

  return (
    <form onSubmit={submit} className="card">
      <h2>{forced ? 'Choose your own password' : 'Change password'}</h2>
      {forced && <p className="muted">You signed in with a one-time password. Choose a new one (at least 12 characters) to continue.</p>}
      <Field label={forced ? 'One-time password' : 'Current password'}>
        <input type="password" value={form.current} onChange={set('current')} autoComplete="current-password" required />
      </Field>
      <Field label="New password"><input type="password" value={form.next} onChange={set('next')} autoComplete="new-password" minLength="12" required /></Field>
      <Field label="Repeat new password"><input type="password" value={form.confirm} onChange={set('confirm')} autoComplete="new-password" required /></Field>
      <ErrorBox message={error} />
      <button type="submit">Save password</button>
    </form>
  )
}
