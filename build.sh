#!/bin/bash
PRGOUT=/tmp/METEO.PRG
DEVKEY=/Users/antirez/hack/2017/connect-iq/developer_key.der

monkeyc -o $PRGOUT -m manifest.xml -y $DEVKEY source/*.mc -z resources/strings.xml -z resources/bitmaps.xml -z resources/resources.xml
killall simulator
connectiq
sleep 1
monkeydo $PRGOUT vivoactive_hr
