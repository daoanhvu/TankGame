package com.nautilus.werewolf.fx.graphics;

import javafx.scene.canvas.GraphicsContext;
import javafx.scene.effect.Effect;
import javafx.scene.image.Image;

public class Card {
    private int x;
    private int y;
    private int width;
    private int height;
    private Image image;

    public int getX() {
        return x;
    }

    public void setX(int x) {
        this.x = x;
    }

    public int getY() {
        return y;
    }

    public void setY(int y) {
        this.y = y;
    }

    public int getWidth() {
        return width;
    }

    public void setWidth(int width) {
        this.width = width;
    }

    public int getHeight() {
        return height;
    }

    public void setHeight(int height) {
        this.height = height;
    }

    public Image getImage() {
        return image;
    }

    public void setImage(Image image) {
        this.image = image;
    }

    public void draw(boolean alive, GraphicsContext g) {
        if(alive) {
            g.drawImage(image, x, y, width, height);
        } else {
            double oldAlpha = g.getGlobalAlpha();
            Effect oldEffect = g.getEffect(null);
            g.setGlobalAlpha(0.45);
            g.setGlobalAlpha(0.45);
            g.drawImage(image, x, y, width, height);
            g.setGlobalAlpha(oldAlpha);
        }
    }
}
