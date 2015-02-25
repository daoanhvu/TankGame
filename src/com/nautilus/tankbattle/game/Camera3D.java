package com.nautilus.tankbattle.game;

import com.nautilus.tankbattle.util.NativeTester;

public class Camera3D {
	
	static {
		NativeTester nativeTester = new NativeTester();
		if (nativeTester.isNeon()) {
			System.loadLibrary("tankbattle-neon");
		} else {
			System.loadLibrary("tankbattle");
		}
	}
	
	private long nativeCamera = 0;
	
	private float[] Ow0 = {0, 0, 0, 1};
	private float[] Xw0 = {2, 0, 0, 1};
	private float[] Yw0 = {0, 2, 0, 1};
	private float[] Zw0 = {0, 0, 2, 1};
     
    private float eyeX = 0f, eyeY = 0f, eyeZ = -6.0f;
    private float centerX = 0, centerY = 0, centerZ = 0;
    
    //These are used for 
    private float scaleX, scaleY;
    private float XScreen0, YScreen0;
    
    public Camera3D() {
    	nativeCamera = initCamera();
    }
    
    /** Viewport attributes */
    private int left, right, top, bottom;
    
    private float[] p0 = {0, 0, 0};
	private float[] p = {0, 0, 0};
	private float[] p1 = {0, 0, 0};
	private float[] p2 = {0, 0, 0};
	private float[] pw0 = {0, 0, 0, 1};
	private float[] pw1 = {0, 0, 0, 1};
	private float[] pw2 = {0, 0, 0, 1};
	
	private native long initCamera();
	private native void lookAt(long address, float ex, float ey, float ez,
			float cx, float cy, float cz, float ux, float uy, float uz);
	private native void perspective(long address, int l, int r, int t, int b,
			float fov, float near, float far);
	private native void project(long address, float[] out, float objX, float objY, float objZ);
	private native void projectOrthor(long address, float[] out, float objX, float objY, float objZ);
	private native void rotate(long address, float yawR, float pitchR, float roll);
	private native void moveAlongForward(long address, float distance);
	private native void jniRelease(long address);
	
	public void lookAt(float ex, float ey, float ez,
			float cx, float cy, float cz, float ux, float uy, float uz) {
		eyeX = ex;
		eyeY = ey;
		eyeZ = ez;
		lookAt(nativeCamera, ex, ey, ez, cx, cy, cz, ux, uy, uz);
	}
	
	public void perspective(int l, int r, int t, int b,
			float fov, float near, float far) {
		left = l;
		right = r;
		top = t;
		bottom = b;
		perspective(nativeCamera, l, r, t, b, fov, near, far);
	}
	
	public void project(float[] out, float objX, float objY, float objZ) {
		project(nativeCamera, out, objX, objY, objZ);
	}
	public void projectOrthor(float[] out, float objX, float objY, float objZ) {
		projectOrthor(nativeCamera, out, objX, objY, objZ);
	}
	
	public void rotate(float yawR, float pitchR, float roll) {
		rotate(nativeCamera, yawR, pitchR, roll);
	}
	
	public void moveAlongForward(float distance) {
		moveAlongForward(nativeCamera, distance);
	}
	
	private void release() {
		jniRelease(nativeCamera);
	}
}
