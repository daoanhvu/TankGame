package com.nautilus.tankbattle;

import com.nautilus.tankbattle.component.GLGraphView;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.game.TankGame;

import android.app.Activity;
import android.os.Bundle;

public class MainActivity extends Activity {

	//private GameSurfaceView view;
	private GLGraphView view;
	private Game game;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		//view = new GameSurfaceView(this);
		view = new GLGraphView(this);
		setContentView(view);
		game = new TankGame();
		game.load(this);
		view.setRenderer(game.getCurrentScreen());
		
	}
	
	protected void onResume() {
		super.onResume();
		view.onResume();
	}
	
	protected void onPause() {
		view.onPause();
		super.onPause();
	}
}
