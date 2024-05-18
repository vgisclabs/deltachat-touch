/*
 * Copyright (C) 2022  Lothar Ketterer
 *
 * This file is part of the app "DeltaTouch".
 *
 * DeltaTouch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by * the Free Software Foundation; version 3.
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
import Lomiri.Components.Popups 1.3
//import Qt.labs.settings 1.0
//import QtMultimedia 5.12
//import QtQml.Models 2.12
import Qt.labs.platform 1.1

import DeltaHandler 1.0

Page {
    id: createGroupPage

    property bool hasChatPic: false
    property bool createNewGroup: false
    property bool selfIsInGroup: true

    property string headerNew: i18n.tr("New Group")
    property string headerEdit: i18n.tr("Edit Group")

    signal prepareAddMembers()

    Loader {
        id: picImportLoader
    }

    Connections {
        target: picImportLoader.item
        onFileSelected: {
            createGroupPage.setPic(urlOfFile)
            picImportLoader.source = ""
        }
        onCancelled: {
            picImportLoader.source = ""
        }
    }

    function updateChatPic(newPath) {
        if (newPath != "") {
            chatPicImage.source = StandardPaths.locate(StandardPaths.CacheLocation, newPath)
            hasChatPic = true
        }
    }

    function updateMemberCount(mcount) {
        memberCount = mcount
    }

    function setPic(imagePath) {
        if (!root.onUbuntuTouch) {
            let tempPath = DeltaHandler.copyToCache(imagePath)
            DeltaHandler.setGroupPic(tempPath)
        } else {
            // the UT specific file import has already called copyToCache
            DeltaHandler.setGroupPic(imagePath)
        }
    }

    function openFileDialog() {
        // only for non-UT
        picImportLoader.source = "FileImportDialog.qml"
        picImportLoader.item.setFileType(DeltaHandler.ImageType)
        picImportLoader.item.open()
    }

    Component.onCompleted: {
        DeltaHandler.newChatPic.connect(updateChatPic)
        DeltaHandler.groupmembermodel.groupMemberCountChanged.connect(updateMemberCount)
        createGroupPage.prepareAddMembers.connect(DeltaHandler.prepareContactsmodelForGroupMemberAddition)

        if (!createNewGroup) {
            let groupPicture = DeltaHandler.getTempGroupPic()
            if (groupPicture != "") {
                chatPicImage.source = StandardPaths.locate(StandardPaths.AppConfigLocation, groupPicture)
                hasChatPic = true
            }
            groupNameField.text = DeltaHandler.getTempGroupName()
        }
    }

    header: PageHeader {
        id: createGroupHeader
        title: createNewGroup ? headerNew : headerEdit

        // Switch off the back icon to avoid unclear situation. User
        // has to explicitly choose cancel or ok.
        leadingActionBar.numberOfSlots: 2
        leadingActionBar.actions: [
            Action {
                iconSource: Qt.resolvedUrl('../../assets/verified.svg')
                visible: DeltaHandler.tempGroupIsVerified()
            },
            Action {
                iconName: 'close'
                text: i18n.tr('Cancel')
                onTriggered: {
                    DeltaHandler.stopCreateOrEditGroup()
                    extraStack.pop()
                }
            }
        ]

        //trailingActionBar.numberOfSlots: 2
        trailingActionBar.actions: [
            Action {
                iconName: 'ok'
                text: i18n.tr('OK')
                onTriggered: {
                    groupNameField.focus = false
                    if (groupNameField.text == "") {
                        PopupUtils.open(errorMessage)
                    } else {
                        groupNameField.focus = false
                        DeltaHandler.finalizeGroupEdit(groupNameField.text, chatPicImage.source)
                        extraStack.pop()
                    }
                }
                visible: selfIsInGroup
            },
            Action {
                iconName: 'view-grid-symbolic'
                text: i18n.tr("QR Invite Code")
                onTriggered: {
                    extraStack.push(Qt.resolvedUrl("QrGroupInvite.qml"))
                }
                visible: selfIsInGroup && !createNewGroup
            }
        ]
    }

    ListItemActions {
        id: leadingMemberAction
        actions: Action {
            iconName: "delete"
            onTriggered: {
                // the index is passed as parameter and can
                // be accessed via 'value'
                PopupUtils.open(
                    Qt.resolvedUrl('ConfirmMemberDeletion.qml'),
                    null,
                    { 'memberVectorIndex': value, }
                )
            }
        }
    }

    LomiriShape {
        id: chatPic
        width: units.gu(12)
        height: width
        anchors {
            top: createGroupHeader.bottom
            topMargin: units.gu(2)
            left: parent.left
            leftMargin: units.gu(1)
        }
        color: "grey"
        source: hasChatPic ? chatPicImage : placeholderImage 
        Image {
            id: placeholderImage
            visible: false
            source: "../../assets/image-icon3.svg"
        }
        Image {
            id: chatPicImage
            visible: false
            source: ""
        }
        sourceFillMode: LomiriShape.PreserveAspectCrop
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (chatPicImage.source != "") {
                    // don't use imageStack as it is layered below extraStack
                    extraStack.push(Qt.resolvedUrl("ImageViewer.qml"), { "imageSource": chatPicImage.source, "enableDownloading": false, "onExtraStack": true })
                }
            }
        }
    }

    Rectangle {
        // ugly hack to be able to position
        // editImageShape with an offset of 
        // just units.gu(1)
        id: positionHelperEditImage
        height: units.gu(2)
        width: height
        anchors {
            verticalCenter: chatPic.top
            horizontalCenter: chatPic.right
        }
        color: theme.palette.normal.background
        visible: selfIsInGroup
    }

    LomiriShape {
        id: editImageShape
        height: units.gu(4)
        width: height
        anchors {
            top: positionHelperEditImage.top
            right: positionHelperEditImage.right
        }
        //color: theme.palette.normal.background
        color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 

        Icon {
            anchors.fill: parent
            name: "edit"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                PopupUtils.open(componentChatPicActions, editImageShape)
            }
        }
        visible: selfIsInGroup
    }
    
    Label {
        id: groupNameLabel
        anchors {
            top: createGroupHeader.bottom
            topMargin: units.gu(3)
            horizontalCenter: groupNameField.horizontalCenter
        }
        text: i18n.tr("Group Name")
    }

    TextArea {
        id: groupNameField
        width: {
            let spaceLeft = parent.width - units.gu(1) - units.gu(12) - units.gu(3)
            return spaceLeft < units.gu(30) ? spaceLeft : units.gu(30)
        }

        anchors {
            top: groupNameLabel.bottom
            topMargin: units.gu(1)
            left: chatPic.right
            leftMargin: units.gu(2)
        }
        autoSize: true
        maximumLineCount: 3
        //text: DeltaHandler.getCurrentxxxxxxx

        onFocusChanged: {
            if (root.oskViaDbus) {
                if (focus) {
                    DeltaHandler.openOskViaDbus()
                } else {
                    DeltaHandler.closeOskViaDbus()
                }
            }
        }
        enabled: selfIsInGroup
    }


    property int memberCount: DeltaHandler.groupmembermodel.tempGroupMemberCount()
    property string oneMember: i18n.tr("%1 member").arg(memberCount)
    property string multipleMembers: i18n.tr("%1 members").arg(memberCount)

    ListItem {
        id: memberCountAndAddItem
        height: memberCountLayout.height + (divider.visible ? divider.height : 0)
        anchors {
            top: chatPic.bottom
            topMargin: units.gu(1)
        }

        ListItemLayout {
            id: memberCountLayout
            title.text: memberCount > 1 ? multipleMembers : oneMember

            Label {
                id: showClassicMailsLabel
                width: createGroupPage.width/4
                text: i18n.tr("Add Members")
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }

            Icon {
                name: "go-next"
                SlotsLayout.position: SlotsLayout.Trailing;
                width: units.gu(2)
            }
        }
        onClicked: {
            prepareAddMembers()
            extraStack.push(Qt.resolvedUrl("GroupAddMember.qml"))
        }
        visible: selfIsInGroup
    }

    ListView {
        id: view
        clip: true 
        width: createGroupPage.width
        anchors {
            top: memberCountAndAddItem.bottom
            topMargin: units.gu(1)
            bottom: createGroupPage.bottom
        }
        model: DeltaHandler.groupmembermodel
        delegate: memberDelegate
//        spacing: units.gu(1)
    }

    Component {
        id: memberDelegate

        ListItem {
            id: memberItem
            height: memberListItemLayout.height + (divider.visible ? divider.height : 0)
            divider.visible: true

            //onClicked: {
            //}

            leadingActions: model.isSelf || !selfIsInGroup ? undefined : leadingMemberAction

            ListItemLayout {
                id: memberListItemLayout
                title.text: model.displayname == '' ? i18n.tr('Unknown') : model.displayname
                subtitle.text: model.address

                LomiriShape {
                    id: profPicShape
                    height: units.gu(5)
                    width: height
                    SlotsLayout.position: SlotsLayout.Leading
                    source: model.profilePic == "" ? undefined : profPic

                    Image {
                        id: profPic
                        source: { 
                            if (model.profilePic == "replace_by_addNew") {
                                return Qt.resolvedUrl('../../assets/addNew.svg')
                            } else {
                                return StandardPaths.locate(StandardPaths.AppConfigLocation, model.profilePic)
                            }
                        }
                        visible: false
                    }

                    Label {
                        id: avatarInitialLabel
                        text: model.avatarInitial
                        fontSize: "x-large"
                        color: "white"
                        visible: model.profilePic == ""
                        anchors.centerIn: parent
                    }

                    color: model.avatarColor
                    sourceFillMode: LomiriShape.PreserveAspectCrop
                    aspect: LomiriShape.Flat
                } // end of LomiriShape id: profPicShape

                Image {
                    id: verifiedSymbol
                    source: Qt.resolvedUrl('../../assets/verified.svg')
                    visible: model.isVerified
                    height: units.gu(3)
                    width: height
                    SlotsLayout.position: SlotsLayout.Trailing
                }
            } // ListItemLayout id: memberListItemLayout
        } // ListItem memberItem
    } // Component memberDelegate
    
    Component {
        id: errorMessage
     
        ErrorMessage {
            //title: i18n.tr("Error")
            text: i18n.tr("Please enter a name for the group.")
        }
    }

    Component {
        id: componentChatPicActions
        Popover {
            id: popoverChatPicActions
            Column {
                id: containerLayout
                anchors {
                    left: parent.left
                    top: parent.top
                    right: parent.right
                }
                ListItem {
                    height: layout1.height
                    // should be automatically be themed with something like
                    // theme.palette.normal.overlay, but this
                    // doesn't seem to work for Ambiance (and importing
                    // Lomiri.Components.Themes 1.3 doesn't solve it). 
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout1
                        title.text: i18n.tr("Change Group Image")
                    }
                    onClicked: {
                        PopupUtils.close(popoverChatPicActions)

                        if (root.onUbuntuTouch) {
                            // The strategy with incubation below did not work reliably.
                            // When called for the first time after start of the app,
                            // the method fileSelected of incubator.object could not be 
                            // connected to createGroupPage.setPic. In these cases,
                            // function(status) was called twice: The first time, the status
                            // was not Component.Ready, the second time it was, but the method
                            // fileSelected of incubator.object could not be connected to 
                            // createGroupPage.setPic (failed silently). This also happened
                            // if the incubator was not a local variable ("let incubator =..."),
                            // but a property of createGroupPage.
                            //
                            // It was also not possible to pass the function that should be connected
                            // to fileSelected in the JSON with the properties. So a workaround via
                            // DeltaHandler is done, see the comments in fileImportSignalHelper.h.
                            DeltaHandler.newFileImportSignalHelper()
                            DeltaHandler.fileImportSignalHelper.fileImported.connect(createGroupPage.setPic)
                            extraStack.push(Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })
                            //let incubator = layout.addPageToCurrentColumn(createGroupPage, Qt.resolvedUrl('FileImportDialog.qml'), { "conType": DeltaHandler.ImageType })

                            //if (incubator.status != Component.Ready) {
                            //    // have to wait for the object to be ready to connect to the signal,
                            //    // see documentation on AdaptivePageLayout and
                            //    // https://doc.qt.io/qt-5/qml-qtqml-component.html#incubateObject-method
                            //    incubator.onStatusChanged = function(status) {
                            //        if (status == Component.Ready) {
                            //            incubator.object.fileSelected.connect(createGroupPage.setPic)
                            //        } else {
                            //            // status is not Component.Ready
                            //        }
                            //    }
                            //} else {
                            //    // object was directly ready
                            //    incubator.object.fileSelected.connect(createGroupPage.setPic)
                            //}
                        } else {
                            createGroupPage.openFileDialog()
                        }
                    }
                }

                ListItem {
                    height: layout2.height
                    color: root.darkmode ? theme.palette.normal.overlay : "#e6e6e6" 
                    ListItemLayout {
                        id: layout2
                        title.text: i18n.tr("Remove Group Image")
                    }
                    onClicked: {
                        PopupUtils.close(popoverChatPicActions)
                        hasChatPic = false
                        chatPicImage.source = ""
                    }
                }
            }
        } // Popover id: containerLayout
    } // Component id: componentChatPicActions
} // Page id: createGroupPage
