import { Calendar } from '@/components/ui/calendar'
import { dateToString, stringToDate } from '@/lib/date-convert'

interface DatePickerProps {
  value: string[]
  onChange: (dates: string[]) => void
}

export function DatePicker({ value, onChange }: DatePickerProps) {
  return (
    <Calendar
      mode='multiple'
      selected={value?.map(stringToDate)}
      weekStartsOn={1}
      disabled={(date) => date > new Date()}
      onSelect={(dates) =>
        onChange(
          dates?.map(dateToString).sort((a, b) => b.localeCompare(a)) ?? []
        )
      }
    />
  )
}
