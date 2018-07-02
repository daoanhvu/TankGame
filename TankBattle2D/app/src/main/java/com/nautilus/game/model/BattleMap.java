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

    static final int TILE_SIZE_PIXEL = 32;
    static final int NUM_OF_TILE = 15;

    private int height;
    private int width;

    private final Bitmap[] mapTile = new Bitmap[NUM_OF_TILE];
    int[][] mapData;
    private Bitmap mapBitmap = null;

    private float[] textureData = new float[12];
    private float y_offset;
    private float mapHeight;
    private float mapWidth;

    public BattleMap() {
    }

    public BattleMap(int w, int h, int[][] data) {
        mapData = data;
        int row = data.length;
        int col = data[0].length;

        loadMap();

        width = col * mapTile[0].getWidth();
        height = row * mapTile[0].getHeight();
        Bitmap.Config config = mapTile[0].getConfig();
        mapBitmap = Bitmap.createBitmap(width, height, config);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        Canvas canvas = new Canvas(mapBitmap);
        Rect r0 = new Rect(0, 0, TILE_SIZE_PIXEL, TILE_SIZE_PIXEL);
        Rect r1 = new Rect(0, 0, TILE_SIZE_PIXEL, TILE_SIZE_PIXEL);
        int x, y;
        for (int i = 0; i < row; ++i) {
            y = i * TILE_SIZE_PIXEL;
            for(int j=0; j<col; ++j) {
                x = j * TILE_SIZE_PIXEL;
                r1.set(x, y, x + TILE_SIZE_PIXEL, y + TILE_SIZE_PIXEL);
                canvas.drawBitmap(mapTile[mapData[i][j]], r0, r1, paint);
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

        for (int i = 0; i < NUM_OF_TILE; i++) {
            mapTile[i].recycle();
        }
    }

    private void loadMap() {
        InputStream fis;
        Bitmap bmp;
        try {
            for (int i = 1; i <= NUM_OF_TILE; i++) {
                fis = TankGameAppliction.getInstance().getAssets().open("mapTile" + i + ".png");
                bmp = BitmapFactory.decodeStream(fis);
                mapTile[i-1] = bmp;
            }
        }catch(IOException ex) {
            ex.printStackTrace();
        }
    }

    public void render() {

    }
}
