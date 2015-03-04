package com.nautilus.tankbattle;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import com.nautilus.tankbattle.framework.Audio;
import com.nautilus.tankbattle.framework.FileIO;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.Graphics;
import com.nautilus.tankbattle.framework.Screen;
import com.nautilus.tankbattle.framework.UserInput;
import com.nautilus.tankbattle.game.StartScreen;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.os.PowerManager;
import android.os.PowerManager.WakeLock;

public class MainActivity extends Activity {
	
	enum GameState {
		Initialized,
		Running,
		Pause,
		Idle,
		Fininished
	}
	
	private GLSurfaceView view;
	private TankBattleGame game;
	WakeLock mWakeLock;
	long mStartTime = System.nanoTime();
	GameState mState = GameState.Initialized; 
	Object stateChanged = new Object();
	boolean finishing = false;
	
	class TankBattleGame implements Game, GLSurfaceView.Renderer {
		
		private Graphics graphics;
		private Audio audio;
		private UserInput userInput;
		private FileIO fileIO;
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
			// TODO Auto-generated method stub
			
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

		@Override
		public void load(Activity activity) {
			// TODO Auto-generated method stub
			
		}

		@Override
		public UserInput getInput() {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public Graphics getGraphics() {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public Audio getAudio() {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public FileIO getFileIO() {
			// TODO Auto-generated method stub
			return null;
		}

		@Override
		public void setScreen(Screen screen) {
			if(screen == null)
				throw new IllegalArgumentException("Screen must not be null!");
			currentScreen.pause();
			currentScreen.dispose();
			currentScreen.resume();
			currentScreen.update(0);
			currentScreen = screen;
		}

		@Override
		public Screen getCurrentScreen() {
			return currentScreen;
		}

		@Override
		public Screen getStartScreen() {
			StartScreen startScreen = new StartScreen(this);
			return startScreen;
		}

		@Override
		public Bitmap getTile(int index) {
			return null;
		}		
	}
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		
		PowerManager powerManager = (PowerManager)getSystemService(Context.POWER_SERVICE);
		mWakeLock = powerManager.newWakeLock(PowerManager.FULL_WAKE_LOCK, "MainActivity");
		
		game = new TankBattleGame();
		view = new GLSurfaceView(this);
		view.setRenderer(game);
		setContentView(view);
	}
	
	@Override
	protected void onResume() {
		super.onResume();
		view.onResume();
		mWakeLock.acquire();
	}
	
	@Override
	protected void onPause() {
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
		mWakeLock.release();
		view.onPause();
		super.onPause();
	}
}
