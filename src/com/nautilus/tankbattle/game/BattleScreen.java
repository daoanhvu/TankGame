package com.nautilus.tankbattle.game;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;

import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.LightSource;
import com.nautilus.tankbattle.framework.Pixmap;
import com.nautilus.tankbattle.framework.Screen;

public class BattleScreen extends Screen implements Pixmap {
	
	/** Additional constants. */
	private static final int POSITION_HANDLE = 0;
	private static final int NORMAL_HANDLE = 1;
	private static final int COLOR_HANDLE = 2;
	
	private static final int POSITION_DATA_SIZE_IN_ELEMENTS = 3;
	private static final int NORMAL_DATA_SIZE_IN_ELEMENTS = 3;
	public static final int BYTES_PER_FLOAT = 4;
	public static final int BYTES_PER_SHORT = 2;
	
	private float[] mapVertices = {
			-5, 5, 0,
			-4, 5, 0,
			-3, 5, 0,
			-2, 5, 0,
			-1, 5, 0,
			0, 5, 0,
			1, 5, 0,
			2, 5, 0,
			3, 5, 0,
			4, 5, 0,
			5, 5, 0,
	};
	
	private int[][] mapData;
	private PixmapFormat pixmapFormat;
	
	//map size in dip
	private int width;
	private int height;
	
	//number of piece of tile
	private int mapRow;
	private int mapColumn;
	
	private LightSource lightSource;

	public BattleScreen(Game game, int w, int h) {
		super(game);
		
		width = w;
		height = h;
		mapRow = width / 32 + 1;
		mapColumn = height / 32 + 1;
		
		mapData = new int[mapColumn][mapRow];
		for(int i=0; i<mapColumn; i++) {
			for(int j=0; j<mapRow; j++)
				mapData[i][j] = 0;
		}
	}
	
	public void drawMap(Canvas canvas) {
		int i, j;
		float left = 0;
		float top = 0;
		Bitmap bmp;
		for(i=0; i<mapColumn; i++) {
			for(j=0; j<mapRow; j++) {
				bmp = game.getTile(mapData[i][j]);
				top = j * bmp.getHeight();
				left = i * bmp.getWidth();
			}
		}
	}

	@Override
	public void update(float deltaTime) {
		
	}

	@Override
	public void present(float deltaTime) {
		
	}

	@Override
	public void pause() {
		
	}

	@Override
	public void resume() {
		
	}

	@Override
	public void dispose() {
		
	}

	@Override
	public int getWidth() {
		return width;
	}

	@Override
	public int getHeight() {
		return height;
	}

	@Override
	public PixmapFormat getFormat() {
		return pixmapFormat;
	}

	@Override
	public void onSurfaceCreated(GL10 gl, EGLConfig config) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void onSurfaceChanged(GL10 gl, int width, int height) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void onDrawFrame(GL10 gl) {
		// TODO Auto-generated method stub
		
	}

}
