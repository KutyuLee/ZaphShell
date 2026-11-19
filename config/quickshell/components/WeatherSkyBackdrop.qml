import QtQuick
import ".."

// Shared animated Honor-style weather sky shader backdrop reused across ScreenFrame, Bar header glass, and WeatherPanel cards.
Item {
    id: root

    property real skyTime: ShellState.weatherSkyTime
    property real introProgress: ShellState.weatherSkyIntro
    property real cornerRadius: ShellState.rightIslandRadius

    readonly property string weatherMode: {
        if (ShellState.weatherDebugMode && ShellState.weatherDebugMode.length > 0) {
            if (ShellState.weatherDebugMode === "partlyCloudy") return "partly";
            return ShellState.weatherDebugMode;
        }
        const d = (ShellState.weatherDesc || "").toLowerCase();
        const ic = ShellState.weatherIcon || "";
        if (d.indexOf("thunder") !== -1 || d.indexOf("storm") !== -1 || ic === "󰙾") return "storm";
        if (d.indexOf("snow") !== -1 || d.indexOf("blizzard") !== -1 || d.indexOf("ice") !== -1 || d.indexOf("sleet") !== -1 || ic === "󰼶") return "snow";
        if (d.indexOf("rain") !== -1 || d.indexOf("drizzle") !== -1 || d.indexOf("shower") !== -1 || ic === "󰖗" || ic === "󰖖") return "rain";
        if (d.indexOf("fog") !== -1 || d.indexOf("mist") !== -1 || d.indexOf("haze") !== -1 || ic === "󰖑") return "fog";
        if (d.indexOf("overcast") !== -1 || (d.indexOf("cloud") !== -1 && d.indexOf("partly") === -1) || ic === "󰖐") return "cloudy";
        if (d.indexOf("partly") !== -1 || ic === "󰖕" || ic === "󰼱") return "partly";
        return "clear";
    }

    readonly property bool isNight: ShellState.isWeatherNight

    property real cloudWeight: weatherMode === "clear" ? 0.04 : (weatherMode === "partly" ? 0.42 : (weatherMode === "cloudy" ? 0.92 : 0.95))
    property real sunWeight: weatherMode === "clear" ? 1.0 : (weatherMode === "partly" ? 0.94 : 0.0)
    property real rainWeight: (weatherMode === "rain" || weatherMode === "storm") ? 1.0 : 0.0
    property real stormWeight: weatherMode === "storm" ? 1.0 : 0.0
    property real snowWeight: weatherMode === "snow" ? 1.0 : 0.0
    property real fogWeight: weatherMode === "fog" ? 1.0 : 0.0
    property real nightWeight: isNight ? 1.0 : 0.0

    Behavior on cloudWeight { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on sunWeight   { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on rainWeight  { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on stormWeight { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on snowWeight  { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on fogWeight   { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on nightWeight { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

    property color skyTopColor: {
        if (isNight) {
            switch (weatherMode) {
                case "clear":  return "#060B1A";
                case "partly": return "#091024";
                case "cloudy": return "#131724";
                case "rain":   return "#0C1322";
                case "storm":  return "#070914";
                case "snow":   return "#121B2E";
                case "fog":    return "#161D29";
                default:       return "#091024";
            }
        }
        switch (weatherMode) {
            case "clear":  return "#1B529E";
            case "partly": return "#2159A6";
            case "cloudy": return "#3B4459";
            case "rain":   return "#253147";
            case "storm":  return "#1A1E30";
            case "snow":   return "#3D4F6E";
            case "fog":    return "#465163";
            default:       return "#2159A6";
        }
    }
    property color skyMidColor: {
        if (isNight) {
            switch (weatherMode) {
                case "clear":  return "#0D1B38";
                case "partly": return "#142342";
                case "cloudy": return "#1E2436";
                case "rain":   return "#162238";
                case "storm":  return "#121528";
                case "snow":   return "#1E2D4A";
                case "fog":    return "#242E3F";
                default:       return "#142342";
            }
        }
        switch (weatherMode) {
            case "clear":  return "#2B6EC2";
            case "partly": return "#3576C4";
            case "cloudy": return "#4C556B";
            case "rain":   return "#32415C";
            case "storm":  return "#252940";
            case "snow":   return "#566B8C";
            case "fog":    return "#5E6B7D";
            default:       return "#3576C4";
        }
    }
    property color skyBotColor: {
        if (isNight) {
            switch (weatherMode) {
                case "clear":  return "#081124";
                case "partly": return "#0B1328";
                case "cloudy": return "#0E111C";
                case "rain":   return "#090E1A";
                case "storm":  return "#060710";
                case "snow":   return "#0E1526";
                case "fog":    return "#10151F";
                default:       return "#0B1328";
            }
        }
        switch (weatherMode) {
            case "clear":  return "#15325E";
            case "partly": return "#193869";
            case "cloudy": return "#1F2436";
            case "rain":   return "#161D2E";
            case "storm":  return "#121422";
            case "snow":   return "#24314A";
            case "fog":    return "#283040";
            default:       return "#193869";
        }
    }

    Behavior on skyTopColor { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on skyMidColor { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on skyBotColor { ColorAnimation { duration: 520; easing.type: Easing.OutCubic } }

    ShaderEffect {
        anchors.fill: parent
        property real uTime: root.skyTime
        property real uIntro: root.introProgress
        property real uCloudiness: root.cloudWeight
        property real uSunAmount: root.sunWeight
        property real uRainAmount: root.rainWeight
        property real uStormAmount: root.stormWeight
        property real uSnowAmount: root.snowWeight
        property real uFogAmount: root.fogWeight
        property real uNightAmount: root.nightWeight
        property real uCornerRadius: root.cornerRadius
        property color uSkyTop: root.skyTopColor
        property color uSkyMid: root.skyMidColor
        property color uSkyBot: root.skyBotColor
        property size uSize: Qt.size(Math.max(1, width), Math.max(1, height))
        fragmentShader: Qt.resolvedUrl("weather_sky_night.frag.qsb")
    }
}
