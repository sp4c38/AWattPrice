export const formatTimeRange = (timestamp) => {
  const datePrefix = timestamp.toLocaleString('de-DE', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit'
  }).replace(',', '.');

  const startHour = timestamp.toLocaleString('de-DE', {
    hour: '2-digit',
    minute: '2-digit'
  });

  const endTime = new Date(timestamp);
  endTime.setHours(endTime.getHours() + 1);
  const endHour = endTime.toLocaleString('de-DE', {
    hour: '2-digit',
    minute: '2-digit'
  });

  return `${datePrefix} ${startHour} - ${endHour}`;
};
