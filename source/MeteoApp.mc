//
// Copyright 2017 Salvatore Sanfilippo
// All Rights Reserved
// This software is released under the terms of the GPL v3 license
// See the LICENSE file in this software distribution for more information.
//

using Toybox.Application as App;

class MeteoApp extends App.AppBase {
    hidden var mView;

    function initialize() {
        App.AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    /* Return our main view and the delegate used in order to trap
     * user interactions. */
    function getInitialView() {
        mView = new MeteoView();
        return [mView, new MeteoDelegate(mView)];
    }
}
