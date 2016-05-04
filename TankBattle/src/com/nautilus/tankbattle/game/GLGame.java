package com.nautilus.tankbattle.game;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import com.nautilus.tankbattle.component.GLGraphView;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.Screen;

import android.opengl.GLSurfaceView;
import android.os.PowerManager.WakeLock;

public abstract class GLGame implements Game, GLSurfaceView.Renderer {
	enum GameState {
		Initialized,
		Running,
		Pause,
		Idle,
		Fininished
	}
	
	GLGraphView view;
	
	long mStartTime = System.nanoTime();
	GameState mState = GameState.Initialized; 
	Object stateChanged = new Object();
	boolean finishing = false;
	Screen currentScreen;
	
	@Override
	public void onSurfaceCreated(GL10 gl, EGLConfig config) {
		if(mState == GameState.Initialized)
			currentScreen = getStartScreen();
		mState = GameState.Running;
		currentScreen.resume();
		mStartTime = System.nanoTime();
	}
	
	@Override
	public void onSurfaceChanged(GL10 gl, int width, int height) {
		
	}
	
	@Override
	public void onDrawFrame(GL10 gl) {
		GameState state = null;
		
		synchronized (stateChanged) {
			state = mState;
		}
		
		if(state == GameState.Running) {
			float deltaTime = (System.nanoTime() - mStartTime) / 1000000000.0f;
			mStartTime = System.nanoTime();
			
			currentScreen.update(deltaTime);
			currentScreen.present(deltaTime);
		}
		
		if(state == GameState.Pause) {
			currentScreen.pause();
			
			synchronized (stateChanged) {
				mState = GameState.Idle;
				stateChanged.notifyAll();
			}
		}
		
		if(state == GameState.Pause) {
			currentScreen.pause();
			currentScreen.dispose();
			synchronized (stateChanged) {
				mState = GameState.Idle;
				stateChanged.notifyAll();
			}
		}
	}
	
	public void onPause() {
		synchronized (stateChanged) {
			mState = GameState.Pause;
			if(isFinishing()) {
				mState = GameState.Fininished;
			}
			
			while(true) {
				try{
					stateChanged.wait();
					break;
				}catch(InterruptedException e) {
					
				}
			}
		}
	}
	
	private boolean isFinishing() {
		return finishing;
	}

	public void onResume() {
		
	}
}
