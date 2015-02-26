package com.nautilus.tankbattle.game;

import android.opengl.GLES20;

import com.nautilus.tankbattle.framework.GameObject;
import com.nautilus.tankbattle.framework.ShaderLoader;

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
	
	private final int stride = 12;
	private final int mPosHandle;
	private final int mNormalHandle;
	
	/**
	 * {  }
	 */
	final int[] bufferIds = {0, 0};
	
	Runnable runingObject = new Runnable() {
		@Override
		public void run() {
			
		}
	};
	
	public Tank(int posHandle, int normalHandle) {
		mPosHandle = posHandle;
		mNormalHandle = normalHandle;
		
		//Test Data
		float[] vertices = {
				-0.5f, 1.0f, 0.2f,
				0.5f, 1.0f, 0.2f,
				-0.5f, -1.0f, 0.2f,
				0.5f, -1.0f, 0.2f
				};
		short[] indices = {0, 2, 1, 3};
		//
		
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
	}

	@Override
	public void render() {
		GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, bufferIds[0]);
		
		GLES20.glEnableVertexAttribArray(mPosHandle);
		GLES20.glVertexAttribPointer(mPosHandle, 3, GLES20.GL_FLOAT, false, stride, 0);                
		
		if(mUseNormals) {
			GLES20.glEnableVertexAttribArray(mNormalHandle);
			GLES20.glVertexAttribPointer(mNormalHandle, 3, GLES20.GL_FLOAT, false, stride, 12);
		}
		
		GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, bufferIds[1]);
		GLES20.glDrawElements(mDrawingPrimitive, mNumIndices, GLES20.GL_UNSIGNED_SHORT, 0);
	
	    GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0);
	    GLES20.glBindBuffer(GLES20.GL_ELEMENT_ARRAY_BUFFER, 0);

	    GLES20.glDisableVertexAttribArray(mPosHandle);
	    GLES20.glDisableVertexAttribArray(mNormalHandle);
	}
}
