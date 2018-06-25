package com.nautilus.game;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;

import com.nautilus.game.engine.DefaultGameEngine;
import com.nautilus.game.engine.GameGLSurfaceView;
import com.nautilus.game.engine.GameRenderer;
import com.nautilus.game.engine.IGameEngine;
import com.nautilus.game.engine.IRenderer;
import com.nautilus.game.model.Tank;

public class MainActivity extends AppCompatActivity {

    private IGameEngine tankEngin;
    private GameGLSurfaceView mGameView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);

        IRenderer renderer = new GameRenderer();
        tankEngin = new DefaultGameEngine();
        mGameView = new GameGLSurfaceView(this);
        mGameView.setGameEngine(tankEngin);

        mGameView.setRenderer(renderer);

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
