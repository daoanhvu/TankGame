package com.nautilus.tankbattle;

import android.app.Application;

public class TankApplication extends Application {
	public static TankApplication instance;
	
	@Override
	public void onCreate() {
		super.onCreate();
	}
}
