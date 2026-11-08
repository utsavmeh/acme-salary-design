import { useEffect, useState } from 'react'
import { api, getToken, sessionHooks, setToken } from './api'
import ChangePassword from './pages/ChangePassword'
import AuditPage from './pages/AuditPage'
import EmployeesPage from './pages/EmployeesPage'
import ImportPage from './pages/ImportPage'
import RatesPage from './pages/RatesPage'
import ReportsPage from './pages/ReportsPage'
import SignIn from './pages/SignIn'

// Which tab each role may see. The server enforces this too; hiding tabs is only a convenience.
const TABS = [
  { id: 'employees', label: 'Employees', roles: ['hr'], Page: EmployeesPage },
  { id: 'reports', label: 'Reports', roles: ['hr'], Page: ReportsPage },
  { id: 'rates', label: 'Exchange rates', roles: ['hr', 'rate_manager'], Page: RatesPage },
  { id: 'import', label: 'Excel import', roles: ['hr'], Page: ImportPage },
  { id: 'audit', label: 'Audit log', roles: ['auditor'], Page: AuditPage },
]

export default function App() {
  const [me, setMe] = useState(null)
  const [notice, setNotice] = useState(null)
  const [tab, setTab] = useState(null)
  const [changingPassword, setChangingPassword] = useState(false)

  const signOut = (message = null) => { setToken(null); setMe(null); setNotice(message) }

  useEffect(() => {
    sessionHooks.onExpired = () => signOut('Your session ended. Please sign in again.')
    if (!getToken()) return
    api.get('/me').then(setMe).catch(() => setToken(null))
  }, [])

  if (!me) return <SignIn notice={notice} onSignedIn={(user) => { setNotice(null); setMe(user) }} />
  if (me.must_change_password) {
    return <div className="app narrow"><ChangePassword forced onChanged={setMe} /></div>
  }

  const tabs = TABS.filter((t) => t.roles.some((r) => me.roles.includes(r)))
  const active = tabs.find((t) => t.id === tab) ?? tabs[0]

  return (
    <div className="app">
      <header>
        <h1>ACME Salary Management</h1>
        <span className="muted">{me.username} · {me.roles.join(', ') || 'no access'}</span>
        <button className="link" onClick={() => setChangingPassword(!changingPassword)}>Change password</button>
        <button className="link" onClick={() => signOut()}>Sign out</button>
      </header>
      {changingPassword && <ChangePassword onChanged={(user) => { setMe(user); setChangingPassword(false) }} />}
      {active ? (
        <>
          <nav>{tabs.map((t) => (
            <button key={t.id} className={t === active ? 'tab active' : 'tab'} onClick={() => setTab(t.id)}>{t.label}</button>
          ))}</nav>
          <main><active.Page me={me} /></main>
        </>
      ) : (
        <main><p className="error">Your account has no role yet. Ask the system operators to give you access.</p></main>
      )}
    </div>
  )
}
