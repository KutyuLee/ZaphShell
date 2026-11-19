import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: weatherSvc

    required property var shellState

    Process {
        id: weatherFetchProc
        command: weatherSvc.shellState.weatherForceRefresh
            ? [weatherSvc.shellState.script("weather.sh"), "--force"]
            : [weatherSvc.shellState.script("weather.sh")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim());
                    if (obj.city) weatherSvc.shellState.weatherCity = obj.city;
                    if (obj.temp) weatherSvc.shellState.weatherTemp = obj.temp;
                    if (obj.tempShort) weatherSvc.shellState.weatherTempShort = obj.tempShort;
                    if (obj.feelsLike) weatherSvc.shellState.weatherFeelsLike = obj.feelsLike;
                    if (obj.humidity) weatherSvc.shellState.weatherHumidity = obj.humidity;
                    if (obj.wind) weatherSvc.shellState.weatherWind = obj.wind;
                    if (obj.icon) weatherSvc.shellState.rawWeatherIcon = obj.icon;
                    if (obj.desc) weatherSvc.shellState.rawWeatherDesc = obj.desc;
                    if (obj.isDay !== undefined) weatherSvc.shellState.weatherIsDay = !!obj.isDay;
                    if (obj.high) weatherSvc.shellState.weatherHigh = obj.high;
                    if (obj.low) weatherSvc.shellState.weatherLow = obj.low;
                    if (Array.isArray(obj.hourly) && obj.hourly.length > 0) weatherSvc.shellState.weatherHourly = obj.hourly;
                    if (Array.isArray(obj.forecast)) weatherSvc.shellState.weatherForecast = obj.forecast;
                } catch (e) {}
                weatherSvc.shellState.weatherForceRefresh = false;
            }
        }
    }

    Timer {
        id: weatherPeriodicTimer
        interval: 600000 // Refresh every 10 minutes
        running: true
        repeat: true
        onTriggered: {
            weatherSvc.shellState.weatherForceRefresh = false;
            weatherFetchProc.running = false;
            weatherFetchProc.running = true;
        }
    }

    function fetch(force) {
        weatherSvc.shellState.weatherForceRefresh = !!force;
        weatherFetchProc.running = false;
        weatherFetchProc.running = true;
    }
}
