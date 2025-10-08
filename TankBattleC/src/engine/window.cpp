#include "window.h"
#include <iostream>

Window::Window(int width, int height, const char* title) {
  if (!glfwInit()) {
    std::cerr << "Failed to initialize GLFW" << std::endl;
    return;
  }

  // Set GLFW options
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);


  this->window = glfwCreateWindow(width, height, title, nullptr, nullptr);

  // Make the window's context current
  glfwMakeContextCurrent(window);

  // Set the callback functions
  // glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
  // glfwSetCursorPosCallback(window, mouse_callback);
  // glfwSetMouseButtonCallback(window, mouse_button_callback);

  glViewport(0, 0, width, height);
}

Window::~Window() {
  glfwDestroyWindow(this->window);
  glfwTerminate();
}

bool Window::shouldClose() {
  return glfwWindowShouldClose(window);
}

void Window::swapBuffer() {
  glfwSwapBuffers(this->window);
}

void Window::pollEvents() {
  glfwPollEvents();
}
