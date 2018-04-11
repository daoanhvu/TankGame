package com.nautilus.werewolf.ui;

import java.awt.Canvas;
import java.awt.Color;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.GradientPaint;
import java.awt.Graphics2D;
import java.awt.Paint;
import java.awt.Toolkit;
import java.awt.AlphaComposite;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.awt.event.MouseMotionListener;
import java.awt.event.ComponentListener;
import java.awt.event.ComponentEvent;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferStrategy;
import java.awt.image.BufferedImage;
import java.awt.Image;
import java.util.Timer;
import java.util.TimerTask;

import com.nautilus.werewolf.game.Game;
import com.nautilus.werewolf.util.ImageUtility;


public class StrategyCanvas extends Canvas {

    /**
     *
     */
    private static final long serialVersionUID = 1L;
    private static final int INFO_PANE_WIDTH = 210;
    private static final int INFO_PANE_HEIGHT = 60;

    static {
        //System.setProperty("sun.java2d.trace", "timestamp,log,count");
        System.setProperty("sun.java2d.transaccel", "True");
        //System.setProperty("sun.java2d.opengl", "True");
        // System.setProperty("sun.java2d.d3d", "false"); //default on windows
        // System.setProperty("sun.java2d.ddforcevram", "true");
    }

    protected BufferStrategy		strategy;
    protected final Timer			timer;
    protected TimerTask			renderTask;
    protected Paint				backgroundGradient;
    protected AffineTransform transform = new AffineTransform();

    private int command = 0x00000000;

    private Image imageCtxMenu;

    private boolean isMousePressed = false;
    private boolean isShowCtxMenu = false;
    private int preMouseX = 0, preMouseY = 0;

    private Game game;

    public StrategyCanvas() {
        this.setIgnoreRepaint(true);
        timer = new Timer(); // used for the render thread

        setListeners();
        setPreferredSize(new Dimension(850, 450));
        initImageInfoPane();
    }

    private void initImageInfoPane(){
        BufferedImage inputImage = new BufferedImage(INFO_PANE_WIDTH, INFO_PANE_HEIGHT, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = (Graphics2D)inputImage.getGraphics();
        g.setColor(new Color(22, 23, 225));
        //g.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER, 0.2f));
        g.fillRect(0, 0, inputImage.getWidth(), inputImage.getHeight());
        g.dispose();

        imageCtxMenu = ImageUtility.makeTransparent(inputImage, 0.25f);
        inputImage.flush();
    }

    public void setup() {
        // create the background gradient paint object.
        backgroundGradient = new GradientPaint(0, 0, Color.gray, getWidth(),
                getHeight(), Color.lightGray.brighter());

        // create a strategy that uses two buffers, or is double buffered.
        this.createBufferStrategy(2);

        // get a reference to the strategy object, for use in our render method
        // this isn't necessary but it eliminates a call during rendering.
        strategy = this.getBufferStrategy();

        start();
    }

    public void setGame(Game _game) {
        this.game = _game;
    }

    /**
     * Initialize the render and update tasks, to call the render method, do
     * timing and FPS counting, handling input and canceling existing tasks.
     */
    public void start() {
        // if the render task is already running stop it, this may cause an
        // exception to be thrown if the task is already canceled.
        if (renderTask != null) {
            renderTask.cancel();
        }

        // our main task for handling the rendering and for updating and
        // handling input and movement events. The timer class isn't the most
        // reliable for game updating and rendering but it will suffice for the
        // purpose of this snippet.
        renderTask = new TimerTask() {
            //long	lasttime	= System.currentTimeMillis();
            @Override
            public void run() {

                // get the current system time
                //long time = System.currentTimeMillis();
                // calculate the time passed in milliseconds
                //double dt = (time - lasttime) * 0.001;
                // save the current time
                //lasttime = time;

                //internalRender();
                //==========Start gender==============
                Graphics2D g2 = (Graphics2D)strategy.getDrawGraphics();
                g2.setPaint(backgroundGradient);
                g2.fillRect(0, 0, getWidth(), getHeight());

                render(g2);

                // properly dispose of the backbuffer graphics object. Release resources
                // and cleanup.
                g2.dispose();

                // flip/draw the backbuffer to the canvas component.
                strategy.show();
                // synchronize with the display refresh rate.
                Toolkit.getDefaultToolkit().sync();
                //==========End gender==============
            }
        };

        // These will cap our frame rate but give us unexpected results if our
        // rendering or updates take longer than the 'period' time. It
        // is likely that we could have overlapping calls.
        // timer.schedule(renderTask, 0, 16);
        timer.schedule(renderTask, 0, 30);
    }

    /**
     * Stops the rendering cycle so that the application can close gracefully.
     */
    protected void stop() {
        renderTask.cancel();
    }

    public void render(Graphics2D g2) {
        // TODO: Draw your game world, or scene or anything else here.
        if(game != null) {
            game.draw(g2);
        }

        if(isShowCtxMenu) {
            g2.drawImage(imageCtxMenu, preMouseX, preMouseY, null);
        }
//        drawInfoPane(g2);
    }


    private void setListeners() {
        addMouseListener(new MouseListener(){
            @Override
            public void mouseClicked(MouseEvent evt) {
                isShowCtxMenu = false;
                if(evt.getButton() == MouseEvent.BUTTON3) {
                    isShowCtxMenu = true;
                } else {

                }
            }

            @Override
            public void mouseEntered(MouseEvent arg0) {
                // TODO Auto-generated method stub

            }

            @Override
            public void mouseExited(MouseEvent arg0) {
                // TODO Auto-generated method stub

            }

            @Override
            public void mousePressed(MouseEvent evt) {
                isMousePressed = true;
                preMouseX = evt.getX();
                preMouseY = evt.getY();

            }

            @Override
            public void mouseReleased(MouseEvent arg0) {
                isMousePressed = false;
            }
        });

        addMouseMotionListener(new MouseMotionListener(){

            public void mouseMoved(MouseEvent evt){
            }

            public void mouseDragged(MouseEvent evt) {
                float dx = evt.getX() - preMouseX;
                float dy = evt.getY() - preMouseY;

                //Do something here

                preMouseX = evt.getX();
                preMouseY = evt.getY();
            }
        });

        addComponentListener(new ComponentListener(){
            public void componentHidden(ComponentEvent e){
            }

            public void  componentMoved(ComponentEvent e){
            }

            public void  componentResized(ComponentEvent e){
                //coord.setup(0,0, getWidth(), getHeight());
//					System.out.println(e.getSource() );
                Component thisComponent = e.getComponent();
                int h = thisComponent.getHeight();
                int w = thisComponent.getWidth();


            }

            public void  componentShown(ComponentEvent e){

            }
        });
    }
}
