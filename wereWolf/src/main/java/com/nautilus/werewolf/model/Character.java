package com.nautilus.werewolf.model;

import com.nautilus.werewolf.common.Constants;
import com.nautilus.werewolf.fx.graphics.Card;

public abstract class Character {

    private String playerName;
    private float point;
    protected boolean alive;
    protected ActionTrigger actionTrigger;
    protected Card card;

    public float getPoint() {
        return point;
    }

    public void setPoint(float point) {
        this.point = point;
    }

    public String getPlayerName() {
        return playerName;
    }

    public void setPlayerName(String playerName) {
        this.playerName = playerName;
    }

    public boolean isAlive() {
        return alive;
    }

    public void setAlive(boolean alive) {
        this.alive = alive;
    }

    public ActionTrigger getActionTrigger() {
        return actionTrigger;
    }

    public void setActionTrigger(ActionTrigger actionTrigger) {
        this.actionTrigger = actionTrigger;
    }

    public Card getCard() {
        return card;
    }

    public void setCard(Card card) {
        this.card = card;
    }

    /**
     *
     * @param killedBy
     * @param time DAY or NIGHT
     */
    public abstract void beKilled(Constants.PARTY killedBy, int time);

    public boolean toBeSeen() {
        return false;
    }
}
