package com.nautilus.werewolf.model;

import com.nautilus.werewolf.common.Constants;

public class DireWolf extends Character {

    private Character partner;

    @Override
    public void beKilled(Constants.PARTY killedBy, int time) {

    }

    public void selectPartner(Character character) {
        partner = character;
    }
}
