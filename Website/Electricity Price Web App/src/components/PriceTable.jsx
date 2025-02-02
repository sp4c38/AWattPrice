import { useTranslation } from 'react-i18next';
import { formatTimeRange } from '../utils/formatTimeRange';

const PriceTable = ({ data, includeTax }) => {
  const { t } = useTranslation();
  return (
    <div className="overflow-x-auto rounded-lg">
      <table className="w-full text-sm">
        <thead>
          <tr>
            <th className="px-6 py-4 text-left text-gray-200 font-semibold bg-gray-800/80">{t('time')}</th>
            <th className="px-6 py-4 text-right text-gray-200 font-semibold bg-gray-800/80">
              {t('price')}
              <span className="text-xs text-gray-400 block">
                {includeTax ? t('includeTax') : t('excludeTax')}
              </span>
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-700">
          {data.map((item, index) => (
            <tr
              key={item.timestamp.getTime()}
              className={`
                ${index % 2 === 0 ? 'bg-gray-800/40' : 'bg-gray-800/20'}
                hover:bg-gray-700/40 transition-colors
              `}
            >
              <td className="px-6 py-3 text-gray-300 whitespace-nowrap">
                {formatTimeRange(item.timestamp)}
              </td>
              <td className="px-6 py-3 text-right text-gray-300 font-medium">
                {item.price.toFixed(2).replace('.', ',')}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default PriceTable;
