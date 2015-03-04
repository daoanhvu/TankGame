package com.nautilus.tankbattle.game;

import java.io.IOException;
import java.io.InputStream;

import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Point;
import android.opengl.GLES20;
import android.opengl.GLUtils;
import android.opengl.Matrix;
import android.view.WindowManager;

import com.nautilus.tankbattle.TankApplication;
import com.nautilus.tankbattle.framework.Game;
import com.nautilus.tankbattle.framework.GameObject;
import com.nautilus.tankbattle.framework.ShaderLoader;
import com.nautilus.tankbattle.util.GraphicUtilities;

public class Tank extends GameObject {
	private int hp;
	
	private float velocityX;
	private float velocityY;
	private float velocityZ;
	
	int mNumIndices;
	boolean mUseNormals;
	boolean mUseTexCoords;
	int mVertexCount;
	int mDrawingPrimitive;
	
	private final int stride = 20;
	private final int mPosHandle;
	private final int mNormalHandle;
	private final int mTextureHandle;
	
	private final float[] mModel = new float[16];
	private final float[] mRotationM = new float[16];
	private final float[] mTranslation = new float[16];
	private boolean moving = false;
	private boolean rotating = false;
	
	/**
	 * {  }
	 */
	final int[] bufferIds = {0, 0};
	final int[] textureIds = {0};
	
	private int vertext_attribute_offset;
	
	Runnable runingObject = new Runnable() {
		@Override
		public void run() {
			
		}
	};
	
	public Tank(Game game, int posHandle, int normalHandle, int textureHandler) {
		mPosHandle = posHandle;
		mNormalHandle = normalHandle;
		mTextureHandle = textureHandler;
		
		//Test Data
		float[] vertices = {
				-0.5f, 1.0f, 0.2f, 0, 0,
				0.5f, 1.0f, 0.2f, 0, 0,
				-0.5f, -1.0f, 0.2f, 0, 0,
				0.5f, -1.0f, 0.2f, 0, 0
				};
		short[] indices = {0, 2, 1, 3};
		//
		
		int vertexCount = vertices.length / 5;
		float absS, absT;
		float heighestX = 0.5f;
		float heighestY = 1f;
		float lowestX = -0.5f;
		float lowestY = -1f;
		float vx, vy;
		
		//Generate UV for the map
		//@see: http://paulyg.f2s.com/uv.htm
		float rangeS = (lowestX - heighestX) * -1; //
		float offsetS = -lowestX; //0 - lowest
		float rangeT = (lowestY - heighestY) * -1;
		float offsetT = -lowestY; //0 - lowest
		for(int i=0; i<vertexCount; i++) {
			vx = vertices[i * 5];
			vy = vertices[i*5 + 1];
			absS = vx + offsetS;
			vertices[i * 5 + 3] = absS / rangeS;
			absT = vy + offsetT;
			vertices[i * 5 + 4] = absT / rangeT;
		}
		
		
		AssetManager assetManager = TankApplication.instance.getAssets();
		InputStream inputStream = null;
		try {
			
			inputStream = assetManager.open("tank7.png");
			Bitmap bmp = BitmapFactory.decodeStream(inputStream);
			// Use tightly packed data. Do we need this???
		    GLES20.glPixelStorei ( GLES20.GL_UNPACK_ALIGNMENT, 1 );
			GLES20.glGenTextures(1, textureIds, 0);
			GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
			GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureIds[0]);
			
			GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0);
			
			// Set filtering
			GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
			GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
			//GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST);
			//GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST);
			 
			// Set wrapping mode
			GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_TEXTURE);
			GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_TEXTURE);
			
			bmp.recycle();
		}catch(IOException ex) {
		}finally{
			if(inputStream !=null)
				try {
					inputStream.close();
				} catch (IOException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
		}
		
		GLES20.glGenBuffers(2, bufferIds, 0);
		mVertexCount = 4;
	    ShaderLoader.initVertexBuffer(GLES20.GL_ARRAY_BUFFER, vertices, bufferIds[0]);
	    ShaderLoader.initIndexBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, indices, bufferIds[1]);
	    mDrawingPrimitive = GLES20.GL_TRIANGLE_STRIP;
	    mNumIndices = indices.length;
	    
	    mUseNormals = false;
	}
	
	public void fire(float xt, float yt, float zt) {
		
	}

	@Override
	public void dispose() {
		if(bufferIds[0] <=0 || bufferIds[1]<=0)
			return;
		GLES20.glDeleteBuffers(2, bufferIds, 0);
	    bufferIds[0] = 0;
	    bufferIds[1] = 0;
	    
	    GLES20.glDeleteTextures(1, textureIds, 0);
	    textureIds[0] = 0;
	}

	
	public void render(int uSamplerLoc) {
	    GLES20.glEnable(GLES20.GL_TEXTURE_2D);
	    vertext_attribute_offset = 0;
	    GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, bufferIds[0]);
	    GLES20.glEnableVertexAttribArray(mPosHandle);
		GLES20.glVertexAttribPointer(mPosHandle, 3, GLES20.GL_FLOAT, false, stride, vertext_attribute_offset);
		
		if(mUseNormals) {
			vertext_attribute_offset += 12; //3 * 4;
			GLES20.glEnableVertexAttribArray(mNormalHandle);
			GLES20.glVertexAttribPointer(mNormalHandle, 3, GLES20.GL_FLOAT, false, stride, vertext_attribute_offset);
		}
		
		vertext_attribute_offset += 8; //2 * 4;
		// Load the texture coordinate
	    GLES20.glEnableVertexAttribArray(mTextureHandle );
	    GLES20.glVertexAttribPointer(mTextureHandle, 2, GLES20.GL_FLOAT, false, stride, vertext_attribute_offset);
		
		// Bind the texture
	    GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
	    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureIds[0]);
	    GLES20.glUniform1i(uSamplerLoc, 0);

	    GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, bufferIds[1]);
		GLES20.glDrawElements(mDrawingPrimitive, mNumIndices, GLES20.GL_UNSIGNED_SHORT, 0);
		
		GLES20.glDisable(GLES20.GL_TEXTURE_2D);
		
		GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0);
	    GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, 0);
	    GLES20.glDisableVertexAttribArray(mPosHandle);
	    GLES20.glDisableVertexAttribArray(mNormalHandle);

	}

	@Override
	public void render() {
	
	}

	@Override
	public void update(float deltaTime) {
		if(moving) {
			x += velocityX;
			y += velocityY;
			Matrix.translateM(mTranslation, 0, x, velocityY, z);
		}
		
		if(rotating) {
			x += velocityX;
			y += velocityY;
			Matrix.rotateM(mRotationM, 0, 5f, deltaTime, deltaTime, deltaTime);
		}
		
		Matrix.multiplyMM(mModel, 0, mRotationM, 0, mTranslation, 0);
	}
}
