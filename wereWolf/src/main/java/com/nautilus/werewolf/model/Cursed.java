package com.nautilus.werewolf.model;

import com.nautilus.werewolf.common.Constants;

public class Cursed extends Character {

    private Constants.PARTY party;

    @Override
    public void beKilled(Constants.PARTY killedBy, int time) {

    }

    public Constants.PARTY getParty() {
        return party;
    }

    public void setParty(Constants.PARTY party) {
        this.party = party;
    }
}
