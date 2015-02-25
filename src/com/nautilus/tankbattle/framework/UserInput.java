package com.nautilus.tankbattle.framework;

import java.util.List;

public interface UserInput {
	public static class KeyEvent {
		public static final int KEY_DOWN = 0;
		public static final int KEY_UP = 1;
		
		public int keyCode;
		public int type;
		public char keyChar;
	}
	
	public static class TouchEvent {
		public static final int TOUCH_DOWN = 0;
		public static final int TOUCH_UP = 1;
		public static final int TOUCH_DRAGGED = 2;
		
		public int type;
		public int x;
		public int y;
		public char pointer;
	}
	
	public boolean isKeyPressed(int keyCode);
	public boolean isTouchDown(int pointer);
	public int touchX(int pointer);
	public int touchY(int pointer);
	
	public float accelX();
	public float accelY();
	public float accelZ();
	
	public List<KeyEvent> keyEvents();
	public List<TouchEvent> touchEvent();
}
