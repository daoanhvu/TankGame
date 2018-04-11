package com.nautilus.werewolf.listener;

import com.nautilus.werewolf.game.Card;

public interface GameStatusChangeListener {
    void onAddCard(int totalPoint);
    void onKillCard(final Card card);
}
