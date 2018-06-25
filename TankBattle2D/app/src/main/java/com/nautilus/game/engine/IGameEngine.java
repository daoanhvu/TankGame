package com.nautilus.game.engine;

/**
 * Created by nautilus on 5/2/2016.
 */
public interface IGameEngine extends Runnable {

    void start();
    void stop();
    void render();

}
