package com.nautilus.tankbattle;

import com.nautilus.tankbattle.component.GameSurfaceView;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.game.TankGame;

import android.app.Activity;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;

public class MainActivity extends Activity {

	private GameSurfaceView view;
	private Game game;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		
		view = new GameSurfaceView(this);
		setContentView(view);
		
		game = new TankGame();
		game.load(this);
		
		view.setGame(game);
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
