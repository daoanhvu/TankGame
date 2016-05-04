package com.nautilus.game.model;

/**
 * Created by davu on 5/3/2016.
 */
public abstract class GameObject {
    protected float x;
    protected float y;
    protected int width;
    protected int height;

    public abstract boolean load();

    public void setX(float x_) {
        x = x_;
    }

    public float getX(){ return x; }

    public void setY(float y_) {
        y = y_;
    }

    public float getY(){ return y; }

    public void setWidth(int w) {
        width = w;
    }

    public int getWidth(){ return width; }

    public void setHeight(int h) {
        height = h;
    }

    public int getHeight(){ return height; }

    public void moveTo(float x_, float y_) {
        x = x_;
        y = y_;
    }
}
