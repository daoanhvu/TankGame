#include "engine.h"
#include "input.h"

Engine::Engine() {

}

Engine::~Engine() {

}

bool Engine::initialize(EngineConfiguration& config) {
  if (!glfwInit()) {
    return false;
  }

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR,3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR,3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

  windowWidth = config.width;
  windowHeight = config.height;

  window = glfwCreateWindow(windowWidth, windowHeight, config.windowTitle.c_str(), nullptr, nullptr);
  if (!window) {
    glfwTerminate(); 
    return false; 
  }
  glfwMakeContextCurrent(window);
  glfwSwapInterval(1); // vsync

  if(!gladLoadGL(glfwGetProcAddress)) {
    glfwTerminate();
    std::fprintf(stderr, "Failed to load OpenGL\n");
    return false;
  }

  Input::Init(window);

  glViewport(0 ,0, windowWidth, windowHeight);

  prevTime = std::chrono::high_resolution_clock::now();

  return true;
}

bool Engine::beginFrame() {
  if(glfwWindowShouldClose(this->window))
    return false;

  glfwPollEvents();

  auto now = std::chrono::high_resolution_clock::now();
  delta = std::chrono::duration<float>(now - prevTime).count();
  prevTime = now;
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
 
  return true;
}

float Engine::deltaTime() {
  return delta;
}

void Engine::endFrame() {
  glfwSwapBuffers(window);
}

void Engine::shutdown() {
  glfwDestroyWindow(window);
  window = nullptr;
  glfwTerminate();
}
   
GLFWwindow* Engine::glWindow() {
  return window;
}