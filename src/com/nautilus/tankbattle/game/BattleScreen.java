package com.nautilus.tankbattle.game;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import android.graphics.Bitmap;
import android.opengl.GLES20;
import android.opengl.GLUtils;
import android.opengl.Matrix;
import android.util.Log;

import com.nautilus.tankbattle.framework.FileIO;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.LightSource;
import com.nautilus.tankbattle.framework.Pixmap;
import com.nautilus.tankbattle.framework.Screen;
import com.nautilus.tankbattle.framework.ShaderLoader;
import com.nautilus.tankbattle.util.GraphicUtilities;

/**
 * 
 * @author Dell
 * @see http://archive.gamedev.net/archive/reference/articles/article1256.html
 * @see @see: http://paulyg.f2s.com/uv.htm
 */
public class BattleScreen extends Screen implements Pixmap {
	
	/** Additional constants. */
	private static final int POSITION_HANDLE = 0;
	private static final int NORMAL_HANDLE = 1;
	private static final int COLOR_HANDLE = 2;
	private static final int TEXTURE_HANDLE = 3;
	
	public static final int BYTES_PER_FLOAT = 4;
	public static final int BYTES_PER_SHORT = 2;
	
	private final float[] mPerspectiveMatrix = new float[16];
	private final float[] mOrthoMatrix = new float[16];
	private final float[] mModelView = new float[16];
	private final float[] mViewMatrix = new float[16];
	private final float[] mMVP = new float[16];
	private final float[] mModel = new float[16];
	private final float[] mRotationM = new float[16];
	//Camera data
	float eyeX = 0, eyeY = -4.5f, eyeZ = 2f;
	float lookX = 0, lookY = 0, lookZ = 0;
	float upX = 0.0f, upY = 1.0f, upZ = 0.0f;
		
	//OpenGL handle
	private int mProgram;
	private int uMVPHandle;
	private int uModelViewMatrixHandle;
	private int uSamplerLoc;
	
	private static final String kVertexShader =
	        "precision mediump float;                       \n" +
	        "uniform mat4 uMVP;                          	\n" +
	        "attribute vec3 aPosition;                   	\n" +
	        "attribute vec2 aTexCoord;						\n" +
	        "varying vec2 vTexCoord;						\n" + 
	        "void main() {                          		\n" +
	        "  gl_Position = uMVP * vec4(aPosition, 1.0); 	\n" +
	        "  vTexCoord = aTexCoord;						\n" +
	        "}";

	private static final String kFragmentShader =
	        "precision mediump float;                   		\n" +
	        "uniform sampler2D uTexture; 						\n" +
	        "varying vec2 vTexCoord;                     		\n" +
	        "void main() {                              		\n" +
	        "    gl_FragColor = texture2D(uTexture, vTexCoord); \n" +
	        "}";
	
	private final int stride = 20;
	private short[] mapIndice = {0, 3, 1, 4, 2, 5};
	
	private Tile[][] tiles;
	private PixmapFormat pixmapFormat;
	
	//map size in dip
	private int width;
	private int height;
	
	private float mapWidth;
	private float mapLength;
	
	//number of piece of tile
	private int mapRow;
	private int mapColumn;
	
	private LightSource lightSource;

	public BattleScreen(Game game) {
		super(game);
	}

	@Override
	public void update(float deltaTime) {
		
	}

	@Override
	public void present(float deltaTime) {
		
	}

	@Override
	public void pause() {
		
	}

	@Override
	public void resume() {
		
	}

	@Override
	public void dispose() {
		if(mapVerticeBufferId != null) {
			GLES20.glDeleteBuffers(2, mapVerticeBufferId, 0);
			GLES20.glDeleteTextures(1, mapVerticeBufferId, 2);
		}
		
		//test data
		if(tank != null)
			tank.dispose();
	}

	@Override
	public int getWidth() {
		return width;
	}

	@Override
	public int getHeight() {
		return height;
	}

	@Override
	public PixmapFormat getFormat() {
		return pixmapFormat;
	}

