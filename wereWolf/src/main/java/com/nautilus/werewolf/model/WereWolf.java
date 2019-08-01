package com.nautilus.werewolf.model;

import com.nautilus.werewolf.common.Constants;

public class WereWolf extends Character {

    @Override
    public void beKilled(Constants.PARTY killedBy, int time) {

    }

    @Override
    public boolean toBeSeen() {
        return true;
    }
}
