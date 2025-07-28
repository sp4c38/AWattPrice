import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import PriceChart from './components/PriceChart';
import LoadingSpinner from './components/LoadingSpinner';
import CountrySelector from './components/CountrySelector';
import TaxToggle from './components/TaxToggle';
import ChartViewToggle from './components/ChartViewToggle';
import PriceTable from './components/PriceTable';
import { fetchPriceData, applyTax, COUNTRIES } from './services/api';
import { getUrlParameter, setUrlParameter } from './utils/urlParams';
import { applyBaseFee } from './utils/baseFee';

function App() {
  const { t } = useTranslation();
  
  // Parse URL parameters for initial country selection
  const getInitialCountry = () => {
    const countryParam = getUrlParameter('country');
    
    // Check if the country parameter is valid (matches one of our country codes)
    if (countryParam) {
      // Convert to uppercase for consistent comparison
      const normalizedCountry = countryParam.toUpperCase();
      
      // Check if it's a valid country code
      if (Object.keys(COUNTRIES).includes(normalizedCountry)) {
        return normalizedCountry;
      }
    }
    
    // Default to Germany if no valid country parameter is found
    return 'DE';
  };

  const getInitialChartView = () => {
    const viewParam = getUrlParameter('view');
    // Default to vertical on desktop and horizontal on mobile
    const isMobile = window.innerWidth < 768;
    if (viewParam === 'horizontal') return true;
    if (viewParam === 'vertical') return false;
    return isMobile; // Default to horizontal on mobile
  };
  
  // Get base fee from URL parameter
  const getBaseFee = () => {
    const baseFeeParam = getUrlParameter('baseFee');
    if (baseFeeParam) {
      try {
        const parsedFee = parseFloat(baseFeeParam);
        // Only apply base fee if it's a valid positive number
        if (!isNaN(parsedFee) && isFinite(parsedFee) && parsedFee > 0) {
          // Round to 2 decimal places for consistency
          return Math.round(parsedFee * 100) / 100;
        }
      } catch (err) {
        console.warn('Invalid base fee parameter:', baseFeeParam);
      }
    }
    return null; // No base fee by default
  };
  
  const [selectedCountry, setSelectedCountry] = useState(getInitialCountry);
  const [includeTax, setIncludeTax] = useState(true);
  const [horizontalView, setHorizontalView] = useState(getInitialChartView);
  const [priceData, setPriceData] = useState([]);
  const [baseFee, setBaseFee] = useState(getBaseFee);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadData = async () => {
    try {
      setLoading(true);
      const data = await fetchPriceData(selectedCountry);
      let processedData = applyTax(data, selectedCountry, includeTax);
      
      // Apply base fee if it exists
      if (baseFee !== null) {
        processedData = applyBaseFee(processedData, baseFee);
      }
      
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
  }, [selectedCountry, includeTax, baseFee]); // Reload when country, tax setting, or base fee changes

  // Add a window resize listener to auto-switch to horizontal mode on mobile
  useEffect(() => {
    const handleResize = () => {
      const isMobile = window.innerWidth < 768;
      if (isMobile && !horizontalView) {
        setHorizontalView(true);
      }
    };
    
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [horizontalView]);

  const handleCountryChange = (country) => {
    setSelectedCountry(country);
    
    // Update URL with the new country parameter
    setUrlParameter('country', country);
  };

  const handleTaxToggle = (newValue) => {
    setIncludeTax(newValue);
  };
  
  const handleViewToggle = (isHorizontal) => {
    setHorizontalView(isHorizontal);
    setUrlParameter('view', isHorizontal ? 'horizontal' : 'vertical');
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
              <ChartViewToggle 
                isHorizontal={horizontalView} 
                onToggle={handleViewToggle} 
              />
              {baseFee !== null && (
                <div className="mt-2 mb-4 py-2 px-3 bg-orange-900/30 border border-orange-500/50 text-orange-200 text-sm rounded-md">
                  {t('baseFeeApplied', { fee: baseFee.toFixed(2).replace('.', ',') })}
                </div>
              )}
              <PriceChart 
                data={priceData}
                isHorizontal={horizontalView}
                title={t('chartTitle', { 
                  country: COUNTRIES[selectedCountry].name, 
                  tax: includeTax ? t('includeTax') : t('excludeTax')
                }) + (baseFee !== null ? ` + ${t('baseFee')}` : '')}
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
                  baseFee={baseFee}
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
