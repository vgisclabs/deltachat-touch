/*
 * Copyright (C) 2022  Lothar Ketterer
 *
 * This file is part of the app "DeltaTouch".
 *
 * DeltaTouch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * DeltaTouch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
//import Lomiri.Components.Popups 1.3
//import Qt.labs.settings 1.0
//import QtMultimedia 5.12
//import QtQml.Models 2.12

import DeltaHandler 1.0

Page {
    id: imageViewer

    header: PageHeader {
        id: pageheader
        title: ""

        trailingActionBar.actions: [
            Action {
                iconName: 'save-as'
                text: i18n.tr("Save")
                onTriggered: {
                    layout.addPageToCurrentColumn(imageViewer, Qt.resolvedUrl("PickerImageToExport.qml"), {"url": imageViewerImage.source})
                }
                // for some reason, ContentHub doesn't work if the image viewer is
                // called from ProfileOther.qml. Error message in xenial is:
                // file:///usr/lib/arm-linux-gnueabihf/qt5/qml/Ubuntu/Components/Popups/1.3/Dialog.qml:239:13:
                // QML Column: Cannot specify top, bottom, verticalCenter, fill
                // or centerIn anchors for items inside Column. Column will not
                // function.
                // Disable downloading of profile images until a solution has been found.
                // TODO: find solution
                visible: enableDownloading
            }
        ]
    }

    property string imageSource
    property bool enableDownloading: true

    Image {
        id: imageViewerImage

        source: imageSource

        function checkXAndY() {
            let pageWidth = imageViewer.width
            let pageHeight = imageViewer.height - pageheader.height
            // Width + height do not change along with pinching. To get the
            // real width/height, it has to be multiplied with the scale
            let realImageWidth = imageViewerImage.paintedWidth * pinch.scale
            let realImageHeight = imageViewerImage.paintedHeight * pinch.scale

            // Similar for x and y: Refer to the theoretical x/y of the image
            // in its original scale, so the x/y value of the visible image
            // has to be calculated:
            let realX = imageViewerImage.x - ((realImageWidth - imageViewerImage.paintedWidth) / 2)
            // For y, the page pageheader has to be taken into account
            let realY = (imageViewerImage.y - ((realImageHeight - imageViewerImage.paintedHeight) / 2)) - pageheader.height

            // HORIZONTAL ALIGNMENT
            if (realImageWidth >= pageWidth) {
                // Currently, the image is wider than the page or just the same
                // size, so there should not be any canvas visible on the left
                // and right.
                if (realX < (pageWidth - realImageWidth)) {
                    // Currently, there's canvas on the right. We thus snap
                    // the image to the right:
                    realX = pageWidth - realImageWidth
                    // convert realX back to x
                    imageViewerImage.x = realX + ((realImageWidth - imageViewerImage.paintedWidth) / 2)
                } else if (realX > 0) {
                    // canvas visible on the left, snap to the left
                    realX = 0;
                    imageViewerImage.x = realX + ((realImageWidth - imageViewerImage.paintedWidth) / 2)
                }
            } else {
                // Width of image is smaller than page width. We have
                // to make sure that no part of the image is out of the
                // page area
                if (realX < 0) {
                    // Image is partly beyound the left border, snap it back
                    realX = 0;
                    imageViewerImage.x = realX + ((realImageWidth - imageViewerImage.paintedWidth) / 2)
                } else if (realX > (pageWidth - realImageWidth)) {
                    realX = pageWidth - realImageWidth
                    imageViewerImage.x = realX + ((realImageWidth - imageViewerImage.paintedWidth) / 2)
                }
            }

            // VERTICAL ALIGNMENT
            if (realImageHeight >= pageHeight) {
                // Currently, the image is taller than the page or just the same
                // size, so there should not be any canvas visible on top and bottom
                if (realY < (pageHeight - realImageHeight)) {
                    // Currently, there's canvas on the bottom. We thus snap
                    // the image to the the bottom:
                    realY = pageHeight - realImageHeight
                    // convert realY back to y
                    imageViewerImage.y = (realY + pageheader.height) + ((realImageHeight - imageViewerImage.paintedHeight) / 2)
                } else if (realY > 0) {
                    // canvas visible on the top, snap to top
                    realY = 0;
                    imageViewerImage.y = (realY + pageheader.height) + ((realImageHeight - imageViewerImage.paintedHeight) / 2)
                }
            } else {
                // Height of image is smaller than page height. We have
                // to make sure that no part of the image is out of the
                // page area
                if (realY < 0) {
                    // Image is partly beyound the top, snap it back
                    realY = 0;
                    imageViewerImage.y = (realY + pageheader.height) + ((realImageHeight - imageViewerImage.paintedHeight) / 2)
                } else if (realY > (pageHeight - realImageHeight)) {
                    realY = pageHeight - realImageHeight
                    imageViewerImage.y = (realY + pageheader.height) + ((realImageHeight - imageViewerImage.paintedHeight) / 2)
                }
            }
        }

        PinchHandler {
            id: pinch
            maximumRotation: 0
            minimumRotation: 0
            minimumScale: 0

            onActiveChanged: {
                if (!active) {
                    imageViewerImage.checkXAndY()
                }
            }
        }

        DragHandler {
            onActiveChanged: {
                if (!active) {
                    imageViewerImage.checkXAndY()
                }
            }
        }

        //fillMode: Image.PreserveAspectFit

        Component.onCompleted: {
            // TODO: more sophisticated pre-scaling - maybe check the other
            // dimension before scaling up one dimension, and if the other dimension
            // will overflow the page, then limit upscaling accordingly?
            // Also: scale down if image is larger than page?
            let scaleUpFactor
            if (imageViewerImage.width < units.gu(30)) {
                scaleUpFactor = units.gu(30) / imageViewerImage.width
                width = units.gu(30)
                height = height * scaleUpFactor
            }

            if (imageViewerImage.height < units.gu(30)) {
                scaleUpFactor = units.gu(30) / imageViewerImage.height
                height = units.gu(30)
                width = width * scaleUpFactor
            }

            y = pageheader.height
        }
    }
}
