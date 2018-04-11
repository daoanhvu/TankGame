package com.nautilus.werewolf.game;

import com.nautilus.werewolf.listener.GameStatusChangeListener;

import java.awt.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

public class Game {

    private Date date;
    private int totalPoint;
    private final List<Card> cards = new ArrayList<>();
    private GameStatusChangeListener gameStatusChangeListener;

    public Game() {
    }

    public void addCard(Card card) {
        cards.add(card);
        totalPoint += card.getCharacter().getPoint();

        if( gameStatusChangeListener != null ) {
            gameStatusChangeListener.onAddCard(totalPoint);
        }
    }

    public void setGameStatusChangeListener( GameStatusChangeListener listener ) {
        this.gameStatusChangeListener = listener;
    }

    public void draw(Graphics2D g2) {
        for(Card card: cards) {
            card.draw(g2);
        }
    }

    //TODO: I hard code here to quickly deliver POC
    public static Game create(String xmlfile) {
        final int tableWidth = 750;
        final int tableHeight = 600;
        final int numberOfPlayer = 11;
        final int padding = 12;

        int h = (((tableWidth + tableHeight) * 2 ) / numberOfPlayer ) - numberOfPlayer * padding;
        int w = h * 2;
        int x = padding;
        int y = padding;

        Game game = new Game();
        try {
            Card card = new Card(x, y, w, h, "Vu Dao");
            Character ch = new Character("Villager", "D:\\projects\\WereWolf\\images\\villager.jpg");
            card.setCharacter(ch);
            game.addCard(card);

            y += w + padding;
            card = new Card(x, y, w, h, "Thai");
            ch = new Character("Villager", "D:\\projects\\WereWolf\\images\\ww.jpg");
            card.setCharacter(ch);
            game.addCard(card);
//
//            card = new Card(0, 0, w, h, "Trang Truong");
//            game.addCard(card);

        } catch (IOException e) {
            e.printStackTrace();
        }


        return game;
    }

}