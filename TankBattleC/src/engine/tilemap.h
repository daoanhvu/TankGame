#ifndef _TILEMAP_H_
#define _TILEMAP_H_

#include <string>
#include <unordered_map>
#include <glm/glm.hpp>

class Renderer2D;
class Texture2D;

struct Tilemap {
  int width;
  int height;
  int tileSize = 32;
  uint8_t* tiles = nullptr;
  std::unordered_map<uint8_t, bool> solidMap {};

  ~Tilemap();

  inline uint8_t get(int x, int y) const {
    if(x<0||y<0||x>=width||y>=height) {
      // treat outside as solid
      return 1;
    }
    return tiles[y*width + x];
  }

  bool loadMapFromFile(const std::string& filename);
  void setSolid(int n, const uint8_t* indices);

  /**
   * Solid means tanks can not go through
   */
  inline bool isSolid(int x, int y) const {
    uint8_t idx = get(x, y);
    auto it = solidMap.find(idx);
    return it != solidMap.end() ? it->second : false;
  }

  void draw(Renderer2D& r, const glm::mat4& vp) const;

};

#endif
