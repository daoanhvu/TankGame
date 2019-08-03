package com.nautilus.werewolf;

import com.nautilus.werewolf.fx.controller.GenericController;
import javafx.fxml.FXMLLoader;
import javafx.geometry.Rectangle2D;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.stage.Screen;
import javafx.stage.Stage;


public class Application extends javafx.application.Application {
    public static void main(String[] args) {
        launch(args);
    }

    @Override
    public void start(Stage primaryStage) throws Exception {
        FXMLLoader fxmlLoader = new FXMLLoader();
        fxmlLoader.setLocation(getClass().getResource("/mainapp.fxml"));
        Parent root = fxmlLoader.load();
        Rectangle2D screenSize = Screen.getPrimary().getBounds();
        //System.out.println(screenSize.getWidth() + ", " + screenSize.getHeight());
        Scene scene = new Scene(root, screenSize.getWidth(), screenSize.getHeight());
        primaryStage
                .iconifiedProperty()
                .addListener( bl -> {

                });
        primaryStage.setTitle("WereWolf 1.0");
        primaryStage.setScene(scene);
        GenericController ctrl = fxmlLoader.getController();
        primaryStage.setOnCloseRequest(ctrl.getOnCloseEventHandler());
        primaryStage.setOnShown(e -> ctrl.onShown());
        primaryStage.setOnHiding(e -> ctrl.onHiding());
        primaryStage.show();
    }
}
