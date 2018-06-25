package com.nautilus.game.model;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.os.ConditionVariable;

import com.nautilus.game.TankGameAppliction;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;

/**
 * Created by davu on 5/3/2016.
 */
public class Tank extends GameObject implements Runnable {
    private Bitmap mBitmap;
    private Thread mThread;
    private float xDirection;
    private float yDirection;
    private float mDirectionMag;
    private float mDirectionAngle;
    private boolean moving = false;

    final Matrix mMatrix = new Matrix();
    final ConditionVariable mutex = new ConditionVariable();

    @Override
    public boolean load() {
        return false;
    }

    public boolean loadImage(InputStream fis) {
        mBitmap = BitmapFactory.decodeStream(fis);
        width = mBitmap.getWidth();
        height = mBitmap.getHeight();
        return true;
    }

    public void draw(Canvas canvas, Paint mPaint) {
        synchronized (mutex) {
            //canvas.drawBitmap(mBitmap, x, y, mPaint);
            canvas.drawBitmap(mBitmap, mMatrix, mPaint);
            mutex.notifyAll();
        }
    }

    public void startMoving() {
        moving = true;
        mThread = new Thread(this);
        mThread.start();
    }

    public void changeDirection(float dx, float dy) {
        synchronized (mutex) {
            mDirectionMag = (float) Math.sqrt((dx * dx) + (dy * dy));
            xDirection = (float) (dx / mDirectionMag);
            yDirection = (float) (dy / mDirectionMag);
            mDirectionAngle = (float) Math.asin(yDirection / mDirectionMag);
            mutex.notifyAll();
        }
    }

    public void stopMoging() {
        moving = false;
        mutex.notifyAll();
    }

    @Override
    public void run() {
        float oldx, oldy;
        try {
            while (moving) {
                oldx = x - width/2.0f;
                oldy = y - height/2.0f;
                x += xDirection;
                y += yDirection;
                synchronized (mutex) {
                    mMatrix.reset();
                    mMatrix.postTranslate(-oldx, -oldy);
                    mMatrix.postRotate((float)Math.toDegrees(mDirectionAngle)+45);
                    //mMatrix.postRotate((float)mDirectionAngle);
                    //mMatrix.postRotate(45);
                    //mMatrix.postTranslate(oldx - width/2.0f, oldy - height/2.0f);
                    mMatrix.postTranslate(x - width/2.0f, y - height/2.0f);
                    mutex.notifyAll();
                }
                Thread.sleep(20);
                //moving = false;
            }
        }catch (InterruptedException ex) {
            ex.printStackTrace();
        }
    }
}
