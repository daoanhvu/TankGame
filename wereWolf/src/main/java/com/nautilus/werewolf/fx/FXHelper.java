package com.nautilus.werewolf.fx;

import com.nautilus.werewolf.fx.controller.GenericController;
import javafx.event.EventHandler;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.stage.Stage;
import javafx.stage.WindowEvent;

import java.io.IOException;

public final class FXHelper {

    public static void launchSceen(Stage stage, String fxmlName, String title, int width, int height) throws IOException {
        FXMLLoader fxmlLoader = new FXMLLoader();
        fxmlLoader.setLocation(FXHelper.class.getResource(fxmlName));
        Parent rootNode = fxmlLoader.load();
        Scene scene = new Scene(rootNode, width, height);
        Stage fxstage = stage ==  null ? new Stage() : stage;
        GenericController controller = fxmlLoader.getController();
        controller.setLoadedRootNode(rootNode);
        EventHandler<WindowEvent> onCloseEventHandler = controller.getOnCloseEventHandler();
        if(onCloseEventHandler != null) {
            fxstage.setOnCloseRequest(onCloseEventHandler);
        }
        controller.setCurrentStage(fxstage);
        fxstage.setTitle(title);
        fxstage.setScene(scene);
        fxstage.show();
    }

    public static GenericController loadComponentFromFXML(Stage stage, String fxmlName) throws IOException {
        FXMLLoader fxmlLoader = new FXMLLoader();
        fxmlLoader.setLocation(FXHelper.class.getResource(fxmlName));
        Parent root = fxmlLoader.load();
        GenericController controller = fxmlLoader.getController();
        controller.setLoadedRootNode(root);
        if(stage != null) {
            stage.setOnShown(e -> controller.onShown());
            stage.setOnHiding(e -> controller.onHiding());
            stage.setOnCloseRequest(controller.getOnCloseEventHandler());
        }
        return controller;
    }

}
