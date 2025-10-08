#include "input.h"
#include <GLFW/glfw3.h>

static GLFWwindow* gWin = nullptr;
void Input::Init(GLFWwindow* win) {  
  gWin = win; 
}

bool Input::IsKeyDown(int key) { 
  return gWin && glfwGetKey(gWin,key)==GLFW_PRESS; 
}