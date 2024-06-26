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


QImage WebxdcImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QImage retImage = m_imageCache[id];

    if (size) {
        size->setWidth(retImage.width());
        size->setHeight(retImage.height());
    }

    return retImage;
}


QString WebxdcImageProvider::getImageId(uint32_t accId, const uint32_t chatId, uint32_t msgId, dc_msg_t* msg)
{
    QString keystring;

    QString tempQString;
    tempQString.setNum(accId);

    keystring = tempQString;
    keystring.append("_");

    tempQString.setNum(chatId);
    keystring.append(tempQString);
    keystring.append("_");

    tempQString.setNum(msgId);
    keystring.append(tempQString);

    if (m_imageCache.contains(keystring)) {
        return keystring;
    } else {
        return addImage(keystring, msg);
    }
}


QString WebxdcImageProvider::addImage(QString imageId, dc_msg_t* msg)
{
    QByteArray byteArray = dc_msg_get_webxdc_info(msg);
    // assign the app icon file name to tempQString
    QString tempQString = QJsonDocument::fromJson(byteArray).object().value("icon").toString();

    size_t tempSizeT;
    char* tempText = dc_msg_get_webxdc_blob(msg, tempQString.toUtf8().constData(), &tempSizeT);
    if (tempText) {
        QImage tempQImage;
        tempQImage.loadFromData(reinterpret_cast<uchar*>(tempText), tempSizeT, "PNG");
        m_imageCache[imageId] = tempQImage;

        dc_str_unref(tempText);
        return imageId;
    } else {
        // TODO: if tempText is NULL, maybe provide a standard image?
        return imageId;
    }

}


void WebxdcImageProvider::clearImageCache()
{
    m_imageCache.clear();
}
