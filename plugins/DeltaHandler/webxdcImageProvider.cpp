/*
 * Copyright (C) 2024  Lothar Ketterer
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

#include "webxdcImageProvider.h"

#include <QImage>
#include <QSize>
#include <QJsonDocument>
#include <QJsonValue>
#include <QJsonObject>
#include <QDebug>


QImage WebxdcImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QImage retImage = m_imageCache[id];

    if (size) {
        size->setWidth(retImage.width());
        size->setHeight(retImage.height());
    }

    return retImage;
}


QString WebxdcImageProvider::createKeystring(uint32_t accId, const uint32_t chatId, uint32_t msgId)
{
    QString retval;
    QString tempQString;

    retval.setNum(accId);
    retval.append("_");
    tempQString.setNum(chatId);
    retval.append(tempQString);
    retval.append("_");
    tempQString.setNum(msgId);
    retval.append(tempQString);

    return retval;
}


// used by msgs of type DC_MSG_WEBXDC
QString WebxdcImageProvider::getImageId(uint32_t accId, const uint32_t chatId, uint32_t msgId, dc_msg_t* msg)
{
    QString keystring = createKeystring(accId, chatId, msgId);

    if (m_imageCache.contains(keystring)) {
        return keystring;
    } else {
        return addImage(keystring, msg);
    }
}


// used by msgs of type DC_MSG_VCARD
QString WebxdcImageProvider::getImageId(uint32_t accId, const uint32_t chatId, uint32_t msgId, QByteArray& imagedata)
{
    QString keystring = createKeystring(accId, chatId, msgId);

    if (m_imageCache.contains(keystring)) {
        return keystring;
    } else {
        QImage tempQImage;
        tempQImage.loadFromData(imagedata);
        m_imageCache[keystring] = tempQImage;
        return keystring;
    }
}


// used by msgs of type DC_MSG_WEBXDC
QString WebxdcImageProvider::addImage(QString imageId, dc_msg_t* msg)
{
    int messageType = dc_msg_get_viewtype(msg);

    char* tempText{nullptr};
    QByteArray byteArray;
    QString tempQString;
    size_t tempSizeT;
    QImage tempQImage;

    switch(messageType) {
        case DC_MSG_WEBXDC:
            tempText = dc_msg_get_webxdc_info(msg);
            byteArray = tempText;
            dc_str_unref(tempText);

            // assign the app icon file name to tempQString
            tempQString = QJsonDocument::fromJson(byteArray).object().value("icon").toString();

            tempText = dc_msg_get_webxdc_blob(msg, tempQString.toUtf8().constData(), &tempSizeT);
            if (tempText) {
                tempQImage.loadFromData(reinterpret_cast<uchar*>(tempText), tempSizeT);
                m_imageCache[imageId] = tempQImage;

                dc_str_unref(tempText);
            }
            break;
        case DC_MSG_VCARD:

            break;

        default:
            // set an empty image
            m_imageCache[imageId] = QImage();
            break;
    }

    return imageId;
}


void WebxdcImageProvider::clearImageCache()
{
    m_imageCache.clear();
}
