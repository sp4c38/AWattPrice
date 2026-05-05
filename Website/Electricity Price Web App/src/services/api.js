import axios from 'axios';

// Use a relative URL so local Vite and production nginx can proxy to the API host.
const BASE_URL = '/api/v3/prices';

export const COUNTRIES = {
  DE: {
    code: 'DE',
    areaKey: 'DE-LU',
    name: 'Deutschland',
    flag: '🇩🇪',
    taxMultiplier: 1.19
  },
  AT: {
    code: 'AT',
    areaKey: 'AT',
    name: 'Österreich',
    flag: '🇦🇹',
    taxMultiplier: 1.20
  }
};

const convertPrice = (priceInEuroPerMWh) => {
  // Convert from Euro/MWh to Cents/kWh
  // Euro/MWh ÷ 10 = Cents/kWh
  return priceInEuroPerMWh / 10;
};

export const fetchPriceData = async (country) => {
  try {
    const areaKey = COUNTRIES[country].areaKey;
    const response = await axios.get(`${BASE_URL}/${areaKey}`);
    
    if (!response.data || !Array.isArray(response.data.prices)) {
      throw new Error('Invalid API response format');
    }

    const now = new Date();
    const startOfCurrentHour = new Date(now);
    startOfCurrentHour.setMinutes(0, 0, 0);

    return response.data.prices
      .map(item => ({
        timestamp: new Date(item.start_timestamp * 1000),
        price: convertPrice(item.marketprice),
        originalPrice: convertPrice(item.marketprice), // Store original price for tax calculations
      }))
      .filter(item => item.timestamp >= startOfCurrentHour) // Include current hour and future prices
      .sort((a, b) => a.timestamp - b.timestamp);

  } catch (error) {
    console.error(`Error fetching price data for ${country}:`, error);
    throw error;
  }
};

export const applyTax = (data, country, includeTax) => {
  return data.map(item => ({
    ...item,
    price: includeTax 
      ? item.originalPrice * COUNTRIES[country].taxMultiplier 
      : item.originalPrice
  }));
};
