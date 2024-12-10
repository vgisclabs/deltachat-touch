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

#ifndef WEBXDCIMAGEPROVIDER_H
#define WEBXDCIMAGEPROVIDER_H

#include <QImage>
#include <QQuickImageProvider>
#include <QMap>

#include "../deltachat.h"

// Class WebxdcImageProvider is to provide the icon of a Webxdc app
// as image to QML. The image provider is registered for QML along with the
// DeltaHandler plugin (see plugin.*), then made available to the
// C++ side via the view (property myview in Main.qml, and calling
// DeltaHandler.chatmodel.setView(myview) in onCompleted).
// Images are requested from QML by setting the Image source
// to "image://webxdcImageProvider/<imageId>".
class WebxdcImageProvider : public QQuickImageProvider
{
    public:
        WebxdcImageProvider() : QQuickImageProvider(QQmlImageProviderBase::Image) {}

        // requestImage() will be called if the "image://" scheme is used in QML, with
        // the id of this image provider, i.e. "image://webxdcImageProvider/<imageId>".
        //
        // IMPORTANT: The image is only available if getImageId() has been called for the
        // corresponding webxdc instance (= dc_msg_t*) before.
        QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;       

        // Returns the imageId as string for the Webxdc app passed via msg.
        //
        // Overloaded.
        QString getImageId(uint32_t accId, const uint32_t chatId, uint32_t msgId, dc_msg_t* msg);
 
        // Returns the imageId as string for the image data passed in the QByteArray
        // (used by vcards). CAVE image data in vcards is base64 encoded, the parameter
        // imagedata for this function must already be decoded.
        //
        // Overloaded.
        QString getImageId(uint32_t accId, const uint32_t chatId, uint32_t msgId, QByteArray& imagedata);

        void clearImageCache();

    private:
        // Caches the QImages with their id as key. Ids are constructed like this: <accId>_<chatId>_<msgId>
        // For an image to be present in the cache, getImageId() has to be called.
        QMap<QString, QImage> m_imageCache;
        
        /* Private methods */
        // Will add the icon of a Webxdc app to m_imageCache if it doesn't exist
        // in there already.
        QString addImage(QString imageId, dc_msg_t* msg);

        // private methods
        QString createKeystring(uint32_t accId, const uint32_t chatId, uint32_t msgId);
};

#endif // WEBXDCIMAGEPROVIDER_H
