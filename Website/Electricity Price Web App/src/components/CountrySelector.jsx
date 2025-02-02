import { COUNTRIES } from '../services/api';

const CountrySelector = ({ selectedCountry, onCountryChange }) => {
  return (
    <div className="flex justify-center space-x-4 mb-6">
      {Object.values(COUNTRIES).map((country) => (
        <button
          key={country.code}
          onClick={() => onCountryChange(country.code)}
          className={`
            px-4 py-2 rounded-lg flex items-center space-x-2 transition-all
            ${selectedCountry === country.code
              ? 'bg-orange-500 text-white'
              : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }
          `}
        >
          <span className="text-xl">{country.flag}</span>
          <span className="font-medium">{country.name}</span>
        </button>
      ))}
    </div>
  );
};

export default CountrySelector;
