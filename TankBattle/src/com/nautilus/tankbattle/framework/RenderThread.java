package com.nautilus.tankbattle.framework;

import java.util.concurrent.Semaphore;

public class RenderThread extends Thread {
	
	private static final Semaphore mSemaphore = new Semaphore(1);
	
	boolean mDone;
	
	public RenderThread() {
		mDone = false;
	}
	
	@Override
	public void run() {
		try {
			try {
			mSemaphore.acquire();
			}catch(InterruptedException ex0) {
				return;
			}
			guardedRun();
		} catch (InterruptedException ex1) {
			
		} finally {
			mSemaphore.release();
		}
	}
	
	private void guardedRun() throws InterruptedException {
		
	}
}
