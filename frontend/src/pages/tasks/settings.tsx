import SettingsForm from '@/components/settings/settings-form'
import { SheetContent } from '@/components/ui/sheet'
import useSettings from '@/hooks/use-settings'

export default function SettingsPage() {
  const { isLoading } = useSettings()

  return (
    !isLoading && (
      <SheetContent onOpenAutoFocus={(e) => e.preventDefault()}>
        <SettingsForm />
      </SheetContent>
    )
  )
}
