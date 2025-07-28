import { useTranslation } from 'react-i18next';

const ChartViewToggle = ({ isHorizontal, onToggle }) => {
  const { t } = useTranslation();
  
  return (
    <div className="flex items-center justify-between md:justify-end mb-2">
      <span className="text-xs md:text-sm text-gray-300 mr-2">
        {t('viewMode')}:
      </span>
      <div className="relative inline-flex">
        <button
          aria-label={t('verticalView')}
          className={`px-2 md:px-3 py-1 text-xs md:text-sm rounded-l-md ${
            !isHorizontal
              ? 'bg-orange-600 text-white'
              : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
          }`}
          onClick={() => onToggle(false)}
        >
          <span className="hidden sm:inline">{t('verticalView')}</span>
          <span className="sm:hidden">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2h-2" />
            </svg>
          </span>
        </button>
        <button
          aria-label={t('horizontalView')}
          className={`px-2 md:px-3 py-1 text-xs md:text-sm rounded-r-md ${
            isHorizontal
              ? 'bg-orange-600 text-white'
              : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
          }`}
          onClick={() => onToggle(true)}
        >
          <span className="hidden sm:inline">{t('horizontalView')}</span>
          <span className="sm:hidden">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 17V7m0 10a2 2 0 01-2 2H5m4 0h2m5-10v10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2z" />
            </svg>
          </span>
        </button>
      </div>
    </div>
  );
};

export default ChartViewToggle;
