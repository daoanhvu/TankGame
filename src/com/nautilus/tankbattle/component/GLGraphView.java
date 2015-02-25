package com.nautilus.tankbattle.component;

import java.util.ArrayList;

import com.nautilus.tankbattle.framework.Screen;
import com.nautilus.tankbattle.game.Camera3D;

import android.content.Context;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.os.AsyncTask;
import android.util.AttributeSet;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;

public class GLGraphView extends GLSurfaceView {

	private final float TOUCH_SCALE_FACTOR = 180.0f/320;
	private Screen renderer;
	private float previousX, previousY;
	
	GestureDetector mGestureDetector;
	ScaleGestureDetector mScaleGestureDetector;
	final V3DGestureListener mOnScrollGestureListener = new V3DGestureListener();
	
	final class V3DGestureListener extends GestureDetector.SimpleOnGestureListener {
		@Override
    	public boolean onDown(MotionEvent ev) {
			previousX = ev.getX(); 
			previousY = ev.getY();
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
    		float x = ev2.getX();
    		float y = ev2.getY();
    		final float dx = x - previousX;
			final float dy = y - previousY;
			queueEvent(new Runnable(){
				@Override
				public void run() {
//					renderer.rotate(dx, dy, 0);
					requestRender();
				}					
			});
			previousX = x; 
			previousY = y;
    		return true;
    	}
	}
	
	final ScaleGestureDetector.OnScaleGestureListener mOnScaleGestureListener = new ScaleGestureDetector.SimpleOnScaleGestureListener() {
		@Override
		public boolean onScale(ScaleGestureDetector detector) {
			final float scaleFactor = detector.getScaleFactor();
			
			if (scaleFactor == 1.0f ) return true;
			
			queueEvent(new Runnable(){
				@Override
				public void run() {
//					renderer.moveAlongForward(scaleFactor);
					requestRender();
				}					
			});
			return true;
		}
	};
	
	public GLGraphView(Context context) {
		super(context);
		setEGLContextClientVersion(2);
		mGestureDetector = new GestureDetector(context, mOnScrollGestureListener);
		//mGestureDetector.setIsLongpressEnabled(true);
		mScaleGestureDetector = new ScaleGestureDetector(context, mOnScaleGestureListener);
	}
	
	public GLGraphView(Context context, AttributeSet aset){
		super(context, aset);
		setEGLContextClientVersion(2);
		mGestureDetector = new GestureDetector(context, mOnScrollGestureListener);
		//mGestureDetector.setIsLongpressEnabled(true);
		mScaleGestureDetector = new ScaleGestureDetector(context, mOnScaleGestureListener);
	}
	
	@Override
	public void setRenderer(GLSurfaceView.Renderer rd){
		super.setEGLConfigChooser(8 , 8, 8, 8, 16, 0);
		super.setRenderer(rd);
		renderer = (Screen)rd;
	}

	@Override
	public boolean onTouchEvent(MotionEvent ev){
		boolean result1 = mScaleGestureDetector.onTouchEvent(ev);
		boolean result2 = mGestureDetector.onTouchEvent(ev);
		//boolean result2 = false;
		return result1 || result2 || super.onTouchEvent(ev);
	}

	public float[] getModelMatrix() {
//		return renderer.getModelMatrix();
		return null;
	}

	public void setModelMatrix(final float[] modeViewM) {
		this.queueEvent(new Runnable(){
			public void run() {
				//renderer.setModelMatrix(modeViewM);
				requestRender();
			}
		});
	}
	
	public void clearAllGraph() {
		this.queueEvent(new Runnable(){
			public void run() {
//				renderer.deleteGraphObjects();
				requestRender();
			}
		});
	}

	
	@Override
	public void onResume() {
		super.onResume();
	}
	
	@Override
	public void onPause() {
		renderer.dispose();
		super.onResume();
	}
}