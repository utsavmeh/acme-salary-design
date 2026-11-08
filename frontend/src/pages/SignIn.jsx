import { useState } from 'react'
import { api, setToken } from '../api'
import { ErrorBox } from '../components/ui'

// The company sign-in system issues the token. Until it is connected, a token can be pasted here
// (in development: `rails "auth:dev_token[me@acme.test,salary-hr]"`).
export default function SignIn({ error, onSignedIn }) {
  const [token, setLocal] = useState('')
  const [message, setMessage] = useState(error)

  const submit = async (event) => {
    event.preventDefault()
    setToken(token.trim())
    try {
      onSignedIn(await api.get('/me'))
    } catch (e) {
      setToken(null)
      setMessage(e.message)
    }
  }

  return (
    <div className="app narrow">
      <h1>ACME Salary Management</h1>
      <form onSubmit={submit} className="card">
        <label className="field">
          <span>Sign-in token</span>
          <textarea rows="4" value={token} onChange={(e) => setLocal(e.target.value)} required />
        </label>
        <ErrorBox message={message} />
        <button type="submit">Sign in</button>
      </form>
    </div>
  )
}
