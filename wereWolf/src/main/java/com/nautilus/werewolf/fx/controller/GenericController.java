package com.nautilus.werewolf.fx.controller;

import javafx.event.EventHandler;
import javafx.scene.Parent;
import javafx.stage.Stage;
import javafx.stage.WindowEvent;

public abstract class GenericController {

    protected Stage currentStage;
    private Parent loadedRootNode;

    public void setCurrentStage(Stage stage) {
        this.currentStage = stage;
    }

    public abstract EventHandler<WindowEvent> getOnCloseEventHandler();
    public abstract void onClosing();
    public abstract void onHiding();
    public abstract void onShown();
    public abstract void onMinimized();
    public abstract void onMaximized();

    public Parent getLoadedRootNode() {
        return loadedRootNode;
    }

    public void setLoadedRootNode(Parent loadedRootNode) {
        this.loadedRootNode = loadedRootNode;
    }
}
