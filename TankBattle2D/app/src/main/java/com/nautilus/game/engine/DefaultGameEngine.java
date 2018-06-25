package com.nautilus.game.engine;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import com.nautilus.game.TankGameAppliction;
import com.nautilus.game.model.GameObject;
import com.nautilus.game.model.BattleMap;
import com.nautilus.game.model.Tank;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;

/**
 * Created by davu on 5/3/2016.
 */
public class DefaultGameEngine implements IGameEngine {
    static final String TAG = "DefaultGameEngine";

    private boolean mRunning = false;
    private Thread gameThread;
    private final ArrayList<Runnable> mEventQueue = new ArrayList<Runnable>();
    private final Object syncEventQueue = new Object();
    private final Object syncRender = new Object();

    //Data
    private BattleMap map;
    private ArrayList<Tank> tanks;

    public DefaultGameEngine() {
    }

    public void load(File file) {
        InputStream fis = null;
        Bitmap bmp;
        int row;
        int col;
        try {

            if(file != null) {
                return;
            }

            //Load default map
            fis = TankGameAppliction.getInstance().getAssets().open("map1.data");
            BufferedReader br = new BufferedReader(new InputStreamReader(fis));
            row = Integer.parseInt(br.readLine());
            col = Integer.parseInt(br.readLine());
            int data[][] = new int[row][col];
            for (int i = 0; i < row; ++i) {
                String line = br.readLine();
                String[] ele = line.split(" ");

                for(int j=0; j<col; ++j) {
                    data[i][j] = Integer.parseInt(ele[j]);
                }
            }
            map = new BattleMap(row, col, data);
        }catch(IOException ex) {
            ex.printStackTrace();
        }
    }

    @Override
    public void start() {
        if(mRunning)
            return;
        gameThread = new Thread(this);
        gameThread.start();
    }

    @Override
    public void finalize() {
        if(mRunning) {
            mRunning = false;
        }
    }

    @Override
    public void run() {
        Runnable event = null;
        while (mRunning) {
            synchronized(syncEventQueue) {
                if (!mEventQueue.isEmpty()) {
                    event = mEventQueue.remove(0);
                    syncEventQueue.notifyAll();
                }
            }

            synchronized(syncRender) {
                if (event != null) {
                    event.run();
                    event = null;
                }

                //Game state may changed here
            }
        }
    }

    public void queueEvent(Runnable task) {
        synchronized (syncEventQueue) {
            mEventQueue.add(task);
            syncEventQueue.notifyAll();
        }
    }

    @Override
    public void stop() {
        Runnable task = new Runnable() {
            @Override
            public void run() {
                mRunning = false;
            }
        };
        synchronized (syncEventQueue) {
            mEventQueue.add(task);
            syncEventQueue.notifyAll();
        }
    }

    //This function is called from UI Thread
    @Override
    public void render() {
        synchronized (syncRender) {
            map.render();
            syncRender.notifyAll();
        }
    }
}
