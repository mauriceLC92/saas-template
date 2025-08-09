import Plausible, { EventOptions } from 'plausible-tracker'
import { createContext, use, useEffect } from 'react'

type TrackEvent = (eventName: string, options?: EventOptions) => void

const plausible = Plausible({
  domain: import.meta.env.VITE_DOMAIN,
  apiHost: import.meta.env.VITE_PLAUSIBLE_API_HOST,
  trackLocalhost: true
})

const PlausibleContext = createContext<{ trackEvent: TrackEvent }>({
  trackEvent: plausible.trackEvent
})

function PlausibleProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    const cleanup = plausible.enableAutoPageviews()
    return () => cleanup()
  }, [])

  return (
    <PlausibleContext value={{ trackEvent: plausible.trackEvent }}>
      {children}
    </PlausibleContext>
  )
}

function usePlausible() {
  const context = use(PlausibleContext)
  if (context === undefined)
    throw new Error('PlausibleContext is being used outside PlausibleProvider')
  return context
}

export { PlausibleProvider, usePlausible }
