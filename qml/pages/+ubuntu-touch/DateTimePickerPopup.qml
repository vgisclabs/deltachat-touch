/*
 * Copyright (C) 2024 Lothar Ketterer
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webenginetester is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Lomiri.Components 1.3
import QtQuick.Controls 2.2 as QQC
import QtQuick.Layouts 1.3
import Lomiri.Components.Popups 1.3

// Popover for date and/or time input. Date/time can be pre-set via the
// day/month/year/hour/minute properties, accepted dates range from 01.01.1901
// to 31.12.2100. Depending on the setting of dateRequested and timeRequested,
// either date or time or both are queried from the user. The date/time
// selected by the user is provided by the dateTimeSelected() signal, see
// comment for this signal below for the format of its parameter. This signal
// is only emitted if the user closes the popup by pressing the button with the
// tick mark, but not if the user closes it by pressing the "x" button or by
// clicking any area outside of the popover.  The closed() signal will be
// emitted when the popover closes for whatever reason.

// THIS IS THE UT VERSION! The difference to the non-UT version is that it uses
// Tumbler for date input as well because the QML Module Calendar from
// QtQuick.Controls 1.4 is not available in UT.

Popover {
    id: popover
    contentWidth: column.width

    property int day: -1
    property int month: -1
    property int year: -1
    property int hour: -1
    property int minute: -1
    property bool dateRequested: false
    property bool timeRequested: true

    // Parameter is a string with either date, or time, or both, as expected by
    // the HTML input element, examples:
    // type time: "20:23"
    // type date: "2023-12-01"
    // type dateTime-local: "2023-12-01T20:23"
    signal dateTimeSelected(string dateTime)

    // Signal will be emitted each time the popover is closed, i.e.,
    // on "ok" as well as on "close" or when the user clicks outside
    // of the popover (causing it to close)
    signal closed()

    function emitDateTimeSelected() {
        let temptext = ""
        if (dateRequested) {
            year = yearTumbler.currentIndex + 1901
            month = monthTumbler.currentIndex + 1
            day = daysTumbler.currentIndex + 1
            temptext = year.toString() + "-" + (month < 10 ? "0" : "") + month.toString() + "-" + (day < 10 ? "0" : "") + day.toString()

            if (timeRequested) {
                temptext += "T"
            }
        }

        if (timeRequested) {
            hour = hoursTumbler.currentIndex
            minute = minutesTumbler.currentIndex
            temptext += (hour < 10 ? "0" : "") + hour.toString() + ":" + (minute < 10 ? "0" : "") + minute.toString()
        }

        dateTimeSelected(temptext)
    }

    Column {
        id: column

        Row {
            id: rowButtons

            Rectangle {
                id: closeRect
                width: (frame.width / 2) - (separatorRect.width / 2)
                height: frame.height / 7
                color: "grey"

                Icon {
                    height: parent.height * 0.8
                    width: height
                    anchors.centerIn: parent
                    source: "qrc:///assets/suru-icons/close.svg"
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: PopupUtils.close(popover)
                }
            }

            Rectangle {
                id: separatorRect
                width: units.gu(0.2)
                height: closeRect.height
                color: "white"
            }

            Rectangle {
                id: okRect
                width: closeRect.width
                height: closeRect.height
                color: "grey"

                Icon {
                    height: parent.height * 0.8
                    width: height
                    anchors.centerIn: parent
                    source: "qrc:///assets/suru-icons/ok.svg"
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        emitDateTimeSelected()
                        PopupUtils.close(popover)
                    }
                }
            }
        }

        QQC.Frame {
            id: frame
            padding: 0

            Row {
                id: rowTumblers

                function isLeapYear(year) {
                    if (0 === year % 400) {
                      return true
                    } else if(0 === year % 100) {
                      return false
                    } else if(0 === year % 4) {
                      return true
                    } else{
                      return false
                    }
                }

                QQC.Tumbler {
                    id: yearTumbler
                    model: 200
                    delegate: delegateYearComponent
                    visible: dateRequested

                    // Scrolling is possible via touch, but not via mouse wheel by
                    // default in Tumbler (wtf). To enable mouse wheel (or touchpad
                    // 2-finger) scrolling, a MouseArea is added. mouse.accepted = false
                    // and other options are necessary for touch scrolling not to be
                    // blocked.
                    MouseArea {
                        property int scrollcounter: 0
                        anchors.fill: parent
                        propagateComposedEvents: true
                        scrollGestureEnabled: false
                        onClicked: mouse.accepted = false
                        onDoubleClicked: mouse.accepted = false
                        onPressAndHold: mouse.accepted = false
                        onPressed: mouse.accepted = false
                        onWheel: {
                            wheel.accepted = true
                            scrollcounter -= wheel.angleDelta.y
                            if (scrollcounter > 64) {
                                scrollcounter = 0
                                if (yearTumbler.currentIndex + 1 == yearTumbler.count) {
                                    yearTumbler.positionViewAtIndex(0, QQC.Tumbler.Center)
                                } else {
                                    yearTumbler.positionViewAtIndex(yearTumbler.currentIndex + 1, QQC.Tumbler.Center)
                                }
                            } else if (scrollcounter < -64) {
                                scrollcounter = 0
                                if (yearTumbler.currentIndex == 0) {
                                    yearTumbler.positionViewAtIndex(yearTumbler.count - 1, QQC.Tumbler.Center)
                                } else {
                                    yearTumbler.positionViewAtIndex(yearTumbler.currentIndex - 1, QQC.Tumbler.Center)
                                }
                            }
                        }
                    }
                }

                // In the current layout, when both date and time are requested,
                // there are 5 Tumblers, and it's a little bit hard to intuitively
                // grasp which Tumbler is for which setting. By separating the date
                // columns via "-" and the time columns via ":", it's hopefully
                // a little bit clearer.
                Label {
                    anchors.verticalCenter: hoursTumbler.verticalCenter
                    text: "-"
                    visible: dateRequested
                }

                QQC.Tumbler {
                    id: monthTumbler
                    model: 12
                    delegate: delegateMonthComponent
                    visible: dateRequested

                    MouseArea {
                        property int scrollcounter: 0
                        anchors.fill: parent
                        propagateComposedEvents: true
                        scrollGestureEnabled: false
                        onClicked: mouse.accepted = false
                        onDoubleClicked: mouse.accepted = false
                        onPressAndHold: mouse.accepted = false
                        onPressed: mouse.accepted = false
                        onWheel: {
                            wheel.accepted = true
                            scrollcounter -= wheel.angleDelta.y
                            if (scrollcounter > 64) {
                                scrollcounter = 0
                                if (monthTumbler.currentIndex + 1 == monthTumbler.count) {
                                    monthTumbler.positionViewAtIndex(0, QQC.Tumbler.Center)
                                } else {
                                    monthTumbler.positionViewAtIndex(monthTumbler.currentIndex + 1, QQC.Tumbler.Center)
                                }
                            } else if (scrollcounter < -64) {
                                scrollcounter = 0
                                if (monthTumbler.currentIndex == 0) {
                                    monthTumbler.positionViewAtIndex(monthTumbler.count - 1, QQC.Tumbler.Center)
                                } else {
                                    monthTumbler.positionViewAtIndex(monthTumbler.currentIndex - 1, QQC.Tumbler.Center)
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.verticalCenter: hoursTumbler.verticalCenter
                    text: "-"
                    visible: dateRequested
                }

                QQC.Tumbler {
                    id: daysTumbler
                    // model will be calculated via onCompleted, and via recalculateCount() which
                    // is bound to index changes in monthTumbler and yearTumbler
                    model: 28
                    delegate: delegateDayComponent
                    visible: dateRequested

                    property var daysPerMonth: [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]

                    function recalculateCount() {
                        let tempindex = daysTumbler.currentIndex
                        model = (monthTumbler.currentIndex == 1 && rowTumblers.isLeapYear(yearTumbler.currentIndex + 1901)) ? 29 : daysPerMonth[monthTumbler.currentIndex]
                        if (tempindex < count) {
                            daysTumbler.positionViewAtIndex(tempindex, QQC.Tumbler.Center)
                        }
                    }

                    MouseArea {
                        property int scrollcounter: 0
                        anchors.fill: parent
                        propagateComposedEvents: true
                        scrollGestureEnabled: false
                        onClicked: mouse.accepted = false
                        onDoubleClicked: mouse.accepted = false
                        onPressAndHold: mouse.accepted = false
                        onPressed: mouse.accepted = false
                        onWheel: {
                            wheel.accepted = true
                            scrollcounter -= wheel.angleDelta.y
                            if (scrollcounter > 64) {
                                scrollcounter = 0
                                if (daysTumbler.currentIndex + 1 == daysTumbler.count) {
                                    daysTumbler.positionViewAtIndex(0, QQC.Tumbler.Center)
                                } else {
                                    daysTumbler.positionViewAtIndex(daysTumbler.currentIndex + 1, QQC.Tumbler.Center)
                                }
                            } else if (scrollcounter < -64) {
                                scrollcounter = 0
                                if (daysTumbler.currentIndex == 0) {
                                    daysTumbler.positionViewAtIndex(daysTumbler.count - 1, QQC.Tumbler.Center)
                                } else {
                                    daysTumbler.positionViewAtIndex(daysTumbler.currentIndex - 1, QQC.Tumbler.Center)
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.verticalCenter: hoursTumbler.verticalCenter
                    text: "  "
                    visible: dateRequested && timeRequested
                }

                QQC.Tumbler {
                    id: hoursTumbler
                    model: 24
                    delegate: delegateHourComponent
                    visible: timeRequested

                    MouseArea {
                        property int scrollcounter: 0
                        anchors.fill: parent
                        propagateComposedEvents: true
                        scrollGestureEnabled: false
                        onClicked: mouse.accepted = false
                        onDoubleClicked: mouse.accepted = false
                        onPressAndHold: mouse.accepted = false
                        onPressed: mouse.accepted = false
                        onWheel: {
                            wheel.accepted = true
                            scrollcounter -= wheel.angleDelta.y
                            if (scrollcounter > 64) {
                                scrollcounter = 0
                                if (hoursTumbler.currentIndex + 1 == hoursTumbler.count) {
                                    hoursTumbler.positionViewAtIndex(0, QQC.Tumbler.Center)
                                } else {
                                    hoursTumbler.positionViewAtIndex(hoursTumbler.currentIndex + 1, QQC.Tumbler.Center)
                                }
                            } else if (scrollcounter < -64) {
                                scrollcounter = 0
                                if (hoursTumbler.currentIndex == 0) {
                                    hoursTumbler.positionViewAtIndex(hoursTumbler.count - 1, QQC.Tumbler.Center)
                                } else {
                                    hoursTumbler.positionViewAtIndex(hoursTumbler.currentIndex - 1, QQC.Tumbler.Center)
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.verticalCenter: hoursTumbler.verticalCenter
                    text: ":"
                    visible: timeRequested
                }

                QQC.Tumbler {
                    id: minutesTumbler
                    model: 60
                    delegate: delegateMinuteComponent
                    visible: timeRequested

                    MouseArea {
                        property int scrollcounter: 0
                        anchors.fill: parent
                        scrollGestureEnabled: true
                        propagateComposedEvents: true
                        onClicked: mouse.accepted = false
                        onDoubleClicked: mouse.accepted = false
                        onPressAndHold: mouse.accepted = false
                        onPressed: mouse.accepted = false
                        onWheel: {
                            wheel.accepted = true
                            scrollcounter -= wheel.angleDelta.y
                            if (scrollcounter > 64) {
                                scrollcounter = 0
                                if (minutesTumbler.currentIndex + 1 == minutesTumbler.count) {
                                    minutesTumbler.positionViewAtIndex(0, QQC.Tumbler.Center)
                                } else {
                                    minutesTumbler.positionViewAtIndex(minutesTumbler.currentIndex + 1, QQC.Tumbler.Center)
                                }
                            } else if (scrollcounter < -64) {
                                scrollcounter = 0
                                if (minutesTumbler.currentIndex == 0) {
                                    minutesTumbler.positionViewAtIndex(minutesTumbler.count - 1, QQC.Tumbler.Center)
                                } else {
                                    minutesTumbler.positionViewAtIndex(minutesTumbler.currentIndex - 1, QQC.Tumbler.Center)
                                }
                            }
                        }
                    }
                }
            } // Row id: rowTumblers
        } // Frame
    } // Column

    Component.onCompleted: {
        // properties year, month, day, hour, minute may be pre-set by the caller,
        // check whether these make sense. If not, use the current date.
        let tempdate = new Date()

        if (dateRequested) {
            if (year < 1901 || year > 2100) {
                year = tempdate.getFullYear()
            }

            if (month < 0 || month > 12) {
                // Have to add 1 for the month because in contrast to getDate() and
                // getFullYear(), getMonth() will return the month as zero-based value.
                // WTF.
                month = tempdate.getMonth() + 1
            }

            let daysMax = (month === 2 && rowTumblers.isLeapYear(year)) ? 29 : daysTumbler.daysPerMonth[month]
            if (day < 0 || day > daysMax) {
                day = tempdate.getDate()
            }

            monthTumbler.positionViewAtIndex(month - 1, QQC.Tumbler.Center)
            yearTumbler.positionViewAtIndex(year - 1901, QQC.Tumbler.Center)

            // model of daysTumbler has to be adapted when the month changes
            monthTumbler.currentIndexChanged.connect(daysTumbler.recalculateCount)
            // need to connect changes in yearTumbler as well to account for leap years
            yearTumbler.currentIndexChanged.connect(daysTumbler.recalculateCount)

            daysTumbler.recalculateCount()

            daysTumbler.positionViewAtIndex(day - 1, QQC.Tumbler.Center)
        }

        if (timeRequested) {
            if (hour < 0 || hour > 24) {
                hour = tempdate.getHours()
            }

            if (minute < 0 || minute > 60) {
                minute = tempdate.getMinutes()
            }

            hoursTumbler.positionViewAtIndex(hour, QQC.Tumbler.Center)
            minutesTumbler.positionViewAtIndex(minute, QQC.Tumbler.Center)
        }
    }

    Component.onDestruction: {
        closed()
    }

    Component {
        id: delegateDayComponent

        Label {
            id: delegateDayLabel
            text: model.index + 1
            opacity: 1.0 - Math.abs(QQC.Tumbler.displacement) / (QQC.Tumbler.tumbler.visibleItemCount / 2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    daysTumbler.positionViewAtIndex(model.index, QQC.Tumbler.Center)
                }
            }
        }
    }

    Component {
        id: delegateMonthComponent

        Label {
            id: delegateMonthLabel
            text: model.index + 1
            opacity: 1.0 - Math.abs(QQC.Tumbler.displacement) / (QQC.Tumbler.tumbler.visibleItemCount / 2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    monthTumbler.positionViewAtIndex(model.index, QQC.Tumbler.Center)
                }
            }
        }
    }

    Component {
        id: delegateYearComponent

        Label {
            id: delegateYearLabel
            text: model.index + 1901
            opacity: 1.0 - Math.abs(QQC.Tumbler.displacement) / (QQC.Tumbler.tumbler.visibleItemCount / 2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    yearTumbler.positionViewAtIndex(model.index, QQC.Tumbler.Center)
                }
            }
        }
    }

    Component {
        id: delegateHourComponent

        Label {
            id: delegateHourLabel
            text: model.index < 10 ? "0" + model.index.toString() : model.index.toString()
            opacity: 1.0 - Math.abs(QQC.Tumbler.displacement) / (QQC.Tumbler.tumbler.visibleItemCount / 2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    hoursTumbler.positionViewAtIndex(model.index, QQC.Tumbler.Center)
                }
            }
        }
    }

    Component {
        id: delegateMinuteComponent

        Label {
            id: delegateMinuteLabel
            text: model.index < 10 ? "0" + model.index.toString() : model.index.toString()
            opacity: 1.0 - Math.abs(QQC.Tumbler.displacement) / (QQC.Tumbler.tumbler.visibleItemCount / 2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    minutesTumbler.positionViewAtIndex(model.index, QQC.Tumbler.Center)
                }
            }
        }
    }
}
