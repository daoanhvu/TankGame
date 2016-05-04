package com.nautilus.game;

import android.app.Application;

/**
 * Created by davu on 5/3/2016.
 */
public class TankGameAppliction extends Application {

    private static TankGameAppliction instance;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
    }

    public static TankGameAppliction getInstance() {
        return instance;
    }
}
