/**
 * Utility functions for handling base fee application
 */

/**
 * Apply base fee to electricity price data
 * @param {Array} data - The array of price data objects
 * @param {Number|null} baseFee - The base fee in cents to add to each price, or null for no base fee
 * @returns {Array} The price data with base fee applied
 */
export const applyBaseFee = (data, baseFee) => {
  // Return the original data if baseFee is null, undefined, or not a positive number
  if (baseFee === null || baseFee === undefined || isNaN(baseFee) || baseFee <= 0) {
    return data;
  }
  
  return data.map(item => ({
    ...item,
    price: item.price + baseFee,
    // Keep originalPrice unchanged as it should not include the base fee
  }));
};
