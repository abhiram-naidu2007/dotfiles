import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var sys

    function errText(e) {
        return e === "no-key"        ? page.sys.tr("No key entered")
             : e === "no-city"       ? page.sys.tr("No city entered")
             : e === "bad-key"       ? page.sys.tr("The key was rejected. Check that it was copied whole.")
             : e === "no-such-city"  ? page.sys.tr("The service does not know that city")
             : e === "rate-limit"    ? page.sys.tr("Too many requests. The key hit its rate limit.")
             : e === "network"       ? page.sys.tr("Could not reach the service")
             : e === "no-curl"       ? page.sys.tr("curl is missing")
             : e === "no-jq"         ? page.sys.tr("jq is missing")
             : e === "bad-answer"    ? page.sys.tr("Could not parse the service reply")
             : page.sys.tr("The service refused") + " (" + e + ")";
    }

    Layout.fillWidth: true
    spacing: 12

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("OpenWeatherMap key") }

        Rectangle {
            id: rectangl
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            property bool shown: false

            TextInput {
                id: keyInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 38
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.weatherKey
                echoMode: parent.shown ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    page.sys.cfg.weatherKey = text.trim();
                    page.sys.saveCfg();
                    page.sys.refreshWeather();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: keyInput.text.length === 0
                    text: page.sys.tr("The 32-character string from the API keys page")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: keyInput.font
                }
            }

            Text {
                id: eye
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(parent.shown ? 0xF0209 : 0xF0208)
                color: eyeMa.containsMouse ? page.sys.colFg : page.sys.colMuted
                font { family: page.sys.fontFam; pixelSize: page.sys.iconSize - 2 }
                Behavior on color { ColorAnimation { duration: 140 } }

                MouseArea {
                    id: eyeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rectangl.shown = !rectangl.shown
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Get one free at openweathermap.org. A new key starts working after an hour or two.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("Stored in settings.json as plain text.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("City") }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 10
            color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.07)

            TextInput {
                id: cityInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                color: page.sys.colFg
                clip: true
                selectByMouse: true
                text: page.sys.cfg.weatherCity
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                onEditingFinished: {
                    page.sys.cfg.weatherCity = text.trim();
                    page.sys.saveCfg();
                    page.sys.refreshWeather();
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: cityInput.text.length === 0
                    text: page.sys.tr("A name or a postcode: Moscow,RU or 101000")
                    color: page.sys.colMuted
                    elide: Text.ElideRight
                    font: cityInput.font
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("A postal code works too. Many cities share a name: if the wrong one is found, add the country code, for example Chennai,IN.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        SetToggle {
            sys: page.sys
            label: page.sys.tr("Weather in the island")
            sub: page.sys.tr("Icon and temperature in the collapsed island, next to the workspaces.")
            on: page.sys.cfg.weatherOnIsland
            onToggled: v => {
                page.sys.cfg.weatherOnIsland = v;
                page.sys.saveCfg();
                if (v) page.sys.refreshWeather();
            }
        }

        SetSelect {
            sys: page.sys
            label: page.sys.tr("Scale")
            options: [
                { id: "metric",   text: page.sys.tr("Celsius") },
                { id: "imperial", text: page.sys.tr("Fahrenheit") }
            ]
            value: page.sys.cfg.weatherUnits
            onPicked: id => {
                page.sys.cfg.weatherUnits = id;
                page.sys.saveCfg();
                page.sys.refreshWeather();
            }
        }
    }

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Now") }

        Text {
            Layout.fillWidth: true
            text: page.sys.weatherBusy
                  ? page.sys.tr("Asking…")
                  : page.sys.weatherErr.length
                    ? page.errText(page.sys.weatherErr)
                    : page.sys.weatherReady
                      ? page.sys.weatherPlace + " · " + page.sys.weatherTemp + "°"
                        + page.sys.weatherUnitLetter + " · " + page.sys.weatherDesc
                      : page.sys.tr("Not asked yet")
            color: page.sys.weatherErr.length ? page.sys.colCrit : page.sys.colFg
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
        }

        Text {
            Layout.fillWidth: true
            visible: page.sys.weatherReady
            text: page.sys.tr("Humidity") + " " + page.sys.weatherHumidity + "% · "
                  + page.sys.tr("Wind") + " " + page.sys.weatherWind + " "
                  + page.sys.weatherWindUnit + " · "
                  + page.sys.tr("Feels like") + " " + page.sys.weatherFeels + "°"
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            SetButton {
                sys: page.sys
                text: page.sys.tr("Refresh")
                primary: true
                enabled: !page.sys.weatherBusy
                onClicked: page.sys.refreshWeather()
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.sys.tr("The shell checks the weather every 15 minutes.")
            color: page.sys.colMuted
            wrapMode: Text.WordWrap
            font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
        }
    }
}
