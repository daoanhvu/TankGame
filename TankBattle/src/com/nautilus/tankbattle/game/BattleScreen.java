package com.nautilus.tankbattle.game;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

import android.graphics.Bitmap;
import android.opengl.GLES20;
import android.opengl.GLUtils;
import android.opengl.Matrix;
import android.util.Log;

import com.nautilus.tankbattle.framework.FileIO;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.LightSource;
import com.nautilus.tankbattle.framework.Screen;
import com.nautilus.tankbattle.framework.ShaderLoader;
import com.nautilus.tankbattle.util.GraphicUtilities;

/**
 * 
 * @author Dell
 * @see http://archive.gamedev.net/archive/reference/articles/article1256.html
 * @see @see: http://paulyg.f2s.com/uv.htm
 */
public class BattleScreen extends Screen {
	
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
	
	private List<Tank> myTanks = new ArrayList<Tank>();
	private List<Tank> enemyTanks = new ArrayList<Tank>();
	
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
	
	private float mapWidth;
	private float mapLength;
	
	//number of piece of tile
	private int mapRow;
	private int mapColumn;
	private short[][] mapData;
	
	private int[] mapBufferIds = null;
	private int[] mapTextureId = new int[1];
	private final float[] bgColor = new float[4];
	
	private LightSource lightSource;

	public BattleScreen(Game game) {
		super(game);
		init();
	}

	@Override
	public void update(float deltaTime) {
		int i;
		for(i=0; i<myTanks.size(); i++) {
			myTanks.get(i).update(deltaTime);
		}
		
		for(i=0; i<enemyTanks.size(); i++) {
			enemyTanks.get(i).update(deltaTime);
		}
	}

	@Override
	public void present(float deltaTime) {
		int i;
		
		GLES20.glClearColor(bgColor[0], bgColor[1], bgColor[2], bgColor[3]);
		
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
		
		for(i=0; i<myTanks.size(); i++) {
			myTanks.get(i).render();
		}
		
		for(i=0; i<enemyTanks.size(); i++) {
			enemyTanks.get(i).render();
		}
	}

	@Override
	public void pause() {
		
	}

	@Override
	public void resume() {
		
	}

	@Override
	public void dispose() {
		if(mapBufferIds != null) {
			GLES20.glDeleteBuffers(2, mapBufferIds, 0);
			GLES20.glDeleteTextures(1, mapBufferIds, 2);
		}
	}

	private void init() {
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

	public void onSurfaceChanged(int width, int height) {
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
	
	private void loadMap() {
		FileIO fileIO = game.getFileIO();
		InputStream inputStream = fileIO.readAsset("mapData.txt");
		float stepX, stepY;
		float x, y;
		int verticeCount;
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
				int verticeColumn = mapColumn + 1;
				int verticeRow = mapRow + 1;
				
				stepX = mapWidth/mapColumn;
				stepY = mapLength/mapRow;
				
				verticeCount = mapRow * mapColumn * 4;
				float[] mapVertices = new float[verticeCount * 5];
				
				float heighestX = mapWidth/2;
				float heighestY = mapLength/2;
				float lowestX = -mapWidth/2;
				float lowestY = -mapLength/2;
				float rangeS = (lowestX - heighestX) * -1; //
				float offsetS = -lowestX; //0 - lowest
				float rangeT = (lowestY - heighestY) * -1;
				float offsetT = -lowestY; //0 - lowest
				float absS, absT, t;
				
				y = heighestY;
				for(int i=0; i<verticeRow; i++) {
					line = br.readLine();
					mapValues = line.split(" ");
					x = lowestX;
					//absT = y + offsetT;
					t = (y + offsetT)/rangeT;
					for(int j=0; j<verticeColumn; j++) {
						absS = x + offsetS;
						mapVertices[(i*verticeColumn + j)*5] = x;
						mapVertices[(i*verticeColumn + j)*5 + 1] = y;
						mapVertices[(i*verticeColumn + j)*5 + 2] = 0;
						mapVertices[(i*verticeColumn + j)*5 + 3] = absS / rangeS;
						//mapVertices[(i*verticeColumn + j)*5 + 4] = absT / rangeT;
						mapVertices[(i*verticeColumn + j)*5 + 4] = t;
						x += stepX;
					}
					
					y -= stepY;
				}
				inputStream.close();
				
				mapBufferIds = new int[2];
				
				Bitmap bmp = GraphicUtilities.buidMap(mapData, ((TankGame)game).tiles);
				GLES20.glGenBuffers(2, mapBufferIds, 0);
				//init vertex buffer
				ShaderLoader.initVertexBuffer(GLES20.GL_ARRAY_BUFFER, mapVertices, mapBufferIds[0]);
				ShaderLoader.initIndexBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, mapIndice, mapBufferIds[1]);
				//Generate buffer
				// Use tightly packed data. Do we need this???
				GLES20.glPixelStorei ( GLES20.GL_UNPACK_ALIGNMENT, 1 );
				GLES20.glGenTextures(1, mapTextureId, 0);
				GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
				GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mapTextureId[0]);
				GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0);
				// Set filtering
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
				// Set wrapping mode
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_TEXTURE);
				GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_TEXTURE);
				bmp.recycle();
			}catch(Exception ex){
				Log.e("BattleScreen", ex.getMessage());
			}
		}
	}
	
	private void drawMap() {
		GLES20.glEnable(GLES20.GL_TEXTURE_2D);
		
		GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, mapBufferIds[0]);
		GLES20.glEnableVertexAttribArray(POSITION_HANDLE);
		GLES20.glVertexAttribPointer(POSITION_HANDLE, 3, GLES20.GL_FLOAT, false, stride, 0);
		
		// Load the texture coordinate
	    GLES20.glEnableVertexAttribArray(TEXTURE_HANDLE );
	    GLES20.glVertexAttribPointer(TEXTURE_HANDLE, 2, GLES20.GL_FLOAT, false, stride, 12);
		
		// Bind the texture
	    GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
	    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, mapTextureId[0]);
	    GLES20.glUniform1i(uSamplerLoc, 0);

	    GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, mapBufferIds[1]);
		GLES20.glDrawElements(GLES20.GL_TRIANGLE_STRIP, mapIndice.length, GLES20.GL_UNSIGNED_SHORT, 0);
		
		GLES20.glDisable(GLES20.GL_TEXTURE_2D);

	}
}
