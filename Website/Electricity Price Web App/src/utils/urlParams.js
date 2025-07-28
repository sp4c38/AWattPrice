/**
 * Utility functions for handling URL parameters
 */

/**
 * Get a parameter value from the URL
 * @param {string} paramName - The name of the parameter to retrieve
 * @param {string} defaultValue - Default value if parameter is not found
 * @returns {string} The parameter value or default value
 */
export const getUrlParameter = (paramName, defaultValue = null) => {
  const params = new URLSearchParams(window.location.search);
  const value = params.get(paramName);
  return value || defaultValue;
};

/**
 * Set a parameter value in the URL without reloading the page
 * @param {string} paramName - The name of the parameter to set
 * @param {string} value - The value to set
 */
export const setUrlParameter = (paramName, value) => {
  const url = new URL(window.location);
  url.searchParams.set(paramName, value);
  window.history.pushState({}, '', url);
};
