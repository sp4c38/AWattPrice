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

const getOptions = (title) => ({
  responsive: true,
  maintainAspectRatio: false,
  interaction: {
    mode: 'index',
    intersect: false,
  },
  scales: {
    x: {
      type: 'time',
      time: {
        unit: 'hour',
        displayFormats: {
          hour: 'HH:mm'
        }
      },
      adapters: {
        date: {
          locale: de
        }
      },
      title: {
        display: true,
        text: 'Zeit',
        color: 'rgba(255, 255, 255, 0.8)'
      },
      grid: {
        color: 'rgba(255, 162, 77, 0.1)'
      },
      ticks: {
        color: 'rgba(255, 255, 255, 0.8)'
      }
    },
    y: {
      title: {
        display: true,
        text: 'Preis (ct/kWh)',
        color: 'rgba(255, 255, 255, 0.8)'
      },
      min: 0,
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
          return formatTimeRange(context[0].raw.x);
        },
        label: (context) => `${context.parsed.y.toFixed(2).replace('.', ',')} ct/kWh`
      },
      backgroundColor: 'rgba(255, 162, 77, 0.9)',
      titleColor: 'rgb(255, 255, 255)',
      bodyColor: 'rgb(255, 255, 255)',
      padding: 10,
      cornerRadius: 4
    }
  }
});

const PriceChart = ({ data, title }) => {
  const chartData = {
    datasets: [
      {
        data: data.map((item) => ({
          x: item.timestamp,
          y: item.price,
        })),
        backgroundColor: 'rgba(249, 115, 22, 0.8)',
        hoverBackgroundColor: 'rgba(249, 115, 22, 1)',
        borderRadius: 4,
        borderSkipped: false,
      },
    ],
  };

  return (
    <div className="w-full h-[600px] card p-4">
      <Bar options={getOptions(title)} data={chartData} />
    </div>
  );
};

export default PriceChart;
