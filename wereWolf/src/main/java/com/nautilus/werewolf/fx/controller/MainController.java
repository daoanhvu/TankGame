package com.nautilus.werewolf.fx.controller;

import com.nautilus.werewolf.fx.FXHelper;
import javafx.application.Platform;
import javafx.event.EventHandler;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.control.Menu;
import javafx.scene.control.MenuBar;
import javafx.scene.control.MenuItem;
import javafx.scene.layout.BorderPane;
import javafx.stage.Stage;
import javafx.stage.WindowEvent;

import java.io.IOException;
import java.net.URL;
import java.util.ResourceBundle;

public class MainController extends GenericController implements Initializable {

    private MenuBar mainMenuBar;

    @FXML
    private BorderPane mainWindow;

    private GenericController centerController;

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
        MenuItem vehicleSimulator = new MenuItem("Vehicle Simulator");
        MenuItem migrateSimulator = new MenuItem("Migrate Simulator");
        MenuItem exportLiveEventItem = new MenuItem("Export Live VehicleLiveEvent");
        menuTools.getItems().add(vehicleSimulator);
        menuTools.getItems().add(migrateSimulator);
        menuTools.getItems().add(exportLiveEventItem);
        vehicleSimulator.setOnAction(t -> {
            try {
                if(mainWindow.getCenter() != null && centerController != null) {
                    centerController.onClosing();
                }

                MainController.this.centerController = FXHelper.loadComponentFromFXML(mainStage, "/vehiclesimulator.fxml");
                mainWindow.setCenter(centerController.getLoadedRootNode());
            } catch (IOException e) {
                e.printStackTrace();
            }
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
            //
        };
    }

    @Override
    public void onClosing() {
        System.out.println("Main window is closing");
    }

    @Override
    public void onHiding() {
        if(centerController != null) {
            centerController.onHiding();
        }
        System.out.println("Main window is hiding");
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
