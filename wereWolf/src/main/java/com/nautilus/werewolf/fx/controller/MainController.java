package com.nautilus.werewolf.fx.controller;

import com.nautilus.werewolf.fx.FXHelper;
import com.nautilus.werewolf.model.Game;

import javafx.application.Platform;
import javafx.event.EventHandler;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuBar;
import javafx.scene.control.MenuItem;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.Pane;
import javafx.stage.Stage;
import javafx.stage.WindowEvent;

import java.io.IOException;
import java.net.URL;
import java.util.ResourceBundle;

public class MainController extends GenericController implements Initializable {

    private MenuBar mainMenuBar;

    @FXML
    private BorderPane mainWindow;
    
    @FXML
    private Pane centerPane;

    private GenericController centerController;
    
    private Game currentGame;

    public MainController() {
    }

    private void initMenuBar() {
        mainMenuBar = new MenuBar();
//		mainMenuBar.setStyle("-fx-background-color: #90caf9");
        // --- Menu File
        Menu menuFile = new Menu("File");
        MenuItem mniQuit = new MenuItem("Quit");
        mniQuit.setOnAction(t -> Platform.exit());
        menuFile.getItems().add(mniQuit);
        // --- Menu Edit
        Menu menuEdit = new Menu("Edit");
        // --- Menu Action
        Menu menuTools = new Menu("Tools");
        MenuItem mniNewGame = new MenuItem("New Game");
        MenuItem migrateSimulator = new MenuItem("Migrate Simulator");
        MenuItem exportLiveEventItem = new MenuItem("Export Live VehicleLiveEvent");
        menuTools.getItems().add(mniNewGame);
        menuTools.getItems().add(migrateSimulator);
        menuTools.getItems().add(exportLiveEventItem);
        mniNewGame.setOnAction(t -> {
            this.currentGame = new Game(centerPane.getWidth(), centerPane.getHeight());
            centerPane.getChildren().add(this.currentGame.gameCanvas());
            this.currentGame.start();
        });
        migrateSimulator.setOnAction(t -> {
            if(mainWindow.getCenter() != null && centerController != null) {
                centerController.onClosing();
            }

            try {
                MainController.this.centerController = FXHelper.loadComponentFromFXML(mainStage, "/migration.fxml");
                mainWindow.setCenter(centerController.getLoadedRootNode());
            } catch (IOException e) {
                e.printStackTrace();
            }
        });

        MenuItem dataMigrationItem = new MenuItem("Data Migration");
        dataMigrationItem.setOnAction(t -> {
            try {
                if(mainWindow.getCenter() != null && centerController != null) {
                    centerController.onClosing();
                }
                centerController = FXHelper.loadComponentFromFXML(null, "/staffs.fxml");
                mainWindow.setCenter(centerController.getLoadedRootNode());
            } catch (IOException e) {
                e.printStackTrace();
            }
        });

        exportLiveEventItem.setOnAction(t -> {
            try {
                if(mainWindow.getCenter() != null && centerController != null) {
                    centerController.onClosing();
                }
                centerController = FXHelper.loadComponentFromFXML(null, "/export_data_csv.fxml");
                mainWindow.setCenter(centerController.getLoadedRootNode());
            } catch (IOException e) {
                e.printStackTrace();
            }
        });

        // --- Menu Help
        Menu menuHelp = new Menu("Help");
        MenuItem helpMenuItem = new MenuItem("Help");
        menuHelp.getItems().add(helpMenuItem);

        MenuItem aboutItem = new MenuItem("About");
        menuHelp.getItems().add(aboutItem);

        mainMenuBar.getMenus().addAll(menuFile, menuEdit, menuTools, menuHelp);
    }

    private Stage mainStage;

    @Override
    public void initialize(URL location, ResourceBundle resources) {
        initMenuBar();
        mainWindow.setTop(this.mainMenuBar);
        mainWindow.sceneProperty().addListener((observable, oldValue, newValue) -> {
            if(oldValue==null) {
                if(newValue != null) {
                    mainStage = (Stage)newValue.getWindow();
                }
            }
        });
        mainWindow.sceneProperty().addListener(observable -> {
        });
    }

    @Override
    public EventHandler<WindowEvent> getOnCloseEventHandler() {
        return event -> {
            if(centerController != null) {
                centerController.onClosing();
            }
            System.out.println("Main window is closing using EventHandler");
            if(this.currentGame != null) {
            	this.currentGame.stop();
            }
        };
    }

    @Override
    public void onClosing() {
        System.out.println("Main window is closing");
        System.out.println("Main window is hiding");
        
    }

    @Override
    public void onHiding() {
        if(centerController != null) {
            centerController.onHiding();
        }
    }

    @Override
    public void onShown() {
        System.out.println("Main window is shown");
        if(centerController != null) {
            centerController.onShown();
        }
    }

    @Override
    public void onMinimized() {

    }

    @Override
    public void onMaximized() {

    }
}
