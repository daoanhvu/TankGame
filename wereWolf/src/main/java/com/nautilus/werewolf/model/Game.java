package com.nautilus.werewolf.model;

import java.util.List;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.image.Image;

import com.nautilus.werewolf.fx.graphics.BackgroundInfo;
import com.nautilus.werewolf.fx.graphics.Card;

import java.util.ArrayList;

import javafx.animation.AnimationTimer;
import javafx.scene.canvas.Canvas;
import javafx.scene.paint.Color;

public class Game {
	private Canvas canvas;
	private double width;
	private double height;
    private AnimationTimer animation;
    private BackgroundInfo backgroundInfo;
    
    private List<Character> characters = new ArrayList<>();
    
    public Game() {
    }
    
    public Game(double width, double height) {
    	this.width = width;
    	this.height = height;
    	canvas = new Canvas(width, height);
    	backgroundInfo = new BackgroundInfo("/sample-village.jpg", width, height);
    	backgroundInfo.setType(BackgroundInfo.USE_IMAGE);
    	
    	//Test data
    	Character ww = new WereWolf();
    	Image img = new Image("/werewolf.png");
    	Card wwCard = new Card(80, 150);
    	wwCard.setImage(img);
    	ww.setCard(wwCard);
    	characters.add(ww);
    }
    
    public void start() {
    	if(animation == null) {
    		animation = new AnimationTimer() {
                @Override
                public void handle(long now) {
                	render();
                }
    		};
    	}
    	animation.start();
    }
    
    public void stop() {
    	if(animation != null) {
    		animation.stop();
    	}
    }
    
    public Canvas gameCanvas() { return canvas; }
    
    private void render() {
    	final GraphicsContext g = this.canvas.getGraphicsContext2D();
    	backgroundInfo.renderIfNeeded(g);
    	for(Character c: characters) {
    		c.card.draw(c.isAlive(), g);
    	}
    }
   
}
