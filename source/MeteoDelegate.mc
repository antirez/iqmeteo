//
// Copyright 2017 Salvatore Sanfilippo
// All Rights Reserved
// This software is released under the terms of the GPL v3 license
// See the LICENSE file in this software distribution for more information.
//

using Toybox.WatchUi as Ui;

class MeteoDelegate extends Ui.BehaviorDelegate {
    var myview;

    /* Menu button press. Basically Vivoactive HR long press on the
     * right button. */
    function onMenu() {
        myview.updatePosition();
        return true;
    }

    /* Initialize and get a reference to the view, so that
     * user iterations can call methods in the main view. */
    function initialize(v) {
        Ui.BehaviorDelegate.initialize();
        myview = v;
    }
}
