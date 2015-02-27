package com.nautilus.tankbattle.component;

import java.lang.ref.WeakReference;
import java.util.ArrayList;

import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.Screen;
import com.nautilus.tankbattle.game.BattleScreen;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.Log;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/**
 * Please read here:
 * 	https://github.com/android/platform_frameworks_base/blob/master/opengl/java/android/opengl/GLSurfaceView.java
 * 
 * @author Dao Anh Vu
 *
 */
public class GameSurfaceView extends SurfaceView implements SurfaceHolder.Callback {

	/**
     * The renderer only renders
     * when the surface is created, or when {@link #requestRender} is called.
     *
     * @see #getRenderMode()
     * @see #setRenderMode(int)
     * @see #requestRender()
     */
    public final static int RENDERMODE_WHEN_DIRTY = 0;
    /**
     * The renderer is called
     * continuously to re-render the scene.
     *
     * @see #getRenderMode()
     * @see #setRenderMode(int)
     */
    public final static int RENDERMODE_CONTINUOUSLY = 1;
    
    private static final float ZOOM_SCALE_MIN = 30f;
    private static final float ZOOM_SCALE_MAX = 400f;
	
	/*=================================================================================*/
    private static final ThreadManager threadManager = new ThreadManager();
	private final WeakReference<GameSurfaceView> mThisWeakRef = new WeakReference<GameSurfaceView>(this);
	private DrawingThread mThread;
	private boolean mDetached;
	/*=================================================================================*/
	
    Paint paint;
    Paint paintCoordX;
    Paint paintCoordY;
    boolean mShouldShowGrid = true;
    boolean showContextMenu = false;
    int bgColor;
    int textColor, xColor, yColor, gridColor;
    private float contextMenuX, contextMenuY;
    private float previousX, previousY;
    
    float oldPoiterDist;
    
    Game game;
    
    /** Viewport */
    int left;
    int right;
    int top;
    int bottom;
    int XScreen0, YScreen0;
    float scaleX, scaleY;
    
    int touchMode;
    float midPointX, midPointY;
    
    GestureDetector gestureDetector;
    V2DGestureListener gestureListener = new V2DGestureListener();
    
    ScaleGestureDetector mScaleGestureDetector;
    
    final class V2DGestureListener extends GestureDetector.SimpleOnGestureListener {
    	@Override
    	public boolean onDown(MotionEvent ev) {
    		return true;
    	}
    	
    	@Override
    	public boolean onFling(MotionEvent ev1, MotionEvent ev2, float velocityX, float velocityY) {
    		return true;
    	}
    	
    	@Override
    	public void onLongPress(MotionEvent ev) {
    		
    	}
    	
    	@Override
    	public boolean onScroll(MotionEvent ev1, MotionEvent ev2, float distX, float distY) {
    		return true;
    	}
    }
    
    final ScaleGestureDetector.OnScaleGestureListener mOnScaleGestureListener = new ScaleGestureDetector.SimpleOnScaleGestureListener() {

//    	float lastSpanX, lastSpanY;

//		@Override
//		public boolean onScaleBegin(ScaleGestureDetector detector) {
//			if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
//				lastSpanX = detector.getCurrentSpanX(); 
//				lastSpanY = detector.getCurrentSpanY();
//			} else {
//				lastSpanX = lastSpanY = detector.getCurrentSpan(); 
//			}
//			
//			return true;
//		}
		
		@Override
		public boolean onScale(ScaleGestureDetector detector) {
			final float scaleFactor = detector.getScaleFactor();
//			final float spanX, spanY;
//			if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
//				spanX = detector.getCurrentSpanX(); 
//				spanY = detector.getCurrentSpanY();
//			} else {
//				spanX = spanY = detector.getCurrentSpan(); 
//			}
			
			queueEvent(new Runnable(){
				@Override
				public void run() {
//					scaleX *= spanX/lastSpanX;
//					scaleY *= spanY/lastSpanY;
					
					scaleX *= scaleFactor;
					scaleY *= scaleFactor;
					
//					Log.i("NMATH2DSurfaceView","scale factor = " + f + "; scaleX = " + scaleX + "; scaleY = " + scaleY);
					
					if(scaleX < ZOOM_SCALE_MIN)
						scaleX = ZOOM_SCALE_MIN;
					else if(scaleX > ZOOM_SCALE_MAX)
						scaleX = ZOOM_SCALE_MAX;
					
					if(scaleY < ZOOM_SCALE_MIN)
						scaleY = ZOOM_SCALE_MIN;
					else if(scaleY > ZOOM_SCALE_MAX)
						scaleY = ZOOM_SCALE_MAX;

					mThread.requestRender();
				}					
			});

//			lastSpanX = spanX;
//			lastSpanY = spanY;
			return true;
		}
	};
		
