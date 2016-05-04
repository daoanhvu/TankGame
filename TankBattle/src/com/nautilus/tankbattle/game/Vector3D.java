package com.nautilus.tankbattle.game;

import android.opengl.Matrix;

public class Vector3D {
	float mX;
	float mY;
	float mZ;
	
	public Vector3D() {}
	
	public Vector3D(final Vector3D v) {
		mX = v.mX;
		mY = v.mY;
		mZ = v.mZ;
	}
	
	public Vector3D(float x, float y, float z) {
		mX = x;
		mY = y;
		mZ = z;
	}
	
	public void set(float x, float y, float z) {
		mX = x;
		mY = y;
		mZ = z;
	}
	
	public void normalize() {
		float d = mX*mX + mY*mY + mZ*mZ;
		float l = (float)Math.sqrt(d);
		mX /= l;
		mY /= l;
		mZ /= l;
	}
	
	public void add(Vector3D vector) {
		mX += vector.mX;
		mY += vector.mY;
		mZ += vector.mZ;
	}

	/*
	 * public void add(float x, float y) { x += x; y += y; }
	 */
	public void sub(Vector3D vector) {
		mX -= vector.mX;
		mY -= vector.mY;
		mZ -= vector.mZ;
	}

	public void subAt(Vector3D vector) {
		mX = vector.mX - mX;
		mY = vector.mY - mY;
		mZ = vector.mZ - mZ;
	}
	
	public void mul(float scalar) {
		mX *= scalar;
		mY *= scalar;
		mZ *= scalar;
	}
	
	public float dot(Vector3D v) {
		return (mX*v.mX + mY*v.mY + mZ*v.mZ);
	}
	
	public Vector3D cross(Vector3D v) {
		Vector3D result = new Vector3D(mY*v.mZ - mZ*v.mY, mZ*v.mX - mX*v.mZ, mX*v.mY - mY*v.mX);
		return result;
	}
	
	public void rot(float alphaInRadian, float xaxis, float yaxis, float zaxis) {
		//Step 0: Normalize rotation axis;
		float d = xaxis*xaxis + yaxis*yaxis + zaxis*zaxis;
		float l = (float)Math.sqrt(d);
		float a = xaxis/l;
		float b = yaxis/l;
		float c = zaxis/l;
		d = (float)Math.sqrt(b*b + c*c);
		
		//Step 1: Build Translation matrices T and T(-1)
		float[] T1 = {
				1, 		0, 		0, 		0,
				0, 		1, 		0, 		0,
				0, 		0, 		1, 		0,
				-xaxis, -yaxis, -zaxis, 1
		};
		
		float[] T = {
				1, 		0, 		0, 		0,
				0, 		1, 		0, 		0,
				0, 		0, 		1, 		0,
				xaxis, yaxis, zaxis, 	1
		};
		
		float cost = c / d;
		float sint = b / d;
		
		//Step 2: Build Rotate X matrice Rx Rx(-1)
		float[] Rx = {
				1, 		0, 		0, 		0,
				0, 		c/d, 	b/d,	0,
				0, 		-b/d,	c/d,	0,
				0, 		0, 		0,		1
		};
		
		float[] Rx1 = {
				1, 		0, 		0, 		0,
				0, 		c/d, 	-b/d,	0,
				0, 		b/d,	c/d,	0,
				0, 		0, 		0,		1
		};
		
		//Step 3: build Rotate Y matrice Ry Ry(-1)
		float[] Ry = {
				d, 	0, 	a, 	0,
				0, 	1, 	0,	0,
				-a, 0,	d,	0,
				0, 	0, 	0,	1
		};
		
		float[] Ry1 = {
				d, 	0, 	-a,	0,
				0, 	1, 	0,	0,
				a, 	0,	d,	0,
				0, 	0, 	0,	1
		};
		
		//Step 4: build Rotate Z matrice Rz
		float[] Rz = {
				cost, 	sint, 	0,		0,
				-sint, 	cost, 	0,		0,
				0, 		0,		1,		0,
				0, 		0, 		0,		1
		};
		
		float[] temp1 = new float[16];
		float[] temp2 = new float[16];
		Matrix.multiplyMM(temp1, 0, T, 0, Rx1, 0);
		Matrix.multiplyMM(temp2, 0, temp1, 0, Ry1, 0);
		Matrix.multiplyMM(temp1, 0, temp2, 0, Rz, 0);
		Matrix.multiplyMM(temp2, 0, temp1, 0, Ry, 0);
		Matrix.multiplyMM(temp1, 0, temp2, 0, Rx, 0);
		Matrix.multiplyMM(temp2, 0, temp1, 0, T1, 0);
		float[] rhsVec = {mX, mY, mZ, 0};
		float[] result = new float[4];
		Matrix.multiplyMV(result, 0, temp2, 0, rhsVec, 0);
		
		mX = result[0];
		mY = result[1];
		mZ = result[2];
	}
}
