package com.nautilus.tankbattle.util;

import android.graphics.Point;
import android.view.Display;
import android.view.WindowManager;

public class GraphicUtilities {
	@SuppressWarnings("deprecation")
	public static Point getWindowSize(WindowManager wm) {
		Display display = wm.getDefaultDisplay();
		Point p = new Point();
		if(android.os.Build.VERSION.SDK_INT >= 13) {
			display.getSize(p);
			return p;
		}
		
		p.x = display.getWidth();
		p.y = display.getWidth();
		return p;
	}
}