	@Override
	public void onSurfaceCreated(GL10 gl, EGLConfig config) {
		//GLES20.glClearColor(backColor[0], backColor[1], backColor[2], backColor[3]);
		GLES20.glClearColor(0.7f, 0.7f, 0.7f, 1.0f);
		//Background color
		GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT | GLES20.GL_DEPTH_BUFFER_BIT);
		//GLES20.glEnable(GLES20.GL_CULL_FACE);
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        
        //prepare shader and GL program
      	int vertextSharder = ShaderLoader.loadShader(GLES20.GL_VERTEX_SHADER, kVertexShader);
      	int fragmentSharder = ShaderLoader.loadShader(GLES20.GL_FRAGMENT_SHADER, kFragmentShader);
      		
      	if (vertextSharder == 0 || fragmentSharder == 0) {
      		Log.e("BattleScreen", "Load shaders failed!");
      		return;
      	}
      		
      	mProgram = GLES20.glCreateProgram();
      	GLES20.glAttachShader(mProgram, vertextSharder);
      	GLES20.glAttachShader(mProgram, fragmentSharder);
      		
      	//IMPORTANT: set position for attribute
      	GLES20.glBindAttribLocation(mProgram, POSITION_HANDLE,"aPosition");
      	GLES20.glBindAttribLocation(mProgram, NORMAL_HANDLE, "aNormal");
      	GLES20.glBindAttribLocation(mProgram, COLOR_HANDLE, "aColor");
      	GLES20.glBindAttribLocation(mProgram, TEXTURE_HANDLE, "aTexCoord");
      		
      	GLES20.glLinkProgram(mProgram);
      		
      	int[] linked = { 0 };
        GLES20.glGetProgramiv(mProgram, GLES20.GL_LINK_STATUS, linked, 0);
        if (linked[0] == 0) {
        	Log.e("BattleScreen", "Linking shaders failed " + GLES20.glGetProgramInfoLog(mProgram));
            return;
        }
        
        //Set camera position
        Matrix.setLookAtM(mViewMatrix, 0, eyeX, eyeY, eyeZ, lookX, lookY, lookZ, upX, upY, upZ);
        Matrix.setIdentityM(mRotationM, 0);
        Matrix.setIdentityM(mModel, 0);

