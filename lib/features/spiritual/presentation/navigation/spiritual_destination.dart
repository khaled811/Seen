/// Every place the dashboard can send the user. Screens that do not exist yet
/// resolve to a placeholder (see `SpiritualPlaceholderScreen`); later
/// milestones swap in the real screen without touching the dashboard.
enum SpiritualDestination {
  tawaf,
  quranIndex,
  quranReader,
  duas,
  qibla,
  prayer,
  tasbeeh,
  cityPicker,
  profile,
}
