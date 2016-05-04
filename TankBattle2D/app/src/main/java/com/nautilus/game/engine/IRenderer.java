package com.nautilus.game.engine;

import android.graphics.Canvas;

/**
 * Created by davu on 5/3/2016.
 */
public interface IRenderer {
    void onSurfaceCreated();
    void render(Canvas canvas);
    void onSurfaceChanged(int width, int height);
}
