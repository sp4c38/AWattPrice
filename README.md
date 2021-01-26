<div style="text-align:center">
	<img src="https://github.com/sp4c38/AWattPrice/blob/master/App%20Icon/AppIconDesign2.png?raw=true" width=100>
</div>

# ⚡️ AWattPrice ⚡️

<p>
<img src="https://img.shields.io/github/last-commit/sp4c38/AWattPrice?label=last%20modified" />
<img src="https://img.shields.io/tokei/lines/github/sp4c38/AWattPrice?label=total%20lines%20of%20code" />
</p>

### App Store Download
<a href="https://apps.apple.com/app/awattprice/id1536629626"><img src="https://raw.githubusercontent.com/sp4c38/AWattPrice/master/readme_assets/download_button.png" width=190 height=63></img></a>  <a style="color:blue;" href="https://apps.apple.com/app/awattprice/id1536629626" target="_blank">

https://apps.apple.com/app/awattprice/id1536629626</a>

### Description

AWattPrice is an app that displays electricity prices retrieved from the public aWATTar API.

aWATTar is an electricty provider, where customers don't pay a fix price for electricity, but instead pay as much for the electricity as it currently costs at stock exchange 📉. This is possible because the electricity price changes every hour.

🌍 Supported regions: Germany 🇩🇪 and Austria 🇦🇹

Current features are:

* View electricity prices throughout the day
* Find the hours when electricity is cheapest (e.g.: find cheapest time to charge electric car, turn on the washing machine or run other electrical consumers)

### Demo:
<img src="https://github.com/sp4c38/AWattPrice/blob/master/readme_assets/demo.gif" width="400"/>

### Technical Notes:
AWattPrice consists out of two parts: The main app bundle and the backend part.
To not overload the public aWATTar API AWattPrice caches the current price data. The AWattPrice Backend will only call the aWATTar API a few times a day.

##### Request Scheme of AWattPrice:
![Request Scheme](https://github.com/sp4c38/AWattPrice/blob/master/readme_assets/request_scheme.png)
