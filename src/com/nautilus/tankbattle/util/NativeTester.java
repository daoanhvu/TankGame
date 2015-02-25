package com.nautilus.tankbattle.util;

public class NativeTester {
	
	static {
		System.loadLibrary("nativetester");
	}
	
	public native boolean isNeon();
}
