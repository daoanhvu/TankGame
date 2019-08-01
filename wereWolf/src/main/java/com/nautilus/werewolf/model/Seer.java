package com.nautilus.werewolf.model;

import com.nautilus.werewolf.common.Constants;

public class Seer extends Character {

    public boolean see(Character aPlayer) {
        return aPlayer.toBeSeen();
    }

    @Override
    public void beKilled(Constants.PARTY killedBy, int time) {

    }
}
