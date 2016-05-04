package com.nautilus.tankbattle.framework;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.Canvas;

public interface Game {
	public void load(Activity activity);
	public UserInput getInput();
	public Graphics getGraphics();
	public Audio getAudio();
	public FileIO getFileIO();
	public void setScreen(Screen screen);
	public Screen getCurrentScreen();
	public Screen getStartScreen();
	public Bitmap getTile(int index);	
}
