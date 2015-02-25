package com.nautilus.tankbattle.framework;

public interface Pixmap {
	public static enum PixmapFormat {
		ARGB8888, ARGB4444, ARGB565
	}
	
	public int getWidth();
	public int getHeight();
	public PixmapFormat getFormat();
	
	public void dispose();
}
