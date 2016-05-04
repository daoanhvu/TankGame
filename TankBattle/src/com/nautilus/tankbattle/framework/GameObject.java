package com.nautilus.tankbattle.framework;

public abstract class GameObject {
	protected float x;
	protected float y;
	protected float z;
	
	protected float width;
	protected float height;
	
	public abstract void render();
	public abstract void dispose();
	public abstract void update(float deltaTime);
}
