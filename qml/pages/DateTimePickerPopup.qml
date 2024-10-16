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
import Ubuntu.Components 1.3
import QtQuick.Controls 1.4 as QQC1
import QtQuick.Controls 2.2 as QQC
import QtQuick.Layouts 1.3
import Ubuntu.Components.Popups 1.3

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

// THIS IS THE non-UT VERSION! The difference to the UT version is that
// the QML Module Calendar from QtQuick.Controls 1.4 is used for date
// input. QtQuick.Controls 1.4 is not available in UT.

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

    property date helperDate

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

    function emitDateTimeSelected() {
        let temptext = ""
        if (dateRequested) {
            year = calendar.selectedDate.getFullYear()
            // Have to add 1 for the month because in contrast to getDate() and
            // getFullYear(), getMonth() will return the month as zero-based value.
            // WTF.
            month = calendar.selectedDate.getMonth() + 1
            day = calendar.selectedDate.getDate()
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
                id: rowData

                QQC1.Calendar {
                    id: calendar
                    visible: dateRequested
                }

                QQC.Tumbler {
                    id: hoursTumbler
                    anchors.verticalCenter: dateRequested ? calendar.verticalCenter : undefined
                    model: 24
                    delegate: delegateHourComponent
                    visible: timeRequested

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
                    id: timeSeparatorLabel
                    anchors.verticalCenter: hoursTumbler.verticalCenter
                    text: ":"
                    visible: timeRequested
                }

                QQC.Tumbler {
                    id: minutesTumbler
                    anchors.verticalCenter: hoursTumbler.verticalCenter
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
            } // Row id: rowData
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

            if (month < 1 || month > 12) {
                // getMonth() returns the month as zero-based value.
                month = tempdate.getMonth() + 1
            }

            let daysPerMonth = [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ]
            let daysMax = (month === 2 && isLeapYear(year)) ? 29 : daysPerMonth[month]
            if (day < 1 || day > daysMax) {
                day = tempdate.getDate()
            }

            // have to use a property of type QML date, couldn't make it work
            // otherwise as calendar.selectedDate does not accept strings as
            // created below
            helperDate = year.toString() + "-" + (month < 10 ? "0" : "") + month.toString() + "-" + (day < 10 ? "0" : "") + day.toString() + "T00:00"
            calendar.selectedDate = helperDate

            // Calendar might be too wide for the screen
            if (column.width > popover.width) {
                if (timeRequested) {
                    hoursTumbler.width = units.gu(4)
                    minutesTumbler.width = units.gu(4)
                    calendar.width = popover.width - hoursTumbler.width - timeSeparatorLabel.width - minutesTumbler.width
                } else {
                    calendar.width = popover.width
                }
            }
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
