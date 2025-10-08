#include "collision.h"
#include <algorithm>
#include <cmath>


static inline void sweepAxis(const Tilemap& map, float& coord, 
  float otherCoord, float halfAxis, float otherHalf, float delta, bool horizontal) {
  if (delta == 0.0f) {
    return;
  }

  float sign = delta > 0.0 ? 1.0f : -1.0f;
  float t = coord + delta;
  float minOther = otherCoord - otherHalf;
  float maxOther = otherCoord + otherHalf;
  int o0 = (int)std::floor(minOther-0.0001f / map.tileSize);
  int o1 = (int)std::floor((maxOther-0.0001f) / map.tileSize);
  int startTile = (int)std::floor(((coord + sign*halfAxis))/map.tileSize);
  int endTile = (int)std::floor(((t + sign*halfAxis))/map.tileSize);

  if (sign > 0.0f) {
    for (int tile = startTile+1; tile<=endTile; ++tile) {
      for (int o=o0; o<=o1; ++o) {
        int tx = horizontal? tile : o;
        int ty = horizontal? o : tile;
        if (map.isSolid(tx,ty)) {
          coord = tile*map.tileSize - sign*halfAxis; // block
          return;
        }
      }
    }
  } else {
    for (int tile = startTile-1; tile>endTile; --tile) {
      for (int o=o0; o<=o1; ++o) {
        int tx = horizontal? tile : o;
        int ty = horizontal? o : tile;
        if (map.isSolid(tx,ty)) {
          coord = (tile+1)*map.tileSize - sign*halfAxis;
          return;
        }
      }
    }
  }
  coord = t;
}

CollisionResult moveAndCollideAABB(const Tilemap& map, glm::vec2 pos, 
    glm::vec2 half, glm::vec2 delta) {
  glm::vec2 p = pos;
  glm::bvec2 hits(false);
  float x = p.x; 
  float y = p.y; 
  float hx = half.x; 
  float hy = half.y;
  float tx = x; 
  float ty = y;
  sweepAxis(map, tx, ty, hx, hy, delta.x, true);
  if (tx != x + delta.x) {
    hits.x = true;
  }

  sweepAxis(map, ty, tx, hy, hx, delta.y, false);
  if (ty != y + delta.y) {
    hits.y = true;
  }

  p.x = tx; 
  p.y = ty;
  return {p, hits};
}