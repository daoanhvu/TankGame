package com.nautilus.tankbattle.framework;

import com.nautilus.tankbattle.framework.Pixmap.PixmapFormat;

public interface Graphics {
	public Pixmap newPixmap(String filename, PixmapFormat format);
	public void clear(int color);
	public void drawPixel(int x, int y, int color);
	public void drawLine(int x1, int y1, int x2, int y2, int color);
	public void drawRect(int x, int y, int width, int height, int color);
	
}
