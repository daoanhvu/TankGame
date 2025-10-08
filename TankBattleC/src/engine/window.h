#ifndef _WINDOW_H_
#define _WINDOW_H_



class Window {
  private:
    

  public:
    Window(int width, int height, const char* title);
    ~Window();

    bool shouldClose();

    void swapBuffer();
    void pollEvents();
};

#endif