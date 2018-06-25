package com.nautilus.game.model;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;

import com.nautilus.game.TankGameAppliction;

import java.io.IOException;
import java.io.InputStream;

public class BattleMap {

    private int height;
    private int width;

    private Bitmap[] mapTitle = new Bitmap[15];
    int[][] mapData;
    private Bitmap mapBitmap = null;

    public BattleMap() {
    }

    public BattleMap(int w, int h, int[][] data) {
        mapData = data;
        int row = data.length;
        int col = data[0].length;

        loadMap();

        width = col * mapTitle[0].getWidth();
        height = row * mapTitle[0].getHeight();
        Bitmap.Config config = mapTitle[0].getConfig();
        mapBitmap = Bitmap.createBitmap(width, height, config);
        Paint paint = new Paint();
        Canvas canvas = new Canvas(mapBitmap);
        Rect r0 = new Rect(0, 0, 32, 32);
        for (int i = 0; i < row; ++i) {
            for(int j=0; j<col; ++j) {
                canvas.drawBitmap(mapTitle[mapData[i][j]], r0, r0, paint);
            }
        }
    }

    public void load(int[][] data, int w, int h) {
        mapData = data;
        height = h;
        width = w;
    }

    @Override
    public void finalize() {
        if(mapBitmap != null)
            mapBitmap.recycle();
    }

    public void loadMap() {
        InputStream fis;
        Bitmap bmp;
        try {
            for (int i = 1; i < 16; i++) {
                fis = TankGameAppliction.getInstance().getAssets().open("mapTile" + i + ".png");
                bmp = BitmapFactory.decodeStream(fis);
                mapTitle[i-1] = bmp;
            }
        }catch(IOException ex) {
            ex.printStackTrace();
        }
    }

    public void render() {

    }
}
