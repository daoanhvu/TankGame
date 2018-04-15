package com.nautilus.werewolf;

import com.nautilus.werewolf.ui.GameMainFrame;

import javax.swing.*;

public class Application {

    public static void main(String[] args) {
        try {
            SwingUtilities.invokeAndWait(new Runnable() {
                @Override
                public void run() {
                    GameMainFrame gameFrame = new GameMainFrame();
                    gameFrame.setVisible(true);
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

}
