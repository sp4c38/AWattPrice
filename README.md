<p align="left">
  <img src="website/images/app-icon.png" width="96" alt="AWattPrice app icon">
</p>

# AWattPrice

<img src="https://img.shields.io/github/last-commit/sp4c38/AWattPrice/develop?label=last%20modified" alt="Last modified">

AWattPrice helps people understand dynamic electricity prices and find
cost-effective windows for power consumption. The app shows upcoming prices in
a clear, interactive graph, helps plan larger appliances such as washing
machines, dishwashers, heat pumps, and electric vehicles, and can tailor the
display to a specific tariff.

It runs on iOS, iPadOS, and macOS, with a FastAPI backend for cached ENTSO-E
market data and price notifications.

<a href="https://apps.apple.com/app/awattprice/id1536629626">
  <img src="website/images/promotional/landscape-banner-ad-1200x720.png" alt="AWattPrice landscape banner">
</a>


## Features

- Interactive price chart for current and upcoming electricity prices.
- Cheapest-window finder for appliances, EV charging, heat pumps, and similar
  loads.
- Tariff adjustments with fixed surcharges, percentage-based fees, monthly
  costs, and taxes where available.
- Push notifications when prices move below or above configured thresholds.
- Energy mix insights, including renewable share where the backend has data.
- Home screen widgets for current prices, upcoming prices, cheap windows, and
  renewable mix.
- German and English localization.

## App Store Screenshots

<p align="center">
  <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-1-Intro%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 1 in English">
  <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-2-Feature%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 2 in English">
  <span style="white-space: nowrap;">
    <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-3-Feature%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 3 in English">
    <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-4-Feature%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 4 in English">
  </span>
  <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-5-Feature%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 5 in English">
  <span style="white-space: nowrap;">
    <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-6-Quotes%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 6 in English">
    <img src="website/images/screenshots/iPhone%206.9″%20for%20App%20Store/en-us-7-Feature%20-%20iPhone.png" width="220" alt="AWattPrice App Store screenshot 7 in English">
  </span>
</p>

## Project Structure

```text
AWattPrice/
  AWattPrice.xcodeproj       Xcode project for the app and widget extension
  AWattPrice/                SwiftUI app target
  AWattPriceWidget/          WidgetKit extension
  Shared/                    Shared models, API client, resources, and storage
  AWattPriceTests/           Unit tests

backend/
  src/                       FastAPI app, data refresher, and notifications
  docs/                      Backend data-flow notes
  compose.v3.yaml            Production Compose setup

website/
  index.html                 Public website with App Store, support, and legal links
  images/                    App icon, App Store badge, screenshots, and media
```
