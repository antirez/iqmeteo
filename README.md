IQ Meteo for vivoactive HR
===

The default weather application of the Garmin vivoactive HR reports very
inaccurate current conditions and forecasts here in Italy, at least in
the city I live.

This widget uses Yahoo Weather in order to replace the default weather
widget with one capable of reporting accurate informations.

Main features of this widget:

* Uses the GPS to get the user position, in order to fetch Yahoo weather information for the exact location.
* Caching of the GPS position. It is only re-fetched if the user long presses the vivoactive HR right button.
* Programmatically generated icons: fast and small.
* Auto switch of temperature unit based on device configuration.
* Single view current condition and forecasts.
* Easy with CPU and battery. It caches the latest condition in order to just render it immediately, while performign the new query. Does not query again if less than 30 seconds elapsed since the latest query.

Currently no other Garmin watches are supported, just the vivosmart HR.
The code is released under the GPL v3 license.
