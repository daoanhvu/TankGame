package com.nautilus.game.engine;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.media.ImageReader;

import com.nautilus.game.TankGameAppliction;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Created by davu on 5/3/2016.
 */
public class DefaultGameEngine implements IGameEngine {

    static final String TAG = "DefaultGameEngine";
    boolean mRunning = false;

    Bitmap[] mapTitle = new Bitmap[15];
    int mapCol, mapRow;
    int[][] mapData;

    public DefaultGameEngine() {
        mapRow = 90;
        mapCol = 27;
        mapData = new int[mapRow][mapCol];

        for(int i=0; i<mapRow; i++) {
            for(int j=0; j<mapCol; j++) {
                mapData[i][j] = 0;
            }
        }
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
        }finally {

        }
    }

    public void drawMap(Canvas canvas, Paint paint) {
        int x, y;
        for(int i=0; i<mapRow; i++) {
            for(int j=0; j<mapCol; j++) {
                x = i * 32;
                y = j * 32;
                canvas.drawBitmap(mapTitle[mapData[i][j]], x, y, paint);
            }
        }
    }

    @Override
    public void finalize() {
        if(mRunning) {
            mRunning = false;
        }
        for (int i = 0; i < 15; i++) {
            mapTitle[i].recycle();
        }
    }

    @Override
    public void run() {
        try {
            while (mRunning) {
                Thread.sleep(5);
            }
        }catch(InterruptedException ex) {
            android.util.Log.e(TAG, ex.getMessage());
        }
    }
}
