#ifndef _ENGINE_H_
#define _ENGINE_H_
#include <string>
#include <chrono>
#include <glad/gl.h>
#include <GLFW/glfw3.h>

typedef struct tagEngineConfiguration {
  int width;
  int height;
  std::string windowTitle = "Nautilus Tank Game";
} EngineConfiguration;

class Engine {
  private:
    int windowWidth;
    int windowHeight;
    GLFWwindow* window;
    std::chrono::high_resolution_clock::time_point prevTime;
    float delta;
  public:
    Engine();
    ~Engine();
    bool initialize(EngineConfiguration& config);
    float deltaTime();

    bool beginFrame();
    void endFrame();
    void shutdown();
    GLFWwindow* glWindow();
};

#endif
