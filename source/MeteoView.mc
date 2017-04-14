//
// Copyright 2017 Salvatore Sanfilippo
// All Rights Reserved
// This software is released under the terms of the GPL v3 license
// See the LICENSE file in this software distribution for more information.
//

using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Application as App;
using Toybox.Position as Position;
using Toybox.System as System;
using Toybox.Communications as Comm;
using Toybox.Time as Time;
using Toybox.Math as Math;

class MeteoView extends Ui.View {
    hidden var mMessage = "Press menu button";
    hidden var mModel;
    hidden var lastPos;
    hidden var lastData;
    hidden var lastFetchTime;
    hidden var updatingGPS = false;
    hidden var httpCode = -1; /* -1 if loading, otherwise last HTTP code. */

    function initialize() {
        System.println("View initialize()");
        Ui.View.initialize();
    }

    /* ======================== Position handling ========================== */

    function onPosition(info) {
        var myapp = App.getApp();
        System.println("onPosition() called");
        if ((lastPos == null &&
             info.accuracy > Position.QUALITY_NOT_AVAILABLE) ||
            (lastPos != null &&
            info.accuracy > Position.QUALITY_LAST_KNOWN))
        {
            System.println("Good enough position received");
            lastPos = info.position.toDegrees()[0].toString() + "," +
                      info.position.toDegrees()[1].toString();
            System.println("lastPos updated to: "+lastPos);
            myapp.setProperty("lastpos",lastPos);
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
            updatingGPS = false;
            lastData = null;
            myapp.setProperty("lastdata",lastData);
            getWeather();
        }

        // Update the view with info messages if there is not a valid
        // weather screen already displayed.
        if (lastData == null) {
            Ui.requestUpdate();
        }
    }

    function updatePosition() {
        if (updatingGPS == true) {
            return;
        }
        System.println("Updating position...");
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        updatingGPS = true;
        Ui.requestUpdate();
    }

    /* ==================== Yahoo Weather API query ======================== */

    /* Performs a GET request to the Yahoo weather API, using the cached
     * GPS position. */
    function getWeather() {
        System.println("Querying API...");
        var queryunit;
        var settings = System.getDeviceSettings();
        if (settings.temperatureUnits == System.UNIT_METRIC) {
            queryunit = "c";
        } else {
            queryunit = "f";
        }
        Comm.makeWebRequest(
            "https://query.yahooapis.com/v1/public/yql",
            {
                "q" => "select * from weather.forecast where woeid in (select woeid from geo.places(1) where text='("+lastPos+")') and u='"+queryunit+"'",
                "format" => "json"
            },
            {
                "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED
            },
            method(:receiveWeather)
        );
        httpCode = -1;
        Ui.requestUpdate();
    }

    /* The handler for the HTTP data request: we just pass the reply to
     * parseWeather() if the response is not an error. The last HTTP response
     * code is always set in the httpCode variable, so that we can display
     * a small "status dot" based on the request status. */
    function receiveWeather(responseCode, data) {
        System.println("Data received with code "+responseCode.toString());
        httpCode = responseCode;
        if (responseCode == 200) {
            parseWeather(data);
        } else {
            /* Can't update the view... */
            Ui.requestUpdate();
        }
    }

    /* Persist the data received via HTTP, and triggers a view update. */
    function parseWeather(data) {
        var myapp = App.getApp();
        lastData = data;
        lastFetchTime = Time.now().value();
        myapp.setProperty("lastdata",lastData);
        myapp.setProperty("lastfetchtime",lastFetchTime);
        Ui.requestUpdate();
    }

    /* ========================= Initialization ============================ */

    /* This is called once in the lifetime of a widget, so we do our
     * initialization here. */
    function onLayout(dc) {
        System.println("onLayout() called");
        var myapp = App.getApp();
        lastPos = myapp.getProperty("lastpos");
        lastData = myapp.getProperty("lastdata");
        lastFetchTime = myapp.getProperty("lastfetchtime");
        if (lastPos == null) {
            updatePosition();
        } else {
            System.println("lastPos initial value: "+lastPos);
            if (lastFetchTime == null ||
                Time.now().value() - lastFetchTime > 30)
            {
                System.println("Fetching data on startup");
                getWeather();
            } else {
                httpCode = 200;
            }
        }
    }

    // Restore the state of the app and prepare the view to be shown
    function onShow() {
    }

