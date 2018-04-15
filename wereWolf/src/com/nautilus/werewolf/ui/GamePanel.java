package com.nautilus.werewolf.ui;

import com.nautilus.werewolf.game.Card;
import com.nautilus.werewolf.game.Game;

import javax.swing.*;
import java.awt.*;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.event.MouseMotionListener;
import java.awt.image.BufferedImage;

public class GamePanel extends JPanel implements MouseMotionListener {

    Game game;
    Card selectedCard;
    private BufferedImage bacground;
    private Rectangle invalidateRect;

    public GamePanel() {
        this.addMouseListener(new MouseAdapter() {
            @Override
            public void mousePressed(MouseEvent e) {
                super.mousePressed(e);

                selectedCard = game.getCardAt(e.getX(), e.getY());

            }

            @Override
            public void mouseReleased(MouseEvent me) {
                super.mouseReleased(me);
                selectedCard = null;
            }
        });

        this.addMouseMotionListener(this);
    }

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Graphics2D g2d = (Graphics2D) g;

        game.draw(g2d);
    }

    public void setGame(Game _game) {
        this.game = _game;
    }

    @Override
    public void mouseDragged(MouseEvent e) {
        if(selectedCard != null) {
            selectedCard.moveTo(e.getX(), e.getY());
            repaint();
        }
    }

    @Override
    public void mouseMoved(MouseEvent e) {

    }
}