        loadMap();
	}

	@Override
	public void onSurfaceChanged(GL10 gl, int width, int height) {
		GLES20.glViewport(0, 0, width, height);
		
		float near = 0.1f;
		float far = 9.0f;
		float range = near - far;
		float aspect = (float)width/height;
		float fovy = (float)Math.tan(0.5 * (Math.PI - Math.toRadians(40)));
		
		GLES20.glViewport(0, 0, width, height);
		
		mPerspectiveMatrix[0] = fovy / aspect;
		mPerspectiveMatrix[1] = 0;
		mPerspectiveMatrix[2] = 0;
		mPerspectiveMatrix[3] = 0;

		mPerspectiveMatrix[4] = 0;
		mPerspectiveMatrix[5] = fovy;
		mPerspectiveMatrix[6] = 0;
        mPerspectiveMatrix[7] = 0;

        mPerspectiveMatrix[8] = 0;
        mPerspectiveMatrix[9] = 0; 
        mPerspectiveMatrix[10] = far / range;
        mPerspectiveMatrix[11] = -1;

        mPerspectiveMatrix[12] = 0;
        mPerspectiveMatrix[13] = 0;
        mPerspectiveMatrix[14] = near * far / range;
        mPerspectiveMatrix[15] = 0;
        
        Matrix.orthoM(mOrthoMatrix, 0, -aspect, aspect, -1, 1, -1, 1);
        //Please check
//        for(int i=0; i<16; i++)
//        	mOrthoMatrix[i] = 0;
//        mOrthoMatrix[0] = 2 / width;
//        mOrthoMatrix[5] = -2 / height;
//        mOrthoMatrix[10] = -2/( far - near );
//        mOrthoMatrix[12] = -1;
//        mOrthoMatrix[13] = 1;
//        mOrthoMatrix[14] = - (far + near) / (far - near);
//        mOrthoMatrix[15] = 1;
	}
	
	short[] buildIndicesForTriangleStrip(int yLength, int xLength) {
    	// Now build the index data
    	int numStripsRequired = yLength - 1;
    	int numDegensRequired = 2 * (numStripsRequired - 1);
    	int verticesPerStrip = 2 * xLength;
    	short[] heightMapIndexData = new short[(verticesPerStrip * numStripsRequired) + numDegensRequired];
    	int offset = 0;
    	for (int y = 0; y < yLength - 1; y++) {
    		if (y > 0) {
    			// Degenerate begin: repeat first vertex
    			heightMapIndexData[offset++] = (short)(y * yLength);
    		}
    		for (int x = 0; x < xLength; x++) {
    			// One part of the strip
    			heightMapIndexData[offset++] = (short)((y * yLength) + x);
    			heightMapIndexData[offset++] = (short)(((y + 1) * yLength) + x);
    		}
    		if (y < yLength - 2) {
    			// Degenerate end: repeat last vertex
    			heightMapIndexData[offset++] = (short)(((y + 1) * yLength) + (xLength - 1));
    		}
    	}

    	short[] result = new short[offset];
    	System.arraycopy(heightMapIndexData, 0, result, 0, offset);
    	return result;
    }
	
	private Tank tank;
	private int[] mapVerticeBufferId = null;
	private void loadMap() {
		FileIO fileIO = game.getFileIO();
		InputStream inputStream = fileIO.readAsset("mapData.txt");
		float stepX, stepY;
		float x, y;
		int verticeCount, k;
		if(inputStream != null) {
			try{
				String line;
				String[] mapValues;
				InputStreamReader isr = new InputStreamReader(inputStream);
				BufferedReader br = new BufferedReader(isr);
				mapWidth = Float.parseFloat(br.readLine());
				mapLength = Float.parseFloat(br.readLine());
				
				mapColumn = Integer.parseInt(br.readLine());
				mapRow = Integer.parseInt(br.readLine());
				tiles = new Tile[mapRow][mapColumn];
				
				stepX = mapWidth/mapColumn;
				stepY = mapLength/mapRow;
				
				verticeCount = mapRow * mapColumn * 4;
				float[] mapVertices = new float[verticeCount * 5];
				
				y = mapLength/2;
				k = 0;
				for(int i=0; i<mapRow; i++) {
					line = br.readLine();
					mapValues = line.split(" ");
					x = -mapWidth/2;
					for(int j=0; j<mapColumn; j++) {
						tiles[i][j].cellValue = Short.parseShort(mapValues[j]);
						
						tiles[i][j].vertices[0] = x;
						tiles[i][j].vertices[1] = y;
						tiles[i][j].vertices[2] = 0;
						tiles[i][j].vertices[3] = 0; //s
						tiles[i][j].vertices[4] = 1; //t
						mapVertices[k*5] = tiles[i][j].vertices[0];
						mapVertices[k*5+1] = tiles[i][j].vertices[1];
						mapVertices[k*5+2] = tiles[i][j].vertices[2];
						mapVertices[k*5+3] = tiles[i][j].vertices[3];
						mapVertices[k*5+4] = tiles[i][j].vertices[4];
						k++;
						
						tiles[i][j].vertices[5] = x;
						tiles[i][j].vertices[6] = y - stepY;
						tiles[i][j].vertices[7] = 0;
						tiles[i][j].vertices[8] = 0; //S
						tiles[i][j].vertices[9] = 0; //T
						mapVertices[k*5] = tiles[i][j].vertices[5];
						mapVertices[k*5+1] = tiles[i][j].vertices[6];
						mapVertices[k*5+2] = tiles[i][j].vertices[7];
						mapVertices[k*5+3] = tiles[i][j].vertices[8];
						mapVertices[k*5+4] = tiles[i][j].vertices[9];
						k++;
						
						tiles[i][j].vertices[10] = x + stepX;
						tiles[i][j].vertices[11] = y - stepY;
						tiles[i][j].vertices[12] = 0;
						tiles[i][j].vertices[13] = 1; //S
						tiles[i][j].vertices[14] = 0; //T
						mapVertices[k*5] = tiles[i][j].vertices[10];
						mapVertices[k*5+1] = tiles[i][j].vertices[11];
						mapVertices[k*5+2] = tiles[i][j].vertices[12];
						mapVertices[k*5+3] = tiles[i][j].vertices[13];
						mapVertices[k*5+4] = tiles[i][j].vertices[14];
						k++;
						
						tiles[i][j].vertices[15] = x + stepX;
						tiles[i][j].vertices[16] = y;
						tiles[i][j].vertices[17] = 0;
						tiles[i][j].vertices[18] = 1; //S
						tiles[i][j].vertices[19] = 1; //T
						mapVertices[k*5] = tiles[i][j].vertices[15];
						mapVertices[k*5+1] = tiles[i][j].vertices[16];
						mapVertices[k*5+2] = tiles[i][j].vertices[17];
						mapVertices[k*5+3] = tiles[i][j].vertices[18];
						mapVertices[k*5+4] = tiles[i][j].vertices[19];
						k++;
						
						x += stepX;
					}
					
					y -= stepY;
				}
				
				mapVerticeBufferId = new int[1];
				GLES20.glGenBuffers(1, mapVerticeBufferId, 0);
				//init vertex buffer
				ShaderLoader.initVertexBuffer(GLES20.GL_ARRAY_BUFFER, mapVertices, mapVerticeBufferId[0]);
				tank = new Tank(game, POSITION_HANDLE, 0, TEXTURE_HANDLE);
				inputStream.close();
			}catch(Exception ex){
				Log.e("BattleScreen", ex.getMessage());
			}
		}
	}
	
	private void drawMap() {
		GLES20.glEnable(GLES20.GL_TEXTURE_2D);
		
		GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, mapVerticeBufferId[0]);
		GLES20.glEnableVertexAttribArray(POSITION_HANDLE);
		GLES20.glVertexAttribPointer(POSITION_HANDLE, 3, GLES20.GL_FLOAT, false, stride, 0);
		
		// Load the texture coordinate
	    GLES20.glEnableVertexAttribArray(TEXTURE_HANDLE );
	    GLES20.glVertexAttribPointer(TEXTURE_HANDLE, 2, GLES20.GL_FLOAT, false, stride, 12);
		
		// Bind the texture
	    GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
	    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mapVerticeBufferId[2]);
	    GLES20.glUniform1i(uSamplerLoc, 0);

	    GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, mapVerticeBufferId[1]);
		GLES20.glDrawElements(GLES20.GL_Q, mapIndice.length, GLES20.GL_UNSIGNED_SHORT, 0);
		
		GLES20.glDisable(GLES20.GL_TEXTURE_2D);

	}

	@Override
	public void onDrawFrame(GL10 gl) {
		GLES20.glClearColor(0.7f, 0.7f, 0.7f, 1.0f);
		GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT | GLES20.GL_DEPTH_BUFFER_BIT);
		GLES20.glUseProgram(mProgram);
		
		uModelViewMatrixHandle = GLES20.glGetUniformLocation(mProgram, "uModelView");
		uMVPHandle = GLES20.glGetUniformLocation(mProgram, "uMVP");
		uSamplerLoc = GLES20.glGetUniformLocation ( mProgram, "uTexture" );
		
		Matrix.multiplyMM(mModelView, 0, mViewMatrix, 0, mModel, 0);
		Matrix.multiplyMM(mMVP, 0, mPerspectiveMatrix, 0, mModelView, 0);
		
		//Setting the camera
		GLES20.glUniformMatrix4fv(uMVPHandle, 1, false, mMVP, 0);
		GLES20.glUniformMatrix4fv(uModelViewMatrixHandle, 1, false, mModelView, 0);
				
		drawMap();		
		tank.render(uSamplerLoc);
		
	}
}

class Tile {
	float x, y;
	float width, height;
	short cellValue;
	float[] vertices = new float[20]; // = 4 vertice * 5 component
}
