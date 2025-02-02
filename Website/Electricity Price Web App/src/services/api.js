import axios from 'axios';

const BASE_URL = 'https://awattprice.space8.me/api/v2/data';

export const COUNTRIES = {
  DE: {
    code: 'DE',
    name: 'Deutschland',
    flag: '🇩🇪',
    taxMultiplier: 1.19
  },
  AT: {
    code: 'AT',
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
    const response = await axios.get(`${BASE_URL}/${country}`);
    
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
