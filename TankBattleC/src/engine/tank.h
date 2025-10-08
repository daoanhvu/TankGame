#ifndef _TANK_H_
#define _TANK_H_

#include <glm/glm.hpp>

typedef struct tagTank {
  int id;
  glm::vec2 position;
  float rot;
  float rotSpeed;
  float speed;
  int hp;
  int ammunition;
  glm::vec2 half{20.0f, 28.0f}; // collision box half-size
} Tank;

#endif