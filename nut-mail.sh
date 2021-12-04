#!/bin/sh
echo -e "Subject: nut: $NOTIFYTYPE\r\n\r\nUPS: $UPSNAME\r\nAlert type: $NOTIFYTYPE\r\n$@\r\n\r\n`upsc pw5119`" | sendmail piernov@piernov.org
