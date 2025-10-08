#ifndef _INPUT_H_
#define _INPUT_H_

struct GLFWwindow;


namespace Input {
  void Init(GLFWwindow* win);
  bool IsKeyDown(int key);
}


#endif