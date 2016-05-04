package com.nautilus.game;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;

import com.nautilus.game.engine.DefaultGameEngine;
import com.nautilus.game.engine.GameView;
import com.nautilus.game.engine.IRenderer;
import com.nautilus.game.model.Tank;

public class MainActivity extends AppCompatActivity {

    static class EngineImp implements IRenderer {

        private Context mContext;
        private int mWidth;
        private int mHeight;

        private Paint mPaint;

        DefaultGameEngine gameEngine;

        //for testing
        Tank tank;

        EngineImp(Context ctx) {
            mContext = ctx;
            mPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

            gameEngine = new DefaultGameEngine();
            gameEngine.loadMap();

            tank = new Tank();
            tank.moveTo(100, 200);
            tank.changeDirection(1, 2);
            if(!tank.load())
                throw new RuntimeException("Could not load Tank object.");
        }

        static class Mutex {

        }

        @Override
        public void render(Canvas canvas) {
            gameEngine.drawMap(canvas, mPaint);
            tank.draw(canvas, mPaint);
        }

        @Override
        public void onSurfaceChanged(int width, int height) {
            mWidth = width;
            mHeight = height;
        }

        @Override
        public void onSurfaceCreated() {
            tank.startMoving();
        }
    }

    private EngineImp tankEngin;
    private GameView mGameView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        tankEngin = new EngineImp(this);
        mGameView = new GameView(this);
        mGameView.setEngine(tankEngin);

        //setContentView(R.layout.activity_main);
        setContentView(mGameView);
    }

    @Override
    protected void onResume() {
        super.onResume();
        mGameView.onResume();
    }

    @Override
    protected void onPause() {
        mGameView.onPause();
        super.onPause();
    }
}
