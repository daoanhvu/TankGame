package com.nautilus.game.engine;

import android.graphics.Canvas;
import android.opengl.GLSurfaceView;

/**
 * Created by davu on 5/3/2016.
 */
public interface IRenderer extends GLSurfaceView.Renderer {
    void setGameEngine(IGameEngine engine);
}
