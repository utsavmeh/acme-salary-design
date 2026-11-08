import { useEffect, useState } from 'react'
import { api, getToken, setToken } from './api'
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
  const [error, setError] = useState(null)
  const [tab, setTab] = useState(null)

  const signOut = () => { setToken(null); setMe(null); setError(null) }

  useEffect(() => {
    if (!getToken()) return
    api.get('/me').then(setMe).catch((e) => { setToken(null); setError(e.message) })
  }, [])

  if (!me) return <SignIn error={error} onSignedIn={setMe} />

  const tabs = TABS.filter((t) => t.roles.some((r) => me.roles.includes(r)))
  const active = tabs.find((t) => t.id === tab) ?? tabs[0]

  return (
    <div className="app">
      <header>
        <h1>ACME Salary Management</h1>
        <span className="muted">{me.email} · {me.roles.join(', ') || 'no access'}</span>
        <button className="link" onClick={signOut}>Sign out</button>
      </header>
      {active ? (
        <>
          <nav>{tabs.map((t) => (
            <button key={t.id} className={t === active ? 'tab active' : 'tab'} onClick={() => setTab(t.id)}>{t.label}</button>
          ))}</nav>
          <main><active.Page me={me} /></main>
        </>
      ) : (
        <main><p className="error">Your account is not in any salary access group. Ask IT to add you.</p></main>
      )}
    </div>
  )
}
