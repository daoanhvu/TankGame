package com.nautilus.tankbattle.framework;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.ShortBuffer;

import android.opengl.GLES20;
import android.util.Log;

public class ShaderLoader {
	private static final int BYTES_PER_FLOAT = 4;
	private static final int BYTES_PER_SHORT = 2;

	/**
	 * Create and compile a shader with specified type
	 * @param type type of shader (GLES20.GL_VERTEX_SHADER or GLES20.GL_FRAGMENT_SHADER)
	 * @param shaderCode String contains shader code
	 * @return id for the shader
	 */
	public static int loadShader(int type, String shaderCode){
		int shader = GLES20.glCreateShader(type);
		int[] compiled = { 0 };
		if(shader == 0) return 0;
			
		GLES20.glShaderSource(shader, shaderCode);
		GLES20.glCompileShader(shader);
		
		GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0);
        if (compiled[0] == 0) {
            Log.e("ShaderLoader", GLES20.glGetShaderInfoLog(shader));
        }
        return shader;
	}
	
	/**
	 * @param target one of value GLES20.GL_ARRAY_BUFFER or GLES20.GL_ELEMENT_ARRAY_BUFFER
	 */
	public static void initVertexBuffer(int target, float[] data, int bufferId){
		int size = data.length * BYTES_PER_FLOAT;
		FloatBuffer fb = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder()).asFloatBuffer();
		fb.put(data);
		fb.position(0);
		
		GLES20.glBindBuffer(target, bufferId);
		GLES20.glBufferData(target, size, fb, GLES20.GL_STATIC_DRAW);
		GLES20.glBindBuffer(target, 0);
	}
	
	public static void initIndexBuffer(int target, short[] data, int bufferId){
		int size = data.length * BYTES_PER_SHORT;
		ShortBuffer fb = ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder()).asShortBuffer();
		fb.put(data);
		fb.position(0);
		
		GLES20.glBindBuffer(target, bufferId);
		GLES20.glBufferData(target, size, fb, GLES20.GL_STATIC_DRAW);
		GLES20.glBindBuffer(target, 0);
	}
}
