import { COUNTRIES } from '../services/api';
import { useTranslation } from 'react-i18next';

const TaxToggle = ({ includeTax, onToggle, selectedCountry }) => {
  const { t } = useTranslation();
  const vatRate = Math.round((COUNTRIES[selectedCountry].taxMultiplier - 1) * 100);

  return (
    <div className="flex items-center justify-center">
      <label className="inline-flex items-center cursor-pointer">
        <div className="relative">
          <input
            type="checkbox"
            className="sr-only peer"
            checked={includeTax}
            onChange={(e) => onToggle(e.target.checked)}
          />
          <div className="w-11 h-6 bg-gray-700 rounded-full peer peer-checked:bg-orange-500 
                        peer-focus:ring-2 peer-focus:ring-orange-300 dark:peer-focus:ring-orange-800 
                        transition-all duration-300">
          </div>
          <div className="absolute left-[2px] top-[2px] w-5 h-5 bg-white rounded-full 
                        peer-checked:translate-x-full transition-all duration-300">
          </div>
        </div>
        <span className="ml-3 text-sm font-medium text-white">
          {t('includeTax')} ({vatRate}%)
        </span>
      </label>
    </div>
  );
};

export default TaxToggle;
