package com.nautilus.tankbattle.util;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Point;
import android.view.Display;
import android.view.WindowManager;

public class GraphicUtilities {
	@SuppressWarnings("deprecation")
	public static Point getWindowSize(WindowManager wm) {
		Display display = wm.getDefaultDisplay();
		Point p = new Point();
		if(android.os.Build.VERSION.SDK_INT >= 13) {
			display.getSize(p);
			return p;
		}
		
		p.x = display.getWidth();
		p.y = display.getWidth();
		return p;
	}
	
	public static Bitmap buidMap(short[][] mapData, Bitmap[] tiles) {
		int tile_width = tiles[0].getWidth();
		int tile_height = tiles[0].getHeight();
		int i, j;
		int columns = mapData[0].length;
		int rows = mapData.length;
		
		Bitmap result = Bitmap.createBitmap(columns * tile_width, rows * tile_height, Bitmap.Config.ARGB_8888);
		Canvas canvas = new Canvas(result);
		Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
		float left = 0;
		float top = 0;
		
		for(i = 0; i < rows; i++) {
			for(j = 0; j < columns; j++) {
				canvas.drawBitmap(tiles[mapData[i][j]], left, top, paint);
				left += tile_width;
			}
			top += tile_height;
			left = 0;
		}
		return result;
	}
}
