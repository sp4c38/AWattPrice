import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import PriceChart from './components/PriceChart';
import LoadingSpinner from './components/LoadingSpinner';
import CountrySelector from './components/CountrySelector';
import TaxToggle from './components/TaxToggle';
import PriceTable from './components/PriceTable';
import { fetchPriceData, applyTax, COUNTRIES } from './services/api';

function App() {
  const { t } = useTranslation();
  const [selectedCountry, setSelectedCountry] = useState('DE');
  const [includeTax, setIncludeTax] = useState(true);
  const [priceData, setPriceData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadData = async () => {
    try {
      setLoading(true);
      const data = await fetchPriceData(selectedCountry);
      const processedData = applyTax(data, selectedCountry, includeTax);
      setPriceData(processedData);
      setError(null);
    } catch (err) {
      setError('Failed to load electricity price data. Please try again later.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    // Refresh data every 5 minutes
    const interval = setInterval(loadData, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [selectedCountry, includeTax]); // Reload when country or tax setting changes

  const handleCountryChange = (country) => {
    setSelectedCountry(country);
  };

  const handleTaxToggle = (newValue) => {
    setIncludeTax(newValue);
  };

  return (
    <div className="min-h-screen p-4 sm:p-6 lg:p-8">
      <div className="max-w-7xl mx-auto relative">
        <header className="mb-8">
          <h1 className="text-3xl font-bold text-center mb-2 text-orange-500">
            {t('title')}
          </h1>
          <p className="text-gray-400 dark:text-gray-400 text-center mb-6">
            {t('description', { country: COUNTRIES[selectedCountry].name })}
          </p>
          <div className="space-y-4">
            <CountrySelector
              selectedCountry={selectedCountry}
              onCountryChange={handleCountryChange}
            />
            <TaxToggle
              includeTax={includeTax}
              onToggle={handleTaxToggle}
              selectedCountry={selectedCountry}
            />
          </div>
        </header>

        {error ? (
          <div className="bg-orange-900/30 border border-orange-500/50 text-orange-200 px-4 py-3 rounded relative" role="alert">
            <span className="block sm:inline">{t('error')}</span>
          </div>
        ) : loading ? (
          <LoadingSpinner />
        ) : (
          <>
            <div className="mb-12">
              <PriceChart 
                data={priceData} 
                title={t('chartTitle', { country: COUNTRIES[selectedCountry].name, tax: includeTax ? t('includeTax') : t('excludeTax') })}
              />
            </div>
            <div className="mb-8">
              <h2 className="text-xl font-semibold text-gray-200 mb-4">
                {t('detailedPriceData')}
              </h2>
              <div className="card p-0 overflow-hidden">
                <PriceTable 
                  data={priceData} 
                  includeTax={includeTax}
                />
              </div>
            </div>
          </>
        )}

        <footer className="mt-12 text-center text-sm text-gray-500 dark:text-gray-400">
          <p>{t('dataUpdates')}</p>
          <p className="mt-2">{t('lastUpdated', { time: new Date().toLocaleTimeString('de-DE') })}</p>
          <p className="mt-4 text-sm">{t('priceDisclaimer')}</p>
        </footer>
      </div>
    </div>
  );
}

export default App;
