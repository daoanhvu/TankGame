package com.nautilus.tankbattle.framework;

public interface Music {
	public void play();
	public void stop();
	public void pause();
	public void setLooping(boolean looping);
	public void setVolume(float vol);
	public boolean isPlaying();
	public boolean isLooping();
	public void dispose();
}