    /* ============================ Rendering ============================== */

    /* Show the weather agent of the specified Yahoo Weather code and
     * description. The function actually generates the graphics only based
     * on the 'code' argumnet, however 'descr', cotaining the text description
     * of the weather condition, it used when no suitable icon can be generated
     * for the code. In this case the text is just displayed instead.
     *
     * The function generates the icons programmatically, and makes sure that
     * most icons randomly change, seeding the PRNG with the time at which
     * the information on the weather was obtained. This way when the info
     * is refreshed, the user has a "visual clue" about things changing. */
    function showWeatherAgent(dc,x,y,size,code,descr) {
        var prngseed;
        if (lastFetchTime != null) {
            prngseed = lastFetchTime;
        } else {
            prngseed = 77339911;
        }
        Math.srand(prngseed);

        var show_sun = false;
        var show_cloud = false;
        var cloud_color = Graphics.COLOR_WHITE;
        var cloud_up = true;
        var show_lightning = false;
        var show_rain = false;
        var rain_severity = 1;
        var rain_color = Graphics.COLOR_BLUE;
        var show_snow = false;
        var show_fog = false;
        var show_text = false;
        var show_wind = false;

        if (code == 0 || code == 3 || code == 4 ||
            code == 37 || code == 38 || code == 39 ||
            code == 45 || code == 47) {
            /* 0 = Tornado,
             * 3 = Severe thunderstorm,
             * 4 = Thunderstorm,
             * 37 = Isolated thunderstorm,
             * 38 = Scattered thunderstorm,
             * 39 = Scattered thunderstorm,
             * 45 = Thundershowers,
             * 47 = Isolated thundershowers. */
            show_cloud = true;
            show_lightning = true;
            show_rain = true;
            rain_severity = 5;
            cloud_color = Graphics.COLOR_DK_GRAY;
        } else if (code == 1 || code == 47) {
            /* 1 = Tropical storm,
             * 47 = Isolated thundershowers. */
            show_cloud = true;
            show_lightning = true;
            show_rain = true;
            rain_severity = 2;
            cloud_color = Graphics.COLOR_LT_GRAY;
        } else if (code == 5 || code == 6 || code == 7) {
            /* 5 = Mixed rain and snow,
             * 6 = Mixed rain and sleet,
             * 7 = Mixed snow and sleet */
            show_rain = true;
            show_snow = true;
            rain_severity = 2;
        } else if (code == 8 || code == 9) {
            /* 8 = Freezing drizzle.
             * 9 = Drizzle. */
            show_rain = true;
            rain_severity = 1;
            show_cloud = true;
            cloud_color = Graphics.COLOR_DK_GRAY;
            rain_color = Graphics.COLOR_WHITE;
        } else if (code == 10) {
            /* 10 = Freezing rain. */
            show_rain = true;
            rain_severity = 3;
            show_cloud = true;
            cloud_color = Graphics.COLOR_DK_GRAY;
            rain_color = Graphics.COLOR_WHITE;
        } else if (code == 11 || code == 12 || code == 40) {
            /* 11 = Showers,
             * 12 = Showers,
             * 40 = Scattered showers */
            show_rain = true;
            rain_severity = 1;
            show_cloud = true;
            cloud_color = Graphics.COLOR_DK_GRAY;
        } else if (code == 13 || code == 14 || code == 15 || code == 16 ||
                   code == 41 || code == 42 || code == 43 || code == 46) {
            /* 13 = Snow flurries,
             * 14 = Light snow showers,
             * 15 = Blowing snow,
             * 16 = Snow,
             * 41 = Heavy snow,
             * 42 = Scattered snow showers,
             * 43 = Heavy snow.
             * 46 = Snow showers. */
            show_snow = true;
            show_cloud = true;
            cloud_color = Graphics.COLOR_LT_GRAY;
        } else if (code == 17) {
            /* 17 = Hail. */
            show_snow = true;
        } else if (code == 18) {
            /* 18 = Sleet. */
            show_snow = true;
            show_rain = true;
            rain_color = Graphics.COLOR_DK_GRAY;
        } else if (code == 19 || code == 20 || code == 21 || code == 22) {
            /* 19 = Dust,
             * 20 = Foggy,
             * 21 = Haze,
             * 22 = Smoky */
            show_fog = true;
        } else if (code == 23 || code == 24) {
            /* 23 = Blustery,
             * 24 = Windy. */
             show_wind = true;
        } else if (code == 26 || code == 27 || code == 28) {
            /* 26 = Cloudy,
             * 27 = Mostly cloudy night,
             * 28 = Mostly cloudy day. */
            show_cloud = true;
        } else if (code == 29 || code == 30 || code == 44) {
            /* 29 = Partly cloudy night,
             * 30 = Partly cloudy day.
             * 44 = Partly cloudy. */
            show_cloud = true;
            show_sun = true;
            cloud_up = false;
        } else if (code == 31 || code == 32 || code == 33 || code == 34 ||
                   code == 37) {
            /* Fair. */
            show_sun = true;
        } else {
            show_text = true;
        }

        if (show_sun) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            dc.fillCircle(x,y,size/2.3);
        }

