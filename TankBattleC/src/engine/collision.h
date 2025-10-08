#ifndef _COLLISION_H_
#define _COLLISION_H_

#include <glm/glm.hpp>
#include "tilemap.h"

typedef struct tagCollisionResult {
  glm::vec2 pos;
  glm::bvec2 hitAxis; // true if collided on axis
} CollisionResult;

// Move an AABB through the tilemap with separable axis resolution.
CollisionResult moveAndCollideAABB(const Tilemap& map, glm::vec2 pos, glm::vec2 half, glm::vec2 delta);

#endif