// Thin wrapper around fetch: adds the sign-in token and turns error responses into exceptions.
const TOKEN_KEY = 'acme_token'

export const getToken = () => sessionStorage.getItem(TOKEN_KEY)
export const setToken = (token) =>
  token ? sessionStorage.setItem(TOKEN_KEY, token) : sessionStorage.removeItem(TOKEN_KEY)

export class ApiError extends Error {
  constructor(status, body) {
    super(describe(body) || `Request failed (${status})`)
    this.status = status
    this.code = body?.code
  }
}

// App registers a function here to send the user back to the sign-in page when a session ends.
export const sessionHooks = { onExpired: () => {} }

function describe(body) {
  if (!body) return null
  if (body.details) {
    const fields = Object.entries(body.details).map(([k, v]) => `${k} ${[].concat(v).join(', ')}`)
    return `${body.error}: ${fields.join('; ')}`
  }
  return body.error
}

async function send(path, { method = 'GET', json, form } = {}) {
  const headers = { Authorization: `Bearer ${getToken()}` }
  let body
  if (json) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(json)
  } else if (form) {
    body = form
  }
  const response = await fetch(`/api${path}`, { method, headers, body })
  if (!response.ok) {
    const text = await response.text()
    let parsed = null
    try { parsed = JSON.parse(text) } catch { /* not JSON */ }
    // 401 on any call except the sign-in itself means the session expired or the account was switched off.
    if (response.status === 401 && path !== '/session') sessionHooks.onExpired()
    throw new ApiError(response.status, parsed)
  }
  return response
}

const toQuery = (params = {}) => {
  const query = new URLSearchParams(Object.entries(params).filter(([, v]) => v !== '' && v != null))
  return query.toString() ? `?${query}` : ''
}

export const api = {
  login: async (username, password) => {
    const result = await (await send('/session', { method: 'POST', json: { username, password } })).json()
    setToken(result.token)
    return result.user
  },
  changePassword: async (current_password, new_password) => {
    const result = await (await send('/me/password', { method: 'PATCH', json: { current_password, new_password } })).json()
    setToken(result.token)
    return result.user
  },
  get: async (path, params) => (await send(path + toQuery(params))).json(),
  post: async (path, json) => (await send(path, { method: 'POST', json: json ?? {} })).json(),
  patch: async (path, json) => (await send(path, { method: 'PATCH', json })).json(),
  upload: async (path, form) => (await send(path, { method: 'POST', form })).json(),
  // Downloads a file with the token attached (a plain link could not send the Authorization header).
  download: async (path, params, filename) => {
    const blob = await (await send(path + toQuery(params))).blob()
    const link = document.createElement('a')
    link.href = URL.createObjectURL(blob)
    link.download = filename
    link.click()
    URL.revokeObjectURL(link.href)
  },
}
