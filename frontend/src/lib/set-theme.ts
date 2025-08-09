import { Theme } from '@/schemas/settings-schema'

export function setTheme(theme: Theme | undefined) {
  const root = window.document.documentElement
  root.classList.remove('light', 'dark')
  if (theme === 'light') {
    localStorage.setItem('theme', 'light')
    root.classList.add('light')
  } else if (theme === 'dark') {
    localStorage.setItem('theme', 'dark')
    root.classList.add('dark')
  } else {
    if (theme === 'system') localStorage.removeItem('theme')

    let systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches
      ? 'dark'
      : 'light'

    if (localStorage.getItem('theme') === 'light') systemTheme = 'light'
    if (localStorage.getItem('theme') === 'dark') systemTheme = 'dark'
    root.classList.add(systemTheme)
  }
}
