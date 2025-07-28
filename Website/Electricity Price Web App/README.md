# Electricity Price Web App

A web application to display electricity prices for different European countries.

## Features

- Real-time electricity price data for Germany and Austria
- Toggle between prices with and without tax
- Interactive price chart and detailed price table
- Country selection via UI
- Support for URL parameters to specify country and view orientation
- Optional base fee that can be added to all prices via URL parameter

## URL Parameters

The app supports the following URL parameters:

- `country`: Set the initial country (e.g., `?country=AT` for Austria, `?country=DE` for Germany)
- `baseFee`: Add a base fee in cents to all price points (e.g., `?baseFee=5.5` adds 5.5 cents/kWh to all prices)
- `view`: Set the chart view orientation (`horizontal` or `vertical`)

Examples:
- `https://your-app-url.com/?country=AT`
- `https://your-app-url.com/?baseFee=4.2&country=DE`

## Development

This project is built with React + Vite.

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh
