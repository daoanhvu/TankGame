package com.nautilus.tankbattle.framework;

public class Material {
	float[] ambient = {0, 0, 0, 0};
	float[] diffuse = {0, 0, 0, 0};
	float[] specular = {0, 0, 0, 0};
	
	public void setAmbient(float[] amb) {
		ambient[0] = amb[0];
		ambient[1] = amb[1];
		ambient[2] = amb[2];
		ambient[3] = amb[3];
	}
	
	public void setDiffuse(float[] diff) {
		diffuse[0] = diff[0];
		diffuse[1] = diff[1];
		diffuse[2] = diff[2];
		diffuse[3] = diff[3];
	}
	
	public void setSpecular(float[] spec) {
		specular[0] = spec[0];
		specular[1] = spec[1];
		specular[2] = spec[2];
		specular[3] = spec[3];
	}
}