	public GameSurfaceView(Context ctx){
		super(ctx);
		
		gestureDetector = new GestureDetector(ctx, gestureListener);
		gestureDetector.setIsLongpressEnabled(true);

		mScaleGestureDetector = new ScaleGestureDetector(ctx, mOnScaleGestureListener);
		
		bgColor = Color.parseColor("#f0eeee");
		gridColor = Color.parseColor("#949393");
		textColor = Color.rgb(23, 100, 99);
		xColor = Color.RED;
		yColor = Color.GREEN;
		SurfaceHolder holder = this.getHolder();
		holder.addCallback(this);
		init();
	}
	
	public GameSurfaceView(Context ctx, int dColor, int xcolor, int ycolor, int zcolor){
		super(ctx);
		
		gestureDetector = new GestureDetector(ctx, gestureListener);
		gestureDetector.setIsLongpressEnabled(true);

		mScaleGestureDetector = new ScaleGestureDetector(ctx, mOnScaleGestureListener);
		
		textColor = dColor;
		xColor = xcolor;
		yColor = ycolor;
		SurfaceHolder holder = this.getHolder();
		holder.addCallback(this);
		init();
	}

	private void init() {
		paint = new Paint(Paint.ANTI_ALIAS_FLAG);
	    paint.setColor(textColor);
	    paint.setStrokeWidth(2);
	    
	    paintCoordX = new Paint(Paint.ANTI_ALIAS_FLAG);
		paintCoordX.setColor(xColor);
		
		paintCoordY = new Paint(Paint.ANTI_ALIAS_FLAG);
		paintCoordY.setColor(yColor);
	}
	
	public void startRender() {
		mThread = new DrawingThread(mThisWeakRef);
		mThread.start();
	}

	public void viewportChanged(int l, int r, int t, int b) {
		left = l;
		right = r;
		top = t;
		bottom = b;
		XScreen0 = (left + right) >> 1;
		YScreen0 = (top + bottom) >> 1;
		scaleX = 30;
		scaleY = 30;
		mThread.onWindowResize(getWidth(), getHeight(),	l, r,t,b);
	}
	
	@Override
	public void surfaceCreated(SurfaceHolder holder) {
		mThread.onSurfaceCreated();
	}
	
	@Override
	public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {
		left = 0;
		right = w;
		top = 0;
		bottom = h;
		XScreen0 = (left + right) >> 1;
		YScreen0 = (top + bottom) >> 1;
		scaleX = 20;
		scaleY = 20;
		mThread.onWindowResize(w, h, left, right, top, bottom);
	}

	@Override
	public void surfaceDestroyed(SurfaceHolder holder) {
		mThread.onSurfaceDestroyed();
	}
	
	@Override
	protected void finalize() throws Throwable {
		try {
			if(mThread != null)
				mThread.requestExitAndWait();
		}finally{
			super.finalize();
		}
	}
	
	public void queueEvent(Runnable r) {
		mThread.queueEvent(r);
	}
	
	@Override
	public boolean onTouchEvent(MotionEvent ev) {
		boolean result = mScaleGestureDetector.onTouchEvent(ev);
		return result || super.onTouchEvent(ev);
	}
	
	public void setGame(Game game) {
		this.game = game;
	}
	
	/**
		This method is a part of View and should not called by client of subclassed by clients of 
		NMathSurfaceView
	*/
	@Override
	protected void onAttachedToWindow() {
		super.onAttachedToWindow();
		
		if(mDetached) {
			int renderMode = RENDERMODE_CONTINUOUSLY;
			if(mThread != null) {
				renderMode = mThread.getRenderMode();
			}
			mThread = new DrawingThread(mThisWeakRef);
			if(renderMode != RENDERMODE_CONTINUOUSLY)
				mThread.setRenderMode(renderMode);
				
			mThread.start();
		}
		mDetached = false;
	}
	
	/**
		This method is part of View class
	*/
	@Override
	protected void onDetachedFromWindow() {
		if(mThread != null) {
			mThread.requestExitAndWait();
		}
		mDetached = true;
		super.onDetachedFromWindow();
	}
	
	static class DrawingThread extends Thread {
		
