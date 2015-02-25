package com.nautilus.tankbattle.framework;

import java.io.IOException;
import java.io.InputStream;

import android.content.Context;
import android.content.res.AssetManager;

public class FileIO {
	public InputStream readAsset(String fileName, Context context) {
		AssetManager assetManager = context.getAssets();
		try {
			InputStream inputStream = assetManager.open(fileName);
			return inputStream;
		}catch(IOException ex) {
			return null;
		}
	}
	
	public InputStream readFile(String fileName) {
		return null;
	}
}
