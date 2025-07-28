import { Bar } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  TimeScale,
} from 'chart.js';
import 'chartjs-adapter-date-fns';
import { de } from 'date-fns/locale';
import { formatTimeRange } from '../utils/formatTimeRange';

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  TimeScale
);

const getOptions = (title, isHorizontal = false) => ({
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: isHorizontal ? 'y' : 'x',
  interaction: {
    mode: 'index',
    intersect: false,
  },
  scales: {
    x: {
      type: isHorizontal ? 'linear' : 'time',
      position: isHorizontal ? 'bottom' : undefined,
      time: isHorizontal ? undefined : {
        unit: 'hour',
        displayFormats: {
          hour: 'HH:mm'
        }
      },
      adapters: isHorizontal ? undefined : {
        date: {
          locale: de
        }
      },
      title: {
        display: true,
        text: isHorizontal ? 'Preis (ct/kWh)' : 'Zeit',
        color: 'rgba(255, 255, 255, 0.8)'
      },
      grid: {
        color: 'rgba(255, 162, 77, 0.1)'
      },
      ticks: {
        color: 'rgba(255, 255, 255, 0.8)'
      },
      min: isHorizontal ? 0 : undefined
    },
    y: {
      type: isHorizontal ? 'time' : 'linear',
      reverse: isHorizontal ? true : false, // Show earliest time at the top in horizontal view
      time: isHorizontal ? {
        unit: 'hour',
        displayFormats: {
          hour: 'HH:mm'
        }
      } : undefined,
      adapters: isHorizontal ? {
        date: {
          locale: de
        }
      } : undefined,
      title: {
        display: true,
        text: isHorizontal ? 'Zeit' : 'Preis (ct/kWh)',
        color: 'rgba(255, 255, 255, 0.8)'
      },
      min: isHorizontal ? undefined : 0,
      grid: {
        color: 'rgba(255, 162, 77, 0.1)'
      },
      ticks: {
        color: 'rgba(255, 255, 255, 0.8)'
      }
    }
  },
  plugins: {
    legend: {
      display: false
    },
    title: {
      display: true,
      text: title,
      color: 'rgb(255, 255, 255)',
      font: {
        size: 16,
        weight: 'normal'
      },
      padding: 20
    },
    tooltip: {
      callbacks: {
        title: (context) => {
          const timeValue = isHorizontal ? context[0].raw.y : context[0].raw.x;
          return formatTimeRange(timeValue);
        },
        label: (context) => {
          const priceValue = isHorizontal ? context[0].parsed.x : context[0].parsed.y;
          return `${priceValue.toFixed(2).replace('.', ',')} ct/kWh`;
        }
      },
      backgroundColor: 'rgba(255, 162, 77, 0.9)',
      titleColor: 'rgb(255, 255, 255)',
      bodyColor: 'rgb(255, 255, 255)',
      padding: 10,
      cornerRadius: 4
    }
  }
});

const PriceChart = ({ data, title, isHorizontal = false }) => {
  const chartData = {
    datasets: [
      {
        data: data.map((item) => ({
          x: isHorizontal ? item.price : item.timestamp,
          y: isHorizontal ? item.timestamp : item.price,
        })),
        backgroundColor: 'rgba(249, 115, 22, 0.8)',
        hoverBackgroundColor: 'rgba(249, 115, 22, 1)',
        borderRadius: 4,
        borderSkipped: false,
      },
    ],
  };

  // Calculate height based on data points and orientation
  const getChartHeight = () => {
    if (isHorizontal) {
      const baseHeight = Math.max(data.length * 25, 400);
      // For mobile devices (horizontal bars) we want to ensure enough height
      const isMobile = window.innerWidth < 768;
      return isMobile 
        ? Math.min(Math.max(baseHeight, window.innerHeight * 0.7), 1500)
        : Math.min(baseHeight, 1200);
    }
    return 600; // Default height for vertical chart
  };

  const chartHeight = getChartHeight();

  return (
    <div className={`w-full ${isHorizontal ? 'overflow-y-auto md:overflow-visible' : ''} card p-2 md:p-4`}>
      <div style={{ height: chartHeight + 'px' }} className="chart-container">
        <Bar options={getOptions(title, isHorizontal)} data={chartData} />
      </div>
    </div>
  );
};

export default PriceChart;
