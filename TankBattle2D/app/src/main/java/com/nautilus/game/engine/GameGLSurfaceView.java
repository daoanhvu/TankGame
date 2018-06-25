package com.nautilus.game.engine;

import android.content.Context;
import android.opengl.GLSurfaceView;
import android.os.ConditionVariable;
import android.util.AttributeSet;
import android.view.SurfaceHolder;


/**
 * Created by nautilus on 5/2/2016.
 */
public class GameGLSurfaceView extends GLSurfaceView implements SurfaceHolder.Callback {

    private static final String TAG = "GameGLSurfaceView";
    private final ConditionVariable syncObj = new ConditionVariable();
    private IGameEngine engine;
    private GameRenderer renderer;

    public GameGLSurfaceView(Context ctx) {
        super(ctx);
        init();
    }

    public GameGLSurfaceView(Context ctx, AttributeSet attrSet) {
        super(ctx, attrSet);
        init();
    }

    private void init() {
        setEGLContextClientVersion(2);
        SurfaceHolder holder = getHolder();
        holder.addCallback(this);
    }

    @Override
    public void setRenderer(Renderer renderer) {
        this.renderer = (GameRenderer)renderer;
        this.renderer.setGameEngine(this.engine);
        super.setRenderer(this.renderer);
    }

    public void setGameEngine(IGameEngine engine) {
        this.engine = engine;
    }

    @Override
    public void surfaceCreated(SurfaceHolder surfaceHolder) {

    }

    @Override
    public void surfaceChanged(SurfaceHolder surfaceHolder, int i, int i1, int i2) {

    }

    @Override
    public void surfaceDestroyed(SurfaceHolder surfaceHolder) {

    }
}
