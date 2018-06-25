package com.nautilus.game.engine;

import android.graphics.Canvas;
import android.opengl.GLSurfaceView;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

public class GameRenderer implements IRenderer {
    private IGameEngine engine;

    @Override
    public void setGameEngine(IGameEngine gameEngine) {
        this.engine = gameEngine;
    }

    @Override
    public void onSurfaceCreated(GL10 gl10, EGLConfig eglConfig) {

    }

    @Override
    public void onSurfaceChanged(GL10 gl10, int i, int i1) {

    }

    @Override
    public void onDrawFrame(GL10 gl10) {
        engine.render();
    }
}