        if (show_cloud) {
            dc.setColor(cloud_color, Graphics.COLOR_BLACK);
            var dy = 0;
            if (cloud_up) {
                dy = (size/2.6);
            }
            dc.fillCircle(x-(size/5),y+(size/4)-dy,size/2);
            dc.fillCircle(x-(size/2),y+(size/4)-dy,size/3);
            dc.fillCircle(x+(size/3),y+(size/3)-dy,size/2.8);
        }

        if (show_rain) {
            dc.setColor(rain_color, Graphics.COLOR_BLACK);
            for (var i = 0; i < 35; i++) {
                var x1 = x-(size/2)+Math.rand()%size;
                var y1 = y-(size/2)+Math.rand()%size;
                var l = size/20;
                if (l<1) {
                    l = 1;
                }
                l *= rain_severity;
                dc.drawLine(x1,y1,x1+l,y1+l);
            }
        }

        if (show_snow) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            for (var i = 0; i < 35; i++) {
                var x1 = x-(size/2)+Math.rand()%size;
                var y1 = y-(size/2)+Math.rand()%size;
                var l = size/20;
                if (l<1) {
                    l = 1;
                }
                dc.fillCircle(x1,y1,l);
            }
        }

        if (show_lightning) {
            var dsize = size.toDouble();
            var points = [[x-dsize/5,y-dsize/12],
                          [x+dsize/2.5,y-dsize/2],
                          [x+dsize/7,y-dsize/10],
                          [x+dsize/2.9,y+dsize/14],
                          [x-dsize/2.5,y+dsize/2],
                          [x,y+dsize/12]];
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            dc.fillPolygon(points);
        }

        if (show_fog) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var x1 = x-(size/2);
            var y1 = y-(size/2);
            var width = size*0.8;
            var height = size/5;
            for (var i = 0; i < 4; i++) {
                var r1 = -(size/5)/2;
                var r2 = -(size/5)/2;
                r1 += Math.rand() % (size/5);
                r2 += Math.rand() % (size/5);
                dc.fillRoundedRectangle(x1+r1,y1,width+r2,height,2);
                y1 += size/4;
            }
        }

        if (show_wind) {
            var x1 = x-(size/2);
            var y1 = y-(size/2);
            var width = size;
            var height = 5;
            for (var i = 0; i < 8; i++) {
                var r1 = -(size/5)/2;
                var r2 = -(size/5)/2;
                r1 += Math.rand() % (size/5);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                dc.fillRoundedRectangle(x1,y1,width+r1,height,2);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                if (i < 4) {
                    dc.fillRoundedRectangle(x1-1,y1-1,width+r1,height,2);
                } else {
                    dc.fillRoundedRectangle(x1-1,y1+1,width+r1,height,2);
                }
                y1 += size/8;
            }
        }

        if (show_text) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            var font = Graphics.FONT_TINY;
            if (size < 10) {
                font = Graphics.FONT_XTINY;
            }
            dc.drawText(x,y, Graphics.FONT_TINY, descr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    /* Render the View: current condition, forecasts and so forth. */
    function renderWeatherCondition(dc) {
        var temperature = lastData["query"]["results"]["channel"]["item"]["condition"]["temp"];
        var condition_code = lastData["query"]["results"]["channel"]["item"]["condition"]["code"].toNumber();
        var condition_descr = lastData["query"]["results"]["channel"]["item"]["condition"]["text"];
        var tempunit = lastData["query"]["results"]["channel"]["units"]["temperature"];
        var wind = lastData["query"]["results"]["channel"]["wind"]["speed"];
        var windunit = lastData["query"]["results"]["channel"]["units"]["speed"];
        var cityname = lastData["query"]["results"]["channel"]["location"]["city"];

        /* Clear the screen. */
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        /* Show status dot. */
        if (httpCode != 200 || updatingGPS == true) {
            var color = Graphics.COLOR_BLACK;
            if (updatingGPS == true) {
                color = Graphics.COLOR_PINK;
            } else if (httpCode == -1) {
                color = Graphics.COLOR_GREEN;
            } else if (httpCode != 200) {
                color = Graphics.COLOR_RED;
            }
            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.fillCircle(dc.getWidth()-6,12,4);
        }

        /* Show the city name. */
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth()/2, 10, Graphics.FONT_XTINY, cityname, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        /* Show weather icon. */
        showWeatherAgent(dc,dc.getWidth()/4,dc.getHeight()/4,50,condition_code,condition_descr);

        /* Show temperature. */
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2+27, 45, Graphics.FONT_NUMBER_THAI_HOT, temperature, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        /* Show wind. */
        wind = wind.toNumber().toString();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2+35, 80, Graphics.FONT_XTINY, wind+" "+windunit, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        /* Show the temperature unit. */
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var tempwidth = dc.getTextWidthInPixels(temperature,Graphics.FONT_NUMBER_THAI_HOT);
        dc.drawText(dc.getWidth()/2+27+tempwidth/2,25,Graphics.FONT_XTINY,tempunit,Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        /* Show forecast. */
        var y = dc.getHeight()/2+8;
        var x = 25;
        for (var i = 0; i < 6; i++) {
            var stri = i.toString();
            var f = lastData["query"]["results"]["channel"]["item"]["forecast"][i];
            showWeatherAgent(dc,x,y,25,f["code"].toNumber(),f["text"]);

            /* Show the day, using multiple font drawing to create a border
             * effect to make it more readable. */
            var tx = x-13;
            var ty = y-13;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            for (var ox = -1; ox <= 1; ox ++) {
                for (var oy = -1; oy <= 1; oy ++) {
                    dc.drawText(tx+ox, ty+oy, Graphics.FONT_XTINY, f["day"], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(tx, ty, Graphics.FONT_XTINY, f["day"], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            /* Finally show the temperatures. */
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x-10, y+18, Graphics.FONT_XTINY, f["low"], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x+10, y+18, Graphics.FONT_XTINY, f["high"], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            x += 45;
            if ((i % 3) == 2) {
                x = 25;
                y += 48;
            }
        }

        /* Yahoo credits. */
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(10, dc.getHeight()-10 , Graphics.FONT_XTINY, "Powered by", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_BLACK);
        dc.drawText(90, dc.getHeight()-10 , Graphics.FONT_XTINY, "YAHOO!", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /* Method called when a view update is needed. Actually the rendering
     * is performed by renderWeatherCondition(), but this function will
     * display a GPS icon if the program is at its first startup and needs
     * to still get a GPS position or the first data fetch. */
    function onUpdate(dc) {
        if (lastData == null || updatingGPS == true) {
            var errormsg;
            if (updatingGPS == true) {
                errormsg = ["Getting GPS location",
                            "Does not work?",
                            "1. Open the 'run' app",
                            "2. Wait for the GPS",
                            "icon to turn green.",
                            "3. Return here."];
            } else {
                errormsg = ["Loading weather data"];
            }
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();

            /* Draw the GPS icon. */
            var cx = dc.getWidth()/2;
            var cy = dc.getHeight()/2+40;
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
            dc.fillCircle(cx,cy,50);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            var points = [[cx+50,cy+50],
                          [cx+100,cy+50],
                          [cx+100,cy-50],
                          [cx-50,cy-50]];
            dc.fillPolygon(points);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            points = [[cx+3,cy+3],
                      [cx+30,cy-30],
                      [cx-3,cy-3]];
            dc.fillPolygon(points);
            dc.fillCircle(cx+30,cy-30,5);

            /* Draw the GPS/data status line. */
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < errormsg.size(); i++) {
                dc.drawText(dc.getWidth()/2, 10+(i*15), Graphics.FONT_XTINY, errormsg[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            return;
        }
        renderWeatherCondition(dc);
    }

    /* This is called when the view is removed from the screen, however we
     * save state as soon as we obtain it, so not useful for us. */
    function onHide() {
    }
}
