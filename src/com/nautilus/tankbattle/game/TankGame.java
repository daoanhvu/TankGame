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

public class TankGame implements Game {
	
	Bitmap[] tiles;
	private Graphics graphics;
	private Audio audio;
	private UserInput userInput;
	private FileIO fileIO;
	private Screen currentScreen;
	private float lastFrameTime;
	
	private int[] mTextures = new int[15];
	private boolean mTextureLoaded = false;
	
	public void load(Activity activity) {
		//1. Load width heigh of device
		WindowManager wm = activity.getWindowManager();
		Point p = GraphicUtilities.getWindowSize(wm);
		
		tiles = new Bitmap[15];
		AssetManager assetManager = activity.getAssets();
		try {
			String filename;
			GLES20.glPixelStorei ( GLES20.GL_UNPACK_ALIGNMENT, 1 );
			GLES20.glGenTextures(15, mTextures, 0);
			for(int i=0; i<15; i++) {
				filename = "mapTile" + (i+1) + ".png";
				InputStream inputStream = assetManager.open(filename);
				tiles[i] = BitmapFactory.decodeStream(inputStream);
				
				GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
				GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mTextures[i]);
				GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, tiles[i], 0);
				// Set filtering
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
				// Set wrapping mode
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_TEXTURE);
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_TEXTURE);
				
				inputStream.close();
			}
			mTextureLoaded = true;
			
		}catch(IOException ex) {
			Log.e("TankGame", ex.getMessage());
		}
		currentScreen = new BattleScreen(this);
	}
	
	public int getTexture(int index) {
		return mTextures[index];
	}
	
	public void releaseTextures() {
		if(mTextureLoaded) {
			GLES20.glDeleteTextures(15, mTextures, 0);
			mTextureLoaded = false;
		}
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
