package com.nautilus.werewolf.ui;

import com.nautilus.werewolf.game.Card;
import com.nautilus.werewolf.game.Game;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

public class GameSettingFrame extends JFrame {

    private JTextField txtNumberOfPlayer;
    private JTextField txtNumberOfVillager;
    private JTextField txtNumberOfWolf;
    private JComboBox<String> cboIsBodyGuard;

    private JButton btnStartGame;

    //TODO: For testing purpose
    private Game game;

    public GameSettingFrame() {
        initComponent();
    }

    private void initComponent() {
        Container c = getContentPane();
        c.setLayout(new BorderLayout(5, 5));
        c.setPreferredSize(new Dimension(1000, 500));


        this.pack();
    }

    private void loadCards() {

    }

    static class CardInfo {
        Card card;
        int count;
    }

}