		private boolean mExited;
		private boolean mShouldExit;
		private boolean mShouldReleaseDrawingContext;
		private boolean mRequestPaused;
		private boolean mPaused;
		private boolean mHasSurface;
		private boolean mHasContext;
		private boolean mSurfaceIsBad;
		private boolean mRequestRender;
		private boolean mRenderComplete;
		private boolean mWaitingForSurface;
		private int mWidth;
		private int mHeight;
		private int mLeft, mTop, mRight, mBottom;
		private int mRenderMode;
		private boolean mSizeChange = true;
		
		private WeakReference<GameSurfaceView> mNMathSurfaceViewWeakRef;
		private ArrayList<Runnable> mEventQueue = new ArrayList<Runnable>();

		DrawingThread(WeakReference<GameSurfaceView> weakRef) {
			super();
			//mShouldExit = false;
			//mExited = false;
			mWidth = 0;
			mHeight = 0;
			mRequestRender = true;
			//mRenderMode = RENDERMODE_WHEN_DIRTY;
			mRenderMode = RENDERMODE_CONTINUOUSLY;
			mNMathSurfaceViewWeakRef = weakRef;
		}
		
		@Override
		public void run() {
			GameSurfaceView view;
			int loop, i, k;
			float x0, y0, x1, y1, vertexCount;
			try{
				Runnable event = null;
				boolean pausing = false;
				boolean sizeChanged = false;
				boolean readyToDraw = false;
				boolean wantRenderNotification = false;
                boolean doRenderNotification = false;
				int w = 0, h = 0, left = 0, right = 0, top = 0, bottom = 0;
				float[] vertices;
				
				while(true) {
					synchronized(threadManager){
						while(true) {
							
							if(mShouldExit) return;
							
							if(!mEventQueue.isEmpty()){
								event = mEventQueue.remove(0);
								break;
							}
							
							pausing = false;
							if(mPaused != mRequestPaused) {
								pausing = mRequestPaused;
	                            mPaused = mRequestPaused;
	                            threadManager.notifyAll();
							}
							
							//have we lost the surface
							if((!mHasSurface) && (!mWaitingForSurface)){
								mWaitingForSurface = true;
								mSurfaceIsBad = false;
								threadManager.notifyAll();
							}
							
							//have we acquired surface
							if( mHasSurface && mWaitingForSurface){
								mWaitingForSurface = false;
								threadManager.notifyAll();
							}
							
							if(doRenderNotification) {
								wantRenderNotification = false;
	                            doRenderNotification = false;
	                            mRenderComplete = true;
	                            threadManager.notifyAll();
							}
							
							readyToDraw = (!mExited) && (!mPaused) && mHasSurface 
									&& (mWidth>0) && (mHeight>0) && (mRequestRender || (mRenderMode == RENDERMODE_CONTINUOUSLY));
							if(readyToDraw) {
								if(mSizeChange) {
									sizeChanged = true;
									w = mWidth;
									h = mHeight;
									left = mLeft;
									right = mRight;
									top = mTop;
									bottom = mBottom;
									wantRenderNotification = true;
									mSizeChange = false;
								}
								mRequestRender = false;
								threadManager.notifyAll();
								break;
							}
							
							threadManager.wait();
						}//end 2nd while
					}//end synchronized
					
					if(event != null) {
						event.run();
						event = null;
						continue;
					}
					
					//check if sizeChanged
					if(sizeChanged) {
						//DO NOTHING HERE
						sizeChanged = false;
					}

					view = mNMathSurfaceViewWeakRef.get();
					//check if it's ready to draw
					
					//readyToDraw = readyToDraw && holder.getSurface().isValid(); 
					if(view != null) {
						Canvas canvas = view.getHolder().lockCanvas();
						
						//Render game scene here
						//view.game.render(canvas);

						view.getHolder().unlockCanvasAndPost(canvas);
					}
					
					if (wantRenderNotification) {
                        doRenderNotification = true;
                    }
				}//end while(!mShouldExit)
			}catch(InterruptedException ex){
				//Do nothing here
			} finally {
				threadManager.threadExiting(this);
			}
		}

		/** Draw */

		public void queueEvent(Runnable r) {
			synchronized(threadManager) {
				mEventQueue.add(r);
				threadManager.notifyAll();
			}
		}
		
		public void requestRender() {
			synchronized(threadManager) {
				mRequestRender = true;
				threadManager.notifyAll();
			}
		}
		
