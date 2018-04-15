package com.nautilus.werewolf.ui;

import javax.swing.*;
import java.awt.*;

public class GameInfoPane extends JPanel {

    TextArea textArea;

    public GameInfoPane() {
        init();
    }

    private void init() {
        textArea = new TextArea();
        textArea.setEditable(false);
        textArea.setFocusable(false);

        textArea.setPreferredSize(new Dimension(300, 600));

        add(textArea);
    }

}
