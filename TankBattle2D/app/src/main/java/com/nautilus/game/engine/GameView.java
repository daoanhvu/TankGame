package com.nautilus.game.engine;

import android.content.Context;
import android.graphics.Canvas;
import android.util.AttributeSet;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import java.lang.ref.WeakReference;
import java.util.ArrayList;

/**
 * Created by nautilus on 5/2/2016.
 */
public class GameView extends SurfaceView implements SurfaceHolder.Callback {

    static final String TAG = "GameView";

    final WeakReference<GameView> mWeakRef = new WeakReference<GameView>(this);
    static final ThreadManager sThreadManager = new ThreadManager();

    boolean mDetached = false;
    GameThread gameThread;
    IRenderer mRenderer;

    public GameView(Context ctx) {
        super(ctx);
        init();
    }

    public GameView(Context ctx, AttributeSet attrSet) {
        super(ctx, attrSet);
        init();
    }

    private void init() {
        SurfaceHolder holder = getHolder();
        holder.addCallback(this);
    }

    public void setEngine(IRenderer renderer) {
        this.mRenderer = renderer;
        gameThread = new GameThread(mWeakRef);
        gameThread.start();
    }

    public void requestRender() {
        gameThread.requestRender();
    }

    @Override
    protected void finalize() throws Throwable {
        try {
            if (gameThread != null) {
                gameThread.requestExitAndWait();
            }
        }finally {
            super.finalize();
        }
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        gameThread.surfaceCreated();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {
        gameThread.windowSizeChanged(w, h);
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        gameThread.surfaceDestroyed();
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();

        if(mDetached && (gameThread != null)) {
            gameThread = new GameThread(mWeakRef);
            gameThread.start();
        }
        mDetached = false;

    }

    @Override
    protected void onDetachedFromWindow() {
        if(gameThread != null)
            gameThread.requestExitAndWait();
        mDetached = true;
        super.onDetachedFromWindow();
    }

    public void onPause() {
        gameThread.onPause();
    }

    public void onResume() {
        gameThread.onResume();
    }

    static class GameThread extends Thread {
        boolean mHasSurface;
        boolean mWaitingForSurface;
        boolean mExited;
        boolean mShouldExit;
        boolean mPaused;
        boolean mRequestPause;
        boolean mSizeChanged;
        boolean mRequestRender;
        boolean mRenderComplete;
        int mWidth;
        int mHeight;

        WeakReference<GameView> mRef;
        private ArrayList<Runnable> mEventQueue = new ArrayList<Runnable>();

        GameThread(WeakReference<GameView> ref) {
            mWidth = 0;
            mHeight = 0;
            mRequestRender = true;
            mRef = ref;
        }


        @Override
        public void run() {
            GameView view;
            Runnable task = null;
            boolean doRenderNotification = false;
            boolean wantRenderNotification = false;
            boolean pausing;
            boolean createSurface = false;
            boolean sizeChanged = false;
            int w = 0;
            int h = 0;

            try {
                while(!mShouldExit) {
                    synchronized (sThreadManager) {
                        while(true) {
                            if(mShouldExit)
                                return;

                            if(!mEventQueue.isEmpty()) {
                                task = mEventQueue.remove(0);
                                break;
                            }

                            pausing = false;
                            if(mPaused != mRequestPause) {
                                pausing = mRequestPause;
                                mPaused = mRequestPause;
                                sThreadManager.notifyAll();
                            }

                            if(pausing) {

                            }

                            if ((! mHasSurface) && (! mWaitingForSurface)) {
                                mWaitingForSurface = true;
                                sThreadManager.notifyAll();
                            }

                            if (mHasSurface && mWaitingForSurface ) {
                                mWaitingForSurface = false;
                                createSurface = true;
                                sThreadManager.notifyAll();
                            }

                            if(doRenderNotification) {
                                wantRenderNotification = false;
                                doRenderNotification = false;
                                mRenderComplete = true;
                                sThreadManager.notifyAll();
                            }

                            //are you ready for rendering
                            if(!mPaused && (mWidth > 0) && (mHeight>0) ) {
                                if(mSizeChanged) {
                                    sizeChanged = true;
                                    w = mWidth;
                                    h = mHeight;
                                    wantRenderNotification = true;
                                    mSizeChanged = false;
                                }

                                mRequestRender = false;
                                sThreadManager.notifyAll();
                                break;

                            }
                            sThreadManager.wait();
                        } //end while
                    } //end synchronized(sThreadManager)

                    if(task != null) {
                        task.run();
                        task = null;
                        continue;
                    }

                    if(sizeChanged) {
                        view = mRef.get();
                        if(view != null) {
                            view.mRenderer.onSurfaceChanged(w, h);
                        }
                        sizeChanged = false;
                    }

                    view = mRef.get();
                    if(createSurface) {
                        view.mRenderer.onSurfaceCreated();
                        createSurface = false;
                    }

                    view = mRef.get();
                    Canvas canvas = view.getHolder().lockCanvas();

                    view.mRenderer.render(canvas);

                    view.getHolder().unlockCanvasAndPost(canvas);

                    if (wantRenderNotification) {
                        doRenderNotification = true;
                    }

                    Thread.sleep(1);
                }
            } catch(InterruptedException e) {
                mShouldExit = true;
            } finally {
                sThreadManager.threadExiting(this);
            }
        }

        void requestRender() {
            synchronized (sThreadManager) {
                mRequestRender = true;
                sThreadManager.notifyAll();
            }
        }

        void surfaceCreated() {
            synchronized (sThreadManager) {
                mHasSurface = true;
                sThreadManager.notifyAll();
                while(mWaitingForSurface && !mExited) {
                    try {
                        sThreadManager.wait();
                    } catch(InterruptedException ex) {
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }

        void windowSizeChanged(int width, int height) {
            synchronized (sThreadManager) {
                mWidth = width;
                mHeight = height;
                mSizeChanged = true;
                mRequestRender = true;
                mRenderComplete = false;
                sThreadManager.notifyAll();

                while(!mExited && !mPaused && !mRenderComplete && (mWidth > 0) && (mHeight>0)) {
                    try {
                        sThreadManager.wait();
                    }catch ( InterruptedException ex ){
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }

        void surfaceDestroyed() {
            synchronized (sThreadManager) {
                mHasSurface = false;
                sThreadManager.notifyAll();
                while( (!mExited) && (!mWaitingForSurface)) {
                    try {
                        sThreadManager.wait();
                    }catch ( InterruptedException ex ){
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }

        void requestExitAndWait() {
            synchronized (sThreadManager) {
                mShouldExit = true;
                sThreadManager.notifyAll();
                while(!mExited) {
                    try {
                        sThreadManager.wait();
                    } catch (InterruptedException ex) {
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }

        void onPause(){
            synchronized (sThreadManager) {
                mRequestPause = true;
                sThreadManager.notifyAll();
                while( !mExited && !mPaused ) {
                    try {
                        sThreadManager.wait();
                    }catch ( InterruptedException ex ){
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }

        void onResume() {
            synchronized (sThreadManager) {
                mRequestPause = false;
                mRequestRender = true;
                mRenderComplete = false;
                sThreadManager.notifyAll();

                while( (!mExited) && mPaused && (!mRenderComplete) ) {
                    try {
                        sThreadManager.wait();
                    }catch ( InterruptedException ex ){
                        Thread.currentThread().interrupt();
                    }
                }
            }
        }

        public void eventQueue(Runnable task) {
            if(task == null)
                throw new IllegalArgumentException("Runnable Task could not be null!");

            synchronized (sThreadManager) {
                mEventQueue.add(task);
                sThreadManager.notifyAll();
            }
        }
    }

    static class ThreadManager {
        private GameThread theThread;

        public synchronized void threadExiting(GameThread thread) {
            thread.mExited =  true;
            if(theThread == thread) {
                theThread = null;
            }
            notifyAll();
        }

        public boolean acquireContext(GameThread thread) {
            if(theThread == thread || theThread == null) {
                theThread = thread;
                notifyAll();
                return true;
            }
            if(theThread != null) {
                notifyAll();
            }
            return false;
        }

        public void releaseContextLocked(GameThread thread) {
            if(theThread == thread) {
                theThread = null;
            }
            notifyAll();
        }
    }
}
