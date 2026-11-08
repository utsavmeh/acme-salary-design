import { useCallback, useEffect, useState } from 'react'

// Runs an async loader whenever `deps` change and exposes { data, error, loading, reload }.
export function useLoad(loader, deps) {
  const [state, setState] = useState({ data: null, error: null, loading: true })
  const run = useCallback(() => {
    setState((s) => ({ ...s, loading: true, error: null }))
    return loader()
      .then((data) => setState({ data, error: null, loading: false }))
      .catch((error) => setState({ data: null, error: error.message, loading: false }))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
  useEffect(() => { run() }, [run])
  return { ...state, reload: run }
}
