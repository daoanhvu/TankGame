package com.nautilus.werewolf.ui;

import com.nautilus.werewolf.game.Game;

import java.awt.Frame;
import java.awt.BorderLayout;
import java.awt.MenuItem;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.awt.MenuBar;
import java.awt.Menu;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;

public class GameMainFrame extends Frame{

    private MenuBar mainMenu;
    private ToolBar mainToolBar;
    private Menu mnFile, mnTool, mnHelp;
    private MenuItem mniQuit, mniOpenCommandPane, mniHelp, mniAbout;
    private MenuItem mni3ModelLab;

    private StrategyCanvas canvas;
    private GameInfoPane infoPane;

    //TODO: For testing purpose
    private Game game;

    public GameMainFrame(){
        super("Nautilus WereWolf 1.0");
        setLayout(new BorderLayout(5, 5));

        infoPane = new GameInfoPane();

        //Menubar
        mainMenu = new MenuBar();
        mnFile = new Menu("File");
        mniQuit = new MenuItem("Quit");
        mniQuit.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                canvas.stop();
                System.exit(0);

            }
        });
        mnFile.add(mniQuit);

        mainMenu.add(mnFile);
        mnTool = new Menu("Tools");
        mniOpenCommandPane = new MenuItem("Command Pane");
        mniOpenCommandPane.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent arg0) {

            }
        });
        mnTool.add(mniOpenCommandPane);

        mainMenu.add(mnTool);
        mnHelp = new Menu("Help");
        mniHelp = new MenuItem("Help");
        mniAbout = new MenuItem("About");
        mnHelp.add(mniHelp);
        mnHelp.add(mniAbout);

        mainMenu.add(mnHelp);
        setMenuBar(mainMenu);

        initToolBar();

        canvas = new StrategyCanvas();
        //canvas = new Lab3DCanvas();
        this.addWindowListener(new WindowAdapter(){
            public void windowClosing(WindowEvent we){
                canvas.stop();
                System.exit(0);
            }

            public void windowOpened(WindowEvent we){
                canvas.setup();
                //canvas.broastCastChanged();
            }
        });
        game = Game.create("");
        canvas.setGame(game);

        this.add(canvas, BorderLayout.CENTER);
        this.add(infoPane, BorderLayout.EAST);

//        canvas.setDrawPaneListener(infoPane);
        this.pack();
    }

    private void initToolBar(){
//        ToolBar mainToolBar = new ToolBar();
//        add(mainToolBar, BorderLayout.NORTH);
    }
}
