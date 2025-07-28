export const formatTimeRange = (timestamp) => {
  // Get the short weekday with proper formatting
  const weekday = timestamp.toLocaleString('de-DE', {
    weekday: 'short'
  }).replace(',', '').trim();
  
  // Format the day and month separately
  const day = timestamp.toLocaleString('de-DE', {
    day: '2-digit',
    month: '2-digit'
  });
  
  // Combine with just a single dot after weekday abbreviation
  const datePrefix = `${weekday}. ${day}`;

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
