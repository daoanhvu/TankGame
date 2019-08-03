package com.nautilus.werewolf.fx.graphics;

import javafx.scene.canvas.GraphicsContext;
import javafx.scene.effect.Effect;
import javafx.scene.image.Image;

public class Card {
    private double x;
    private double y;
    private double width;
    private double height;
    private Image image;
    
    public Card() {
    }
    
    public Card(double w, double h) {
    	this.width = w;
    	this.height = h;
    }

    public double getX() {
        return x;
    }

    public void setX(double x) {
        this.x = x;
    }

    public double getY() {
        return y;
    }

    public void setY(double y) {
        this.y = y;
    }

    public double getWidth() {
        return width;
    }

    public void setWidth(double width) {
        this.width = width;
    }

    public double getHeight() {
        return height;
    }

    public void setHeight(double height) {
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
            g.drawImage(image, x, y, width, height);
            g.setGlobalAlpha(oldAlpha);
            g.setEffect(oldEffect);
        }
    }
}
