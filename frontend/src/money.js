// Money is handled as whole cents so adding amounts never gives 0.30000000000000004.
export const toCents = (text) => {
  const match = /^\d+(\.\d{1,2})?$/.exec(String(text ?? '').trim())
  if (!match) return null
  const [whole, fraction = ''] = String(text).trim().split('.')
  return Number(whole) * 100 + Number(fraction.padEnd(2, '0'))
}

export const fromCents = (cents) => `${Math.trunc(cents / 100)}.${String(Math.abs(cents) % 100).padStart(2, '0')}`
