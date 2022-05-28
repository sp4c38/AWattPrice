<div>
	<img src="https://github.com/sp4c38/AWattPrice/blob/master/App%20Icon/AppIconDesign2.png?raw=true" width=100>
	<h1>⚡️ AWattPrice ⚡️</div>
</div>

<img src="https://img.shields.io/github/last-commit/sp4c38/AWattPrice?label=last%20modified" />

### App Store Download
<a href="https://apps.apple.com/app/awattprice/id1536629626"><img src="https://raw.githubusercontent.com/sp4c38/AWattPrice/master/readme_assets/download_button.png" width=190 height=63></img></a>  <a style="color:blue;" href="https://apps.apple.com/app/awattprice/id1536629626" target="_blank">

https://apps.apple.com/app/awattprice/id1536629626</a>

🌍 <b>Supported aWATTar regions:</b> Germany 🇩🇪 and Austria 🇦🇹

💰 <b> Cost:</b> 100% free of charge

💬 <b>Supported languages:</b> German and English

📱 <b>Supported devices:</b> iOS 14+ and iPadOS 14+ devices

🗂 <b>App category:</b> Utilities

### Description

AWattPrice shows the hourly prices by the electricity provider aWATTar. Instead of paying a fixed price for electricity, aWATTar customers are billed the current stock price. These prices are based on factors like available wind and
solar power generation. Hence, they vary over time. Let's say one wants to operate a washing machine for some time. It will pay
off to run it when prices are low. That reduces the electricity bill and helps the grid to balance out peaks. Further it strengthens
the use of regenerative power.

Features:

1️⃣ <b>Show</b> hourly electricity prices in an interactive chart.

2️⃣ <b>Find</b> the time frame with the lowest energy cost. Example: Charge the car by 23 kWh via an 11 kW outlet. The app will tell when to start for the minimal cost. You can also enter a time amount to find the cheapest prices for.

3️⃣ <b>Get notified</b> when prices drop under a certain value.

Prices are sourced from the public aWATTar data feed. You can
switch between prices for Austria and Germany. At about 2 pm the data is updated to show prices for the following day.

AWattPrice is a personal hobby project. Sharing is caring. The app is not related in any way to the company aWATTar GmbH.
Feedback of all kind and patches are very welcome.

## Screenshots
<div>
	<img src="https://github.com/sp4c38/AWattPrice/blob/master/readme_assets/screenshots/1_screenshot.png?raw=true" width=270>
	<img src="https://github.com/sp4c38/AWattPrice/blob/master/readme_assets/screenshots/2_screenshot.png?raw=true" width=270>
	<img src="https://github.com/sp4c38/AWattPrice/blob/master/readme_assets/screenshots/3_screenshot.png?raw=true" width=270>
</div>

### Technical Note:
AWattPrice consists out of two parts: The main app bundle and the backend part.
To not overload the public aWATTar API AWattPrice caches the current price data. The AWattPrice Backend will only call the aWATTar API a few times a day.