		/**
		 * don't call this inside DrawingThread
		 */
		public void requestExitAndWait() {
			synchronized(threadManager) {
				mShouldExit = true;
				threadManager.notifyAll();
				while(!mExited) {
					try {
						threadManager.wait();
					} catch (InterruptedException e) {
						Thread.currentThread().interrupt();
					}
				}
			}
		}
		
		public void setRenderMode(int renderMode) {
			if(renderMode != RENDERMODE_CONTINUOUSLY && renderMode != RENDERMODE_WHEN_DIRTY)
				throw new IllegalArgumentException("renderMode");
			synchronized(threadManager) {
				mRenderMode = renderMode;
				threadManager.notifyAll();
			}
		}
		
		public int getRenderMode() {
			synchronized(threadManager) {
				return mRenderMode;
			}
		}
		
		public void onWindowResize(int w, int h, int left, int right, int top, int bottom) {
			synchronized(threadManager) {
				mWidth = w;
				mHeight = h;
				mLeft = left;
				mRight = right;
				mTop = top;
				mBottom = bottom;
				mRenderComplete = false;
				mRequestRender = true;
				mSizeChange = true;
				threadManager.notifyAll();
				while(!mExited && !mPaused && !mRenderComplete && mWidth>0
						&& mHeight>0 && mHasSurface && (mRequestRender || (mRenderMode == RENDERMODE_CONTINUOUSLY))) {
					try {
						threadManager.wait();
					} catch (InterruptedException e) {
						Thread.currentThread().interrupt();
					}
				}
			}
		}
		
		public void onSurfaceCreated() {
			synchronized(threadManager) {
				mHasSurface = true;
				threadManager.notifyAll();
				while(mWaitingForSurface && !mExited){
					try {
						threadManager.wait();
					} catch (InterruptedException e) {
						Thread.currentThread().interrupt();
					}
				}
			}
		}
		
		public void onSurfaceDestroyed() {
			synchronized(threadManager) {
				mHasSurface = false;
				threadManager.notifyAll();
				
				while(!mExited && !mWaitingForSurface) {
					try {
						threadManager.wait();
					} catch (InterruptedException e) {
						Thread.currentThread().interrupt();
					}
				}
			}
		}
		
		public void onPause() {
			synchronized(threadManager) {
				mRequestPaused = true;
				threadManager.notifyAll();
				while( !mExited && !mPaused) {
					try {
						threadManager.wait();
					} catch (InterruptedException e) {
						Thread.currentThread().interrupt();
					}
				}
			}
		}
		
		public void onResume() {
			synchronized(threadManager) {
				mRequestPaused = false;
				mRequestRender = true;
				mRenderComplete = false;
				threadManager.notifyAll();
				while(!mExited && mPaused && (!mRenderComplete)) {
					try {
						threadManager.wait();
					} catch (InterruptedException e) {
						// TODO Auto-generated catch block
						Thread.currentThread().interrupt();
					}
				}
			}
		}
	}
	
	/*=================================================================*/
	private static class ThreadManager {
		private DrawingThread mThread;

		public synchronized void threadExiting(DrawingThread thread) {
			thread.mExited = true;
			if(mThread == thread)
				mThread = null;
			
			notifyAll();
		}
		
		public void releaseContextLocked(DrawingThread thread) {
			if(mThread == thread)
				mThread = null;
			notifyAll();
		}
	}
	/*=================================================================*/
	
	public int getBgColor() {
		return bgColor;
	}
	
	public void setBgColor(final int color) {
		if (mThread != null) {
			mThread.queueEvent(new Runnable(){
				public void run() {
					bgColor = color;
					mThread.requestRender();
				}
			});
		} else {
			bgColor = color;
		}
	}
	
	public void setShouldShowGrid(final boolean value) {
		if (mThread != null) {
			mShouldShowGrid = value;
			mThread.requestRender();
		} else {
			mShouldShowGrid = value;
		}
	}
	
	public boolean shouldShowGrid() {
		return mShouldShowGrid;
	}

	public Paint getPaintY() {
		// TODO Auto-generated method stub
		return paintCoordY;
	}

	public Paint getPaintX() {
		// TODO Auto-generated method stub
		return paintCoordX;
	}

	public void onResume() {
		if(mThread == null){
			startRender();
		}
		mThread.onResume();
	}

	public void onPause() {
		mThread.onPause();
	}

	public void getRange(double[] range) {		
		range[0] = (left - XScreen0)/scaleX - 1.0f;
		range[1] = (right - XScreen0)/scaleX - 1.0f;
		
		range[2] = (YScreen0 - top)/scaleY;
		range[3] = (YScreen0 - bottom)/scaleY;
		
	}
}
