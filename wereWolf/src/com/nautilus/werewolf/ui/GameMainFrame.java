package com.nautilus.werewolf.ui;

import com.nautilus.werewolf.game.Game;

import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;

import javax.swing.*;

public class GameMainFrame extends JFrame {

    private JMenuBar mainMenu;
    private JToolBar mainToolBar;
    private JMenu mnFile, mnTool, mnHelp;
    private JMenuItem mniQuit, mniOpenCommandPane, mniHelp, mniAbout;
    private JMenuItem mni3ModelLab;

//    private StrategyCanvas canvas;
    private GamePanel gamePanel;
    private GameInfoPane infoPane;

    private JPanel pnQuestionPane;
    private JButton btnNextQuestion;

    //TODO: For testing purpose
    private Game game;

    public GameMainFrame(){
        super("Nautilus WereWolf 1.0");
        Container c = getContentPane();
        c.setLayout(new BorderLayout(5, 5));

//        c.setBounds(0, 0, 800, 600);
        c.setPreferredSize(new Dimension(1200, 700));

        infoPane = new GameInfoPane();

        //Menubar
        mainMenu = new JMenuBar();
        mnFile = new JMenu("File");
        mniQuit = new JMenuItem("Quit");
        mniQuit.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {

                System.exit(0);

            }
        });
        mnFile.add(mniQuit);

        mainMenu.add(mnFile);
        mnTool = new JMenu("Tools");
        mniOpenCommandPane = new JMenuItem("Command Pane");
        mniOpenCommandPane.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent arg0) {

            }
        });
        mnTool.add(mniOpenCommandPane);

        mainMenu.add(mnTool);
        mnHelp = new JMenu("Help");
        mniHelp = new JMenuItem("Help");
        mniAbout = new JMenuItem("About");
        mnHelp.add(mniHelp);
        mnHelp.add(mniAbout);

        mainMenu.add(mnHelp);
        setJMenuBar(mainMenu);

        initToolBar();

        gamePanel = new GamePanel();
        //canvas = new Lab3DCanvas();
        this.addWindowListener(new WindowAdapter(){
            public void windowClosing(WindowEvent we){

                System.exit(0);
            }

            public void windowOpened(WindowEvent we){
//                canvas.broastCastChanged();
            }
        });
        game = Game.create("");
        gamePanel.setGame(game);

        c.add(gamePanel, BorderLayout.CENTER);
        c.add(infoPane, BorderLayout.EAST);

//        canvas.setDrawPaneListener(infoPane);
        this.pack();
    }

    private void initToolBar(){
//        ToolBar mainToolBar = new ToolBar();
//        add(mainToolBar, BorderLayout.NORTH);
    }
}
