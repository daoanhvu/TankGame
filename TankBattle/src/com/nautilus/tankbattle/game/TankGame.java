package com.nautilus.tankbattle.game;

import java.io.IOException;
import java.io.InputStream;

import android.app.Activity;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Point;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.GLUtils;
import android.util.Log;
import android.view.WindowManager;

import com.nautilus.tankbattle.framework.Audio;
import com.nautilus.tankbattle.framework.FileIO;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.Graphics;
import com.nautilus.tankbattle.framework.Screen;
import com.nautilus.tankbattle.framework.UserInput;
import com.nautilus.tankbattle.util.GraphicUtilities;

public class TankGame extends GLGame {
	
	Bitmap[] tiles;
	private Graphics graphics;
	private Audio audio;
	private UserInput userInput;
	private FileIO fileIO;
	
	private float lastFrameTime;
	
	public void load(Activity activity) {
		//1. Load width heigh of device
		WindowManager wm = activity.getWindowManager();
		Point p = GraphicUtilities.getWindowSize(wm);
		
		tiles = new Bitmap[15];
		AssetManager assetManager = activity.getAssets();
		try {
			String filename;
			for(int i=0; i<15; i++) {
				filename = "mapTile" + (i+1) + ".png";
				InputStream inputStream = assetManager.open(filename);
				tiles[i] = BitmapFactory.decodeStream(inputStream);
				inputStream.close();
			}
		}catch(IOException ex) {
			Log.e("TankGame", ex.getMessage());
		}
		currentScreen = new BattleScreen(this);
	}
	
	public void dispose() {
		for(int i=0; i<tiles.length; i++)
			tiles[i].recycle();
	}
	
	@Override
	public Bitmap getTile(int index) {
		return tiles[index];
	}

	@Override
	public UserInput getInput() {
		return userInput;
	}

	@Override
	public Graphics getGraphics() {
		return graphics;
	}

	@Override
	public Audio getAudio() {
		return audio;
	}

	@Override
	public void setScreen(Screen screen) {
		currentScreen = screen;
	}

	@Override
	public Screen getCurrentScreen() {
		return currentScreen;
	}

	@Override
	public Screen getStartScreen() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public FileIO getFileIO() {
		return fileIO;
	}

}
