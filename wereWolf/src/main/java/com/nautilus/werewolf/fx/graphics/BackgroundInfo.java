package com.nautilus.werewolf.fx.graphics;

import javafx.scene.canvas.GraphicsContext;
import javafx.scene.image.Image;
import javafx.scene.paint.Color;

public class BackgroundInfo {

    public static final int USE_COLOR = 0;
    public static final int USE_IMAGE = 1;

    private Color color;
    private Image mapImage;
    private int type;
    private double width;
    private double height;
    private int needReRender;

    public BackgroundInfo(String imageUrl, double w, double h) {
        needReRender = 0;
        color = new Color(0.4179, 0.4179, 0.4179, 1);
        mapImage = new Image(imageUrl);
        this.width = w;
        this.height = h;
    }

    public void renderIfNeeded(GraphicsContext g) {
        if(needReRender < 2) {
            if(type == USE_COLOR) {
                g.clearRect(0, 0, width, height);
                g.setFill(color);
                g.fill();
            } else {
                g.drawImage(mapImage, 0.0, 0.0, width, height);
            }
            needReRender++;
        }
    }

    public void size(double w, double h) {
        this.width = w;
        this.height = h;
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

    public int getType() {
        return type;
    }

    public void setType(int type) {
        if(this.type != type) {
            needReRender = 0;
        }
        this.type = type;
    }
}
