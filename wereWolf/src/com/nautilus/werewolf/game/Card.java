package com.nautilus.werewolf.game;

import java.awt.*;

public class Card {

    private int x;
    private int y;
    private int width;
    private int height;

    private String playerName;
    private Character character;
    private boolean alive;

    public Card(int _x, int _y, int _w, int _h,
                String name) {
        this.x = _x;
        this.y = _y;
        this.width = _w;
        this.height = _h;
        alive = true;
    }

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

    public String getPlayerName() {
        return playerName;
    }

    public void setPlayerName(String playerName) {
        this.playerName = playerName;
    }

    public Character getCharacter() {
        return character;
    }

    public void setCharacter(Character character) {
        this.character = character;
    }

    public boolean isAlive() {
        return alive;
    }

    public void setAlive(boolean alive) {
        this.alive = alive;
    }

    public void draw(Graphics2D g2) {
        Color old = g2.getColor();

        g2.setColor(Color.RED);
        g2.drawRect(x, y, width, height);
        if( alive ) {
            g2.drawImage(character.getImage(), null, x, y);
        } else {

        }
    }
}
